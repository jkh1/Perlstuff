# Author: jkh1
# 2014-11-12

=head1 NAME

  CellH5::Position

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of a position within a well.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Position;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Group");
use CellH5::ImageHandle;
use CellH5::ObjectHandle;
use CellH5::EventHandle;


=head2 new

 Arg1: CellH5::Well object
 Arg2: string, position name/label
 Description: Creates a new Position object and opens the corresponding group
              in the cellh5 file.
 Returntype: CellH5::Position object

=cut

sub new {

  my $class = shift;
  my ($well,$name) = @_ if @_;
  my $self = HDF5::Group->open($well,"position/$name");
  $self->{'well'} = $well;
  $self->{'name'} = $name;
  bless ($self, $class);
  return $self;
}

=head2 well

 Description: Gets the well the position is in.
 Returntype: CellH5::Well object

=cut

sub well {
  my $self = shift;
  return $self->{'well'};
}

=head2 get_image_handle

 Description: Gets an image handle object to access images taken at this
              position.
 Returntype: CellH5::ImageHandle object

=cut

sub get_image_handle {

  my $self = shift;
  my $image = CellH5::ImageHandle->new($self);
  return $image;
}

=head2 get_object_handle

 Description: Gets a handle to objects at this position.
 Returntype: CellH5::ObjectHandle object

=cut

sub get_object_handle {

  my $self = shift;
  my $oh = CellH5::ObjectHandle->new($self);
  return $oh;
}

=head2 get_event_handle

 Description: Gets a handle to events at this position.
 Returntype: CellH5::EventHandle object

=cut

sub get_event_handle {

  my $self = shift;
  my $eh = CellH5::EventHandle->new($self);
  return $eh;
}

1;
