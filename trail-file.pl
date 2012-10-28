#!/usr/bin/perl

use strict;
use warnings;

use Smart::Comments;

use AnyEvent;

local $| = 1;

my $file = shift;

die "Usage: $0 file\n" if not defined $file or ! -e $file;

open my $fh, '<', $file
    or die "Can't open $file: $!";

my $w; $w = AnyEvent->io(
    fh      => $fh,
    poll    => 'r',
    cb      => sub {
        my @data;
        while ( defined (my $line = <$fh>) ){
            push @data, $line;
        }
        data_analyse(\@data) if @data;
    },
);

AnyEvent->condvar->recv;

# do something to the new coming data
sub data_analyse {
    my $data = shift;

    foreach my $line ( @$data ) {
        print "$line";
    }
}
