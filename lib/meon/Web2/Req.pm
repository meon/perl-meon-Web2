package meon::Web2::Req;

use strict;
use warnings;
use 5.010;

our $VERSION = '0.01';

use Carp qw(croak);
use Path::Class qw(file dir);
use JSON::XS;
use Try::Tiny;
use HTTP::Exception;
use Plack::MIME;
use AnyEvent::IO qw(aio_load);
use XML::LibXML;
use XML::LibXSLT;

use base qw(Plack::Request);

sub host_url {
    my ($self) = @_;
    # TODO support https
    return $self->{host_url} //= URI->new('http://' . $self->headers->header('Host') . '/');
}

sub want_json {
    my ($self) = @_;
    return $self->{want_json} //= (
        ($self->headers->header('Accept') // '') eq 'application/json'
        ? 1
        : 0
    );
}

our $pending_req      = 0;
our @no_cache_headers = ('Cache-Control' => 'private, max-age=0', 'Expires' => '-1');
our $json             = JSON::XS->new->utf8->pretty->canonical;

sub new {
    my ($class, $env, $plack_respond) = @_;
    croak 'missing args'
        if !$env || !$plack_respond;

    $pending_req++;
    my $self = $class->SUPER::new($env);
    $self->{plack_respond} = $plack_respond;

    return $self;

}

sub DESTROY {
    $pending_req--;
}

sub get_pending_req {
    return $pending_req;
}

sub responded {
    return $_[0]->env->{responded};
}

sub plack_respond {
    return $_[0]->{plack_respond};
}

sub resp_text_plain {
    my ($self, @text) = @_;
    return $self->respond(200, [], join("\n", @text));
}

sub respond {
    my ($self, $status, $headers, $payload) = @_;

    my %headers_as_hash = map {defined($_) ? lc($_) : $_} @$headers;
    my $content_type;

    if ($self->want_json                      # json wanted via accept headerts
        && !ref($payload)                     # payload not a reference
        && !$headers_as_hash{'content-type'}  # and content type is not forced (statics for example)
    ) {
        if ($status >= 400) {
            $payload = {
                'error' => {
                    err_status => $status,
                    err_msg    => $payload,
                }
            };
        }
    }

    # encode any reference as json
    if (ref($payload)) {
        try {
            $payload      = $json->encode($payload);
            $content_type = 'application/json';
        }
        catch {
            $payload = $json->encode('failed to serialize json: ' . $_);
        };
    }

    push(@$headers, ('Content-Type' => ($content_type || 'text/plain')))
        unless ($headers_as_hash{'content-type'});

    my $res = $self->plack_respond->([$status, [@no_cache_headers, @$headers], [$payload]]);
    $self->env->{responded} = 1;
    return $res;
}

sub hostname {
    my ($self) = @_;
    return $self->env->{hostname} //= $self->headers->header('Host') // '';
}

sub hostname_dir {
    my $self = shift;
    $self->env->{hostname_dir} = shift
        if @_;

    unless (defined($self->env->{hostname_dir})) {
        my $hostname_dir_name = meon::Web2::Config->hostname_to_folder($self->hostname);
        $self->env->{hostname_dir} =
            dir(meon::Web2::SPc->srvdir, 'www', 'meon-web2', $hostname_dir_name)->absolute->resolve;
    }
    return $self->env->{hostname_dir};
}

sub resolve_path {
    my ($self) = @_;

    my $rfile_path = $self->path;
    return $self->respond(200, [], meon::Web2->hcheck_data)
        if ($rfile_path eq '/hcheck');

    $rfile_path .= 'index'
        if ($rfile_path =~ m{/$});
    $rfile_path = file($rfile_path);
    $rfile_path->cleanup;

    # xml files
    my $abs_x_file_path = dir($self->hostname_dir, 'content')->file($rfile_path . '.xml');
    return $self->respond_xml_file($abs_x_file_path)
        if -e $abs_x_file_path;

    # static files
    my $abs_s_file_path = dir($self->hostname_dir, 'www')->file($rfile_path);
    HTTP::Exception::404->throw()
        unless (-e $abs_s_file_path);
    return $self->respond_static_file($abs_s_file_path)
        if (-f $abs_s_file_path);
    HTTP::Exception::400->throw(status_message => 'invalid path');
}

sub respond_xml_file {
    my ($self, $abs_x_file_path) = @_;

    my $debug_xslt_file =
        file(meon::Web2::SPc->datadir, 'meon-web', 'template', 'xsl', 'debug.xsl');
    my $xslt_file = file($self->hostname_dir, 'template', 'xsl', 'default.xsl');

    my $xml_parser   = XML::LibXML->new();
    my $template_xml = $xml_parser->parse_string(_fetch_file($xslt_file), $xslt_file->dir . '/');
    my $doc_xml      = $xml_parser->parse_string(_fetch_file($abs_x_file_path));

    my $xslt_proc  = XML::LibXSLT->new();
    my $xslt_trans = $xslt_proc->parse_stylesheet($template_xml);
    my $xslt_res   = $xslt_trans->transform($doc_xml);
    my $content    = $xslt_trans->output_string($xslt_res);

    return $self->respond(200, ['Content-Type' => 'text/html; charset=utf-8'], $content);
}

sub respond_static_file {
    my ($self, $abs_rfile_path) = @_;

    my $content_type = Plack::MIME->mime_type($abs_rfile_path) || 'text/plain';
    my ($content) = _fetch_file($abs_rfile_path);
    return $self->respond(200, ['Content-Type' => $content_type], $content);
}

sub _fetch_file {
    my ($file) = @_;

    my $filedata = AE::cv;
    aio_load(
        $file,
        sub {
            my ($content) = @_
                or die('failed to slurp "' . $file . '"');
            $filedata->($content);
        }
    );

    return $filedata->recv;
}

1;

__END__

=head1 NAME

meon::Web2::Req - http request-response class

=head1 SYNOPSYS

    my $this_req = meon::Web2::Req->new($env, $plack_respond);
    $this_req->resp_text_plain('Hello world!');

=head1 DESCRIPTION

This is an object created for each request handled by L<meon::Web2>.
It's base class is L<Plack::Request> and it will decode hostname and path to corresponding
configuration and folder structure.

=head1 METHODS

=head2 text_plain(@text_lines)

Send text plain response.

=head2 respond($status, $headers, $payload)

Send plack response.

=head2 get_pending_req

Returns number of currently pending async requests.

=cut
