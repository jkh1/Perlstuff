# Author: jkh1
# 2014-11-12

=head1 NAME

  CellH5::File

=head1 SYNOPSIS



=head1 DESCRIPTION

 Module to access cellh5 files.


=head1 SEE ALSO

 http://www.cellh5.org/

=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

package CellH5::File;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use base ("HDF5::File");
use CellH5::Plate;

=head2 new

 Arg: (optional) string, file name
 Description: Creates a new File object. If a file name is given and a file
              with this name exits, it is opened. Otherwise a new file with
              the given name is created and opened.
 Returntype: CellH5::File object

=cut

sub new {
  my ($class,$name) = @_;
  my $self;
  if (defined($name)) {
    unless (-e $name) {
      $self = HDF5::File->new($name);
    }
    else {
      $self = HDF5::File->open($name);
    }
  }
  bless ($self, $class);
  return $self;
}

=head2 plates

 Description: Gets all plates stored in the file.
 Returntype: list of CellH5::Plate objects

=cut

sub plates {

  my $self = shift;
  my $plate_group = $self->open_group('sample/0/plate');
  my @plates;
  foreach my $name($plate_group->get_groups()) {
    push @plates, CellH5::Plate->new($self,$name);
  }
  return @plates;
}

=head2 get_plate_by_name

 Arg1: string, plate name
 Description: Gets a plate from the file.
 Returntype: CellH5::Plate object

=cut

sub get_plate_by_name {

  my $self = shift;
  my $name = shift if @_;
  my $plate = CellH5::Plate->new($self,$name);
  return $plate;
}

1;
