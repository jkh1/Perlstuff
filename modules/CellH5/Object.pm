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
    my $obj_handle = $self->position->get_object_handle;
    my $d = $obj_handle->get_all_centers;
    my $idx = $self->idx;
    if ($d->[$idx]) {
      $self->{'x'} = $d->[$idx]->{'x'};
      $self->{'y'} = $d->[$idx]->{'y'};
      $self->{'z'} = $d->[$idx]->{'z'} || 0;
    }
  }
  return ($self->{'x'},$self->{'y'},$self->{'z'});
}

=head2 bounding_box

 Description: Gets the coordinates of the object's bounding box.
 Returntype: list of integers as (top,bottom,left,right) coordinates

=cut

sub bounding_box {

  my $self = shift;
  if (!defined($self->{'top'})) {
    my $obj_handle = $self->position->get_object_handle;
    my $data = $obj_handle->get_all_bounding_boxes;
    my $idx = $self->idx;
    if ($data->[$idx]) {
      $self->{'top'} = $data->[$idx]->{'top'};
      $self->{'bottom'} = $data->[$idx]->{'bottom'};
      $self->{'left'} = $data->[$idx]->{'left'};
      $self->{'right'} = $data->[$idx]->{'right'};
    }
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
    my $obj_handle = $self->position->get_object_handle;
    my $d = $obj_handle->get_all_features;
    my $idx = $self->idx;
    if ($d->[$idx]) {
      $self->{'features'} = $d->[$idx];
    }
  }
  return @{$self->{'features'}} if $self->{'features'};
}

=head2 class

 Description: Gets the class assigned to the object.
 Returntype: CellH5::Class object

=cut

sub class {

  my $self = shift;
  if (!defined($self->{'class'})) {
    my $file = $self->position->well->plate->file;
    my $class_handle = CellH5::ClassHandle->new($file);
    my @classes = $class_handle->get_all_classes;
    $self->{'class'} = $classes[$self->class_idx];
    $class_handle->close;
  }
  return $self->{'class'};
}

=head2 class_idx

 Description: Gets the index of the class assigned to the object.
 Returntype: integer, class index

=cut

sub class_idx {

  my $self = shift;
  if (!defined($self->{'class_idx'})) {
    my $obj_handle = $self->position->get_object_handle();
    my @classes = $obj_handle->get_classification_data;
    $self->{'class_idx'} = $classes[$self->idx];
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
              object. Padding with 0s (black) is done when the requested
              box falls outside the source image boundaries.
 Returntype: CellH5::Image object

=cut

sub get_image  {

  my $self = shift;
  my ($m,$n) = @_ if @_;
  my $image_handle = $self->position->get_image_handle;
  my @dims = $image_handle->dims;  # dimensions are in the order c,t,z,y,x
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
    my ($m0,$n0) = ($m,$n);
    my $top = $y - int($n/2);
    my $bottom = $y + int($n/2);
    my $left = $x - int($m/2);
    my $right = $x + int($m/2);
    # Check bounds and deal with out-of-range values
    if ($top < 0) {
      $n += $top;
      $top = 0;
    }
    if ($bottom >= $dims[-2]) {
      $n = $n0 - ($bottom - $dims[-2]) -1;
    }
    if ($left < 0) {
      $m += $left;
      $left = 0;
    }
    if ($right >= $dims[-1]) {
      $m = $m0 - ($right - $dims[-1])- 1;
    }
    $pixels = $image_handle->read_data_slice([$channel_idx,$time_idx,$z,$top,$left],[1,1,1,1,1],[1,1,1,$n,$m],[1,1,1,1,1]);
    # If image is smaller than requested, pad with 0s (black)
    if ($n<$n0) {
      my @row = (0) x $m;
      if ($top) { # Pad the bottom
	foreach my $i($n..$n0-1) {
	  $pixels->[0][0][0][$i] = \@row;
	}
      }
      else { # Pad the top
	foreach my $i(0..$n0-$n-1) {
	  unshift(@{$pixels->[0][0][0]},\@row);
	}
      }
    }
    if ($m<$m0) {
      if ($left) { # Pad the right
	foreach my $i(0..$n0-1) {
	  foreach my $j($m..$m0-1) {
	    $pixels->[0][0][0][$i][$j] = 0;
	  }
	}
      }
      else { # Pad the left
	foreach my $i(0..$n0-1) {
	  foreach my $j(0..$m0-$m-1) {
	    unshift(@{$pixels->[0][0][0][$i]},0);
	  }
	}
      }
    }
  }
  my $image = $image_handle->new_image({ 'pixels' => $pixels->[0][0][0] });
  return $image;
}

1;
