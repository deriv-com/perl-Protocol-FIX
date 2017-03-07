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
        ok !$err;

        ($m, $err) = $proto->parse_message(\"8=FIX.4.4");
        ok !$m;
        ok !$err;
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
        ok !$err;
    };

    subtest "incomplete length tag pair" => sub {
        my $buff = dehumanize("8=FIX.4.4 | 9=4");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        ok !$err;
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
        ok !$err;

        $buff = dehumanize("8=FIX.4.4 | 9=4 | 10=01");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        ok !$err;

        # 10=A inside body
        $buff = $buff = dehumanize("8=FIX.4.4 | 9=4 | 10=A | ");
        ($m, $err) = $proto->parse_message(\$buff);
        ok !$m;
        ok !$err;
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

subtest "simple logon message" => sub {
    my $buff = dehumanize('8=FIX.4.4 | 9=55 | 35=A | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 98=0 | 108=60 | 10=106 | ');

    my ($mi, $err) = $proto->parse_message(\$buff);
    ok $mi;
    ok !$err;

    is $mi->name, 'Logon';
    is $mi->category, 'admin';
    is $mi->value('SenderCompID'), 'me';
    is $mi->value('TargetCompID'), 'you';
    is $mi->value('MsgSeqNum'), '1';
    is $mi->value('SendingTime'), '20090107-18:15:16';
    is $mi->value('EncryptMethod'), 'NONE';
    is $mi->value('HeartBtInt'), 60;
};

# TODO
# feed by-byte valid message
# feed 2 serialized messages


done_testing
