# Author: jkh1
# 2014-09-02

=head1 NAME

  Labstuff::Sample

=head1 SYNOPSIS

 See t/test.pl

=head1 DESCRIPTION

 Representation of a biological sample. A sample is the biological entity that
 is the subject of the experiment, e.g. cells.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package Labstuff::Sample;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;

=head2 new

 Arg: (optional) hash
 Description: Creates a new Sample object. If given a hash, will set the
              corresponding attributes.
 Returntype: Sample object

=cut

sub new {

  my $class = shift;
  my %param = @_ if @_;
  my $self = {};
  bless ($self, $class);
  if (%param) {
    while (my ($key,$value) = each %param) {
      $self->{$key} = $value;
    }
  }
  return $self;
}

=head2 ID

 Arg: (optional) string
 Description: Gets/sets sample ID
 Returntype: string

=cut

sub ID {

  my $self = shift;
  $self->{'ID'} = shift if @_;
  return $self->{'ID'};
}

=head2 refDB

 Arg: (optional) string
 Description: Gets/sets database in which the ID is valid.
 Returntype: string

=cut

sub refDB {

  my $self = shift;
  $self->{'refDB'} = shift if @_;
  return $self->{'refDB'};
}

=head2 name

 Arg: (optional) string
 Description: Gets/sets sample name
 Returntype: string

=cut

sub name {

  my $self = shift;
  $self->{'name'} = shift if @_;
  return $self->{'name'};
}

=head2 description

 Arg: (optional) string
 Description: Gets/sets sample description
 Returntype: string

=cut

sub description {

  my $self = shift;
  $self->{'description'} = shift if @_;
  return $self->{'description'};
}

=head2 EFOID

 Arg: (optional) string
 Description: Gets/sets ID of the Experimental Factor Ontology term related
              to this sample
 Returntype: string

=cut

sub EFOID {

  my $self = shift;
  $self->{'EFOID'} = shift if @_;
  return $self->{'EFOID'};
}

=head2 EFOterm

 Arg: (optional) string
 Description: Gets/sets the Experimental Factor Ontology term related to this
              sample
 Returntype: string

=cut

sub EFOterm {

  my $self = shift;
  $self->{'EFOterm'} = shift if @_;
  return $self->{'EFOterm'};
}

sub AUTOLOAD {

  my $self = shift;
  my $attribute = our $AUTOLOAD;
  $attribute =~s/.*:://;
  $self->{$attribute} = shift if @_;
  return $self->{$attribute};
}

1;
