# Author: jkh1
# 2014-11-12

=head1 NAME

  CellH5::Plate

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of a (multi-)sample plate. This can be a cell array (i.e.
 spots on a microscopy slide) or a multi-well plate or even a single sample
 slide or tube.
 Conventions:
 - Rows are along the shortest dimension, e.g. an 8x12 plate has 8 rows.
 - Rows are labelled with letters starting from A.
 - Columns are numbered starting from 1.
 - Well A1 represents the top left corner of the plate.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::Plate;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::Group");
use CellH5::Well;

=head2 new

 Arg1: CellH5::File object
 Arg2: string, plate name
 Description: Creates a new Plate object and opens the corresponding group in
              the file.
 Returntype: CellH5::Plate object

=cut

sub new {

  my $class = shift;
  my ($file,$name) = @_ if @_;
  my $self = HDF5::Group->open($file,"sample/0/plate/$name");
  $self->{'file'} = $file;
  $self->{'name'} = $name;
  bless ($self, $class);
  return $self;
}

=head2 file

 Description: Gets the file this plate is in
 Returntype: CellH5::File object

=cut

sub file {
  my $self = shift;
  return $self->{'file'};
}

=head2 wells

 Description: Gets all wells on the plate.
 Returntype: list of CellH5::Well objects

=cut

sub wells {

  my $self = shift;
  my $well_group = HDF5::Group->open($self,'experiment');
  foreach my $name($well_group->get_groups()) {
    push @{$self->{'wells'}}, CellH5::Well->new($self,$name);
  }
  return @{$self->{'wells'}};
}

=head2 get_well

 Arg: string, well name
 Description: Gets a well.
 Returntype: Well object

=cut

sub get_well {

  my ($self,$name) = @_;
  my $well = CellH5::Well->new($self,$name);
  return $well;
}

1;
