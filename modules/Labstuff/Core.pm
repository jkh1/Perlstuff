# Author: jkh1
# 2014-11-26

=head1 NAME

  Labstuff::Core

=head1 SYNOPSIS



=head1 DESCRIPTION

 Loads all Labstuff modules and provides some higher level methods.


=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut


package Labstuff::Core;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Labstuff::Plate;
use Labstuff::Well;
use Labstuff::Sample;
use Labstuff::Treatment;
use Labstuff::Reporter;
use Labstuff::Data;
use File::Temp;
use Scalar::Util qw(blessed);
use Sereal::Encoder;
use Sereal::Decoder;

=head2 new

 Description: Creates a new Core object.
 Returntype: Core object

=cut

sub new {

  my $class = shift;
  my $self = {};
  bless ($self, $class);
  return $self;
}

=head2 store

 Arg: Labstuff::* object
 Description: Serializes a Labstuff::* object.
 Returntype: string, file path of the serialized object

=cut

sub store {

  my $self = shift;
  my $object = shift;
  my $class = ref($object);
  my $encoder = Sereal::Encoder->new({no_bless_objects => 1});
  # For safety, we store unblessed objects and save the class as metadata
  # to allow reblessing on retrieval
  my $serialized = $encoder->encode($object,$class);
  my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.labstuff');
  my $filename = $fh->filename;
  # File should have been opened in binmode already
  # binmode $fh;
  print $fh $serialized;
  close $fh;

  return $filename;
}

=head2 retrieve

 Arg: string, file path of the serialized object
 Description: Gets back a serialized Labstuff::* object.
 Returntype: Labstuff::* object

=cut

sub retrieve {

  my $self = shift;
  my $file = shift;
  if (-e $file) {
    open(my $fh, "<", $file) or die "\nERROR: Can't read file $file: $!";
    binmode $fh;
    my $data;
    if (my $size = -s $fh) {
      my ($pos, $read) = 0;
      while ($pos < $size) {
	defined($read = read($fh, $data, $size - $pos, $pos)) or die "\nERROR: Can't read file $file: $!";
	$pos += $read;
      }
    }
    else {
      $data = <$fh>;
    }
    close $fh;
    my ($object,$class);
    my $decoder = Sereal::Decoder->new({no_bless_objects => 1});
    $decoder->decode_with_header($data,$object,$class);
    # Object class was stored as metadata so that we can rebless the object
    if ($class) {
      $object = $self->rebless($object,$class);
    }
    return $object;
  }
  else {
    croak "\nERROR: $file not found";
  }
}

=head2 rebless

 Arg1: hashref
 Arg2: class
 Description: Reblesses the given hashref into the given class. It also
              recursively reblesses all Labstuff::* objects contained within
              the hashref.
 Returntype: Labstuff::* object

=cut

sub rebless {

  my $self = shift;
  my $object = shift;
  my $class = shift;
  bless($object,$class) if ($class=~/^Labstuff/);
  # Objects contained within this object also need reblessing
  my %is_class = (Data=>1, Plate=>1, Reporter=>1, Sample=>1, Treatment=>1, Well=>1);
  foreach my $attribute(keys %{$object}) {
    foreach my $cls(keys %is_class) {
      if ($attribute=~/^$cls[s]*$/i) {
	if (ref($object->{$attribute}) eq 'HASH') {
	  my $item = $object->{$attribute};
	  $self->rebless($item,"Labstuff::$cls");
	}
	elsif (ref($object->{$attribute}) eq 'ARRAY') {
	  foreach my $item(@{$object->{$attribute}}) {
	    $self->rebless($item,"Labstuff::$cls");
	  }
	}
	elsif (blessed($object)) {
	  # Already reblessed. Can happen with circular references.
	}
	else { # Shouldn't happen
	  carp "\nWARNING: Attribute $attribute is not a hash or array reference";
	}
      }
    }
  }
  return $object;
}

sub new_plate {

  my $self = shift;
  return Labstuff::Plate->new(@_);
}

sub new_well {

  my $self = shift;
  return Labstuff::Well->new(@_);
}

sub new_reporter {

  my $self = shift;
  return Labstuff::Reporter->new(@_);
}

sub new_sample {

  my $self = shift;
  return Labstuff::Sample->new(@_);
}

sub new_treatment {

  my $self = shift;
  return Labstuff::Treatment->new(@_);
}

sub new_data {

  my $self = shift;
  return Labstuff::Treatment->new(@_);
}

1;
