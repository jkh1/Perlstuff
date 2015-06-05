# Author: jkh1
# 2014-11-12

=head1 NAME

  CellH5::Well

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of an element of a (multi-)sample plate.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Well;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Group");
use CellH5::Position;

=head2 new

 Arg1: CellH5::Plate object
 Arg2: string, well name/label
 Description: Creates a new Well object and opens the corresponding group in
              the cellh5 file.
 Returntype: CellH5::Well object

=cut

sub new {

  my $class = shift;
  my ($plate,$name) = @_ if @_;
  my $plate_name = $plate->name;
  my $self = HDF5::Group->open($plate,"experiment/$name");
  $self->{'plate'} = $plate;
  $self->{'name'} = $name;
  bless ($self, $class);
  return $self;
}

=head2 plate

 Description: Gets the plate the well belongs to
 Returntype: CellH5::Plate object

=cut

sub plate {
  my $self = shift;
  return $self->{'plate'};
}

=head2 positions

 Description: Gets all positions in the well
 Returntype: list of CellH5::Position objects

=cut

sub positions {

  my $self = shift;
  my $name = $self->name;
  my $position_group = $self->open_group("position");
  foreach my $name($position_group->get_groups()) {
    push @{$self->{'positions'}}, CellH5::Position->new($self,$name);
  }
  return @{$self->{'positions'}};
}

=head2 get_position

 Arg: string, position name
 Description: Gets a given position in the well
 Returntype: CellH5::Position object

=cut

sub get_position {

  my $self = shift;
  my $name = shift if @_;
  my $pos = CellH5::Position->new($self,$name);
  return $pos;
}


1;
