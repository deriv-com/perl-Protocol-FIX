package Protocol::FIX::MessageInstance;

use strict;
use warnings;

## VERSION

sub new {
    my ($class, $message, $tags_accessor) = @_;
    my $obj = {
        name          => $message->{name},
        category      => $message->{category},
        tags_accessor => $tags_accessor,
    };
    return bless $obj, $class;
}

sub value {
    return shift->{tags_accessor}->value(shift);
}

sub name { shift->{name} }

sub category { shift->{category} }

1;
