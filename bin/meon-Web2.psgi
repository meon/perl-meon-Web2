#!/usr/bin/env perl

use strict;
use warnings;

use Plack::Builder;

use meon::Web2;

my $app       = sub {meon::Web2->plack_handler(@_)};

builder {
    enable "Plack::Middleware::ContentLength";
    $app;
};

__END__

=head1 NAME

meon-web2.psgi - PSGI file for meon::Web2

=cut
