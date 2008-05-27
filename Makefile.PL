use inc::Module::Install;

name 'MetaCPAN';
all_from 'lib/MetaCPAN.pm';

requires 'Archive::Extract';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Runtime' => '5.7011';
requires 'Catalyst::View::Template::Declare';
requires 'DBIx::Class';
requires 'Data::Dumper';
requires 'DateTime';
requires 'Digest::MD5';
requires 'ExtUtils::Manifest';
requires 'File::Next';
requires 'File::Path';
requires 'File::Spec';
requires 'File::Temp';
requires 'File::pushd';
requires 'IPC::Open3';
requires 'JSON::Any';
requires 'Log::Log4perl';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::AttributeHelpers';
requires 'MooseX::Getopt';
requires 'MooseX::Types::Path::Class';
requires 'PerlIO::gzip';
requires 'String::TT';
requires 'YAML';
requires 'YAML::Syck';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;

