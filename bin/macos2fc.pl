#!/usr/bin/env perl
#
# create a directory full of symlinks and a fontconfig XML config file
# pointing to it, to support all active MacOS fonts, not just the ones
# in the short list of directories that Fontconfig typically searches.
# Run "fc-list | wc -l" before and after to confirm that it succeeded.

use strict;
use warnings;
use utf8::all;
use File::Path qw(make_path remove_tree);

my $DIR = "$ENV{HOME}/.config/fontconfig";
my $NAME = "mac-activated-fonts";
make_path($DIR);
chdir($DIR) or die "$0: $DIR: $!\n";
make_path("conf.d", "$NAME-new");

open(my $Out, ">", "conf.d/00-$NAME.conf-new");
print $Out <<EOF;
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
 <dir>$DIR/$NAME</dir>
</fontconfig>
EOF
close($Out);

open(my $In, "-|", "/usr/sbin/system_profiler SPFontsDataType");
my @fonts;
my $currfont = {};
while (<$In>) {
	chomp;
	s/^( *)//;
	my $indent = length($1);
	if ($indent == 4) {
		# ignore resource-fork PS fonts with no file extension
		if ($currfont->{filename} and $currfont->{filename} =~ /^.+\./) {
			push(@fonts, $currfont);
		}
		s/:\s*$//;
		$currfont = { filename => $_ };
	}
	next unless $currfont->{filename};
	if ($indent == 6) {
		if (/^(Enabled: No|Kind: Bitmap)/) {
			$currfont = {};
			next;
		}
		if (/^Location: (.*)$/) {
			$currfont->{location} = $1;
		}elsif (/^Kind: (.*)$/) {
			$currfont->{kind} = $1;
		}
	}elsif ($indent == 8) {
		s/:\s*$//;
		$currfont->{fonts} = []
			unless ref $currfont->{fonts} eq "ARRAY";
		push(@{$currfont->{fonts}}, { name => $_});
	}elsif ($indent == 10) {
		my @tmp = @{$currfont->{fonts}};
		if (my ($key, $val) = /^(Full Name|Family|Style): (.*)$/) {
			$key =~ tr/ A-Z/_a-z/;
			$tmp[$#tmp]->{$key} = $val;
		}
	}else{
		next;
	}
}
close($In);
push(@fonts, $currfont);

open($Out, ">", "$NAME-new/README.txt")
	or die "$0: $DIR/$NAME-new/README.txt: $!";
print $Out "#\n#filename[,index]\tfull name\tfamily\tstyle\n#\n";
foreach my $file (sort { $a->{filename} cmp $b->{filename} } @fonts) {
	my $filename = $file->{filename};
	$filename =~ s/^\.//; # Adobe Typekit fonts have leading "."
	symlink($file->{location}, "$NAME-new/$filename");
	my $index = 0;
	foreach my $font (@{$file->{fonts}}) {
		my $i = $index > 0 ? ",$index" : "";
		print $Out join("\t", $file->{filename} . $i, $font->{full_name},
			$font->{family}, $font->{style}), "\n";
		$index++;
	}
}
close($Out);

remove_tree("conf.d/00-$NAME.conf", "$NAME");
rename("$NAME-new", $NAME);
rename("conf.d/00-$NAME.conf-new", "conf.d/00-$NAME.conf");

exit 0;
