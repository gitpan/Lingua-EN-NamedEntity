package Lingua::EN::NamedEntity;
use Lingua::Stem::En;
Lingua::Stem::En::stem_caching({ -level => 2});
use 5.006;
use strict;
use warnings;
use Carp;
use DB_File;
my $home = ((getpwuid $<)[7]). "/.namedentity";
our %dictionary;
tie %dictionary, "DB_File", $home."/wordlist" 
    or carp "Couldn't open wordlist: $!\n";

my %forenames;
tie %forenames, "DB_File", $home."/forename"
    or carp "Couldn't open forename list: $!\n";
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
	extract_entities
);

our $VERSION = '1.0';

# Regexps for constructing capitalised sequences
my $conjunctives = qr/of|and|the|&|\+/i;
my $break = qr/\b|^|$/;
my $people_initial = qr/Mrs?|Ms|Dr|Sir|Lady|Lord/;
my $people_terminal = qr/Sr|Jr|Esq/;
my $places_initial = qr/Mt|Ft|St|Lake|Mount/;
my $abbr = qr/$people_initial|$people_terminal|$places_initial|St/;
my $capped = qr/$break (?:$abbr(\.|$break)?|[A-Z][a-z]* $break)/x;
my $folky = qr/-(?:(?:in|under|over|by|the)-)+/i;
my $middle = qr/ $folky | 
                [\s-] (?:$conjunctives [\s-])* /x;
my $phrase = qr/$capped (?:$middle $capped)*/x;

my $word = qr/\s*\b\w+\b\s*/;
my $context = qr/$word{1,2}/;

sub extract_entities {
    my $text = shift;
    $text =~ s/\n/ /g;
    $text =~ s/ +/ /g;
    my @candidates;
    @candidates = combine_contexts(
    map { categorize_entity($_) }
     _spurn_dictionary_words(_extract_capitalized($text)));
}


sub categorize_entity {
    my $e = shift;
    $e->{scores} = { person => 1, place => 1, organisation => 1};
    bless $e, "Lingua::EN::NamedEntity";
    $e->definites and return $e;
    $e->name_clues;
    $e->place_clues;
    $e->org_clues;
    $e->fix_scores;
    return $e;
}

my $places_terminal = qr/St(reet)?|Ave(nue)?/i;
sub definites {
    my $e = shift;
    my $ent = $e->{entity};
    if ($ent =~ /^$people_initial\.?\b/ or $ent =~ /\b$people_terminal\.?$/) {
        $e->{scores}{person} = 100;
        return 1;
    }
    if ($ent =~ /^$places_initial\.?\b/ or $ent =~ /\b$places_terminal\.?$/) {
        $e->{scores}{place} = 100;
        return 1;
    }
    return 0;
}

my $pre_name =
qr/chair|\w+man|\w+person|director|executive|manager|president|secretary|chancellor|
minister|governor|chief|deputy|head|member|officer/ix;
sub name_clues {
    my $e = shift;
    my $ent = $e->{entity};
    my @x;
    $e->{scores}{person} += 10 if $e->{pre} =~ /(\b|^)$pre_name(\b|$)/;
    $e->{scores}{person} += 3 if (@x = split /\W+/, $ent) == 2; 
    my @words = grep { exists $forenames{lc $_} } split /\W+/, $ent;
    $e->{scores}{person} += 5 * @words;
}

my $pre_place = qr/in|at/i;
sub place_clues {
    my $e = shift;
    my @x;
    $e->{scores}{place} += 3  if (@x = split /\W+/, $e->{entity}) == 1; 
    $e->{scores}{place} += 3 if $e->{pre} =~ /(^|\b)$pre_place(\b|$)/;
}

sub org_clues {
    my $e = shift;
    my $ent = $e->{entity};
    $e->{scores}{organisation} += 10 if $ent =~ /\b(&|and|\+)\b/;
    my @words = grep { _stemmed_word_in_dictionary($_) } split /\W+/, $ent;
    $e->{scores}{organisation} += @words;
}

sub fix_scores {
    my $e = shift;
    if (!$e->{class}) {
        $e->{class} = (sort {$e->{scores}{$b}<=>$e->{scores}{$a}} keys
        %{$e->{scores}} )[0];
    }
    return $e;
}

sub _spurn_dictionary_words {
    my @initial = @_;
    my @candidates;
    # Spurn sentence-initial dictionary words
    for my $e (@initial) {
        do { push @candidates, $e; next} if $e->{pre} and $e->{entity} =~ / /; 
        my $word = lc $e->{entity};
        next if exists $dictionary{$word} ||
                _stemmed_word_in_dictionary($word);
        push @candidates, $e;
    }
    return @candidates;
}

sub _stemmed_word_in_dictionary {
    my $word = lc shift;
    my ($stemmed) = @{ Lingua::Stem::En::stem({ -words => [ $word ] }) };
    return exists $dictionary{$stemmed};
}

sub _extract_capitalized {
    my $text = shift;
    my @results;
    while ($text =~ /($phrase)/ms) {
        my $entity = $1;
        $text =~ s/($context?)\Q$entity\E($context?)/$2/;
        my ($pre, $post)= ($1, $2);
        while ($entity =~ s/^($conjunctives\s+)// or
               $entity =~ s/^(.+?)(Mrs?|Ms|Dr|Mt|Ft)/$2/) {
            $pre .= $1;
        }
        next if length $entity <2;
        push @results, { entity => $entity, pre => $pre, post => $post };
    }
    return @results;
}

sub combine_contexts {
    my @entities = @_;
    my %combined;
    my @rv;
    # If something's a person in one sentence, it's likely to be one in
    # another too!
    for my $e (@entities) {
        $combined{$e->{entity}}{entity} = $e->{entity};
        for my $class (keys %{$e->{scores}}) {
            $combined{$e->{entity}}{scores}{$class} += $e->{scores}{$class}
        }
    }
    for my $e (values %combined) {
        push @rv, fix_scores($e);
     }
    return @rv;
}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Lingua::EN::NamedEntity - Basic Named Entity Extraction algorithm

=head1 SYNOPSIS

  use Lingua::EN::NamedEntity;
  my @entities = extract_entities($some_text);

=head1 DESCRIPTION

"Named entities" is the NLP jargon for proper nouns which represent
people, places, organisations, and so on. This module provides a 
very simple way of extracting these from a text. If we run the
C<extract_entities> routine on a piece of news coverage of recent UK
political events, we should expect to see it return a list of hash
references looking like this:
 
  { entity => 'Mr Howard', class => 'person', scores => { ... }, },
  { entity => 'Ministry of Defence', class => 'organisation', ... },
  { entity => 'Oxfordshire', class => 'place', ... },

The additional C<scores> hash reference in there breaks down the various
possible classes for this entity in an open-ended scale. 

Naturally, the more text you throw at this, the more accurate it becomes.

=head2 EXPORT

C<extract_entities>

=head1 AUTHOR

Simon Cozens, C<simon@kasei.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Simon Cozens

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
