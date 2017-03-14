package Protocol::FIX::Group;

use strict;
use warnings;

use Protocol::FIX;
use UNIVERSAL;

## VERSION

use mro;
use parent qw/Protocol::FIX::BaseComposite/;

sub new {
    my ($class, $base_field, $composites) = @_;

    die "base field for group must be a class of 'Protocol::FIX::Field'"
        unless UNIVERSAL::isa($base_field, "Protocol::FIX::Field");

    die "type of base field must be strictly 'NUMINGROUP'"
        unless $base_field->{type} eq 'NUMINGROUP';

    my $obj = next::method($class, $base_field->{name}, 'group', $composites);

    $obj->{base_field} = $base_field;

    return $obj;
}

sub serialize {
    my ($self, $repetitions) = @_;

    die '$repetitions must be ARRAY in $obj->serialize($repetitions)'
        unless ref($repetitions) eq 'ARRAY';

    die '@repetitions must be non-empty in $obj->serialize($repetitions)'
        if @$repetitions == 0;

    my @strings = ($self->{base_field}->serialize(scalar @$repetitions));

    for my $values (@$repetitions) {
        push @strings, $self->next::method($values);
    }

    return join $Protocol::FIX::SEPARATOR, @strings;
}

1;
