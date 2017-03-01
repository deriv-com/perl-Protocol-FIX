package Protocol::FIX::Group;

use strict;
use warnings;

use Protocol::FIX;
use mro;
use parent qw/Protocol::FIX::BaseComposite/;

sub new {
    my ($class, $base_field, $composites) = @_;

    die "base field for group must be a class of 'Protocol::FIX::Field'"
        unless UNIVERSAL::isa($base_field, "Protocol::FIX::Field");

    die "type of base field must be strictly 'NUMINGROUP'"
        unless $base_field->{type} eq 'NUMINGROUP';

    my $obj = Protocol::FIX::BaseComposite::new($class, $base_field->{name}, 'group', $composites);

    $obj->{base_field} = $base_field;

    return $obj;
}

sub serialize {
    my ($self, @repetitions) = @_;

    die '@repetitions must be non-empty in $obj->serialize(@repetitions)'
        if @repetitions == 0;


    my $buff = $self->{base_field}->serialize(scalar @repetitions)
        . $Protocol::FIX::SEPARATOR;

    for my $values (@repetitions) {
        $buff .= $self->next::method($values);
    }
    return $buff;
}

1;
