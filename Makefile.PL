use inc::Module::Install;

name 'MetaCPAN-Web';
all_from 'lib/MetaCPAN/Web.pm';

requires 'Catalyst::Runtime' => '5.7011';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::Template::Declare';

requires 'YAML'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats

requires 'Archive::Extract';
requires 'DBIx::Class';
requires 'Data::Dumper';
requires 'DateTime';
requires 'Digest::MD5';
requires 'ExtUtils::Manifest';
requires 'File::Path';
requires 'File::Spec';
requires 'File::Temp';
requires 'File::pushd';
requires 'IPC::Open2';
requires 'Log::Log4perl';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::AttributeHelpers';
requires 'MooseX::Getopt';
requires 'MooseX::Types::Path::Class';
requires 'Perl6::Junction';
requires 'YAML::Syck';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
