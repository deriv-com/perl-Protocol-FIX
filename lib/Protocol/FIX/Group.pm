package Protocol::FIX::Group;

use strict;
use warnings;
use UNIVERSAL;
use Protocol::FIX;

sub new {
    my ($class, $base_field, $composites) = @_;

    die "base field for group must be a class of 'Protocol::FIX::Field'"
        unless UNIVERSAL::isa($base_field, "Protocol::FIX::Field");

    die "type of base field must be strictly 'NUMINGROUP'"
        unless $base_field->{type} eq 'NUMINGROUP';

    die "composites array must be even"
        if @$composites % 2;

    die "composites array must be non-empty"
        unless @$composites;

    my @composites;
    my @mandatory_composites;
    my %composite_by_name;
    for (my $idx = 0; $idx < @$composites; $idx += 2) {
        my $c = $composites->[$idx];
        my $required = $composites->[$idx + 1];
        die "The object $idx must be a composite"
            unless Protocol::FIX::is_composite($c);

        my $prerequisite_composite;
        if ($c->{type} eq 'DATA') {
            my $valid_definition
                =  ($idx > 0)
                && $composites->[$idx-2]->{type} eq 'LENGTH'
                ;
            die "The field type 'LENGTH' must appear before field " . $c->{name}
                unless $valid_definition;
            $prerequisite_composite = $composites->[$idx-2];
        }

        push @composites, $c, ($required ? 1 : 0);
        push @mandatory_composites, $c->{name} if $required;
        $composite_by_name{$c->{name}} = [$c, $prerequisite_composite];
    }

    my $obj = {
        name                 => $base_field->{name},
        type                 => 'group',
        base_field           => $base_field,
        composites           => \@composites,
        composite_by_name    => \%composite_by_name,
        mandatory_composites => \@mandatory_composites,
    };

    return bless $obj, $class;
}

sub serialize {
    my ($self, @repetitions) = @_;

    die '@repetitions must be non-empty in $obj->serialize(@repetitions)'
        if @repetitions == 0;

    my @strings = ( $self->{base_field}->serialize(scalar @repetitions) );

    for my $values (@repetitions) {
        die "values must be non-empty even array"
            if (ref($values) ne 'ARRAY') || !@$values || (@$values % 2);

        my %used_composites;
        for (my $idx = 0; $idx < @$values; $idx += 2) {
            my $name = $values->[$idx];
            my $value = $values->[$idx + 1];
            my $c_info = $self->{composite_by_name}->{$name};
            die "Composite '$name' is not available"
                unless $c_info;

            my $c = $c_info->[0];
            if ($c->{type} eq 'DATA') {
                my $c_length = $c_info->[1];
                my $valid_sequence
                    =  ($idx > 0)
                    && $self->{composite_by_name}->{$values->[$idx-2]}->[0] == $c_length;
                    ;

                die "The field '" . $c_length->{name} . "' must precede '" . $c->{name} . "'"
                    unless $valid_sequence;

                my $actual_length = length($value);
                die "The length field '" . $c_length->{name} . "' ($actual_length) isn't equal previously declared (" . $values->[$idx-1] . ")"
                    unless $values->[$idx-1] == $actual_length;
            }

            push @strings, $c->serialize($value);
            $used_composites{$name} = 1;
        }
        for my $mandatory_name (@{ $self->{mandatory_composites} }) {
            die "'$mandatory_name' is mandatory for '" . $self->{name} . "'"
                unless exists $used_composites{$mandatory_name};
        }
    }
    return join "\x{01}", @strings, '';
}

1;
