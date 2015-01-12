# Author: jkh1
# 2014-11-28

=head1 NAME

  CellH5::ImageHandle

=head1 SYNOPSIS



=head1 DESCRIPTION

  Access to a 5-dimensional array of pixels as stored in the cellh5 format.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::ImageHandle;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Dataset");
use CellH5::Image;

=head2 new

 Arg1: CellH5::Position object
 Description: Creates a new ImageHandle object and opens the image/channel
              dataset at the given position.
 Returntype: CellH5::ImageHandle object

=cut

sub new {

  my $class = shift;
  my $position = shift if @_;
  my $self = HDF5::Dataset->open($position,"image/channel");
  $self->{'position'} = $position;
  bless ($self, $class);
  return $self;
}

=head2 position

 Description: Gets the position object associated with the handle.
 Returntype: CellH5::Position object

=cut

sub position {
  my $self = shift;
  return $self->{'position'};
}

=head2 new_image

 Arg: hashref, must include a 'pixels' attribute with ref to a 2D array
      of pixels
 Description: Creates a new image object
 Returntype: CellH5::Image object

=cut

sub new_image {

  my $self = shift;
  my $hashref = shift if @_;
  return CellH5::Image->new($hashref);
}

=head2 get_image

 Arg1: integer, channel index
 Arg2: integer, time point index
 Arg3: integer, plane (z-slice) index
 Description: Extracts the (x,y) pixels along the given dimensions.
 Returntype: CellH5::Image object

=cut

sub get_image {

  my $self = shift;
  my ($channel,$time_point,$z) = @_ if @_;
  my @dims = $self->dims;  # dimensions are in the order c,t,z,y,x
  my $data = $self->read_data_slice([$channel,$time_point,$z,0,0],[1,1,1,1,1],[1,1,1,$dims[-2],$dims[-1]],[1,1,1,1,1]);
  my $image = CellH5::Image->new({ 'pixels' => $data->[0][0][0] });
  return $image;
}

=head2 get_primary_channel_idx

 Description: Gets the index of the primary channel
 Returntype: integer

=cut

sub get_primary_channel_idx {

  my $self = shift;
  my $idx;
  my $file = $self->position->well->plate->file;
  my $image_def = $file->open_group("definition/image");
  my $channel_def = $image_def->open_dataset("channel");
  my $data = $channel_def->read_data();
  my ($n) = $channel_def->dims;
  foreach my $i(0..$n-1) {
    if ($data->[$i]->{'channel_name'} eq 'primary') {
      $idx = $i;
      last;
    }
  }
  $channel_def->close;
  $image_def->close;
  return $idx;
}

=head2 make_gallery

 Arg: list of CellH5::Image objects
 Description: Creates a gallery of the images. Assumes images are of the same
              size.
 Returntype: CellH5::Image object

=cut

sub make_gallery {

  my $self = shift;
  my @images = @_ if @_;
  my ($m,$n) = $images[0]->dims;
  my $gallery_pixels = [];
  foreach my $i(0..$n-1) {
    foreach my $j(0..$#images) {
      my $pix = $images[$j]->pixels;
      if (!defined($pix->[$i])) {
	croak "\nERROR: Images are not of the same size";
      }
      push @{$gallery_pixels->[$i]},@{$pix->[$i]};
    }
  }
  my $gallery = CellH5::Image->new({ 'pixels' => $gallery_pixels });
  return $gallery;
}

1;
