# Author: jkh1
# 2014-12-02

=head1 NAME

  CellH5::Object

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of a segmented object


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Object;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;

=head2 new

 Arg1: CellH5::Position object
 Arg2: hashref
 Description: Creates a new segmented object
 Returntype: CellH5::Object object

=cut

sub new {

  my $class = shift;
  my ($position, $self) = @_ if @_;
  if (!defined($self->{'idx'})) {
    croak "\nERROR: Can't create new object without idx";
  }
  $self->{'position'} = $position;
  bless ($self, $class);
  return $self;
}

sub position {

  my $self = shift;
  return $self->{'position'};
}

sub idx {

  my $self = shift;
  return $self->{'idx'};
}

sub label_id {

  my $self = shift;
  if (!defined($self->{'obj_label_id'})) {
    my $oh = $self->position->get_object_handle();
    my $obj = $oh->get_object_by_idx($self->idx);
    # Do not overwrite $self with the new object to avoid losing
    # attributes already set
    $self->{'obj_label_id'} = $obj->label_id;
    $self->{'time_idx'} = $obj->time_idx;
  }
  return $self->{'obj_label_id'};
}

sub time_idx {

  my $self = shift;
  if (!defined($self->{'time_idx'})) {
    my $oh = $self->position->get_object_handle();
    my $obj = $oh->get_object_by_idx($self->idx);
    # Do not overwrite $self with the new object to avoid losing
    # attributes already set
    $self->{'obj_label_id'} = $obj->label_id;
    $self->{'time_idx'} = $obj->time_idx;
  }
  return $self->{'time_idx'};
}

=head2 center

 Description: Gets the coordinates of the object's center.
 Returntype: list of integers as (x,y,z) coordinates

=cut

sub center {

  my $self = shift;
  if (!defined($self->{'x'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/center");
    my $data = $d->read_data();
    my ($n) = $d->dims;
    my $idx = $self->idx;
    $self->{'x'} = $data->[$idx]->{'x'};
    $self->{'y'} = $data->[$idx]->{'y'};
    if ($data->[$idx]->{'z'}) {
      $self->{'z'} = $data->[$idx]->{'z'};
    }
    else {
      $self->{'z'} = 0;
    }
    $d->close;
  }
  return ($self->{'x'},$self->{'y'},$self->{'z'});
}

=head2 bounding_box

 Description: Gets the coordinates of the object's bounding box.
 Returntype: list of integers as (left,right,top,bottom) coordinates

=cut

sub bounding_box {

  my $self = shift;
  if (!defined($self->{'top'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/bounding_box");
    my $data = $d->read_data();
    my ($n) = $d->dims;
    my $idx = $self->idx;
    $self->{'top'} = $data->[$idx]->{'top'};
    $self->{'bottom'} = $data->[$idx]->{'bottom'};
    $self->{'left'} = $data->[$idx]->{'left'};
    $self->{'right'} = $data->[$idx]->{'right'};
    $d->close;
  }
  return ($self->{'top'},$self->{'bottom'},$self->{'left'},$self->{'right'});
}

=head2 features

 Description: Gets the feature vector describing the object.
 Returntype: list of doubles

=cut

sub features {

  my $self = shift;
  if (!defined($self->{'features'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/object_features");
    my @dims = $d->dims;
    my $features = $d->read_data_slice([$self->idx,0],[1,1],[1,$dims[-1]],[1,1]);
    $self->{'features'} = $features->[0];
    $d->close;
  }
  return @{$self->{'features'}} if $self->{'features'};
}

=head2 class_idx

 Description: Gets the index of the class assigned to the object.
 Returntype: integer, class index

=cut

sub class_idx {

  my $self = shift;
  if (!defined($self->{'class_idx'})) {
    my $d = $self->position->open_dataset("feature/primary__primary/object_classification/prediction");
    my $data = $d->read_data();
    my ($n) = $d->dims;
    foreach my $i(0..$n-1) {
      if ($i == $self->idx) {
	$self->{'class_idx'} = $data->[$i]->{'label_idx'};
	last;
      }
    }
    $d->close;
  }
  return $self->{'class_idx'};
}

=head2 class_probability

 Description: Gets the probability associated with the class assigned to the object.
 Returntype: double

=cut

sub class_probability {

  my $self = shift;
  if (!defined($self->{'class_probability'})) {
    my $idx = $self->class_idx;
    my $d = $self->position->open_dataset("feature/primary__primary/object_classification/probability");
    my @dims = $d->dims;
    my $p = $d->read_data_slice([$self->idx,$idx],[1,1],[1,1],[1,1]);
    $self->{'class_probability'} = $p->[0][0];
    $d->close;
  }
  return $self->{'class_probability'};
}

=head2 parents

 Description: Gets the objects preceding this one in the tracking
 Returntype: list of CellH5::Object objects

=cut

sub parents {

  my $self = shift;
  if (!defined($self->{'parents'})) {
    my $oh = $self->position->get_object_handle();
    my $trackref = $oh->get_tracking_data;
    if ($trackref->{$self->idx} && $trackref->{$self->idx}{'parents'}) {
      foreach my $idx(@{$trackref->{$self->idx}{'parents'}}) {
	push @{$self->{'parents'}}, CellH5::Object->new($self->position,{ 'idx' => $idx });
      }
    }
  }
  return @{$self->{'parents'}} if $self->{'parents'};
}

=head2 children

 Description: Gets the objects following this one in the tracking
 Returntype: list of CellH5::Object objects

=cut

sub children  {

  my $self = shift;
  if (!defined($self->{'children'})) {
    my $oh = $self->position->get_object_handle();
    my $trackref = $oh->get_tracking_data;
    if ($trackref->{$self->idx} && $trackref->{$self->idx}{'children'}) {
      foreach my $idx(@{$trackref->{$self->idx}{'children'}}) {
	push @{$self->{'children'}}, CellH5::Object->new($self->position,{ 'idx' => $idx });
      }
    }
  }
  return @{$self->{'children'}} if $self->{'children'};
}

=head2 get_image

 Arg: (optional) list of integers, size of the image
 Description: Gets the image defined by the object's bounding box or, if
              given a size, defined by the corresponding box centered on the
              object.
 Returntype: CellH5::Image object

=cut

sub get_image  {

  my $self = shift;
  my ($m,$n) = @_ if @_;
  my $image_handle = $self->position->get_image_handle;
  my $channel_idx = $image_handle->get_primary_channel_idx;
  my $time_idx = $self->time_idx;
  my ($x,$y,$z) = $self->center;
  my $pixels;
  unless ($m or $n) {
    my ($top,$bottom,$left,$right) = $self->bounding_box;
    $pixels = $image_handle->read_data_slice([$channel_idx,$time_idx,$z,$top,$left],[1,1,1,1,1],[1,1,1,$bottom-$top,$right-$left],[1,1,1,1,1]);
  }
  else {
    if ($m && !$n) {
      $n = $m;
    }
    if ($n && !$m) {
      $m = $n;
    }
    my $top = $y - int($n/2);
    my $left = $x - int($m/2);
    # TODO: Check bounds and deal with out of range values
    $pixels = $image_handle->read_data_slice([$channel_idx,$time_idx,$z,$top,$left],[1,1,1,1,1],[1,1,1,$m,$n],[1,1,1,1,1]);
  }
  my $image = $image_handle->new_image({ 'pixels' => $pixels->[0][0][0] });
  return $image;
}

1;
