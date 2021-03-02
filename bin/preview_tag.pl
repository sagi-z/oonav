#!/usr/bin/env perl

$|=1;

# Example input:
# * $ARGV[0]='/^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$//^    def handle_after(self, cmd, parse_context, ret_val):$/'
#
# * $ARGV[1]='3. ScaleUpTriggerInterception.handle_after : docko/client/plugins/scale/commands.py'
#
# * $ARGV[2]='50'

if (@ARGV < 2 or @ARGV > 3) {
    print STDERR "Arguments are PATTERNS INFO [MAXLINES=100]\n";
    print STDERR "Got ", int(@ARGV)," args:\n@ARGV\n";
    exit 1;
}

if (exists($ENV['OONAV_DEBUG'])) {
    # Reproduce then with:
    #  preview_tag.pl "$(cat /tmp/1)" "$(cat /tmp/2)" "$(cat /tmp/3)"
    open(F1, ">", "/tmp/1");
    print F1 $ARGV[0];
    close(F1);
    open(F2, ">", "/tmp/2");
    print F2 $ARGV[1];
    close(F2);
    open(F3, ">", "/tmp/3");
    print F3 $ARGV[2];
    close(F3);
}

$patterns=$ARGV[0];
$info=$ARGV[1];
$max_lines=$ARGV[2] ? $ARGV[2] : 100;


@info=split(/\s/, $info);
 
# The info is indexed with a period after the number
$index=int((split(/\./,$info[0]))[0]) - 1;

# The last info part is the filename
$file=$info[-1];
@parts=split(/\./, $file);
if (@parts) {
    $lang="--language $parts[-1]";
} else {
    $lang=""
}

# Choose the pattern according to the $index
@patterns=split(/\$\//, $patterns);
$pattern=substr($patterns[$index], 1);
$pattern=~s/([()])/\\$1/g;

if (exists($ENV['OONAV_DEBUG'])) {
    open(F4, ">", "/tmp/4");
    print F4 $pattern;
    close(F4);
}

$pipe2=undef;
if (grep { -x "$_/batcat"} split /:/,$ENV{PATH}) {
    $pipe2="batcat --color=always --style=snip -u --paging=never $lang";
}
elsif (grep { -x "$_/bat"} split /:/,$ENV{PATH}) {
    $pipe2="bat --color=always -u --style=snip --paging=never $lang";
}

open(FILE, "<", $file) or die "Can't open < $file: $!";

if ($pipe2) {
    open($fout, "| $pipe2") or die "Can't open a pipe to $pipe2: $!";
} else {
    $fout=STDOUT;
}

$found=0;
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
if ($pipe2) {
    close($fout);
}
if (!$found) {
    print STDERR "Failed to find '$pattern' in $file.\n"
}

# vim: sw=4:ts=4:expandtab:
