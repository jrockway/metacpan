package MetaCPAN::Script::Import::Git;
use 5.010;
use Moose;

use MetaCPAN::DB;
use DateTime;
use DateTime::Format::Epoch;
use MooseX::Types::Path::Class qw(Dir);
use Moose::Util::TypeConstraints;
use version;
use File::pushd;
use Archive::Extract;
use File::Next;
use String::TT qw/strip/;
use File::Temp qw/tempdir/;

with qw/MooseX::Getopt MetaCPAN::Script::Role::WithDatabase/;

subtype ModuleName => as Str => where {
    my $mod = $_;
    my @parts = split /::/, $mod;
    /\W/ and return 0 for @parts; # fail if there are non-word chars
    return 1;
};

has 'module' => (
    is       => 'ro',
    isa      => 'ModuleName',
    required => 1,
);

has 'repository' => (
    is       => 'ro',
    isa      => Dir,
    coerce   => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $module = $self->module;
        $module =~ s{/}{}g;
        $module =~ s/::/-/g;
        return "$module.git";
    },
);

has 'backpan' => (
    is       => 'ro',
    isa      => Dir,
    required => 1,
    coerce   => 1,
);

sub BUILD {
    my $self = shift;

    # die before we try reading a bunch of files that won't be there
    my $backpan = $self->backpan;
    confess "backpan $backpan does not exist" unless -d $backpan;
    confess "$backpan does not look much like a backpan"
      unless -d $backpan->subdir('authors');

    # updating an existing repo is possible, but probably not what you want
    confess 'destination repository must not exist' if -e $self->repository;
}

sub determine_sources {
    my $self = shift;
    my $modules = $self->_schema->resultset('Modules')->search({
        package => $self->module,
    }, {
        prefetch => { distribution => 'author' },
    });

    my @candidates = sort { qv($a->[0]) <=> qv($b->[0]) } map {
        [$_->version, $_->distribution->filename, $_->distribution->release_date, $_]
     } $modules->all;

#    for (@candidates){
#        print "  ". join ",", @$_; print "\n";
#    }

    # XXX: this should be done in the indexer
    foreach my $c (@candidates){
        my $filename = $c->[1];
        $filename =~ m{/authors/id/([a-z]/[a-z][a-z]/[a-z]+/[^/]+)$}
          or confess 'Invalid filename';
        $c->[1] = $self->backpan->subdir('authors/id')->file($1)->absolute;
    }

    # row object, Path::Class::file object
    return map { [$_->[3], $_->[1]] } @candidates;
}

sub create_repository {
    my $self = shift;
    my $repo = $self->repository;
    mkdir $repo or confess "Failed to mkdir $repo: $!";
    my $pwd = pushd $repo;
    `git init`;
    return;
}

sub import_tarfiles {
    my ($self, @sources) = @_;
    my $pwd = pushd $self->repository;
    open my $git, '|-', 'git', 'fast-import', '--quiet' or
      confess "Could not open git fast-import: $!";

    my $formatter = DateTime::Format::Epoch->new(
        # congratulations on the worst API ever.
        epoch => DateTime->from_epoch( epoch => 0 ),
    );

    foreach my $source (@sources){
        my $dest = Path::Class::dir(tempdir( CLEANUP => 1 ));

        { # extract the archive
            my $archive = $source->[1];
            my $ae = Archive::Extract->new( archive => $archive->stringify );
            next unless $ae;
            $ae->extract( to => $dest ) or confess "Failed to extract $ae to $dest";
        }

        my $version  = $source->[0]->version || 'unknown';
        my ($commit_message, $fullname, $email, $date);
        { # start a commit
            my $d = $source->[0]->distribution;
            $email    = $d->author->email;
            $email  ||= uc($d->author->pause_id) . '@cpan.org';
            $fullname = $d->author->name || uc $d->author->pause_id;
            $date     = $formatter->format_datetime(
                $source->[0]->distribution->release_date,
            );
            $date = "$date +0000"; # XXX: fix timezone
            my $now = $formatter->format_datetime(
                DateTime->now,
            );
            $now = "$now +0000";

            $commit_message = "$version CPAN release";
            my $commit_length  = length $commit_message;
            $commit_message =~ s/EOM//g; # just to be safe.

            print {$git} strip qq{
                commit refs/heads/master
                author "$fullname" <$email> $date
                committer "git-cpan" <jon\@jrock.us> $now
                data <<EOM
            }, "$commit_message\nEOM\n\n","deleteall\n";

        }

        my @files = grep { !/^..?$/ }$dest->open->read;
        $dest = $dest->subdir($files[0]) if @files == 1;

        # now add the files one by one
        my $files = File::Next::files($dest);
        while(defined( my $file = $files->() )){
            $file = Path::Class::file($file);
            my $content;
            if(-l $file){
                $content = readlink $file;
            }
            else {
                $content = $file->slurp;
            }
            my $length   = length $content;
            my $filename = $file;
            $filename =~ s{^$dest/}{}g;
            my $permissions =
              -l $file ? '120000' :
              -x $file ? '100755' :
                         '100644' ;

            print {$git} strip qq{
                # adding $filename (from $file inside @{[$source->[1]]})
                M $permissions inline $filename
                data $length
            }, "$content\n";
        }

        # finally, tag the commit as a CPAN release
        print {$git} strip qq{
            tag $version
            from refs/heads/master
            tagger "$fullname" <$email> $date
            data <<EOM
        }, "$commit_message\nEOM\n\n";
    }
    close $git; # done!
}

sub checkout {
    my $self = shift;
    my $repo = pushd $self->repository;
    `git checkout master`;
}

sub run {
    my $self = shift;
    my @sources = $self->determine_sources;
    $self->create_repository;
    $self->import_tarfiles(@sources);
    $self->checkout;
}

1;

__END__
die "usage: import-tars *.tar.{gz,bz2,Z}\n" unless @ARGV;

my $branch_name = 'import-tars';
my $branch_ref = "refs/heads/$branch_name";
my $committer_name = 'T Ar Creator';
my $committer_email = 'tar@example.com';

open(FI, '|-', 'git', 'fast-import', '--quiet')
	or die "Unable to start git fast-import: $!\n";
foreach my $tar_file (@ARGV)
{
	$tar_file =~ m,([^/]+)$,;
	my $tar_name = $1;

	if ($tar_name =~ s/\.(tar\.gz|tgz)$//) {
		open(I, '-|', 'gzcat', $tar_file) or die "Unable to gzcat $tar_file: $!\n";
	} elsif ($tar_name =~ s/\.(tar\.bz2|tbz2)$//) {
		open(I, '-|', 'bzcat', $tar_file) or die "Unable to bzcat $tar_file: $!\n";
	} elsif ($tar_name =~ s/\.tar\.Z$//) {
		open(I, '-|', 'zcat', $tar_file) or die "Unable to zcat $tar_file: $!\n";
	} elsif ($tar_name =~ s/\.tar$//) {
		open(I, $tar_file) or die "Unable to open $tar_file: $!\n";
	} else {
		die "Unrecognized compression format: $tar_file\n";
	}

	my $commit_time = 0;
	my $next_mark = 1;
	my $have_top_dir = 1;
	my ($top_dir, %files);

	while (read(I, $_, 512) == 512) {
		my ($name, $mode, $uid, $gid, $size, $mtime,
			$chksum, $typeflag, $linkname, $magic,
			$version, $uname, $gname, $devmajor, $devminor,
			$prefix) = unpack 'Z100 Z8 Z8 Z8 Z12 Z12
			Z8 Z1 Z100 Z6
			Z2 Z32 Z32 Z8 Z8 Z*', $_;
		last unless $name;
		$mode = oct $mode;
		$size = oct $size;
		$mtime = oct $mtime;
		next if $mode & 0040000;

		print FI "blob\n", "mark :$next_mark\n", "data $size\n";
		while ($size > 0 && read(I, $_, 512) == 512) {
			print FI substr($_, 0, $size);
			$size -= 512;
		}
		print FI "\n";

		my $path = "$prefix$name";
		$files{$path} = [$next_mark++, $mode];

		$commit_time = $mtime if $mtime > $commit_time;
		$path =~ m,^([^/]+)/,;
		$top_dir = $1 unless $top_dir;
		$have_top_dir = 0 if $top_dir ne $1;
	}

	print FI <<EOF;
commit $branch_ref
committer $committer_name <$committer_email> $commit_time +0000
data <<END_OF_COMMIT_MESSAGE
Imported from $tar_file.
END_OF_COMMIT_MESSAGE

deleteall
EOF

	foreach my $path (keys %files)
	{
		my ($mark, $mode) = @{$files{$path}};
		my $git_mode = 0644;
		$git_mode |= 0700 if $mode & 0111;
		$path =~ s,^([^/]+)/,, if $have_top_dir;
		printf FI "M %o :%i %s\n", $git_mode, $mark, $path;
	}
	print FI "\n";

	print FI <<EOF;
tag $tar_name
from $branch_ref
tagger $committer_name <$committer_email> $commit_time +0000
data <<END_OF_TAG_MESSAGE
Package $tar_name
END_OF_TAG_MESSAGE

EOF

	close I;
}
close FI;

1;
