# Author: jkh1
# 2014-12-04

=head1 NAME

  CellH5::ObjectHandle

=head1 SYNOPSIS



=head1 DESCRIPTION

 Access to segmented objects


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::ObjectHandle;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Dataset");
use CellH5::Object;

=head2 new

 Arg1: CellH5::Position object
 Description: Creates a new handle object to give access to objects at the
              given position.
 Returntype: CellH5::ObjectHandle object

=cut

sub new {

  my $class = shift;
  my $position = shift if @_;
  my $self = HDF5::Dataset->open($position,"object/primary__primary");
  bless ($self, $class);
  $self->{position} = $position;
  return $self;
}

=head2 position

 Description: Gets the position the handle is associated with.
 Returntype: CellH5::Position object

=cut

sub position {

  my $self = shift;
  return $self->{'position'};
}

=head2 get_all_objects

 Description: Gets all objects from the position the handle is associated with.
 Returntype: list of CellH5::Object objects

=cut

sub get_all_objects {

  my $self = shift;
  my @objects;
  my $data = $self->read_data();
  my ($n) = $self->dims;
  foreach my $i(0..$n-1) {
    $data->[$i]->{'idx'} = $i;
    my $object = CellH5::Object->new($self->position,$data->[$i]);
    push @objects, $object;
  }
  return @objects;
}

=head2 get_object_by_idx

 Arg: integer, index of the object
 Description: Gets the object with the given index.
 Returntype: CellH5::Object object

=cut

sub get_object_by_idx {

  my $self = shift;
  my $idx = shift if @_;
  my @objects = $self->get_all_objects;
  return $objects[$idx];
}

=head2 get_all_objects_by_time

 Arg: integer, time index
 Description: Gets all the objects at the given time point.
 Returntype: list of CellH5::Object objects

=cut

sub get_all_objects_by_time {

  my $self = shift;
  my $idx = shift if @_;
  my @object = grep { $_->time_idx == $idx } $self->get_all_objects;
  return @object;
}

=head2 get_all_features

 Description: Gets all the feature vectors describing objects at the position
              the handle is associated with.
 Returntype: Arrayref (2D array)

=cut

sub get_all_features {

  my $self = shift;
  if (!defined($self->{'features'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/object_features");
    my $self->{'features'} = $d->read_data();
    $d->close;
  }
  return $self->{'features'};
}

=head2 get_tracking_data

 Description: Gets tracking data for all objects.
              Synopsis for use of the returned hashref:
                  @{$hashref->{$object_idx}{'children'}}
                  @{$hashref->{$object_idx}{'parents'}}
 Returntype: hashref

=cut

sub get_tracking_data {

  my $self = shift;
  if (!defined($self->{'tracking'})) {
    my $d = $self->position->open_dataset("object/tracking");
    my $data = $d->read_data();
    my ($n) = $d->dims;
    my %tracking;
    foreach my $i(0..$n-1) {
      push @{$tracking{$data->[$i]->{'obj_idx1'}}{'children'}}, $data->[$i]->{'obj_idx2'};
      push @{$tracking{$data->[$i]->{'obj_idx2'}}{'parents'}}, $data->[$i]->{'obj_idx1'};
    }
    $self->{'tracking'} = \%tracking;
    $d->close;
  }
  return $self->{'tracking'};
}

=head2 get_all_centers

 Description: Gets all object centers from the position the handle is
              associated with.
              Synopsis for use of returned arrayref:
                  $centers->[$obj_idx]->{'x'}
 Returntype: Arrayref of hashrefs

=cut

sub get_all_centers {

  my $self = shift;
  if (!defined($self->{'centers'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/center");
    $self->{'centers'} = $d->read_data();
    $d->close;
  }
  return $self->{'centers'};
}

=head2 get_all_bounding_boxes

 Description: Gets the coordinates of the object's bounding box.
              Synopsis for use of returned arrayref:
                   $boxes->[$obj_idx]->{'top'}
 Returntype: Arrayref of hashrefs

=cut

sub get_all_bounding_boxes {

  my $self = shift;
  if (!defined($self->{'bounding_boxes'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/bounding_box");
    $self->{'bounding_boxes'} = $d->read_data();
    $d->close;
  }
  return $self->{'bounding_boxes'};
}

1;
