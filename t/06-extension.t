use strict;
use warnings;

use Test::More;
use Test::Warnings;
use List::Util qw/any/;

use Protocol::FIX;

my $proto = Protocol::FIX->new('FIX44')->extension('t/data/extension-sample.xml');
ok $proto;

my $awesome_field = $proto->field_by_name('AwesomeField');
ok $awesome_field, "custom field defininition is available";

my $m = $proto->message_by_name('Logon');
ok $m;

my $f_descr = $m->{composite_by_name}->{AwesomeField};
ok $f_descr, "custom field is available in the message";
is $f_descr->[0], $awesome_field, "it refers to the correct object";

my $is_mandatory = any { $_ eq $awesome_field->{name} } @{ $m->{mandatory_composites} };
ok $is_mandatory, "required='Y' has been applied";

done_testing;
