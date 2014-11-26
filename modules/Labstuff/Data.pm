# Author: jkh1
# 2014-11-26

=head1 NAME

  Labstuff::Data

=head1 SYNOPSIS



=head1 DESCRIPTION

 Representation of a data file


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut


package Labstuff::Data;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Scalar::Util qw(weaken);

=head2 new

 Arg: (optional) hash
 Description: Creates a new Data object. If given a hash, will set the
              corresponding attributes.
 Returntype: Data object

=cut

sub new {

  my $class = shift;
  my %param = @_ if @_;
  my $self = {};
  bless ($self, $class);
  if (%param) {
    while (my ($key,$value) = each %param) {
      $self->{$key} = $value;
      if ($key eq 'plate' || $key eq 'well') {
	weaken($self->{$key});
      }
    }
  }
  return $self;
}

=head2 ID

 Arg: (optional) string
 Description: Gets/sets the data object ID.
 Returntype: string

=cut

sub ID {

  my $self = shift;
  $self->{'ID'} = shift if @_;
  return $self->{'ID'};
}

=head2 type

 Arg: (optional) string
 Description: Gets/sets the data type.
 Returntype: string

=cut

sub type {

  my $self = shift;
  $self->{'type'} = shift if @_;
  return $self->{'type'};
}

=head2 filepath

 Arg: (optional) string
 Description: Gets/sets the path to the data file, including the name of the file.
 Returntype: string

=cut

sub filepath {

  my $self = shift;
  $self->{'filepath'} = shift if @_;
  return $self->{'filepath'};
}

=head2 filename

 Arg: (optional) string
 Description: Gets/sets name of the data file.
 Returntype: string

=cut

sub filename {

  my $self = shift;
  $self->{'filename'} = shift if @_;
  return $self->{'filename'};
}

=head2 format

 Arg: (optional) string
 Description: Gets/sets the data file format.
 Returntype: string

=cut

sub format {

  my $self = shift;
  $self->{'format'} = shift if @_;
  return $self->{'format'};
}

=head2 origin

 Arg: (optional) string
 Description: Gets/sets origin of the data object. This describes how the
              data was generated.
 Returntype: string

=cut

sub origin {

  my $self = shift;
  $self->{'origin'} = shift if @_;
  return $self->{'origin'};
}

sub AUTOLOAD {

  my $self = shift;
  my $attribute = our $AUTOLOAD;
  $attribute =~s/.*:://;
  $self->{$attribute} = shift if @_;
  return $self->{$attribute};
}

1;
