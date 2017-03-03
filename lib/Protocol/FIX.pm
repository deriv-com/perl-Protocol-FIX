package Protocol::FIX;

use strict;
use warnings;

use XML::Fast;
use File::ShareDir qw/dist_dir/;
use Path::Tiny;
use UNIVERSAL;

use Protocol::FIX::Component;
use Protocol::FIX::Field;
use Protocol::FIX::Group;
use Protocol::FIX::BaseComposite;
use Exporter qw/import/;

our @EXPORT_OK = qw/humanize/;

my $distribution = 'Protocol-FIX';

my %specificaion_for = (
    fix44 => 'FIX44.xml'
);

our $SEPARATOR = "\x{01}";

sub new {
    my ($class, $version) = @_;
    die("FIX protocol version should be specified")
        unless $version;

    my $file = $specificaion_for{lc $version};
    die("Unsupported FIX protocol version: $version. Supported versions are: "
        . join(", ", sort {$a cmp $b} keys %specificaion_for))
        unless $file;

    my $dir = $ENV{PROTOCOL_FIX_SHARE_DIR} // dist_dir($distribution);
    my $xml = path("$dir/$file")->slurp;
    my $protocol_definition = xml2hash $xml;
    my $obj = {
        version => lc $version,
    };
    bless $obj, $class;
    $obj->_construct_from_definition($protocol_definition);
    return $obj;
};


sub humanize {
    my $s = shift;
    return $s =~ s/\x{01}/ | /gr;
}

# checks that object conforms "composite" concept, i.e. field, group, component
# and message(?)
sub is_composite {
    my $obj = shift;
    return defined($obj)
        && UNIVERSAL::can($obj, 'serialize')
        && exists $obj->{name}
        && exists $obj->{type}
    ;
};

sub _construct_fields {
    my ($self, $definition) = @_;

    my $fields_lookup = {
        by_number => {},
        by_name => {},
    };

    for my $field_descr ( @{ $definition->{fix}->{fields}->{field} } ) {
        my ($name, $number, $type) = map { $field_descr->{$_} } qw/-name -number -type/;
        my $values;
        my $values_arr = $field_descr->{value};
        if ($values_arr) {
            for my $value_desc (@$values_arr) {
                my ($key, $description) = map { $value_desc->{$_} } qw/-enum -description/;
                $values->{$key} = $description;
            }
        }
        my $field = Protocol::FIX::Field->new($number, $name, $type, $values);
        $fields_lookup->{by_number}->{$number} = $field;
        $fields_lookup->{by_name}->{$name} = $field;
    }

    return $fields_lookup;
}

sub _get_composites {
    my ($values, $lookup) = @_;
    return () unless $values;

    my $array = ref($values) ne 'ARRAY' ? [$values] : $values;
    my @composites = map {
        my $ref = $_;
        my $name = $ref->{-name};
        my $required = $ref->{-required} eq 'Y';
        my $composite = $lookup->{by_name}->{$name};

        die($name) unless $composite;

        ($composite, $required);
    } @$array;
    return @composites;
};

sub _construct_components {
    my ($self, $definition, $fields_lookup) = @_;

    my $components_lookup = {
        by_name => {},
    };

    my @components_queue = map { $_->{-type} = 'component'; $_; } @{ $definition->{fix}->{components}->{component} };
OUTER:
    while (my $component_descr = shift @components_queue) {
        my @composites;
        my $name = $component_descr->{-name};
        my $type = $component_descr->{-type};

        my $fatal = 0;
        eval {
            push @composites, _get_composites($component_descr->{component}, $components_lookup);

            my $group_descr = $component_descr->{group};
            if ($group_descr) {
                my @group_composites;

                # we might fail to construct group as dependent components might not be
                # constructed yet
                push @group_composites, _get_composites($group_descr->{component}, $components_lookup);

                # now we should be able to construct group
                $fatal = 1;
                push @group_composites, _get_composites($group_descr->{field}, $fields_lookup);

                my $group_name = $group_descr->{-name};
                my $base_field = $fields_lookup->{by_name}->{$group_name}
                    // die("${$group_name} refers field '${$group_name}', which is not available");
                my $group = Protocol::FIX::Group->new($base_field, \@group_composites);

                my $group_required = $group_descr->{-required} eq 'Y';
                push @composites, $group => $group_required;
            }
        };
        if ($@) {
            die("$@") if ($fatal);
            # not constructed yet, postpone current component construction
            push @components_queue, $component_descr;
            next OUTER;
        }

        eval { push @composites, _get_composites($component_descr->{field}, $fields_lookup) };
        # make it human friendly
        die("Cannot find fild '$@' referred by '$name'")
            if ($@);

        my $component = Protocol::FIX::Component->new($name, \@composites);
        $components_lookup->{by_name}->{$name} = $component;
    }

    return $components_lookup;
}

sub _construct_composite {
    my ($self, $name, $descr, $fields_lookup, $components_lookup) = @_;

    my @composites;
    eval {
        push @composites, _get_composites($descr->{field}, $fields_lookup);
        push @composites, _get_composites($descr->{component}, $components_lookup);
    };
    if ($@) {
        die("Cannot find composite '$@', referred in '$name'")
    }

    return Protocol::FIX::BaseComposite->new($name, $name, \@composites);
}

sub _construct_from_definition {
    my ($self, $definition) = @_;

    my $fields_lookup = $self->_construct_fields($definition);
    my $components_lookup = $self->_construct_components($definition, $fields_lookup);

    my $header_descr = $definition->{fix}->{header};
    my $trailer_descr = $definition->{fix}->{trailer};
    my $header = $self->_construct_composite('header', $header_descr, $fields_lookup, $components_lookup);
    my $trailer = $self->_construct_composite('trailer', $trailer_descr, $fields_lookup, $components_lookup);

    $self->{header} = $header;
    $self->{trailer} = $trailer;
    $self->{fields_lookup} = $fields_lookup;
    $self->{components_lookup} = $components_lookup;
};

sub field_by_name {
    my ($self, $field_name) = @_;
    my $field = $self->{fields_lookup}->{by_name}->{$field_name};
    if (!$field) {
       die("Field '$field_name' is not available in protocol" . $self->{version});
    }
    return $field;
};

sub field_by_number {
    my ($self, $field_number) = @_;
    my $field = $self->{fields_lookup}->{by_number}->{$field_number};
    if (!$field) {
       die("Field $field_number is not available in protocol " . $self->{version});
    }
    return $field;
};

sub component_by_name {
    my ($self, $name) = @_;
    my $component = $self->{components_lookup}->{by_name}->{$name};
    if (!$component) {
       die("Component '$name' is not available in protocol " . $self->{version});
    }
    return $component;
}

sub header {
    return shift->{header};
}

sub trailer {
    return shift->{trailer};
}

1;
