use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Warnings;

use Protocol::FIX::Field;

subtest "STRING" => sub {
    subtest "string filed w/o enumerations" => sub {
        my $f = Protocol::FIX::Field->new(1, 'Account', 'STRING');
        my $s = $f->serialise('abc');
        is $s, '1=abc';

        ok $f->check('abc');
        ok !$f->check(undef);

        ok !$f->check('='), "delimiter is not allowed";
        like exception { $f->serialise('=') }, qr/not acceptable/;
    };

    subtest "string filed with enumerations" => sub {
        my $f = Protocol::FIX::Field->new(5, 'AdvTransType', 'STRING', {
            N => 'NEW',
            C => 'CANCEL',
            R => 'REPLACE',
        });
        is $f->serialise('NEW'), '5=N';

        ok $f->check('NEW');
        ok $f->check('CANCEL');
        ok $f->check('REPLACE');

        ok !$f->check(undef);
        ok !$f->check('NEw');
        ok !$f->check('something else');
    };
};

subtest "INT" => sub {
    subtest "w/o enumerations" => sub {
        my $f = Protocol::FIX::Field->new(68, 'TotNoOrders', 'INT');
        is $f->serialise(5), '68=5';
        ok $f->check(5);
        ok $f->check(-5);

        ok !$f->check("+5");
        ok !$f->check("abc");
        ok !$f->check("");
        ok !$f->check(undef);
    };

    subtest "with enumerations" => sub {
        my $f = Protocol::FIX::Field->new(87, 'AllocStatus', 'INT', {
            0 => 'ACCEPTED',
            1 => 'BLOCK_LEVEL_REJECT',
        });
        is $f->serialise('BLOCK_LEVEL_REJECT'), '87=1';
        ok $f->check('ACCEPTED');

        ok !$f->check(0);
        ok !$f->check(1);
        ok !$f->check("");
        ok !$f->check(undef);
    };
};

subtest "LENGTH" => sub {
    my $f = Protocol::FIX::Field->new(90, 'SecureDataLen', 'LENGTH');
    is $f->serialise(3), '90=3';
    ok $f->check(5);
    ok $f->check(55);

    ok !$f->check(0);
    ok !$f->check(-5);
    ok !$f->check("abc");
    ok !$f->check("");
    ok !$f->check(undef);
};

subtest "DATA" => sub {
    my $f = Protocol::FIX::Field->new(91, 'SecureData', 'DATA');
    is $f->serialise('abc==='), '91=abc===';
    ok $f->check('a');
    ok $f->check("\x01");
    ok $f->check(0);

    ok !$f->check("");
    ok !$f->check(undef);
};

done_testing;
