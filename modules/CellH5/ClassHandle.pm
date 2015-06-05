# Author: jkh1
# 2015-05-21

=head1 NAME

  CellH5::ClassHandle

=head1 SYNOPSIS



=head1 DESCRIPTION

 Access to classifier classes information from the cellh5 file
 definition section.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package CellH5::ClassHandle;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Scalar::Util qw(weaken);
use base ("HDF5::Dataset");
use CellH5::Class;

=head2 new

 Arg1: CellH5::File object
 Description: Creates a new handle object to give access to classes used
              in the file.
 Returntype: CellH5::ClassHandle object

=cut

sub new {

  my $class = shift;
  my $file = shift if @_;
  my $self = HDF5::Dataset->open($file,"/definition/feature/primary__primary/object_classification/class_labels");
  bless ($self, $class);
  $self->{'file'} = $file;
  weaken($self->{'file'});

  return $self;
}

=head2 file

 Description: Gets the file the handle is associated with.
 Returntype: CellH5::File object

=cut

sub file {

  my $self = shift;
  return $self->{'file'};
}


=head2 get_all_classes

 Description: Gets all classes specified in the file definition section.
 Returntype: list of CellH5::Class objects

=cut

sub get_all_classes {

  my $self = shift;
  my @classes;
  my $data = $self->read_data();
  my ($n) = $self->dims;
  foreach my $i(0..$n-1) {
    $data->[$i]->{'idx'} = $i;
    my $class = CellH5::Class->new($data->[$i]);
    push @classes, $class;
  }
  return @classes;
}


1;
