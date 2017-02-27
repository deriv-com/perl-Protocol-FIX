package Protocol::FIX::Field;

use strict;
use warnings;

=x
Known types:

AMT
BOOLEAN
CHAR
COUNTRY
CURRENCY
DATA
EXCHANGE
FLOAT
INT
LENGTH
LOCALMKTDATE
MONTHYEAR
MULTIPLEVALUESTRING
NUMINGROUP
PERCENTAGE
PRICE
PRICEOFFSET
QTY
SEQNUM
STRING
UTCDATEONLY
UTCTIMEONLY
UTCTIMESTAMP

=cut

my %per_type = (
    # anyting defined and not containing delimiter
    STRING => sub { defined($_[0]) && $_[0] !~ /=/ },
    INT => sub { defined($_[0]) && $_[0] =~ /^-?\d+$/ },
);

sub new {
    my ($class, $number, $name, $type, $values) = @_;
    my $obj = {
        number => $number,
        name => $name,
        type => $type,
    };

    if ($values) {
        my $reverse_values = {};
        @{$reverse_values}{values %$values} = keys %$values;
        $obj->{values} = {
            by_number => $values,
            by_name => $reverse_values,
        };
    }

    return bless $obj, $class;
};

sub check {
    my ($self, $value) = @_;

    my $type_checker = $per_type{$self->{type}};
    my $result = $self->{values}
        ? (defined($value) && exists $self->{values}->{by_name}->{$value})
        : $per_type{$self->{type}}->($value);

    return $result;
}

sub serialise {
    my ($self, $value) = @_;

    my $packed_value =  $self->{values} ? do {
        my $number = $self->{values}->{by_name}->{$value};
        die("The value '$value' is not acceptable for field " . $self->{name})
            unless $number;
        $number;
    } : $value;
    die("The value '$value' is not acceptable for field " . $self->{name})
        unless $self->check($value);

    return $self->{number} . '=' . $packed_value;
};

1;
