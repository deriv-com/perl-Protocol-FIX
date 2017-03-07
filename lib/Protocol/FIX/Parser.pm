package Protocol::FIX::Parser;

use strict;
use warnings;

use List::Util qw/first/;
use Protocol::FIX qw/humanize/;
use Protocol::FIX::TagsAccessor;
use Protocol::FIX::MessageInstance;

sub _parse_tag_pair {
    my ($protocol, $pair, $check_value) = @_;
    return unless $pair;

    if ($pair =~ /^(\d{1,3})($Protocol::FIX::TAG_SEPARATOR)(.*)$/) {
        my ($tag_id, $value) = ($1, $3);

        my $field = $protocol->{fields_lookup}->{by_number}->{$tag_id};
        return (undef, "Protocol error: unknown tag '$tag_id' in tag pair '" . Protocol::FIX::humanize($pair) . "'")
            unless $field;

        return unless defined $3;

        return ([$field, $value]) unless $check_value;

        return (undef, "Protocol error: value for field '" . $field->{name} . "' does not pass validation in tag pair '"
            . Protocol::FIX::humanize($pair) . "'")
            unless $field->check_raw($value);

        return ([$field, $value]);

    } else {
        if ($pair =~ /[\D$Protocol::FIX::TAG_SEPARATOR]+/)  {
            return (undef, "Protocol error: sequence '" . Protocol::FIX::humanize($pair) . "' does not match tag pair");
        }
        return;
    }
}

sub parse {
    my ($protocol, $buff_ref) = @_;
    my $consumed_length = 0;

    # this are fatal messages, i.e. point to developer error, hence we die
    die("buffer is undefined, cannot parse") unless defined $buff_ref;
    die("buffer is not scalar reference") unless ref($buff_ref) eq 'SCALAR';

    my $begin_string = $protocol->{begin_string};
    my $buff_length = length($$buff_ref);

    # no enough data
    return if $buff_length < length($begin_string);

    if (substr($$buff_ref, 0, length($begin_string)) ne $begin_string) {
        return (undef, "Mismatch protocol introduction, expected: $begin_string");
    }

    # no enough data
    return if $buff_length == length($begin_string);

    my @header_pairs = split $Protocol::FIX::SEPARATOR, $$buff_ref, 3;

    # minimal required fields: BeginString, MessageLength, MessageType, CheckSum
    return (undef, "Protocol error: separator expecter right after $begin_string")
        if (@header_pairs < 2);

    $consumed_length += length($begin_string) + 1;

    # extract, but do not check-for-correctness body length
    my $body_length = do {
        my $pair_is_complete = @header_pairs > 2;
        my ($tag_pair, $err) = _parse_tag_pair($protocol, $header_pairs[1], $pair_is_complete);
        return (undef, $err) if $err;

        my ($field, $value) = @$tag_pair;
        if ($field->{name} ne 'BodyLength') {
            return (undef, "Protocol error: expected field 'BodyLength', but got '"
                . $field->{name} . "', in sequence '" . $header_pairs[1] . "'");
        }
        return unless $pair_is_complete;

        $consumed_length += length($header_pairs[1]) + 1;
        $value;
    };

    return if $buff_length <= $consumed_length + $body_length;
    my $trailer = substr($$buff_ref, $consumed_length + $body_length);

    # -1 is included as it is terminator / end of message boundary
    my @trailer_pairs = split $Protocol::FIX::SEPARATOR, $trailer, -1;

    # 3 tags expected: empty - checksum - empty(or may be new message)
    return if (@trailer_pairs < 3) || !$trailer_pairs[1];
    # from here we assume $body_length is valid

    my $checksum_pair = $trailer_pairs[1];
    my $body;
    my $checksum = do {
        my ($tag_pair, $err) = _parse_tag_pair($protocol, $checksum_pair, 1);
        return (undef, $err) if $err;

        my ($field, $value) = @$tag_pair;
        if ($field->{name} ne 'CheckSum') {
            return (undef, "Protocol error: expected field 'CheckSum', but got '"
                . $field->{name} . "', in sequence '" . $checksum_pair . "'");
        }

        my $is_number = ($value =~ /^\d{3}$/);

        if (!$is_number || ($is_number && ($value > 255))) {
            return (undef, "Protocol error: value for field '" . $field->{name} . "' does not pass validation in tag pair '"
                        . Protocol::FIX::humanize($checksum_pair) . "'")
        }

        $body = substr($$buff_ref, $consumed_length, $body_length);
        my $sum = 0;
        $sum += ord $_ for split //, $body;
        $sum %= 256;

        if ($sum != $value) {
            return (undef, "Protocol error: Checksum mismatch;  got $sum, expected $value for message '"
                        . Protocol::FIX::humanize($body) . "'");
        }
        $value;
    };
    my ($message, $errors) = _parse_body($protocol, \$body);
}

sub _parse_body {
    my ($protocol, $body_ref) = @_;
    my @pairs = split $Protocol::FIX::SEPARATOR, $$body_ref;

    my @tag_pairs = map {
        my ($tag_pair, $err) = _parse_tag_pair($protocol, $_, 1);
        return (undef, $err) if $err;
        $tag_pair;
    } @pairs;

    my $msg_type_pair = first { $_->[0]->{name} eq 'MsgType' } @tag_pairs;
    return (undef, "Protocol error: 'MsgType' was not found in body")
        unless $msg_type_pair;

    my ($field_msg_type, $msg_type) = @$msg_type_pair;
    my $message = $protocol->{messages_lookup}->{by_number}->{$msg_type};
    # we don't die, as it might be possible to use custom message types
    # http://fixwiki.org/fixwiki/MsgType
    return (undef, "Protocol error: MessageType '$msg_type' is not available")
        unless $message;

    my ($ta, $err) = _construct_tag_accessor($protocol, $message, \@tag_pairs);
    return (undef, $err) if $err;

    return (new Protocol::FIX::MessageInstance($message, $ta));
};

sub _construct_tag_accessor {
    my ($protocol, $composite, $tag_pairs) = @_;

    my @direct_pairs;
    for my $pair (@$tag_pairs) {
        my ($field, $value) = @$pair;

        next if exists $protocol->managed_composites->{$field->{name}};

        if ($composite->{composite_by_name}->{$field->{name}}) {
            my $humanized_value = $field->{values}->{by_id}->{$value} // $value;
            push @direct_pairs, $field => $humanized_value;
        } else {
            ...;
        }
    }
    return (Protocol::FIX::TagsAccessor->new(\@direct_pairs));
}

1;
