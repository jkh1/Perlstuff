# Author: jkh1
# 2015-05-21

=head1 NAME

  CellH5::Class

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of a classifier class


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

package CellH5::Class;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;

=head2 new

 Arg: hashref
 Description: Creates a new class object
 Returntype: CellH5::Class object

=cut

sub new {

  my $class = shift;
  my $self = shift if @_;
  if (!defined($self->{'idx'})) {
    croak "\nERROR: Can't create new class without idx";
  }
  bless ($self, $class);
  return $self;
}

=head2 idx

 Description: Gets the index of the class in the file definition.
 Returntype: integer

=cut

sub idx {

  my $self = shift;
  return $self->{'idx'};
}

=head2 label

 Description: Gets the label of the class. Not to be confused with idx.
 Returntype: integer

=cut

sub label {

  my $self = shift;

  return $self->{'label'};
}

=head2 name

 Description: Gets the class name.
 Returntype: string

=cut

sub name {

  my $self = shift;

  return $self->{'name'};
}

=head2 color

 Arg: (optional) string
 Description: Gets/sets the color assigned to this class
 Returntype: string

=cut

sub color {

  my $self = shift;
  my $color = shift if @_;
  if (defined($color)) {
    $self->{'color'} = $color;
  }
  return $self->{'color'};
}

1;
