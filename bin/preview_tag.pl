#!/usr/bin/env perl

use strict;

$|=1;

# Example input:
# $ARGV[0]='/^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$/'
#
# $ARGV[1]='/^class FormatInterception(InterceptingClientCmd):$//^class HelpInterception(InterceptingClientCmd):$//^class ScaleUpTriggerInterception(InterceptingClientCmd):$//^class FormattedVersionInterception(InterceptingClientCmd):$//^class SimpleVersionCmdInterception(InterceptingClientCmd):$//^class SimpleVersionOptInterception(InterceptingClientCmd):$//^class YAMLVarsInterception(InterceptingClientCmd):$/'
#
# $ARGV[2]='3. ScaleUpTriggerInterception.handle_after : docko/client/plugins/scale/commands.py'
#
# $ARGV[3]='50'

if (@ARGV < 3 or @ARGV > 5) {
    print STDERR "Arguments are [--debug] METHOD_PATTERNS CLASS_PATTERNS INFO [MAXLINES=100]\n";
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
    #  preview_tag.pl "$(cat /tmp/oonav1)" "$(cat /tmp/oonav2)" "$(cat /tmp/oonav3)" "$(cat /tmp/oonav4)"
    open(F1, ">", "/tmp/oonav1");
    print F1 $ARGV[0];
    close(F1);
    open(F2, ">", "/tmp/oonav2");
    print F2 $ARGV[1];
    close(F2);
    open(F3, ">", "/tmp/oonav3");
    print F3 $ARGV[2];
    close(F3);
    open(F4, ">", "/tmp/oonav4");
    print F4 $ARGV[3];
    close(F4);
}

my $method_patterns=$ARGV[0];
my $class_patterns=$ARGV[1];
my $info=$ARGV[2];
my $max_lines=$ARGV[3] ? $ARGV[3] : 100;

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

# Choose the patterns according to the $index
my @method_patterns_arr=split(/\$\//, $method_patterns);
my $method_pattern=substr($method_patterns_arr[$index], 1);
$method_pattern=~s/([()])/\\$1/g;

my @class_patterns_arr=split(/\$\//, $class_patterns);
my $class_pattern=substr($class_patterns_arr[$index], 1);
$class_pattern=~s/([()])/\\$1/g;

#print "will use class pattern '$class_pattern' for method pattern '$method_pattern' for info '@info'\n";
#exit;

if ($debug_on) {
    open(F5, ">", "/tmp/oonav-method_pattern");
    print F5 $method_pattern;
    close(F5);
    open(F6, ">", "/tmp/oonav-class_pattern");
    print F6 $class_pattern;
    close(F6);
}

my $pipe2=undef;
if (grep { -x "$_/batcat"} split /:/,$ENV{PATH}) {
    $pipe2="batcat --color=always --style=snip -u --paging=never $lang";
}
elsif (grep { -x "$_/bat"} split /:/,$ENV{PATH}) {
    $pipe2="bat --color=always --style=snip -u --paging=never $lang";
}

open(FILE, "<", $file) or die "Can't open < $file: $!";

my $fout=*STDOUT;
if (defined $pipe2) {
    open($fout, "| $pipe2") or die "Can't open a pipe to $pipe2: $!";
}

my $found_class=0;
my $found_method=0;
for my $line (<FILE>) {
    if (! $found_class && $line=~/$class_pattern/) {
        $found_class=1;
    } elsif ($found_class && ! $found_method && $line=~/$method_pattern/) {
        $found_method=1;
    }
    if ($found_method && $max_lines) {
        print $fout "$line";
        $max_lines--;
    }
}

# Finish up
close(FILE);
if (defined $pipe2) {
    close($fout);
}
if (!$found_method) {
    print STDERR "Failed to find '$method_pattern' in $file.\n"
}

# vim: sw=4:ts=4:expandtab:
