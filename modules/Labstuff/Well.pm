# Author: jkh1
# 2014-09-02

=head1 NAME

  Labstuff::Well

=head1 SYNOPSIS

 See t/test.pl

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


package Labstuff::Well;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Scalar::Util qw(weaken);


=head2 new

 Arg1: Plate object
 Arg2: string, position
 Description: Creates a new Well object.
 Returntype: Well object

=cut

sub new {

  my ($class,$plate,$position) = @_;
  my $self;
  unless ($plate && $plate->isa('Labstuff::Plate')) {
    croak "\nERROR: Plate required";
  }
  unless ($position) {
    croak "\nERROR: Position in the plate required";
  }
  else {
    $self = {};
    $self->{'plate'} = $plate;
    $self->{'position'} = $position;
    weaken($self->{'plate'});
    bless ($self, $class);
    if (!$self->row_idx || $self->row_idx > $plate->rows || $self->col > $plate->cols) {
      croak "\nERROR: Invalid well position for the given plate";
    }
  }

  return $self;
}

=head2 plate

 Description: Gets the plate this well belongs to
 Returntype: Plate object

=cut

sub plate {

  my $self = shift;
  return $self->{'plate'};
}

=head2 position

 Arg: (optional) string, well position on the plate
 Description: Gets/sets well position, e.g. A1.
              Note this can only be set once i.e. to rearrange a plate,
              create a new one.
 Returntype: string

=cut

sub position {

  my $self = shift;
  if (@_) {
    if (!$self->{'position'}) {
      $self->{'position'} = shift;
    }
    else {
      carp "\nWARNING: Well position already set. Can't change it.";
    }
  }
  return $self->{'position'};
}

=head2 row

 Description: Gets label of row where the well is located.
 Returntype: string

=cut

sub row {

  my $self = shift;
  my $row = substr($self->position,0,1);
  return $row;
}

=head2 row_idx

 Description: Gets the index (starting at 1) corresponding to the row label,
              e.g. A => 1
 Returntype: integer

=cut

sub row_idx {

  my $self = shift;
  my %row_idx = (A=>1,B=>2,C=>3,D=>4,E=>5,F=>6,G=>7,H=>8,I=>9,J=>10,K=>11,L=>12,M=>13,N=>14,O=>15,P=>16,Q=>17,R=>18,S=>19,T=>20,U=>21,V=>22,W=>23,X=>24,Y=>25,Z=>26);
  return $row_idx{$self->row};
}

=head2 col

 Description: Gets the well's column index
 Returntype: integer

=cut

sub col {

  my $self = shift;
  my $col = substr($self->position,1);
  return $col;
}

=head2 label

 Arg: (optional) string
 Description: Gets/sets label for the well
 Returntype: string

=cut

sub label {

  my $self = shift;
  $self->{'label'} = shift if @_;
  return $self->{'label'};
}

=head2 samples

 Arg: (optional) list of Sample objects
 Description: Gets/sets sample(s) present in the well.
              Note that once filled, a well can't be modified.
 Returntype: list of Sample objects

=cut

sub samples {

  my $self = shift;
  if (@_) {
    if (!$self->{'samples'}) {
      @{$self->{'samples'}} = grep {$_} @_;
    }
    else {
      carp "\nWARNING: Well is not empty. Won't change content.";
    }
  }
  return @{$self->{'samples'}} if $self->{'samples'};
}

=head2 treatments

 Arg: (optional) list of Treatment objects
 Description: Gets/sets experimental treatment the well content has been
              subjected to, e.g. RNAi, drug...
              Note that once filled, a well can't be modified.
 Returntype: list of Treatment objects

=cut

sub treatments {

  my $self = shift;
  if (@_) {
    if (!$self->{'treatments'}) {
      @{$self->{'treatments'}} = grep {$_} @_;
    }
    else {
      carp "\nWARNING: Well is not empty. Won't change content.";
    }
  }
  return @{$self->{'treatments'}} if $self->{'treatments'};
}

=head2 reporters

 Arg: (optional) list of Reporter objects
 Description: Gets/sets reporters used in the well
              Note that once filled, a well can't be modified.
 Returntype: list of Reporter objects

=cut

sub reporters {

  my $self = shift;
  if (@_) {
    if (!$self->{'reporters'}) {
      @{$self->{'reporters'}} = grep {$_} @_;
    }
    else {
      carp "\nWARNING: Well is not empty. Won't change content.";
    }
  }
  return @{$self->{'reporters'}} if $self->{'reporters'};
}

=head2 duplicate

 Arg1: Plate object
 Arg2: Position on the plate
 Description: Copy the well into a new position on another plate
 Returntype: Well object

=cut

sub duplicate {

  my ($self,$plate,$position) = @_;
  my $well = Labstuff::Well->new($plate,$position);
  $well->label($self->label);
  $well->samples($self->samples);
  $well->treatments($self->treatments);
  $well->reporters($self->reporters);
  foreach my $i(0..scalar($plate->wells)-1) {
    if ($plate->{'wells'}->[$i]->position eq $well->position) {
      $plate->{'wells'}->[$i] = $well;
      last;
    }
  }
  return $well;
}

sub AUTOLOAD {

  my $self = shift;
  my $attribute = our $AUTOLOAD;
  $attribute =~s/.*:://;
  $self->{$attribute} = shift if @_;
  return $self->{$attribute};
}

1;
