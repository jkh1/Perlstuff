# Author: jkh1
# 2014-12-05

=head1 NAME

  CellH5::Event

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of an event. An event is a sequence of objects.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Event;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;

=head2 new

 Arg1: CellH5::Position object
 Arg2: hashref
 Description: Creates a new event object.
 Returntype: CellH5::Event object

=cut

sub new {

  my $class = shift;
  my ($position,$self) = @_ if @_;
  if (!defined($self->{'id'})) {
    croak "\nERROR: Can't create new object without id";
  }
  $self->{'position'} = $position;
  bless ($self, $class);
  return $self;
}

=head2 position

 Description: Gets the position the event comes from.
 Returntype: CellH5::Position object

=cut

sub position {

  my $self = shift;
  return $self->{'position'};
}

=head2 id

 Description: Gets the event id.
 Returntype: integer

=cut

sub id {

  my $self = shift;
  return $self->{'id'};
}

=head2 objects

 Description: Gets the objects that form this event.
 Returntype: list of CellH5::Object objects

=cut

sub objects {

  my $self = shift;
  return @{$self->{'objects'}} if $self->{'objects'};
}

1;
