use Test::More tests => 15;
use_ok("Lingua::EN::NamedEntity");

open KELLY, "t/kelly" or die $!;
my $text; { local $/; $text = <KELLY>; }
my @entities = extract_entities($text);

my %ents = map { $_->{entity} => $_->{class} } @entities;

my %expected = (
"Ministry of Defence" => "organisation",
"Sir Richard Dearlove" => "person",
"Martin Howard" => "person",
"Oxfordshire" => "place",
"Nick Higham" => "person",
"Mr Gilligan" => "person",
"Dr Andy Shuttleworth" => "person"
);

for (keys %expected) {
    ok(exists $ents{$_}, "Found $_");
    is($ents{$_}, $expected{$_}, "Classified $_ as $ents{$_}");
}
