#!/usr/bin/env perl

# create a terrible cheesy mockup of a 'newspaper' front page,
# to test a realistic combination of the module's features.

use Modern::Perl;
use PDF::Cairo qw(in);
use PDF::Cairo::Layout;

my $pdf = PDF::Cairo->new(
	paper => 'usletter',
	file => 'frontpage.pdf',
);

# divide up the sheet into a full-width header and two body columns
#
my $page = $pdf->pagebox;

# half-inch margins all around
$page->shrink(all => in(0.5));

my ($header, $body) = $page->split(height => '5%');

# add a little whitespace below the header
$body->shrink(top => 6);

# two columns with quarter-inch gutter
my ($col1, $col2) = $body->split(width => '50%');
$col1->shrink(right => in(1/8));
$col2->shrink(left => in(1/8));

$pdf->save;
$pdf->strokecolor('darkgray');
$pdf->linewidth(2);
$pdf->move($header->x, $header->y + 2)->rel_line($header->width, 0)->stroke;
$pdf->linewidth(0.5);
$pdf->move($header->xy)->rel_line($header->width, 0)->stroke;
$pdf->move($body->cx, $body->y)->rel_line(0, $body->height)->stroke;
$pdf->restore;

# don't print header text on top of the lines we just drew
$header->shrink(bottom => 4);

my $h_font1 = $pdf->loadfont('Times-Bold');
$pdf->setfont($h_font1, 36);
$pdf->move($header->cx, $header->y)->
	print("The FrontPage Times", align => 'center');
my $h_font2 = $pdf->loadfont('Times-Roman');
$pdf->setfont($h_font2, 12);
$pdf->move($header->xy)->print("Early Edition");
$pdf->move($header->x + $header->width, $header->y)->
	print("May 31, 2019", align => 'right');

# load an image into column 1, scaled to its width
my $image = $pdf->loadimage("data/v04image002.png");
my $scale = $col1->width / $image->get_width;

# split column1 at the scaled height of the image
# (TODO: expose image height/width properly, not by
# secretly knowing it's a Cairo::ImageSurface)
my @tmp = $col1->split(height => $image->get_height * $scale);
$pdf->showimage($image, $tmp[0]->xy, scale => $scale);

# leave a bit of whitespace under the image
$col1 = $tmp[1];
$col1->shrink(top => 6);

# use Pango to layout an 'article'
my $layout = PDF::Cairo::Layout->new($pdf);
$layout->size($col1->size);
$pdf->move($col1->x, $col1->y + $col1->height);

my $headline = <<EOF;
<span font="Times 8"><big><b>Picture Is Unrelated!</b></big>

<span style="italic" rise="4096">by Nobody Special</span></span>
EOF
# strip EOL but preserve paragraph separator
$headline =~ s/\n(?!\n)/ /g;
$headline =~ s/\n /\n/g;
$headline =~ s/^ *//;
chomp($headline);

$layout->markup($headline);
$layout->show;

# account for the space used up by the headline
# (TODO: bbox needs to have negative height, but just height seems wrong)
$col1->shrink(top => -$layout->ink->{height});
$layout->size($col1->size);

my $markup = slurp("data/layout1.txt");
$markup =~ s/\n(?!\n)/ /g;
$markup =~ s/\n /\n/g;
$markup =~ s/^ *//;
chomp($markup);

# set some text options
$layout->indent(10);
$layout->spacing(2.5);
$layout->ellipsize('end');

$pdf->move($col1->x, $col1->y + $col1->height);
$layout->markup($markup);
$layout->show;

# now for column 2!

# Note: if you set a font size in a <span>, and have a newline at
# the end of the markup, the final line will be set with the line
# spacing of the Cairo font size that was current when you called
# show().
$markup = slurp("data/layout2.txt");
$markup =~ s/\n(?!\n)/ /g;
$markup =~ s/\n /\n/g;
$markup =~ s/^ *//;
chomp($markup);

$layout->size($col2->size);
$layout->indent(0);
$layout->spacing(0);
$layout->ellipsize('none');
$layout->justify(1);
$layout->alignment('center');
$layout->markup($markup);
$pdf->move($col2->x, $col2->y + $col2->height);
$layout->show;

$col2->shrink(top => -$layout->ink->{height});

$pdf->move($col2->x, $col2->y + $col2->height - 1);
$pdf->save;
$pdf->rel_line($col2->width, 0);
$pdf->rel_move(0, -2);
$pdf->rel_line(-$col2->width, 0);
$pdf->linewidth(0.1);
$pdf->strokecolor('red');
$pdf->stroke;
$pdf->restore;

$col2->shrink(top => 6);

$markup = slurp("data/layout3.txt");
$markup =~ s/\n(?!\n)/ /g;
$markup =~ s/\n /\n/g;
$markup =~ s/^ *//;
chomp($markup);

$layout->size($col2->size);
$layout->spacing(3);
$layout->justify(0);
$layout->alignment('left');
$layout->markup($markup);
$pdf->move($col2->x, $col2->y + $col2->height);
$layout->show;

my $svg = PDF::Cairo->loadsvg("data/treasure-map.svg");
$pdf->place($svg, $col2->x + $col2->width, $col2->y, scale => 0.1, align => 'right');

$pdf->write;
exit;

sub slurp {
	do {local( @ARGV, $/ ) = $_[0]; <>}
}
