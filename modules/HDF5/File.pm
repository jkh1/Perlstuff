# Author: jkh1
# 2014-02-18

=head1 NAME

  HDF5::File

=head1 SYNOPSIS



=head1 DESCRIPTION

 Module to access HDF5 files.


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

package HDF5::File;

our $VERSION = '0.01';
use 5.006;
use strict;
use Inline ( C =>'DATA',
	     NAME =>'HDF5::File',
	     DIRECTORY => '',
	     LIBS => '-lhdf5',
	     CC => 'gcc',
#	     VERSION => '0.01'
	   );
use Carp;
use Scalar::Util qw(blessed);
use HDF5::Group;

=head2 new

 Arg1: string, file name
 Arg2: (optional) string, access mode, Use 'overwrite' to overwrite existing
       file. Default is to fail if file already exists.
 Description: Creates (and opens) a new HDF5 file.
 Returntype: HDF5::File object

=cut

sub new {
  my ($class,$name,$access_mode) = @_;
  my $self = {};
  bless ($self, $class);
  my $overwrite = 0;
  if ($access_mode eq 'overwrite') {
    $overwrite = 1;
  }
  $self->{'refCobject'} = _create_file($name,$overwrite);
  $self->{'name'} = $name;
  return $self;
}

=head2 open

 Arg1: string, file name
 Arg2: string, access mode. File is opened with read-write access by default.
       Use 'r' or 'readonly' for opening with read-only access.
 Description: Opens an existing HDF5 file.
 Returntype: HDF5::File object

=cut

sub open {
  my ($self,$name,$access_mode) = @_;
  my $mode = 0;
  if ($access_mode eq 'r' or $access_mode eq 'readonly') {
    $mode = 1;
  }
  if (blessed($self)) {
    $self->{'refCobject'} = _open_file($name,$mode);
  }
  else {
    my $class = $self;
    $self = {};
    bless($self, $class);
    $self->{'refCobject'} = _open_file($name,$mode);
  }
  $self->{'name'} = $name;
  return $self;
}

=head2 close

 Description: Closes the HDF5 file.
 Returntype: 1 on success, 0 otherwise

=cut

sub close {
  my $self = shift;
  my $status = _close_file($self->{'refCobject'});
  return $status;
}

=head2 flush

 Description: Flushes all buffers associated with the file to disk
 Returntype: 1 on success, 0 otherwise

=cut

sub flush {
  my $self = shift;
  my $status = _flush_file($self->{'refCobject'});
  return $status;
}

=head2 reopen

 Description: Creates a new file object from an already opened file. Both file
              objects share caches and other information but the new file is
              not mounted anywhere and no other file is mounted on it.
              Note: This can NOT open a closed file.
 Returntype: HDF5::File

=cut

sub reopen {
  my $self = shift;
  my $class = blessed($self) || $self;
  my $newfile = {};
  bless($newfile, $class);
  $newfile->{'refCobject'} = _reopen_file( $self->{'refCobject'});
  return $newfile;
}


=head2 mount

 Arg1: HDF5::Group
 Arg2: string, mount point name
 Arg3: HDF5::File
 Description: Mounts the given file onto the specified group of the calling
              file. Closing the parent file unmounts the child file.
 Returntype: 1 on success, 0 otherwise

=cut

sub mount {
  my ($self,$group,$name,$file,$plist) = @_;
  unless ($group->is_open) {
    croak "\nERROR: Group must be open";
  }
  unless ($file->is_open) {
    croak "\nERROR: File must be open";
  }
  my $status = _mount($self->{'refCobject'},$group->{'refCobject'},$name,$file->{'refCobject'});
  return $status;
}

=head2 unmount

 Arg1: HDF5::Group
 Arg2: string, mount point name
 Description: Unmount file at the given mount point.
              Note this does NOT close the unmounted file.
 Returntype: 1 on success, 0 otherwise

=cut

sub unmount {
  my ($self,$group,$name) = @_;
  my $status = _unmount($self->{'refCobject'},$group->{'refCobject'},$name);
  return $status;
}

=head2 create_group

 Arg: string, group name
 Description: Creates a new group in the file.
 Returntype: HDF5::Group

=cut

sub create_group {
  my ($self,$name) = @_;
  my $group = HDF5::Group->new($self,$name);
  return $group;
}

=head2 open_group

 Arg: string, group name
 Description: Opens a group from the file.
 Returntype: HDF5::Group

=cut

sub open_group {
  my ($self,$name) = @_;
  my $group = HDF5::Group->open($self,$name);
  return $group;
}

=head2 get_groups

 Description: Gets names of groups that are direct members of the file
 Returntype: list of strings

=cut

sub get_groups {

  my $self = shift;
  my @names;
  _get_groups($self->{'refCobject'},\@names);

  return @names;
}

=head2 get_all_groups

 Description: Recursively gets names of all groups that are in the file
 Returntype: list of strings

=cut

sub get_all_groups {

  my $self = shift;
  my @names = map {$_ = '/'.$_} $self->get_groups();
  my @paths;
  while (my $path = shift @names) {
    push @paths,$path;
    my $g = $self->open_group($path);
    my @gr = $g->get_groups();
    foreach my $gr(@gr) {
      push @names,"$path/$gr";
    }
    $g->close();
  }
  return @paths;
}

=head2 id

 Description: Gets the file identifier.
              This is set internally when the file is created or opened.
 Returntype: integer

=cut

sub id {

  my $self = shift;
  my $id = _fid($self->{'refCobject'});
  return $id;
}

=head2 name

 Description: Gets the name of the file.
 Returntype: string

=cut

sub name {

  my $self = shift;

  return $self->{'name'};
}

=head2 is_open

 Description: Checks if the file is open
 Returntype: 1 if open, 0 otherwise

=cut

sub is_open {

  my $self = shift;
  my $status = _is_open($self->{'refCobject'});
  return $status;
}

sub DESTROY {

  my $self = shift;
  _cleanup_file($self->{'refCobject'});
}

1;

__DATA__
__C__

#include <hdf5.h>

typedef struct {

  hid_t id;
  herr_t status;
  int is_open;

} hdf5;

 typedef struct {

  hid_t id;
  herr_t status;
  int is_open;

} group;

SV* _create_file(char* fname, int clobber) {

  hdf5* file;
  Newx(file, 1, hdf5);
  if (clobber) {
    file->id = H5Fcreate(fname,H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
  }
  else {
    file->id = H5Fcreate(fname,H5F_ACC_EXCL, H5P_DEFAULT, H5P_DEFAULT);
  }
  file->is_open = 1;

  SV* h5 = newSViv(0);
  sv_setiv( h5, (IV)file);
  SvREADONLY_on(h5);

  return h5;
}

SV* _open_file(char* fname, int readonly) {

  hdf5* file;
  Newx(file, 1, hdf5);
  if (readonly) {
    file->id = H5Fopen(fname, H5F_ACC_RDONLY, H5P_DEFAULT);
  }
  else {
    file->id = H5Fopen(fname, H5F_ACC_RDWR, H5P_DEFAULT);
  }
  if (file->id<0) {
    croak("\nERROR: Failed to open file %s\n",fname);
  }
  file->is_open = 1;

  SV* h5 = newSViv(0);
  sv_setiv( h5, (IV)file);
  SvREADONLY_on(h5);

  return h5;
}

int _close_file(SV* h5) {

  hdf5* file = (hdf5*)SvIV(h5);
  file->status = H5Fclose(file->id);
  file->is_open = 0;

  return file->status < 0 ? 0:1;
}

int _fid(SV* h5) {

  hdf5* file = (hdf5*)SvIV(h5);

  return file->id;
}

int _is_open(SV* h5) {

  hdf5* file = (hdf5*)SvIV(h5);
  return file->is_open;
}

int _flush_file(SV* h5)  {

  hdf5* file = (hdf5*)SvIV(h5);
  file->status = H5Fflush(file->id, H5F_SCOPE_GLOBAL);

  return file->status < 0 ? 0:1;
}

SV* _reopen_file(SV* h5) {

  hdf5* file = (hdf5*)SvIV(h5);

  hdf5* newfile;
  Newx(newfile, 1, hdf5);
  newfile->id = H5Freopen(file->id);
  newfile->is_open = 1;

  SV* newh5 = newSViv(0);
  sv_setiv( newh5, (IV)file);
  SvREADONLY_on(newh5);

  return newh5;
}

int _mount(SV* parent, SV* loc, char* name, SV* child)  {

  hdf5* parentfile = (hdf5*)SvIV(parent);
  hdf5* childfile = (hdf5*)SvIV(child);
  group* grp = (group*)SvIV(loc);
  hid_t gid = grp->id;
  hid_t fid = childfile->id;
  parentfile->status = H5Fmount(gid, name, fid, H5P_DEFAULT);

  return parentfile->status < 0 ? 0:1;
}

int _unmount(SV* h5, SV* loc, char* name)  {

  hdf5* file = (hdf5*)SvIV(h5);
  group* grp = (group*)SvIV(loc);

  file->status = H5Funmount(grp->id, name);

  return file->status < 0 ? 0:1;
}

void _cleanup_file(SV* h5) {

  hdf5* file = (hdf5*)SvIV(h5);
  if (file->is_open) {
    file->status = H5Fclose(file->id);
    file->is_open = 0;
  }
  Safefree(file);
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
