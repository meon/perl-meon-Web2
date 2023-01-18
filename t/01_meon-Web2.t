#! /usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::Most;
use Test::WWW::Mechanize;

use FindBin qw($Bin);
use Path::Class qw(file);
use lib file($Bin, 'tlib')->stringify;
use JSON::XS;

use_ok('Test::meon::Web2::service') or die;

my $meon_web2_srv = Test::meon::Web2::service->start;
my $service_url   = $meon_web2_srv->url;
my $mech          = Test::WWW::Mechanize->new();
my $json          = JSON::XS->new->pretty->canonical->utf8;

subtest '/hcheck' => sub {
    $mech->get_ok($service_url . 'hcheck', 'get hcheck')
        or diag($mech->content)
        and return;
    my $hcheck = eval {$json->decode($mech->content)} // {};
    is($hcheck->{service_name}, 'meon::Web2', 'hcheck service_name');
};

subtest 'localhost' => sub {
    for my $path (qw(non-existing index.xml)) {
        $mech->get($service_url . $path);
        is($mech->status, 404, 'check "' . $path . '" not found');
    }
    for my $path (q{}, qw(index favicon.ico)) {
        $mech->get($service_url . $path);
        is($mech->status, 200, 'check "' . $path . '" found');
    }

    ($mech->get_ok($service_url . 'static/test.txt', 'test.txt')
            and is($mech->content, "123\n", 'test.txt content'))
        or diag($mech->content);
    ($mech->get_ok($service_url . 'test.xml', 'test.xml')
            and is($mech->content, "<test></test>\n", 'test.xml content'))
        or diag($mech->content);

    if ($mech->get_ok($service_url . '/', 'fetch index page')) {
        $mech->title_is('localhost test', 'html rendered');
        $mech->has_tag_like('p', 'meon::Web2 default page', 'check para')
            or diag($mech->content);
    }
};

done_testing();
