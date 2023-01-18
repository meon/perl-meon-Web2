package meon::Web2;

use strict;
use warnings;
use 5.010;
use utf8;

our $VERSION = '0.01';

use Try::Tiny;
use HTTP::Exception;
use Scalar::Util qw(blessed);

use meon::Web2::Req;
use meon::Web2::Config;

our $start_time = time();
our $req_count  = 0;

sub plack_handler {
    my ($self, $env) = @_;

    return sub {
        my $plack_respond = shift;

        $req_count++;
        my $this_req = meon::Web2::Req->new($env, $plack_respond);

        # set process name and last requested path for debug/troubleshooting
        $0 = __PACKAGE__ . ' ' . $this_req->path_info;

        my $resp = try {
            $this_req->resolve_path;
        }
        catch {
            my $e           = $_;
            my $status_code = 503;
            my $status_msg  = 'internal server error: ' . $e;

            if (blessed($e) && $e->can('code') && $e->can('status_message')) {
                $status_code = $e->code;
                $status_msg  = $e->status_message;
            }
            $this_req->respond($status_code, [], $status_msg)
                unless $this_req->responded;
        };

        return $resp;
    };
}

sub hcheck_data {
    return {
        'service_name'     => __PACKAGE__,
        'version'          => __PACKAGE__->VERSION,
        'uptime'           => (time() - $start_time),
        'request_count'    => $req_count,
        'pending_requests' => meon::Web2::Req->get_pending_req,
    };
}

1;

__END__

=head1 NAME

meon::Web2 - flexible file-based web content management system

=head1 SYNOPSYS

    $ plackup -Ilib --port 8089 --server Twiggy bin/meon-Web2.psgi
    $ curl http://localhost:8089/

=head1 DESCRIPTION

This is an early successor of L<meon::Web> build to run using async L<Twiggy> for speed and elegance.

=head1 SEE ALSO

L<meon::Web2::Req> - request-respond class

=head1 CONTRIBUTORS & CREDITS

The following people have contributed to this distribution by committing their
code, sending patches, reporting bugs, asking questions, suggesting useful
advice, nitpicking, chatting on IRC or commenting on my blog (in no particular
order):

    you?

=head1 BUGS

Please report any bugs or feature requests via L<https://github.com/meon/perl-meon-Web2/issues>.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2020 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
