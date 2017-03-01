package Protocol::FIX;

use strict;
use warnings;

use XML::Fast;
use File::ShareDir qw/dist_dir/;
use Path::Tiny;
use UNIVERSAL;

use Protocol::FIX::Field;

my $distribution = 'Protocol-FIX';

my %specificaion_for = (
    fix44 => 'FIX44.xml'
);

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

sub _construct_from_definition {
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

    $self->{fields_lookup} = $fields_lookup;
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
       die("Field $field_number is not available in protocol" . $self->{version});
    }
    return $field;
};



1;
