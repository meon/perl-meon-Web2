use strict;
use warnings;
use Module::Build::SysPath;

use 5.010;

my $builder = Module::Build::SysPath->new(
    module_name       => 'meon-Web2',
    license           => 'perl',
    dist_author       => 'Jozef Kutej <jkutej@cpan.org>',
    dist_version_from => 'lib/meon/Web2.pm',

    configure_requires => {
        'Module::Build::SysPath' => 0.13,
        'Module::Build'          => '0.3607',
    },
    build_requires => {
        'Module::Build::SysPath' => 0.13,
        'Test::Most'             => 0,
        'Test::WWW::Mechanize'   => 0,
        'Moose'                  => 0,
        'namespace::autoclean'   => 0,
        'Plack::Test::Server'    => 0,
        'Plack::Builder'         => 0,
    },
    requires => {
        'perl'                             => '5.010',
        'Try::Tiny'                        => 0,
        'Plack::Request'                   => 0,
        'Plack::Middleware::ContentLength' => 0,
        'Twiggy'                           => 0,
        'Carp'                             => 0,
        'JSON::XS'                         => 0,
        'Config::INI::Reader'              => 0,
        'Log::Log4perl'                    => 0,
        'HTTP::Exception'                  => 0,
        'Path::Class'                      => 0,
        'Plack::MIME'                      => 0,
        'AnyEvent::IO'                     => 0,
        'Run::Env'                         => 0,
        'File::is'                         => 0,
        'XML::LibXML'                      => 0,
        'XML::LibXSLT'                     => 0,
    },
    script_files => [qw(
            bin/meon-web2.psgi
            )
    ],
    conffiles => [qw(
            etc/meon/web2-config.ini
            etc/meon/web2-log4perl.conf
            )
    ],
    add_to_cleanup => ['meon-Web2-*'],
    create_readme  => 1,
);

$builder->create_build_script();
