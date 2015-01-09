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

{
  my $pnmtopng = qx(which pnmtopng);
  chomp($pnmtopng);
  my $convert = qx(which convert);
  chomp($convert);
  my $cmd = $pnmtopng || $convert;

  sub pnm2png {
    return $cmd;
  }

}

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

=head2 dims

 Description: Gets the dimensions of the image
 Returntype: Array

=cut

sub dims {

  my $self = shift;
  my $pixels = $self->pixels;
  my $n = scalar(@{$pixels});
  my $m = scalar(@{$pixels->[0]});
  return ($m,$n);
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
  my ($m,$n) = $self->dims;
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
  my $cmd = pnm2png();
  if (!$cmd) {
    croak "\nERROR: Couldn't find netpbm's pnmtopng or ImageMagick's convert";
  }
  my $fh = File::Temp->new(UNLINK=>0);
  my $fname = $fh->filename;
  if ($self->pgm($fname)) {
    my @cmd;
    if ($cmd =~/pnmtopng/) {
      @cmd = ("$cmd $fname > $filename");
    }
    else {
      @cmd = ($cmd, $fname, $filename);
    }
    system(@cmd) == 0 or die "\nERROR: Couldn't write PNG file $filename using command\n",join(" ",@cmd),"\n";
  }
  unlink($fname);
  1;
}

1;
