# Author: jkh1
# 2014-12-06

=head1 NAME

  CellH5::Image

=head1 SYNOPSIS



=head1 DESCRIPTION

 An image is a 2D array of pixels


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Image;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use File::Temp;

=head2 new

 Arg: hashref, must include a 'pixels' attribute with ref to a 2D array
      of pixels
 Description: Creates a new image object
 Returntype: CellH5::Image object

=cut

sub new {

  my $class = shift;
  my $self = shift if @_;
  if (!defined($self->{'pixels'})) {
    croak "\nERROR: Can't create new image without pixels";
  }
  bless ($self, $class);
  return $self;
}

=head2 pixels

 Description: Gets the image's 2D array of pixels
 Returntype: Arrayref

=cut

sub pixels {
  my $self = shift;
  return $self->{'pixels'};
}

=head2 pgm

 Arg: string, file name
 Description: Outputs the image's 2D array of pixels as a PGM file
 Returntype: true

=cut

sub pgm {

  my $self = shift;
  my $filename = shift if @_;
  my $image = $self->pixels;
  my $n = scalar(@{$image});
  my $m = scalar(@{$image->[0]});
  open (my $out,">",$filename) or die "\nERROR: Can't write file $filename: $!\n";
  binmode($out);
  print $out "P2\n$m $n\n255\n";
  my $count = 0;
  foreach my $i(0..$n-1) {
    foreach my $j(0..$m-1) {
      print $out $image->[$i][$j];
      if (++$count>=70) {
	print $out "\n";
	$count = 0;
      }
      else {
	print $out " ";
      }
    }
  }
  close $out;
}

=head2 png

 Arg: string, file name
 Description: Outputs the image's 2D array of pixels as a PNG file.
              This actually writes a temporary PGM file and then converts it
              to png using either Netpbm's pnmtopng or ImageMagick's convert
 Returntype: true

=cut

sub png {

  my $self = shift;
  my $filename = shift if @_;
  my $pnmtopng = qx(which pnmtopng);
  chomp($pnmtopng);
  my $convert = qx(which convert);
  chomp($convert);
  my $cmd = $pnmtopng || $convert;
  if (!$cmd) {
    croak "\ERROR: Couldn't find netpbm's pnmtopng or ImageMagick's convert";
  }
  my $fh = File::Temp->new();
  my $fname = $fh->filename;
  if ($self->pgm($fname)) {
    my @cmd;
    if ($cmd =~/pnmtopng/) {
      @cmd = qw($cmd $fname > $filename);
    }
    else {
      @cmd = qw($cmd $fname $filename);
    }
    system(@cmd) == 0 or die "\nERROR: Couldn't write PNG file $filename";
  }
  1;
}

1;
