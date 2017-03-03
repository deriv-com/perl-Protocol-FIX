use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Warnings;

use Protocol::FIX qw/humanize/;
use Protocol::FIX::Field;
use Protocol::FIX::Group;
use Protocol::FIX::Component;
use Protocol::FIX::Message;

my $proto = Protocol::FIX->new('FIX44');

subtest "LogonMessage" => sub {

    my @composites = (
        $proto->field_by_name('EncryptMethod') => 1,
        $proto->field_by_name('HeartBtInt') => 1,
        $proto->field_by_name('RawDataLength') => 0,
        $proto->field_by_name('RawData') => 0,
        $proto->field_by_name('ResetSeqNumFlag') => 0,
        $proto->field_by_name('NextExpectedMsgSeqNum') => 0,
        $proto->field_by_name('MaxMessageSize') => 0,
        # NoMsgTypes - it's group
        $proto->field_by_name('TestMessageIndicator') => 0,
        $proto->field_by_name('Username') => 0,
        $proto->field_by_name('Password') => 0,
    );

    my $m = Protocol::FIX::Message->new(
        'Logon',
        'admin',
        'A',
        \@composites,
        $proto,
    );
    ok $m;

    my $s = $m->serialize([
        SenderCompID => 'me',
        TargetCompID => 'you',
        MsgSeqNum   => 1,
        SendingTime => '20090107-18:15:16',
        EncryptMethod => 'NONE',
        HeartBtInt => 21,
    ]);
    is humanize($s),
        '8=FIX.4.4 | 9=55 | 35=A | 49=me | 56=you | 34=1 | 52=20090107-18:15:16 | 98=0 | 108=21 | 10=103';

};

done_testing;
