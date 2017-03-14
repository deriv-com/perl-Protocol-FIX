package Protocol::FIX::TagsAccessor;

use strict;
use warnings;

## VERSION

sub new {
    my ($class, $tag_pairs) = @_;
    my %by_name;
    for (my $idx = 0; $idx < @$tag_pairs; $idx += 2) {
        my $composite = $tag_pairs->[$idx];
        # value is either value (i.e. string) or another TagAccessor
        my $value = $tag_pairs->[$idx + 1];
        $by_name{$composite->{name}} = $value;

    };
    return bless \%by_name, $class;
};

sub value {
    my ($self, $name) = @_;
    my $value = $self->{$name};

}

1;
