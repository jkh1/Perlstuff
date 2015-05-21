# Author: jkh1
# 2014-12-02

=head1 NAME

  CellH5::EventHandle

=head1 SYNOPSIS



=head1 DESCRIPTION

 Access to events


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::EventHandle;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Dataset");
use CellH5::Event;

=head2 new

 Arg: CellH5::Position object
 Description: Creates a new event handle object and opens the corresponding
              dataset at the given position.
 Returntype: CellH5::EventHandle object

=cut

sub new {

  my $class = shift;
  my $position = shift if @_;
  my $self = HDF5::Dataset->open($position,"object/event");
  $self->{'position'} = $position;
  bless ($self, $class);
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

=head2 get_all_events

 Description: Gets all events data.
 Returntype: list of CellH5::Event objects

=cut

sub get_all_events {

  my $self = shift;
  my $data = $self->read_data();
  my ($n) = $self->dims;
  my @objects = $self->position->get_object_handle->get_all_objects;
  my %event;
  my %seen;
  foreach my $i(0..$n-1) {
    my $id = $data->[$i]->{'obj_id'};
    if (!$event{$id}) {
      $event{$id} = CellH5::Event->new($self->position,{ 'id' => $id });
    }
    unless ($seen{$id}{$data->[$i]->{'idx1'}}++) {
      push @{$event{$id}->{'objects'}},$objects[$data->[$i]->{'idx1'}];
    }
    unless ($seen{$id}{$data->[$i]->{'idx2'}}++) {
      push @{$event{$id}->{'objects'}},$objects[$data->[$i]->{'idx2'}];
    }
  }
  return values %event;
}

=head2 get_event_by_id

 Arg: integer, event id
 Description: Gets the event with the given id.
 Returntype: CellH5::Event object

=cut

sub get_event_by_id {

  my $self = shift;
  my $id = shift;
  my $event;
  foreach my $ev($self->get_all_events) {
    if ($ev->id == $id) {
      $event = $ev;
      last;
    }
  }
  return $event;
}

1;
