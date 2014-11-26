# Author: jkh1
# 2014-09-02

=head1 NAME

  Labstuff::Plate

=head1 SYNOPSIS

 See t/test.pl

=head1 DESCRIPTION

 Representation of a (multi-)sample plate. This can be a cell array (i.e.
 spots on a microscopy slide) or a multi-well plate or even a single sample
 slide or tube. A plate is composed of one or more wells.
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


package Labstuff::Plate;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Labstuff::Well;


=head2 new

 Arg: hash, valid keys are:
         wells => number of wells
         rows  => number of rows
         cols  => number of columns
         name  => plate name
 Description: Creates a new Plate object.
 Returntype: Plate object

=cut

sub new {

  my $class = shift;
  my %param = @_ if @_;
  unless ($param{'wells'} || ($param{'rows'} && $param{'cols'})) {
    croak ("\nERROR: Number of wells required or specify the number of rows and columns");
  }
  my $self = {};
  bless ($self, $class);
  if ($param{'rows'} && $param{'cols'}) {
    $self->{'rows'} = $param{'rows'};
    $self->{'cols'} = $param{'cols'};
  }
  else {
    # Known plate formats
    if ($param{'wells'} == 8) {
      $self->{'rows'} = 2;
      $self->{'cols'} = 4;
    }
    elsif ($param{'wells'} == 48) {
      $self->{'rows'} = 6;
      $self->{'cols'} = 8;
    }
    elsif ($param{'wells'} == 96) {
      $self->{'rows'} = 8;
      $self->{'cols'} = 12;
    }
    elsif ($param{'wells'} == 384) {
      $self->{'rows'} = 16;
      $self->{'cols'} = 24;
    }
    else {
      croak "\nERROR: Unknown plate format, specify number of rows and columns";
    }
  }
  $self->{'name'} = $param{'name'} if (defined($param{'name'}));
  # Initialize wells
  my @row_labels = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
  foreach my $r(1..$self->{'rows'}) {
    foreach my $c(1..$self->{'cols'}) {
      my $pos = $row_labels[$r-1].$c;
      my $well = Labstuff::Well->new($self,$pos);
      push @{$self->{'wells'}},$well;
    }
  }
  return $self;
}

=head2 ID

 Arg: (optional) string, plate ID
 Description: Gets/sets plate ID
 Returntype: string

=cut

sub ID {

  my $self = shift;
  $self->{'ID'} = shift if @_;
  return $self->{'ID'};
}

=head2 name

 Arg: (optional) string, plate name
 Description: Gets/sets plate name
 Returntype: string

=cut

sub name {

  my $self = shift;
  $self->{'name'} = shift if @_;
  return $self->{'name'};
}

=head2 type

 Arg: (optional) string, plate type
 Description: Gets/sets plate type, e.g. slide, multi-well plate, tube
 Returntype: string

=cut

sub type {

  my $self = shift;
  $self->{'type'} = shift if @_;
  return $self->{'type'};
}

=head2 nrows

 Arg: (optional) integer
 Description: Gets number of rows
 Returntype: integer

=cut

sub nrows {

  my $self = shift;
  return $self->{'rows'};
}

=head2 ncols

 Arg: (optional) integer
 Description: Gets number of columns
 Returntype: integer

=cut

sub ncols {

  my $self = shift;
  return $self->{'cols'};
}

=head2 wells

 Description: Gets all wells on the plate
 Returntype: list of Well objects

=cut

sub wells {

  my $self = shift;
  return @{$self->{'wells'}};
}

=head2 filled_wells

 Description: Gets all wells with a sample
 Returntype: list of Well objects

=cut

sub filled_wells {

  my $self = shift;
  return grep {$_->samples} @{$self->{'wells'}};
}

=head2 get_well

 Arg: string, well position
 Description: Gets a well
 Returntype: Well object

=cut

sub get_well {

  my ($self,$pos) = @_;
  my ($well) = grep {$_->position eq $pos} $self->wells;
  return $well;
}

=head2 get_row

 Arg: string, row label
 Description: Gets a row of wells
 Returntype: list of Well objects

=cut

sub get_row {

  my ($self,$row) = @_;
  my @wells = grep {$_->row eq $row} $self->wells;
  return @wells;
}

=head2 get_col

 Arg: string, column index
 Description: Gets a column of wells
 Returntype: list of Well objects

=cut

sub get_col {

  my ($self,$col) = @_;
  my @wells = grep {$_->col eq $col} $self->wells;
  return @wells;
}

=head2 data

 Arg: (optional) list of Data objects
 Description: Gets/Adds plate-level data files.
 Returntype: list of Data objects

=cut

sub data {

  my $self = shift;
  push @{$self->{'data'}}, grep {$_} @_ if @_;
  return @{$self->{'data'}} if $self->{'data'};
}

=head2 replicate

 Arg: integer, number of replicates to create
 Description: Produces the requested number of replicates.
 Returntype: list of Plate objects

=cut

sub replicate {

  my ($self,$r) = @_;
  my @plates;
  foreach my $i(1..$r) {
    my $plate = Labstuff::Plate->new(rows=>$self->rows,cols=>$self->cols);
    foreach my $well($self->wells) {
      $well->duplicate($plate,$well->position);
    }
    $plate->name($self->name);
    $plate->type($self->type);
    push @plates,$plate;
  }
  return @plates;
}

sub AUTOLOAD {

  my $self = shift;
  my $attribute = our $AUTOLOAD;
  $attribute =~s/.*:://;
  $self->{$attribute} = shift if @_;
  return $self->{$attribute};
}

1;
