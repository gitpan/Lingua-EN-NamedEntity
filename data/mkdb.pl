#!/usr/bin/perl

require DB_File;
my %wordlist;

my $dir = './blib/lib/Lingua/EN/NamedEntity';

print  "\n";
print  "I'm going to write some wordlists as DB_Files into a subdirectory\n";
print  "in your home directory, to increase start-up time.\n";

#my $dir = ((getpwuid $<)[7]). "/.namedentity";
#if (-d $dir) {
#  print  "Except I see you'd already got some. Carry on, then!\n";
#  return 1;
#}

unless (-d $dir) {
  mkdir $dir or die "Well, I can't seem to create $dir - $!\n";
}
tie %wordlist, "DB_File", "$dir/wordlist"
  or die "Something went wrong with DB_File";

print  "Looking for a wordlist...";
my $words = -e "/usr/share/dict/words" ? "/usr/share/dict/words"
  : -e "/usr/dict/words" && "/usr/dict/words";
if ($words && open DICT, $words) {
  $|=1;
  print  " I shall use $words\nThis will take some time. ";
  my $size = -s $words;
  my %said;
  while (<DICT>) {
    chomp;
    next if /[A-Z]/;
    my $percent = int(100*(tell(DICT)/$size));
    print $percent, "% " if !($percent %10) and !($said{$percent}++);
    $wordlist{$_}=1;
  }
  print  "\n";
} else {
  print  " I shall try and download one\n";
  require LWP::Simple; import LWP::Simple;
  my $wlz = 
    get(q(ftp://ftp.ox.ac.uk/pub/wordlists/dictionaries/words-english.gz));
  if ($wlz) {
    require Compress::Zlib;
    print  "I hope you have a lot of memory. This may hurt.\n";
    my $wl = Compress::Zlib::decompress($wlz);
    for (split /\n/, $wl) {	# Ow, the pain
      next if /[A-Z]/;
      $wordlist{$_}=1;
    }
  } else {
    die "No dice. Please install an operating system!\n";
  }
}

print  "Converting the forename list\n";
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
  print  $percent, "% " unless $percent %10 or $said{$percent}++;
}
print  "\n";


