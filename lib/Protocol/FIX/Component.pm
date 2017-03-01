package Protocol::FIX::Component;

use strict;
use warnings;

use Protocol::FIX;

use parent qw/Protocol::FIX::BaseComposite/;

sub new {
    my ($class, $name, $composites) = @_;

    return next::method($class, $name, 'component', $composites);
}

1;
