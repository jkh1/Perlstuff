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
use CellH5::ClassHandle;

=head2 new

 Arg1: (optional) string, file name
 Arg2: (optional) string, access mode. Existing files are opened with
       read-write access by default. Use 'readonly' for opening with
       read-only access.
 Description: Creates a new File object. If a file name is given and a file
              with this name exits, it is opened. Otherwise a new file with
              the given name is created and opened.
 Returntype: CellH5::File object

=cut

sub new {
  my ($class,$name,$access_mode) = @_;
  my $self;
  if (defined($name)) {
    unless (-e $name) {
      $self = HDF5::File->new($name);
    }
    else {
      if ($access_mode eq 'readonly') {
	$self = HDF5::File->open($name,'readonly');
      }
      else {
	$self = HDF5::File->open($name);
      }
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

=head2 get_all_classes

 Description: Gets all classes specified in the file definition section.
 Returntype: list of CellH5::Class objects

=cut

sub get_all_classes {

  my $self = shift;
  my $class_handle = CellH5::ClassHandle->new($self);
  my @classes;
  my $data = $class_handle->read_data();
  my ($n) = $class_handle->dims;
  foreach my $i(0..$n-1) {
    $data->[$i]->{'idx'} = $i;
    my $class = CellH5::Class->new($data->[$i]);
    push @classes, $class;
  }
  $class_handle->close;
  return @classes;
}

1;
