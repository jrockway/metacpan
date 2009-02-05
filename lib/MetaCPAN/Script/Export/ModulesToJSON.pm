package MetaCPAN::Script::Export::ModulesToJSON;
use Moose;
use JSON::Any;
use MooseX::Types::Path::Class qw(Dir);

with qw/MooseX::Getopt MetaCPAN::Script::Role::WithDatabase/;

has destination => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

has modules => (
    is         => 'ro',
    isa        => 'ArrayRef',
    auto_deref => 1,
    lazy_build => 1,
);

sub create_file_for {
    my ($self, $module, $data) = @_;
    my $file = $self->destination->file(join('/', split /::/, $module).'.json');
    $file->parent->mkpath;
    my $json = JSON::Any->new->Dump($data);
    print {$file->openw} $json;
}

sub _build_modules {
    my $self = shift;
    return [
        $self->_schema->resultset('Modules')->search(
            {},
            { group_by => 'package' }
        )->get_column('package')->all,
    ];
}

sub run {
    my $self = shift;
    for my $module ($self->modules){
        $self->create_file_for(
            $module,
            {
                versions => [
                    map {
                        my $dist = $_->distribution->filename;
                        $dist =~ s{^.+(id/.+)$}{$1};
                        $dist =~ s{id/(.)/(..)/(.+)/}{\U$1/$2/$3/}; # upcase
                        +{
                            version      => $_->version,
                            release_date => qq{}. $_->distribution->release_date,
                            distribution => $dist,
                            author       => {
                                name  => $_->distribution->author->name,
                                email => $_->distribution->author->email,
                                id    => $_->distribution->author->pause_id,
                            },
                        }
                    }
                      $self->_schema->resultset('Modules')->search({
                          package => $module,
                      }, {
                          order_by => 'release_date DESC',
                          prefetch => { distribution => 'author' },
                      })->all,
                ],
            }
        );
    }
}

1;
