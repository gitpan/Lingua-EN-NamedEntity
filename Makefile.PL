use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Lingua::EN::NamedEntity',
    VERSION_FROM      => 'NamedEntity.pm', # finds $VERSION
    PREREQ_PM         => 
    { DB_File => 0,
    Compress::Zlib => 0,
      LWP::Simple => 0 }, # e.g., Module::Name => 1.1
    
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'NamedEntity.pm', # retrieve abstract from module
       AUTHOR         => 'Simon Cozens <simon@kasei.com>') : ()),
);

require DB_File;
my %wordlist;
print "I'm going to write some wordlists as DB_Files into a subdirectory
in your home directory, to increase start-up time.\n";
my $dir = ((getpwuid $<)[7]). "/.namedentity";
if (-d $dir) {
    print "Except I see you'd already got some. Carry on, then!\n";
    exit;
}

mkdir $dir or die "Well, I can't seem to create $dir - $!\n";
tie %wordlist, "DB_File", "$dir/wordlist"
    or die "Something went wrong with DB_File";

print "Looking for a wordlist...";
if (open DICT, "/usr/share/dict/words") {
    $|=1;
    print " I shall use /usr/share/dict/words\nThis will take some time. ";
    my $size = -s "/usr/share/dict/words";
    my %said;
    while (<DICT>) {
        chomp;
        next if /[A-Z]/;
        my $percent = int(100*(tell(DICT)/$size));
        print $percent, "% " if !($percent %10) and !($said{$percent}++);
        $wordlist{$_}=1;
    }
    print "\n";
} else {
    print " I shall try and download one\n";
    require LWP::Simple; import LWP::Simple;
    my $wlz = 
        get(q(ftp://ftp.ox.ac.uk/pub/wordlists/dictionaries/words-english.gz));
    if ($wlz) {
        require Compress::Zlib;
        print "I hope you have a lot of memory. This may hurt.\n";
        my $wl = Compress::Zlib::decompress($wlz);
        for (split /\n/, $wl) { # Ow, the pain
            next if /[A-Z]/;
            $wordlist{$_}=1;
        }
    } else {
       die "No dice. Please install an operating system!\n";
    }
}

print "Converting the forename list\n";
my %forename;
tie %forename, "DB_File", "$dir/forename"
    or die "Something went wrong with DB_File";
open IN, "data/givennames-ol" or die "Couldn't open data file: $!";
my $size = -s "data/givennames-ol";
my %said;
while (<IN>) {
    chomp;
    s/[^a-zA-Z ]//g;
    $forename{lc $_}=1;
    my $percent = int(100*(tell(IN)/$size));
    print $percent, "% " unless $percent %10 or $said{$percent}++;
}
print "\n";
