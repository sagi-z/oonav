#!/usr/bin/env perl

use strict;

$|=1;

# Example input:
# * $ARGV[0]='/^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$/'
#
# * $ARGV[1]='3. ScaleUpTriggerInterception.handle_after : docko/client/plugins/scale/commands.py'
#
# * $ARGV[2]='50'

if (@ARGV < 2 or @ARGV > 4) {
    print STDERR "Arguments are [--debug] PATTERNS INFO [MAXLINES=100]\n";
    print STDERR "Got ", int(@ARGV)," args:\n@ARGV\n";
    exit 1;
}

my $debug_on=0;
if ($ARGV[0] eq '--debug') {
    $debug_on=1;
    shift @ARGV;
}

if ($debug_on) {
    # Reproduce then with:
    #  preview_tag.pl "$(cat /tmp/oonav1)" "$(cat /tmp/oonav2)" "$(cat /tmp/oonav3)"
    open(F1, ">", "/tmp/oonav1");
    print F1 $ARGV[0];
    close(F1);
    open(F2, ">", "/tmp/oonav2");
    print F2 $ARGV[1];
    close(F2);
    open(F3, ">", "/tmp/oonav3");
    print F3 $ARGV[2];
    close(F3);
}

my $patterns=$ARGV[0];
my $info=$ARGV[1];
my $max_lines=$ARGV[2] ? $ARGV[2] : 100;

my @info=split(/\s/, $info);
 
# The info is indexed with a period after the number
my $index=int((split(/\./,$info[0]))[0]) - 1;

# The last info part is the filename
my $file=$info[-1];
my @parts=split(/\./, $file);
my $lang="";
if (@parts) {
    $lang="--language $parts[-1]";
}

# Choose the pattern according to the $index
my @patterns_arr=split(/\$\//, $patterns);
my $pattern=substr($patterns_arr[$index], 1);
$pattern=~s/([()])/\\$1/g;

if ($debug_on) {
    open(F4, ">", "/tmp/oonav4");
    print F4 $pattern;
    close(F4);
}

my $pipe2=undef;
if (grep { -x "$_/batcat"} split /:/,$ENV{PATH}) {
    $pipe2="batcat --color=always --style=snip -u --paging=never $lang";
}
elsif (grep { -x "$_/bat"} split /:/,$ENV{PATH}) {
    $pipe2="bat --color=always -u --style=snip --paging=never $lang";
}

open(FILE, "<", $file) or die "Can't open < $file: $!";

my $fout=*STDOUT;
if (defined $pipe2) {
    open($fout, "| $pipe2") or die "Can't open a pipe to $pipe2: $!";
}

my $found=0;
for my $line (<FILE>) {
    if (! $found && $line=~/$pattern/) {
        $found=1;
    }
    if ($found && $max_lines) {
        print $fout "$line\n";
        $max_lines--;
    }
}

# Finish up
close(FILE);
if (defined $pipe2) {
    close($fout);
}
if (!$found) {
    print STDERR "Failed to find '$pattern' in $file.\n"
}

# vim: sw=4:ts=4:expandtab:
