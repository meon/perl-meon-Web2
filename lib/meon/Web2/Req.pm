package meon::Web2::Req;

use strict;
use warnings;
use 5.010;

our $VERSION = '0.01';

use base qw(Plack::Request);

use Carp qw(croak);

our $pending_req      = 0;
our @no_cache_headers = ('Cache-Control' => 'private, max-age=0', 'Expires' => '-1');

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

sub resp_text_plain {
    my ($self, @text) = @_;
    return $self->respond(200, [], join("\n", @text));
}

sub respond {
    my ($self, $status, $headers, $payload) = @_;

    return $self->{plack_respond}->([$status, [@no_cache_headers, @$headers], [$payload]]);
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
