#!/usr/bin/perl -w

use strict;
use warnings;
use IO::Socket::UNIX qw(SOCK_STREAM);

my $RUN_PATH="/var/run";

my $sendMonitor = sub {
    my $name = shift;
    my $msg  = shift;
    print "$RUN_PATH/$name $msg";

    my $sock = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => "$RUN_PATH/$name",
    ) || do {
        print "Cannot open socket $!\n";
        exit 1;
    };
    print $sock $msg;
# print $sock "$msg\n";
    $sock->close();
};

my $acpiShutdown = sub {
    $sendMonitor->(shift, "system_powerdown\n");
};

$acpiShutdown->($ARGV[0]);

1;
