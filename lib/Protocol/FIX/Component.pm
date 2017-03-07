package Protocol::FIX::Component;

use strict;
use warnings;

use Protocol::FIX;
use UNIVERSAL;

use parent qw/Protocol::FIX::BaseComposite/;

sub new {
    my ($class, $name, $composites) = @_;

    my $obj = next::method($class, $name, 'component', $composites);

    my %component_for;
    for (my $idx = 0; $idx < @$composites; $idx += 2) {
        my $c = $composites->[$idx];
        if (UNIVERSAL::isa($c, 'Protocol::FIX::Component')) {
            my $sub_dependency = $c->{field_to_component};
            for my $k (keys %$sub_dependency) {
                if (exists $component_for{$k}) {
                    die("Ambiguity when constructing component '$name': '$k' already points to '"
                        . $component_for{$k} . "', trying to add another pointer to '" . $sub_dependency->{$k} . "'");
                }
                $component_for{$k} = $sub_dependency->{$k};
            }
        }
        if (exists $component_for{$c->{name}}) {
            die("Ambiguity when constructing component '$name': '"  . $c->{name} . "' already points to '"
                . $component_for{$c->{name}} . "', trying to add another pointer to '" . $name . "'");
        }
        $component_for{$c->{name}} = $name;
    }
    $obj->{field_to_component} = \%component_for;

    return $obj;
}

1;
