package Protocol::FIX::Message;

use strict;
use warnings;

use Protocol::FIX;

use mro;
use parent qw/Protocol::FIX::BaseComposite/;

sub new {
    my ($class, $name, $category, $message_type, $composites, $protocol) = @_;

    my $message_type_field = $protocol->field_by_name('MsgType');

    my $message_type_string = $message_type_field->{values}->{by_id}->{$message_type};
    die "specified message type '$message_type' is not available in protocol"
        unless defined $message_type_string;

    my $serialized_message_type = $message_type_field->serialize($message_type_string);

    die "message category must be defined"
        if (!defined($category) || $category !~ /.+/);

    my @all_composites = (
        @{ $protocol->header->{composites} },
        @$composites,
        @{ $protocol->trailer->{composites} }
    );

    my @body_composites;
    for(my $idx = 0; $idx < @all_composites; $idx += 2) {
        my $c = $all_composites[$idx];
        next if exists $protocol->managed_composites->{$c->{name}};

        push @body_composites, $c, $all_composites[$idx + 1];
    }

    my $obj = next::method($class, $name, 'message', \@body_composites);

    $obj->{category} = $category;
    $obj->{serialized} = {
        begin_string => $protocol->{begin_string},
        message_type => $serialized_message_type,
    };
    $obj->{managed_composites} = {
        BodyLength => $protocol->field_by_name('BodyLength'),
        CheckSum   => $protocol->field_by_name('CheckSum'),
    };

    return $obj;
};

sub category {
    return shift->{category};
}

sub message_type {
    return shift->{message_type};
}

sub serialize {
    my ($self, $values) = @_;

    my $body = $self->{serialized}->{message_type}
        . $Protocol::FIX::SEPARATOR
        . $self->next::method($values);

    my $body_length = $self->{managed_composites}->{BodyLength}
        ->serialize(length($body));

    my $sum = 0;
    $sum += ord $_ for split //, $body;
    $sum %= 256;
    my $checksum = $self->{managed_composites}->{CheckSum}
        ->serialize(sprintf('%03d', $sum));

    return join(
        $Protocol::FIX::SEPARATOR,
        $self->{serialized}->{begin_string},
        $body_length,
        $body,
        $checksum,
        ''
    );
}

1;
