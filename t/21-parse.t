use strict;
use warnings;

use Test::Fatal;
use Test::More;
use Test::Warnings;

use Protocol::FIX qw/humanize/;

my $proto = Protocol::FIX->new('FIX44');

sub dehumanize {
    my $buff = shift;
    return $buff =~ s/ \| /\x{01}/gr;
};

subtest "header & trail errors" => sub {
    my ($m, $err);

    subtest "not enough data" => sub {
        ($m, $err) = $proto->parse_message(\"");
        ok !$m;
        is $err, undef;

        ($m, $err) = $proto->parse_message(\"8=FIX.4.4");
        ok !$m;
        is $err, undef;
    };

    subtest "protocol mismatch" => sub {
        ($m, $err) = $proto->parse_message(\"8=FIX.4.3");
        ok !$m;
        is $err, "Mismatch protocol introduction, expected: 8=FIX.4.4";
    };

    subtest "protocol error (wrong separator)" => sub {
        ($m, $err) = $proto->parse_message(\"8=FIX.4.4_");
        ok !$m;
        is $err, "Protocol error: separator expecter right after 8=FIX.4.4";
    };

    subtest "protocol error (wrong tag)" => sub {
        my $buff = dehumanize("8=FIX.4.4 | z=5");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: sequence 'z=5' does not match tag pair";
    };

    subtest "protocol error (wrong tag)" => sub {
        my $buff = dehumanize("8=FIX.4.4 | zz");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: sequence 'zz' does not match tag pair";
    };

    subtest "protocol error (wrong tag)" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 999=5");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: unknown tag '999' in tag pair '999=5'";
    };

    subtest "protocol error (not length)" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 8=4");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: expected field 'BodyLength', but got 'BeginString', in sequence '8=4'";
    };

    subtest "incomplete length tag pair" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=4");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, undef;
    };

    subtest "incomplete length tag pair" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=4");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, undef;
    };

    subtest "wrong body length" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=0 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: value for field 'BodyLength' does not pass validation in tag pair '9=0'";
    };

    subtest "no checksum yet" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=4 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, undef;

        $buff = dehumanize("8=FIX.4.4 | 9=4 | 10=01");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, undef;

        # 10=A inside body
        $buff = $buff = dehumanize("8=FIX.4.4 | 9=4 | 10=A | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, undef;
    };

    subtest "wrong checksum" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=3 | ... | 10=A | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: value for field 'CheckSum' does not pass validation in tag pair '10=A'";

        $buff = dehumanize("8=FIX.4.4 | 9=3 | ... | 10=1000 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: value for field 'CheckSum' does not pass validation in tag pair '10=1000'";

        $buff = dehumanize("8=FIX.4.4 | 9=3 | ... | 10=256 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: value for field 'CheckSum' does not pass validation in tag pair '10=256'";

        $buff = dehumanize("8=FIX.4.4 | 9=3 | ... | 10=015 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: Checksum mismatch;  got 138, expected 015 for message '...'";
    };

};

subtest "body errors" => sub {
    my ($m, $err, $buff);

    subtest "no MsgType" => sub {
        $buff = dehumanize("8=FIX.4.4 | 9=3 | 9=4 | 10=170 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: 'MsgType' was not found in body";
    };

    subtest "wrong MsgType" => sub {
        $buff = dehumanize("8=FIX.4.4 | 9=5 | 35=ZZ | 10=089 | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        is $err, "Protocol error: value for field 'MsgType' does not pass validation in tag pair '35=ZZ'";
    };

};

subtest "simple message (Logon)" => sub {
    my $buff = dehumanize('8=FIX.4.4 | 9=55 | 35=A | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 98=0 | 108=60 | 10=106 | ');

    my ($mi, $err) = $proto->parse_message(\$buff);
    ok $mi;
    is $err, undef;

    is $mi->name, 'Logon';
    is $mi->category, 'admin';
    is $mi->value('SenderCompID'), 'me';
    is $mi->value('TargetCompID'), 'you';
    is $mi->value('MsgSeqNum'), '1';
    is $mi->value('SendingTime'), '20090107-18:15:16';
    is $mi->value('EncryptMethod'), 'NONE';
    is $mi->value('HeartBtInt'), 60;
};

subtest "message with component (MarketDataRequestReject)" => sub {
    my $buff = dehumanize('8=FIX.4.4 | 9=65 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 816=1 | 817=def | 10=127 | ');
    my $buff_copy = $buff;

    my $check_message = sub {
        my ($mi, $err) = @_;
        ok $mi;
        is $err, undef;

        is $mi->name, 'MarketDataRequestReject';
        is $mi->category, 'app';
        is $mi->value('SenderCompID'), 'me';
        is $mi->value('TargetCompID'), 'you';
        is $mi->value('MsgSeqNum'), '1';
        is $mi->value('SendingTime'), '20090107-18:15:16';
        is $mi->value('MDReqID'), 'abc';

        my $group = $mi->value('MDRjctGrp')->value('NoAltMDSource');
        ok $group;
        is scalar(@$group), 1;
        is $group->[0]->value('AltMDSourceID'), 'def';
    };

    subtest "single message consumption" => sub {
        my ($mi, $err) = $proto->parse_message(\$buff);
        $check_message->($mi, $err);
        is $buff, '';
    };

    subtest "double message consumption" => sub {
        $buff = $buff_copy . $buff_copy;
        my ($mi1, $err1) = $proto->parse_message(\$buff);
        $check_message->($mi1, $err1);
        is $buff, $buff_copy;

        my ($mi2, $err2) = $proto->parse_message(\$buff);
        $check_message->($mi2, $err2);
        is $buff, '';
    };

    subtest "byte-by-byte feeding" => sub {
        for my $length (0 .. length($buff_copy) - 1) {
            $buff = substr($buff_copy, 0, $length);
            my ($mi, $err) = $proto->parse_message(\$buff);
            is $mi, undef;
            is $err, undef;
        }
    };

    subtest "2 entities in group" => sub {
        $buff = dehumanize('8=FIX.4.4 | 9=74 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 816=2 | 817=def | 817=ghjl | 10=003 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        ok $mi;
        is $err, undef;
    };
};

subtest "body errors" => sub {
    subtest "unexpected field (BeginString)" => sub {
        my $buff = dehumanize('8=FIX.4.4 | 9=72 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 8=FIX.4.4 | 816=1 | 817=def | 10=113 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        is $mi, undef;
        is $err, "Protocol error: field 'BeginString' was not expected in message 'MarketDataRequestReject'";
    };

    subtest "unexpected field (HeartBtInt)" => sub {
        my $buff = dehumanize('8=FIX.4.4 | 9=70 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 108=21 | 816=1 | 817=def | 10=238 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        is $mi, undef;
        is $err, "Protocol error: field 'HeartBtInt' was not expected in message 'MarketDataRequestReject'";
    };

    subtest "too many groups (1 declared, send 2)" => sub {
        my $buff = dehumanize('8=FIX.4.4 | 9=73 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 816=1 | 817=def | 817=aaa | 10=128 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        is $mi, undef;
        is $err, "Protocol error: field 'AltMDSourceID' was not expected in message 'MarketDataRequestReject'";
    };

    subtest "too few groups (2 declared, send 1)" => sub {
        my $buff = dehumanize('8=FIX.4.4 | 9=65 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 262=abc | 816=2 | 817=def | 10=128 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        is $mi, undef;
        is $err, "Protocol error: cannot construct item #2 for component 'MDRjctGrp' (group 'NoAltMDSource')";
    };

    subtest "missing mandatory field" => sub {
        my $buff = dehumanize('8=FIX.4.4 | 9=57 | 35=Y | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 816=1 | 817=def | 10=129 | ');
        my ($mi, $err) = $proto->parse_message(\$buff);
        is $mi, undef;
        is $err, "Protocol error: 'MDReqID' is mandatory for message 'MarketDataRequestReject'";
    };
};

subtest "message with group (Logon)" => sub {
    fail "implement me";
};

subtest "Complex message: component, with group of components" => sub {
    fail "implement me";
};

done_testing;
