package MetaCPAN::Script::AddAuthors;
use Moose;
use MooseX::Types::Path::Class qw(File);
use PerlIO::gzip;

with qw/MooseX::Getopt MetaCPAN::Script::Role::WithDatabase/;

has 'authors_file' => (
    is       => 'ro',
    isa      => File,
    required => 1,
    coerce   => 1,
);

sub update_author {
    my ($self, $pause, $fullname, $email) = @_;
    my $author = $self->_schema->resultset('Authors')->find_or_new(
        pause_id => $pause,
    );
    $author->email($email);
    $author->name($fullname);
    $author->insert_or_update;
}

sub parse_line {
    my ($self, $line, $number) = @_;
    $line =~ /^alias\s+([0-9A-Z-]+)\s+"(.+)?\s<(.+)>"$/ and
      return ($1, $2, $3);

    die "parse error at line $number: cannot parse $line";
}

sub get_lines {
    my $self = shift;
    my $fh = $self->authors_file->open;
    binmode $fh, ':gzip';
    my @lines = <$fh>;
    close $fh;
    return @lines;
}

sub run {
    my $self = shift;

    my $i = 0;
    for my $line ($self->get_lines){
        $i++;
        $self->update_author($self->parse_line($line));
    }
    print {*STDERR} "Updated $i authors\n";
    return;
}

1;
