use strict;
use warnings;

use Test::More;

use Protocol::FIX;

my $proto = Protocol::FIX->new('FIX44');
ok $proto;

subtest "check simple field" => sub {
    my $f_account = $proto->field_by_name('Account');
    ok $f_account;
    my $f_account_2 = $proto->field_by_number(1);
    ok $f_account_2;
    is $f_account, $f_account_2;
};


subtest "check field with enum(AdvSide)" => sub {
    my $f = $proto->field_by_name('AdvSide');
    ok $f;
    my $f_2 = $proto->field_by_number(4);
    ok $f_2;
    is $f, $f_2;
};


done_testing;
