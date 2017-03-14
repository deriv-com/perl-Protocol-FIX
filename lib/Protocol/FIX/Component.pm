package Protocol::FIX::Component;

use strict;
use warnings;

use Protocol::FIX;
use parent qw/Protocol::FIX::BaseComposite/;

## VERSION

sub new {
    my ($class, $name, $composites) = @_;

    my $obj = next::method($class, $name, 'component', $composites);

    return $obj;
}

1;
