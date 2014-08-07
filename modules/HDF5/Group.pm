# Author: jkh1
# 2014-02-20

=head1 NAME

  HDF5::Group

=head1 SYNOPSIS



=head1 DESCRIPTION

 Module to access HDF5 groups.


=head1 SEE ALSO

 http://www.hdfgroup.org/HDF5

=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package HDF5::Group;

our $VERSION = '0.01';
use 5.006;
use strict;
use Inline ( C =>'DATA',
	     NAME =>'HDF5::Group',
	     DIRECTORY => '',
	     LIBS => '-lhdf5',
	     CC => 'gcc',
#	     VERSION => '0.01'
	   );
use Scalar::Util qw(weaken);
use Carp;
use HDF5::Dataset;

=head2 new

 Arg1: HDF5::File
 Arg2: string, group name
 Description: Creates (and open) a new group in the given file.
 Returntype: HDF5::Group object

=cut

sub new {
  my ($class,$file,$name) = @_;
  my $self = {};
  bless ($self, $class);
  $self->{'refCobject'} = _new($file->{'refCobject'},$name);
  $self->{'file'} = $file;
  weaken($self->{'file'});
  $self->{'name'} = $name;
  return $self;
}

=head2 open

 Arg1: (optional) HDF5::File or HDF5::Group
 Arg2: (optional) group name
 Description: Opens a group from the given location or reopens a group
              that was previously closed
 Returntype: HDF5::Group object

=cut

sub open {
  my ($self,$location,$name) = @_;
  unless (ref($self)) {
    my $class = $self;
    $self = {};
    bless ($self, $class);
  }
  my $loc;
  if (!$location) {
    if (ref($self)) {
      $loc = $self->file->{'refCobject'};
      $name = $self->{'name'};
    }
    else {
      croak "\nERROR: Location required";
    }
  }
  else {
    if(ref($location) eq 'HDF5::File') {
      $loc = $location->{'refCobject'};
      $self->{'file'} = $location;
      weaken($self->{'file'});
      $self->{'name'} = $name;
    }
    else {
      $loc = $location->{'refCobject'};
      $self->{'file'} = $location->file;
      weaken($self->{'file'});
    }
  }
  $self->{'refCobject'} = _open_group($loc,$name);
  $self->{'name'} = $name;
  return $self;
}

=head2 close

 Description: Closes the group.
 Returntype: 1 on success, 0 otherwise

=cut

sub close {
  my $self = shift;
  my $status = _close_group($self->{'refCobject'});
  return $status;
}

=head2 id

 Description: Gets the group identifier.
              This is set internally when the group is created or opened.
 Returntype: integer

=cut

sub id {

  my $self = shift;
  my $id = _gid($self->{'refCobject'});
  return $id;
}

=head2 name

 Description: Gets the name of the group.
 Returntype: string

=cut

sub name {

  my $self = shift;
  return $self->{'name'};
}

=head2 file

 Description: Gets the file the group belongs to.
 Returntype: HDF5::File

=cut

sub file {

  my $self = shift;
  return $self->{'file'};
}

=head2 is_open

 Description: Checks if the group is open
 Returntype: 1 if open, 0 otherwise

=cut

sub is_open {

  my $self = shift;
  my $status = _is_open($self->{'refCobject'});
  return $status;
}

=head2 get_datasets

 Description: Gets names of datasets that are direct members of the group
 Returntype: list of strings

=cut

sub get_datasets {

  my $self = shift;
  my @names;
  _get_datasets($self->{'refCobject'},\@names);

  return @names;
}

=head2 open_dataset

 Arg: string, dataset name
 Description: Opens a dataset from the group
 Returntype: HDF5::Dataset

=cut

sub open_dataset {

  my ($self,$name) = @_;
  my $dataset = HDF5::Dataset->open($self,$name);

  return $dataset;
}

=head2 get_groups

 Description: Gets names of groups that are direct members of the group
 Returntype: list of strings

=cut

sub get_groups {

  my $self = shift;
  my @names;
  _get_groups($self->{'refCobject'},\@names);

  return @names;
}

=head2 get_all_groups

 Description: Recursively gets names of all groups that are in the calling group
 Returntype: list of strings

=cut

sub get_all_groups {

  my $self = shift;
  my @names = $self->get_groups();
  my @paths;
  my $file = $self->file;
  while (my $path = shift @names) {
    push @paths,$path;
    my $g = HDF5::Group->open($self,$path);
    my @gr = $g->get_groups();
    foreach my $gr(@gr) {
      push @names,"$path/$gr";
    }
    $g->close();
  }
  return @paths;
}


sub DESTROY {

  my $self = shift;
  _cleanup_group($self->{'refCobject'});
}

1;

__DATA__
__C__

#include <hdf5.h>

typedef struct {

  hid_t id;
  herr_t status;
  int is_open;

} group;

typedef struct {

  hid_t id;
  herr_t status;
  int is_open;

} hdf5;

SV* _new(SV* h5, char* gname) {

  hdf5* file = (hdf5*)SvIV(h5);
  group* grp;
  Newx(grp, 1, group);
  grp->id = H5Gcreate2(file->id, gname, H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  if (grp->id<0) {
    croak("\nERROR: Failed to create group %s",gname);
  }
  grp->is_open = 1;

  SV* g = newSViv(0);
  sv_setiv( g, (IV)grp);
  SvREADONLY_on(g);

  return g;
}

SV* _open_group(SV* loc, char* gname) {

  group* l = (group*)SvIV(loc);
  hid_t loc_id = l->id;
  group* grp;
  Newx(grp, 1, group);
  grp->id = H5Gopen2(loc_id, gname, H5P_DEFAULT);
  if (grp->id<0) {
    croak("\nERROR: Failed to open group %s\n",gname);
  }
  grp->is_open = 1;

  SV* g = newSViv(0);
  sv_setiv( g, (IV)grp);
  SvREADONLY_on(g);

  return g;
}


int _close_group(SV* g) {

  group* grp = (group*)SvIV(g);
  grp->status = H5Gclose(grp->id);
  grp->is_open = 0;

  return grp->status < 0 ? 0:1;
}

int _gid(SV* g) {

  group* grp = (group*)SvIV(g);

  return grp->id;
}

int _is_open(SV* g) {

  group* grp = (hdf5*)SvIV(g);

  return grp->is_open;
}

void _get_datasets(SV* g, SV* listref) {

  AV* list = (AV*)SvRV(listref);
  group* grp = (group*)SvIV(g);
  H5G_info_t  ginfo;
  herr_t status = H5Gget_info (grp->id, &ginfo);
  int i;
  for (i=0; i<ginfo.nlinks; i++) {
    ssize_t size = 1 + H5Lget_name_by_idx(grp->id, ".", H5_INDEX_NAME, H5_ITER_INC, i, NULL, 0, H5P_DEFAULT);
    char* name = (char*) malloc(size);
    size = H5Lget_name_by_idx (grp->id, ".", H5_INDEX_NAME, H5_ITER_INC, i, name, (size_t) size, H5P_DEFAULT);
    H5O_info_t object_info;
    status = H5Oget_info_by_name(grp->id, name, &object_info, H5P_DEFAULT);
    if (object_info.type == H5O_TYPE_DATASET) {
      SV* nm = newSVpv(name, size);
      av_push(list, nm);
    }
    free(name);
  }
}

void _get_groups(SV* g, SV* listref) {

  AV* list = (AV*)SvRV(listref);
  group* grp = (group*)SvIV(g);
  H5G_info_t  ginfo;
  herr_t status = H5Gget_info(grp->id, &ginfo);
  int i;
  for (i=0; i<ginfo.nlinks; i++) {
    ssize_t size = 1 + H5Lget_name_by_idx(grp->id, ".", H5_INDEX_NAME, H5_ITER_INC, i, NULL, 0, H5P_DEFAULT);
    char* name = (char*) malloc(size);
    size = H5Lget_name_by_idx (grp->id, ".", H5_INDEX_NAME, H5_ITER_INC, i, name, (size_t) size, H5P_DEFAULT);
    H5O_info_t object_info;
    status = H5Oget_info_by_name(grp->id, name, &object_info, H5P_DEFAULT);
    if (object_info.type == H5O_TYPE_GROUP) {
      SV* nm = newSVpv(name, size);
      av_push(list, nm);
    }
    free(name);
  }
}

void _cleanup_group(SV* g) {

  group* grp = (group*)SvIV(g);
  if (grp->is_open) {
    grp->status = H5Gclose(grp->id);
    grp->is_open = 0;
  }
  Safefree(grp);
}

