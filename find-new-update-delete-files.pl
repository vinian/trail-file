#!/usr/bin/perl

use strict;
use warnings;

use Smart::Comments;
use LWP::UserAgent;
use FindBin;
use POSIX;
use List::AllUtils qw( uniq );

daemon();

my $dir = '/dir/which/need/to/find';
our @all_files = `find $dir -type f`;
map { chomp } @all_files;

# every three min check
my $sleep_time = 180;

my $old_time = time;
while ( 1 ) {
    my $new_time = time;
    my $time = adjust_pass_time($old_time, $new_time);
    my $new_files = find_new_and_update_files($dir, $time);
    my $del_files = find_delete_files($dir, \@all_files);

    my @need_purge_files = (@$new_files, @$del_files);
    @need_purge_files = uniq @need_purge_files;
### @need_purge_files
    purge_files( $dir, \@need_purge_files );
    $old_time = time;
    sleep $sleep_time;

}

sub find_new_and_update_files {
    my ($dir, $time) = @_;
    ### $time
    $time = 5 if not defined $time;
    # it can only find new and modify file
    my @files = `find $dir -type f -mmin -$time 2>/dev/null`;

    map { chomp } @files;

    # found the file that only renamed
    my $rename_files = find_rename_files($dir, \@all_files);
    push @files, @$rename_files;
### @files
    push @all_files, @files;

    foreach my $f ( @files ) {
        run_log($f, 'new or update');
    }

    return \@files;
}

sub find_rename_files {
    my ($dir, $old_files) = @_;
    my @found_files = `find $dir -type f`;

    map { chomp } @found_files;

    my %hash;
    $hash{$_} = 1 for @$old_files;
    my @new_files;
    foreach my $f ( @found_files ) {
        if ( not exists $hash{$f} ) {
	    push @new_files, $f;
            $hash{$f} = 1;
	}
    }
  
    @all_files = keys %hash;
    return \@new_files;
}

sub find_delete_files {
    my ($dir, $old_files) = @_;
    my (@exist_files, @del_files);
    foreach my $file ( @$old_files ) {
        if ( -e $file ) {
             push @exist_files, $file;
         } else {
            push @del_files, $file;
         }
    }

    @all_files = @exist_files;

    foreach my $f ( @del_files ) {
        run_log($f, 'deleted');
    }
### @del_files

    return \@del_files;
}

sub purge_files {
    my ($dir, $files) = @_;

    my @cache_servers = qw(localhost);
    my $ua = LWP::UserAgent->new(
        timeout => 10,
    );
    foreach my $file ( @$files ) {
      $file =~ s{$dir}{};
        foreach my $server ( @cache_servers ) {
            my $url = "http://$server:9000/purge/$file";
### $url
            my $response = $ua->get( $url );
            if ( $response->is_success ) {
                run_log("purge cache $url success");
            } else {
                run_log("purge cache $url failed: ", $response->status_line());
            }
        }
    }
}

sub daemon {
    my ($pid, $sess_id, $i);

    if ( $pid = fork ) {
        exit 0;
    }

    Carp::croak "can't detach from controlling terminal"
          unless $sess_id = POSIX::setsid();

    $SIG{'HUP'} = 'IGNORE';

    if ( $pid = fork ) {
        exit 0;
    }

    chdir "/";
    umask 0;

    open(STDIN,  "<", "/dev/null");
    open(STDOUT, "<", "/dev/null");
    open(STDERR, "<", "/dev/null");
}

sub run_log {
    my @args = join ' ', @_;

    my $file = $FindBin::Bin .  '/ebook_purge.log';
    open my $fh, '>>', $file
        or die "Can't open $file: $!";
    print $fh time, ' ', @args;
    print $fh "\n";
    close $fh;

    return;
}

sub adjust_pass_time {
    my ($o_time, $n_time) = @_;

    my $pass = sprintf("%d", ($n_time - $o_time)/60) + 1;

    $pass = 5 if $pass < 0;
    return $pass;
}

