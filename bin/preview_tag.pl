#!/usr/bin/env perl

$|=1;

if (@ARGV < 2 or @ARGV > 3) {
    print STDERR "Arguments are PATTERNS INFO [MAXLINES=100]\n";
    print STDERR "Got ", int(@ARGV)," args:\n@ARGV\n";
    exit 1;
}

#open(F1, ">", "/tmp/1");
#print F1 $ARGV[0];
#close(F1);
#open(F2, ">", "/tmp/2");
#print F2 $ARGV[1];
#close(F2);
#open(F3, ">", "/tmp/3");
#print F3 $ARGV[2];
#close(F3);

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

#open(F4, ">", "/tmp/4");
#print F4 $pattern;
#close(F4);

$pipe2=undef;
if (grep { -x "$_/batcat"} split /:/,$ENV{PATH}) {
    $pipe2="batcat --color=always --style=snip -u --paging=never $lang";
}
elsif (grep { -x "$_/bat"} split /:/,$ENV{PATH}) {
    $pipe2="bat --color=always -u --style=snip --paging=never $lang";
} else {
    $pipe2='cat';
}

open(FILE, "<", $file) or die "Can't open < $file: $!";
open(FOUT, "| $pipe2") or die "Can't open a pipe to $pipe2: $!";

$found=0;
for my $line (<FILE>) {
    if (! $found && $line=~/$pattern/) {
        $found=1;
    }
    if ($found && $max_lines) {
        print FOUT "$line\n";
        $max_lines--;
    }
}
close(FILE);
if ($found) {
    close(FOUT);
} else {
    print STDERR "Failed to find '$pattern' in $file.\n"
}
