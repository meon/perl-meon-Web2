#! /usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::Most;
use Test::WWW::Mechanize;

use FindBin qw($Bin);
use Path::Class qw(file);
use lib file($Bin, 'tlib')->stringify;

use_ok('Test::meon::Web2::service')     or die;

my $meon_web2_srv = Test::meon::Web2::service->start;
my $service_url   = $meon_web2_srv->url;
my $mech          = Test::WWW::Mechanize->new();

subtest '/hcheck' => sub {
    $mech->get_ok($service_url . 'hcheck', 'get hcheck')
        or diag($mech->content);
    $mech->content_like(qr/Service-Name: meon::Web2/, 'hcheck content')
        or diag($mech->content);
};

done_testing();
