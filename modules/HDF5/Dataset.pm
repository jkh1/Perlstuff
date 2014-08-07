# Author: jkh1
# 2014-02-21

=head1 NAME

  HDF5::Dataset

=head1 SYNOPSIS



=head1 DESCRIPTION

 Module to access HDF5 datasets.
 Datasets are multidimensional arrays with all elements of the same type.
 Supported data types for reading are:
     integer, float, string, opaque, compound, enum and array.
 Some limitations:
     - some low-level interfaces are not available (e.g. property list, reference...)
     - datasets can't have more than 5 dimensions.
     - enum data are read as integers
     - opaque data are read as arrays of uint8 values and written as variable length arrays of uint8 values
     - arrays can only have numeric data types (i.e. integer or float)
     - nested arrays are not supported
     - compound data are limited to the following data types:
           integer, enum, float, string and array.
     - nested compound data are not supported
     - requires gcc compiler (due to use of variable lengths arrays in structs)
     - in some instances, memory is allocated on the stack

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

package HDF5::Dataset;

our $VERSION = '0.01';
use 5.006;
use strict;
use Config;
use Inline ( C => 'DATA',
	     NAME =>'HDF5::Dataset',
	     DIRECTORY => '',
	     LIBS => '-lhdf5',
	     CC => 'gcc',
#	     VERSION => '0.01'
	   );
use Scalar::Util qw(weaken);
use Carp;


=head2 new

 Arg1: HDF5::File or HDF5::Group
 Arg2: string, name
 Arg3: arrayref, dataset dimensions (maximum of 5)
 Arg4: (optional) datatype 'string' or 'opaque' (default to float)
 Arg5: (unused) tag for opaque data (must be less than 256 bytes)
 Description: Creates (and open) a new HDF5 dataset at the given location.
              Up to 5 dimensions are allowed. Opaque data are mapped to
              arrays of bytes (uint8 values).
 Returntype: HDF5::Dataset object

=cut

sub new {
  my ($class,$loc,$name,$dims,$datatype,$tag) = @_;
  my $self = {};
  bless ($self, $class);
  unless (defined($name)) {
    croak "\nERROR: Dataset name required";
  }
  if ($datatype eq 'string') {
    $datatype = 1;
  }
  elsif ($datatype eq 'opaque') {
    $datatype = 2;
    $self->tag($tag) if ($tag);
  }
  else {
    $datatype = 0;
  }
  unless ($dims) {
    croak "\nERROR: Dataset dimensions required";
  }
  my $n = scalar(@{$dims});
  if ($n>5) {
    croak "\nERROR: No more than 5 dimensions allowed";
  }
  $self->{'refCobject'} = _create_dataset($loc->{'refCobject'},$name,$n,$dims,$datatype);
  $self->{'name'} = $name;
  if ($loc->isa("HDF5::File")) {
    $self->{'file'} = $loc;
    weaken($self->{'file'});
  }
  elsif ($loc->isa("HDF5::Group")) {
    $self->{'file'} = $loc->file;
    weaken($self->{'file'});
    $self->{'group'} = $loc;
    weaken($self->{'group'});
  }
  else {
    croak "\nERROR: Arg1 must be an HDF5::File or HDF5::Group object";
  }
  return $self;
}

=head2 open

 Arg1: HDF5::File or HDF5::Group
 Arg2: string, dataset name (as path relative to Arg1)
 Description: Opens a dataset from the given HDF5 file.
 Returntype: HDF5::Dataset

=cut

sub open {
  my ($self,$file,$name) = @_;
  if (ref($self)) {
    $self->{'refCobject'} = _open_dataset($file->{'refCobject'},$name);
  }
  else {
    my $class = $self;
    $self = {};
    bless ($self, $class);
    $self->{'refCobject'} = _open_dataset($file->{'refCobject'},$name);
  }
  $self->{'name'} = $name;
  return $self;
}

=head2 close

 Description: Closes the dataset.
 Returntype: 1 on success, 0 otherwise

=cut

sub close {
  my $self = shift;
  my $status = _close_dataset($self->{'refCobject'});
  return $status;
}

=head2 id

 Description: Gets the dataset identifier.
              This is set internally when the dataset is created or opened.
 Returntype: integer

=cut

sub id {

  my $self = shift;
  my $id = _dset_id($self->{'refCobject'});
  return $id;
}

=head2 name

 Description: Gets the name of the dataset.
 Returntype: string

=cut

sub name {

  my $self = shift;

  return $self->{'name'};
}

=head2 dims

 Description: Gets the dimensions of the dataset.
 Returntype: array

=cut

sub dims {

  my $self = shift;
  my $dims = [];
  _get_dims($self->{'refCobject'},$dims);

  return @{$dims};
}

=head2 datatype

 Description: Gets the datatype of the dataset.
 Returntype: string

=cut

sub datatype {

  my $self = shift;
  my $datatype = "";
  _get_type($self->{'refCobject'},$datatype);

  return $datatype;
}

=head2 tag

 Arg: string
 Description: Gets/sets the tag associated with an opaque dataset.
 Returntype: string

=cut

sub tag {

  my $self = shift;
  $self->{'tag'} = shift if @_;
  return $self->{'tag'};
}

=head2 file

 Description: Gets the file the dataset belongs to.
 Returntype: HDF5::File

=cut

sub file {

  my $self = shift;
  return $self->{'file'};
}

=head2 group

 Description: Gets the group the dataset belongs to.
 Returntype: HDF5::Group

=cut

sub group {

  my $self = shift;
  return $self->{'group'};
}

=head2 is_open

 Description: Checks if the dataset is open
 Returntype: 1 if open, 0 otherwise

=cut

sub is_open {

  my $self = shift;
  my $status = _is_open($self->{'refCobject'});
  return $status;
}

=head2 write_data

 Arg: Arrayref of data to write
 Description: Writes data to the dataset
 Returntype: 1 if successful, 0 otherwise

=cut

sub write_data {

  my ($self,$data) = @_;
  my $status = _write_dataset($self->{'refCobject'},$data);
  return $status;
}

=head2 read_data

 Arg1: (optional) 1 to try and set size of the stack to 128 M.
       This is an experimental feature. It seems to work with Linux
       but doesn't work with Mac OS X
 Description: Reads an entire dataset.
 Returntype: Arrayref

=cut

sub read_data {

  my $self = shift;
  my $stack_increase = shift || 0;
  my $data = [];
  my $tag;
  my $status = _read_dataset($self->{'refCobject'},$data,$tag,$stack_increase);
  $self->{'tag'} = $tag if (defined($tag));
  return $data;
}

=head2 read_data_slice

 Arg1: arrayref, start
 Arg2: arraryref, stride
 Arg3: arrayref, count
 Arg4: arrayref, block
 Description: Reads part of a dataset. Supported data types are
              string, integer, float and array.
              For arrays, only the first dimension is considered, i.e.
              one is limited to extracting the nth array.
 Returntype: Arrayref

=cut

sub read_data_slice {

  my $self = shift;
  my @params = @_ if @_;
  if (!defined($params[0]) || !defined($params[2])) {
    croak "\nERROR: Missing parameters to read_data_slice\n";
  }
  my @dims = $self->dims;
  if ($self->datatype eq 'string' || $self->datatype eq 'array' || $self->datatype eq 'integer' || $self->datatype eq 'float') {
    if ($self->datatype ne 'array') {
      foreach my $param(@params) {
	if (scalar(@{$param})!=scalar(@dims)) {
	  croak "\nERROR: parameter must have as many elements as the dataset has dimensions";
	}
      }
    }
    my $data = [];
    my $tag;
    my $status = _read_dataset_slice($self->{'refCobject'},$data,$tag,@params);
    $self->{'tag'} = $tag if (defined($tag));
    return $data;
  }
  else {
    croak "\nERROR: Unsupported data type (",$self->datatype,") in read_data_slice";
  }
}

=head2 move

 Arg1: HDF5::Group, destination group
 Arg2: (optional) string, new dataset name
 Description: Moves dataset to another group in the same file,
              optionally changing the dataset name.
 Returntype: 1 if successful, 0 otherwise

=cut

sub move {

  my ($self,$to,$new_name) = @_;
  my @elements = split(/\//,$self->name);
  my $ds_name = $elements[-1];
  my $to_name;
  if ($new_name) {
    $to_name .= $new_name;
  }
  else {
    $to_name .= $ds_name;
  }
  my $to_id = $to->id;
  my $from_id = $self->group->id;
  my $status = _move_dataset($from_id,$ds_name,$to_id,$to_name);
  if ($status) {
    $self->{'group'} = $to;
    $self->{'name'} = $to_name;
  }

  return $status;
}

sub DESTROY {

  my $self = shift;
  _cleanup_dataset($self->{'refCobject'});
}

1;

__DATA__
__C__

#include <sys/resource.h>
#include <hdf5.h>

int raise_stack_limit(void) {
  /* Raise stack limit to 128 M */
  struct rlimit rl;
  rl.rlim_cur = 134217728;
  setrlimit(RLIMIT_STACK, &rl);
  struct rlimit nrl;
  getrlimit (RLIMIT_STACK, &nrl);
  return nrl.rlim_cur;
}

typedef struct {

  hid_t id;
  hid_t dtype;
  herr_t status;
  int is_open;

} dset;

typedef struct {

  hid_t id;
  herr_t status;
  int is_open;

} group;


/* Read buffers for different data types */
char* get_char_buffer(int r, hsize_t* dims) {

  char* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(char)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_char_buffer()\n");
  }

  return buffer;
}

unsigned char* get_uchar_buffer(int r, hsize_t* dims) {

  unsigned char* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(unsigned char)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_uchar_buffer()\n");
  }

  return buffer;
}

short* get_short_buffer(int r, hsize_t* dims) {

  short* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(short)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_short_buffer()\n");
  }

  return buffer;

}

unsigned short* get_ushort_buffer(int r, hsize_t* dims) {

  unsigned short* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(unsigned short)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_short_buffer()\n");
  }

  return buffer;

}

int* get_int_buffer(int r, hsize_t* dims) {

  int* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(int)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_int_buffer()\n");
  }

  return buffer;

}

unsigned int* get_uint_buffer(int r, hsize_t* dims) {

  unsigned int* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(unsigned int)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_int_buffer()\n");
  }

  return buffer;

}

long* get_long_buffer(int r, hsize_t* dims) {

  long* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(long)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_long_buffer()\n");
  }

  return buffer;

}

unsigned long* get_ulong_buffer(int r, hsize_t* dims) {

  unsigned long* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(unsigned long)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_long_buffer()\n");
  }

  return buffer;

}

float* get_float_buffer(int r, hsize_t* dims) {

  float* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(float)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_float_buffer()\n");
  }

  return buffer;

}

double* get_double_buffer(int r, hsize_t* dims) {

  double* buffer;
  int i;
  int N = 1;
  for (i = 0; i < r; i++) {
    N = N * dims[i];
  }

  buffer = malloc(sizeof(double)*N);
  if (!buffer) {
    croak("Memory allocation failure in get_double_buffer()\n");
  }

  return buffer;

}

SV* _create_dataset(SV* loc, char* dname, int r, SV* dims, int datatype) {

  dset* data;
  Newx(data, 1, dset);
  group* l = (group*)SvIV(loc);
  hid_t loc_id = l->id;

  AV *sz;
  sz = (AV*)SvRV(dims);
  int i;
  hsize_t size[r];
  for (i = 0; i < r; i++) {
    size[i] = SvNV(*av_fetch(sz,i,0));
  }
  hid_t space_id = H5Screate_simple(r, size, NULL);
  hid_t type;
  if (datatype == 1) {
    /* type is variable length string */
    type = H5Tcopy(H5T_C_S1);
    herr_t status = H5Tset_size(type, H5T_VARIABLE);
  }
  else if (datatype == 2) {
    /* type is opaque */
    type = H5Tvlen_create(H5T_NATIVE_UCHAR);
  }
  else if (datatype == 3) {
    /* type is compound */
    type = H5T_COMPOUND;
  }
  else {
    /* default to double */
    type = H5T_NATIVE_DOUBLE;
  }
  data->id = H5Dcreate2(loc_id,dname,type,space_id,H5P_DEFAULT,H5P_DEFAULT, H5P_DEFAULT);
  if (data->id<0) {
    croak("\nERROR: Failed to create dataset %s",dname);
  }
  data->dtype = type;
  data->is_open = 1;

  herr_t flag = H5Sclose(space_id);

  SV* d = newSViv(0);
  sv_setiv( d, (IV)data);
  SvREADONLY_on(d);

  return d;
}

SV* _open_dataset(SV* loc, char* dname) {

  group* l = (group*)SvIV(loc);
  hid_t loc_id = l->id;
  dset* set;
  Newx(set, 1, dset);
  set->id = H5Dopen2(loc_id, dname, H5P_DEFAULT);
  if (set->id<0) {
    croak("\nERROR: Failed to open dataset %s\n",dname);
  }
  set->dtype = H5Dget_type(set->id);
  set->is_open = 1;

  SV* d = newSViv(0);
  sv_setiv( d, (IV)set);
  SvREADONLY_on(d);

  return d;
}

int _close_dataset(SV* d) {

  dset* set = (dset*)SvIV(d);
  set->status = H5Dclose(set->id);
  set->is_open = 0;

  return set->status < 0 ? 0:1;
}

int _dset_id(SV* set) {

  dset* dataset = (dset*)SvIV(set);

  return dataset->id;
}

void _get_dims (SV* d, SV* dimsref) {

  int i;
  dset* dataset = (dset*)SvIV(d);
  hid_t space_id = H5Dget_space(dataset->id);
  H5T_class_t t_class;
  t_class = H5Tget_class(dataset->dtype);
  int r = H5Sget_simple_extent_ndims(space_id);
  if (t_class == H5T_OPAQUE) {
    r++;
  }
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  if (t_class == H5T_OPAQUE) {
   size_t len = H5Tget_size(dataset->dtype);
   dims[r] = len;
   r++;
  }
  else if (t_class == H5T_ARRAY) {
    hsize_t adims[r];
    r = H5Tget_array_ndims(dataset->dtype);
    H5Tget_array_dims2(dataset->dtype, adims);
    int n = H5Sget_simple_extent_npoints(space_id);
    r++;
    dims[r];
    dims[0] = n;
    for (i = 0; i < r; i++) {
      dims[i+1] = adims[i];
    }
  }
  herr_t flag = H5Sclose(space_id);
  AV *dimensions;
  dimensions = (AV*)SvRV(dimsref);
  for (i = 0; i < r; i++) {
    SV* X = newSVnv(dims[i]);
    av_store(dimensions, i, X);
  }
}

void _get_type (SV* d, SV* datatype) {

  dset* dataset = (dset*)SvIV(d);
  hid_t type = dataset->dtype;
  H5T_class_t t_class;
  t_class = H5Tget_class(type);
  int is_vlen = 0;
  if (t_class == H5T_VLEN) {
    /* what is this a vlen of ? */
    hid_t base_type = H5Tget_super(type);
    t_class = H5Tget_class(base_type);
    H5Tclose(base_type);
    is_vlen = 1;
  }
  switch(t_class) {
    case H5T_STRING: {
      char *t;
      if (is_vlen) {
	t = "vlen of string";
	sv_setpvn(datatype, t, 14);
      }
      else {
	t = "string";
	sv_setpvn(datatype, t, 6);
      }
      break;
    }
    case H5T_OPAQUE: {
      char *t;
      if (is_vlen) {
	t = "vlen of opaque";
	sv_setpvn(datatype, t, 14);
      }
      else {
	char *t = "opaque";
	sv_setpvn(datatype, t, 6);
      }
      break;
    }
    case H5T_FLOAT: {
      char *t;
      if (is_vlen) {
	t = "vlen of float";
	sv_setpvn(datatype, t, 14);
      }
      else {
	t = "float";
	sv_setpvn(datatype, t, 5);
      }
      break;
    }
    case H5T_INTEGER: {
      char *t;
      if (is_vlen) {
	t = "vlen of integer";
	sv_setpvn(datatype, t, 15);
      }
      else {
	t = "integer";
	sv_setpvn(datatype, t, 7);
      }
      break;
    }
    case H5T_COMPOUND: {
      char *t;
      if (is_vlen) {
	t = "vlen of compound";
	sv_setpvn(datatype, t, 16);
      }
      else {
	t = "compound";
	sv_setpvn(datatype, t, 8);
      }
      break;
    }
    case H5T_ARRAY: {
      char *t;
      if (is_vlen) {
	t = "vlen of array";
	sv_setpvn(datatype, t, 13);
      }
      else {
	char *t = "array";
	sv_setpvn(datatype, t, 5);
      }
      break;
    }
    default :
	sv_setpv(datatype,(char*)&PL_sv_undef);
  }
}

int _move_dataset(int file_id, char* dataset_name, int grp_id, char* link_name) {
  int status = 0;
  status = H5Lcreate_hard((hid_t)file_id,dataset_name,(hid_t)grp_id,link_name,H5P_DEFAULT,H5P_DEFAULT);
  if (status<0) {
    croak("\nERROR: Failed to create hard link (id: %i)\n",grp_id);
  }
  status = H5Ldelete(file_id,dataset_name,H5P_DEFAULT);
  if (status<0) {
    croak("\nERROR: Failed to remove link\n");
  }
  return status < 0 ? 0:1;
}

int _is_open(SV* set) {

  dset* dataset = (dset*)SvIV(set);
  return dataset->is_open;
}

int _write_dataset(SV* set, SV* dataref) {

  dset* dataset = (dset*)SvIV(set);
  hid_t space_id = H5Dget_space(dataset->id);
  int r = H5Sget_simple_extent_ndims(space_id);
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  hid_t id = dataset->id;
  hid_t type = dataset->dtype;

  AV *data;
  data = (AV*)SvRV(dataref);
  AV *Xa, *Xab;
  int a,b,c,d,e,f,n;
  H5T_class_t t_class;
  t_class = H5Tget_class(type);

  if (t_class == H5T_STRING) {
    switch(r) {
      case 1 : {
        char* buffer[(int)dims[0]];
        for (a = 0; a < dims[0]; a++) {
          SV *X = (SV*)SvRV(*av_fetch(data, a, 0));
	  buffer[a] = (char*)X;
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 2 : {
        char* buffer[(int)dims[0]][(int)dims[1]];
        for (a = 0; a < dims[0]; a++) {
          Xa = (AV*)SvRV(*av_fetch(data, a, 0));
          for (b = 0; b < dims[1]; b++) {
	    SV *X = (SV*)SvRV(*av_fetch(Xa, b, 0));
	    buffer[a][b] = (char*)X;
          }
        }
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 3 : {
        char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b, 0));
	    for (c = 0; c < dims[2]; c++) {
	      SV *X = (SV*)SvRV(*av_fetch(Xab, c, 0));
	      buffer[a][b][c] = (char*)X;
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 4 : {
        char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b,0));
	    for (c = 0; c < dims[2]; c++) {
	      AV *Xabc = (AV*)SvRV(*av_fetch(Xab, c, 0));
	      for (d = 0; d < dims[3]; d++) {
		SV *X = (SV*)SvRV(*av_fetch(Xabc, d, 0));
		buffer[a][b][c][d] = (char*)X;
	      }
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	break;
      }
      case 5 : {
        char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]][(int)dims[4]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b, 0));
	    for (c = 0; c < dims[2]; c++) {
	      AV *Xabc = (AV*)SvRV(*av_fetch(Xab, c, 0));
	      for (d = 0; d < dims[3]; d++) {
		AV *Xabcd = (AV*)SvRV(*av_fetch(Xabc, d, 0));
		for (e = 0; e < dims[4]; e++) {
		  SV *X = (SV*)SvRV(*av_fetch(Xabcd, e, 0));
		  buffer[a][b][c][d][e] = (char*)X;
		}
	      }
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	break;
      }
    }
  }
  else if (t_class == H5T_VLEN) {
    size_t len;
    switch(r) {
      case 1 : {
	hvl_t buffer[dims[0]];
	for (a = 0; a < dims[0]; a++) {
	  unsigned char* wdata = (unsigned char*)SvPV(*av_fetch(data, a, 0),len);
	  buffer[a].p = malloc((len)*sizeof(unsigned char));
	  buffer[a].len = len;
	  for(b=0; b<(len); b++) {
	    ((unsigned char *)buffer[a].p)[b] = wdata[b];
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	H5Dvlen_reclaim(type, space_id, H5P_DEFAULT, buffer);
        break;
      }
      default : {
	croak("\nERROR: Vlen datatype can only have one dimension.\n");
      }
    }
  }
  else if (t_class == H5T_COMPOUND) {

  }
  else {
    switch(r) {
      case 1 : {
        double buffer[(int)dims[0]];
        for (a = 0; a < dims[0]; a++) {
	  buffer[a] = (double)SvNV(*av_fetch(data, a, 0));
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 2 : {
        double buffer[(int)dims[0]][(int)dims[1]];
        for (a = 0; a < dims[0]; a++) {
          Xa = (AV*)SvRV(*av_fetch(data, a, 0));
          for (b = 0; b < dims[1]; b++) {
	    buffer[a][b] = (double)SvNV(*av_fetch(Xa, b, 0));
          }
        }
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 3 : {
        double buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b, 0));
	    for (c = 0; c < dims[2]; c++) {
	      buffer[a][b][c] = (double)SvNV(*av_fetch(Xab, c, 0));
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
        break;
      }
      case 4 : {
        double buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b, 0));
	    for (c = 0; c < dims[2]; c++) {
	      AV *Xabc = (AV*)SvRV(*av_fetch(Xab, c, 0));
	      for (d = 0; d < dims[3]; d++) {
		buffer[a][b][c][d] = (double)SvNV(*av_fetch(Xabc, d, 0));
	      }
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	break;
      }
      case 5 : {
        double buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]][(int)dims[4]];
	for (a = 0; a < dims[0]; a++) {
	  Xa = (AV*)SvRV(*av_fetch(data, a, 0));
	  for (b = 0; b < dims[1]; b++) {
	    Xab = (AV*)SvRV(*av_fetch(Xa, b, 0));
	    for (c = 0; c < dims[2]; c++) {
	      AV *Xabc = (AV*)SvRV(*av_fetch(Xab, c, 0));
	      for (d = 0; d < dims[3]; d++) {
		AV *Xabcd = (AV*)SvRV(*av_fetch(Xabc, d, 0));
		for (e = 0; e < dims[4]; e++) {
		  buffer[a][b][c][d][e] = (double)SvNV(*av_fetch(Xabcd, e, 0));
		}
	      }
	    }
	  }
	}
	dataset->status = H5Dwrite(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	break;
      }
    }
  }
  herr_t flag = H5Sclose(space_id);
  return dataset->status < 0 ? 0:1;
}

void _read_string(dset* dataset, int r, hid_t space_in, AV *data, hid_t space_out) {

  AV *Xa, *Xab;
  int a,b,c,d,e, status;
  hid_t id = dataset->id;
  hid_t type = dataset->dtype;
  hsize_t dims[r];
  if (space_out != H5S_ALL) {
    r = H5Sget_simple_extent_dims(space_out, dims, NULL);
  }
  else {
    r = H5Sget_simple_extent_dims(space_in, dims, NULL);
  }

  switch(r) {
    case 1 : {
      if ( H5Tis_variable_str(type) ) {
	typedef struct {
	  char* string;
	} rdata;
	rdata buffer[dims[0]];
	status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
	for (a = 0; a < dims[0]; a++) {
	  SV* X = newSVpv(buffer[a].string,0);
	  av_store(data, a, X);
	}
      }
      else {
	typedef struct {
	  char string[1024];
	} rdata;
	rdata buffer[dims[0]];
	status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
	for (a = 0; a < dims[0]; a++) {
	  SV* X = newSVpv(buffer[a].string,0);
	  av_store(data, a, X);
	}
      }
      break;
    }
    case 2 : {
      char* buffer[(int)dims[0]][(int)dims[1]];
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  SV* X = newSVpv(buffer[a][b],0);
	  av_store(Xa, b, X);
	}
      }
      break;
    }
    case 3 : {
      char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]];
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    SV* X = newSVpv(buffer[a][b][c],0);
	    av_store(Xab, c, X);
	  }
	}
      }
      break;
    }
    case 4 : {
      char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]];
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      SV* X = newSVpv(buffer[a][b][c][d],0);
	      av_store(Xabc, d, X);
	    }
	  }
	}
      }
      break;
    }
    case 5 : {
      char* buffer[(int)dims[0]][(int)dims[1]][(int)dims[2]][(int)dims[3]][(int)dims[4]];
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer);
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      AV *Xabcd = newAV();
	      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
	      av_store(Xabc, d, Xabcdref);
	      for (e = 0; e < dims[4]; e++) {
		SV* X = newSVpv(buffer[a][b][c][d][e],0);
		av_store(Xabcd, e, X);
	      }
	    }
	  }
	}
      }
      break;
    }
  }
  dataset->status = status;
}

void _read_opaque(dset* dataset, int r, hid_t space_id, AV *data) {

  AV *Xi, *Xij;
  int a,b, status;
  hid_t id = dataset->id;
  hid_t type = dataset->dtype;
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  size_t len = H5Tget_size(type);
  switch(r) {
    case 1 : {
      unsigned char buffer[(int)dims[0]][len];
      status = H5Dread(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
      for (a=0; a<dims[0]; a++) {
	SV **svs;
	svs = (SV **) malloc(len*sizeof(SV *));
	for (b=0; b<len; b++) {
	  svs[b] = sv_newmortal();
	  sv_setiv((SV*)svs[b],buffer[a][b]);
	}
	AV* X = av_make(len,svs);
	free(svs);
	SV* Xref = newRV_noinc((SV*)X);
	av_store(data, a, Xref);
      }
      break;
    }
    default : {
      croak("\nERROR: Opaque datatype can only have one dimension.\n");
    }
  }
  dataset->status = status;
}

void _read_array(dset* dataset, int r, hid_t space_in, AV *data, hid_t space_out) {

  AV *Xa, *Xab;
  int a,b,c,d,e,f,i,n,status;
  hid_t id = dataset->id;
  hid_t type = H5Tget_native_type(dataset->dtype, H5T_DIR_ASCEND);
  r = H5Tget_array_ndims(type);
  hsize_t dms[r];
  status = H5Tget_array_dims2(type, dms);
  if (space_out != H5S_ALL) {
    n = H5Sget_simple_extent_npoints(space_out);
  }
  else {
    n = H5Sget_simple_extent_npoints(space_in);
  }
  hsize_t dims[r+1];
  dims[0] = n;
  r++;
  for(a = 1; a < r; a++) {
    dims[a] = dms[a-1];
  }
  hid_t base_type = H5Tget_super(type);
  hid_t base_class = H5Tget_class(base_type);
  int size = H5Tget_size(base_type);

  char* buffer_char;
  unsigned char* buffer_uchar;
  short* buffer_short;
  unsigned short* buffer_ushort;
  int* buffer_int;
  unsigned int* buffer_uint;
  long* buffer_long;
  unsigned long* buffer_ulong;
  float* buffer_float;
  double* buffer_double;

  if (base_class == H5T_FLOAT) {
    if (size == 1) {
      buffer_char = get_char_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_char);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
      buffer_float = get_float_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_float);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
      buffer_double = get_double_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_double);
    }
    else {
      croak("\nERROR: Unknown float type in _read_array (size= %i).\n",size);
    }
  }
  else if (base_class == H5T_INTEGER) {
    if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
      buffer_char = get_char_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_char);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
      buffer_uchar = get_uchar_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_uchar);
    }
    else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
      buffer_short = get_short_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_short);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
      buffer_ushort = get_ushort_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_ushort);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
      buffer_int = get_int_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_int);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
      buffer_uint = get_uint_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_uint);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
      buffer_long = get_long_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_long);
    }
    else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
      buffer_ulong = get_ulong_buffer(r,dims);
      status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_ulong);
    }
    else {
      croak("\nERROR: Unknown integer type in _read_array (size= %i).\n",size);
    }
  }
  else {
    croak("\nERROR: Unsupported data type in _read_array.\n");
  }

  if (status<0) {
    croak("\nERROR: Failed to read array data set.\n");
  }

  switch(r-1) {
    case 1 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  int idx = a*dims[1]+b;
	  SV* X;
	  if (base_class == H5T_FLOAT) {
	    if (size == 1) {
	      X = newSVnv(buffer_char[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
	      X = newSVnv(buffer_float[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
	      X = newSVnv(buffer_double[idx]);
	    }
	  }
	  else if (base_class == H5T_INTEGER) {
	    if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
	      X = newSVnv(buffer_char[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
	      X = newSVnv(buffer_uchar[idx]);
	    }
	    else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
	      X = newSVnv(buffer_short[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
	      X = newSVnv(buffer_ushort[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
	      X = newSVnv(buffer_int[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
	      X = newSVnv(buffer_uint[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
	      X = newSVnv(buffer_long[idx]);
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
	      X = newSVnv(buffer_ulong[idx]);
	    }
	  }
	  av_store(Xa, b, X);
	}
      }
      break;
    }
    case 2 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    int idx = a*dims[1]*dims[2]+b*dims[2]+c;
	    SV* X;
	    if (base_class == H5T_FLOAT) {
	      if (size == 1) {
		 X = newSVnv(buffer_char[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
		X = newSVnv(buffer_float[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
		X = newSVnv(buffer_double[idx]);
	      }
	    }
	    else if (base_class == H5T_INTEGER) {
	      if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
		X = newSVnv(buffer_char[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
		X = newSVnv(buffer_uchar[idx]);
	      }
	      else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
		X = newSVnv(buffer_short[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
		X = newSVnv(buffer_ushort[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
		X = newSVnv(buffer_int[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
		X = newSVnv(buffer_uint[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
		X = newSVnv(buffer_long[idx]);
	      }
	      else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
		X = newSVnv(buffer_ulong[idx]);
	      }
	    }
	    av_store(Xab, c, X);
	  }
	}
      }
      break;
    }
    case 3 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
 	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      int idx = a*dims[1]*dims[2]*dims[3]+b*dims[2]*dims[3]+c*dims[3]+d;
	      SV* X;
	      if (base_class == H5T_FLOAT) {
		if (size == 1) {
		  X = newSVnv(buffer_char[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
		  X = newSVnv(buffer_float[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
		  X = newSVnv(buffer_double[idx]);
		}
	      }
	      else if (base_class == H5T_INTEGER) {
		if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
		  X = newSVnv(buffer_char[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
		  X = newSVnv(buffer_uchar[idx]);
		}
		else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
		  X = newSVnv(buffer_short[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
		  X = newSVnv(buffer_ushort[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
		  X = newSVnv(buffer_int[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
		  X = newSVnv(buffer_uint[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
		  X = newSVnv(buffer_long[idx]);
		}
		else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
		  X = newSVnv(buffer_ulong[idx]);
		}
	      }
	      av_store(Xabc, d, X);
	    }
	  }
	}
      }
      break;
    }
    case 4 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      AV *Xabcd = newAV();
	      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
	      av_store(Xabc, d, Xabcdref);
	      for (e = 0; e < dims[4]; e++) {
		int idx = a*dims[1]*dims[2]*dims[3]*dims[4]+b*dims[2]*dims[3]*dims[4]+c*dims[3]*dims[4]+d*dims[4]+e;
		SV* X;
		if (base_class == H5T_FLOAT) {
		  if (size == 1) {
		    X = newSVnv(buffer_char[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
		    X = newSVnv(buffer_float[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
		    X = newSVnv(buffer_double[idx]);
		  }
		}
		else if (base_class == H5T_INTEGER) {
		  if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
		    X = newSVnv(buffer_char[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
		    X = newSVnv(buffer_uchar[idx]);
		  }
		  else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
		    X = newSVnv(buffer_short[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
		    X = newSVnv(buffer_ushort[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
		    X = newSVnv(buffer_int[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
		    X = newSVnv(buffer_uint[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
		    X = newSVnv(buffer_long[idx]);
		  }
		  else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
		    X = newSVnv(buffer_ulong[idx]);
		  }
		}
		av_store(Xabcd, e, X);
	      }
	    }
	  }
	}
      }
      break;
    }
    case 5 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      AV *Xabcd = newAV();
	      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
	      av_store(Xabc, d, Xabcdref);
	      for (e = 0; e < dims[4]; e++) {
		AV *Xabcde = newAV();
		SV* Xabcderef = newRV_noinc((SV*)Xabcde);
		av_store(Xabcd, e, Xabcderef);
		for (f = 0; f < dims[5]; f++) {
		  int idx = a*dims[1]*dims[2]*dims[3]*dims[4]*dims[5]+b*dims[2]*dims[3]*dims[4]*dims[5]+c*dims[3]*dims[4]*dims[5]+d*dims[4]*dims[5]+e*dims[5]+f;
		  SV* X;
		  if (base_class == H5T_FLOAT) {
		    if (size == 1) {
		      X = newSVnv(buffer_char[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
		      X = newSVnv(buffer_float[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
		      X = newSVnv(buffer_double[idx]);
		    }
		  }
		  else if (base_class == H5T_INTEGER) {
		    if (H5Tequal(base_type,H5T_NATIVE_CHAR)>0 || H5Tequal(base_type,H5T_NATIVE_SCHAR)>0) {
		      X = newSVnv(buffer_char[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_UCHAR)>0) {
		      X = newSVnv(buffer_uchar[idx]);
		    }
		    else if (H5Tequal(base_type ,H5T_NATIVE_SHORT)>0) {
		      X = newSVnv(buffer_short[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_USHORT)>0) {
		      X = newSVnv(buffer_ushort[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_INT)>0) {
		      X = newSVnv(buffer_int[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_UINT)>0) {
		      X = newSVnv(buffer_uint[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_LONG)>0) {
		      X = newSVnv(buffer_long[idx]);
		    }
		    else if (H5Tequal(base_type,H5T_NATIVE_ULONG)>0) {
		      X = newSVnv(buffer_ulong[idx]);
		    }
		  }
		  av_store(Xabcd, e, X);
		}
	      }
	    }
	  }
	}
      }
      break;
    }
  }
  H5Tclose(base_type);
  dataset->status = status;
}

void _read_vlen(dset* dataset, int r, hid_t space_id, AV *data) {

  AV *Xa, *Xab;
  int a,b,c,d,e;
  hid_t id = dataset->id;
  hid_t type = H5Tget_native_type(dataset->dtype,H5T_DIR_ASCEND);
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  hid_t base_type = H5Tget_super(type);
  hid_t base_class = H5Tget_class(base_type);
  int size = H5Tget_size(base_type);
  size_t len;
  switch(r) {
    case 1 : {
      hvl_t buffer[(int)dims[0]];
      dataset->status = H5Dread(id, type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
      if (base_class == H5T_INTEGER) {
	if (size<4) {
	  for (a=0; a<dims[0]; a++) {
	    len = buffer[a].len;
	    SV* X = newSVpvn(buffer[a].p,len);
	    av_store(data, a, X);
	  }
	}
	else if (size>=4 && size<8) {
	  for (a=0; a<dims[0]; a++) {
	    len = buffer[a].len;
	    Xa = newAV();
	    SV* Xaref = newRV_noinc((SV*)Xa);
	    av_store(data, a, Xaref);
	    for (b=0;b<len;b++) {
	      SV* X = newSVnv(((int *)buffer[a].p)[b]);
	      av_push(Xa, X);
	    }
	  }
	}
	else { /*size>=8 */
	  for (a=0; a<dims[0]; a++) {
	    len = buffer[a].len;
	    Xa = newAV();
	    SV* Xaref = newRV_noinc((SV*)Xa);
	    av_store(data, a, Xaref);
	    for (b=0;b<len;b++) {
	      SV* X = newSVnv(((long *)buffer[a].p)[b]);
	      av_push(Xa, X);
	    }
	  }
	}
      }
      else {
	for (a=0; a<dims[0]; a++) {
	  len = buffer[a].len;
	  Xa = newAV();
	  SV* Xaref = newRV_noinc((SV*)Xa);
	  av_store(data, a, Xaref);
	  for (b=0;b<len;b++) {
	    SV* X = newSVnv(((double *)buffer[a].p)[b]);
	    av_push(Xa, X);
	  }
	}
      }
      H5Dvlen_reclaim(type, space_id, H5P_DEFAULT, buffer);
      break;
    }
    default : {
      croak("\nERROR: Vlen datatype can only have one dimension.\n");
    }
  }
  herr_t flag = H5Sclose(space_id);
}

void _read_double(dset* dataset, int r, hid_t space_in, AV *data, hid_t space_out) {

  AV *Xa, *Xab;
  int a,b,c,d,e,status;
  hid_t id = dataset->id;
  hid_t type = H5Tget_native_type(dataset->dtype, H5T_DIR_ASCEND);
  hsize_t dims[r];
  if (space_out != H5S_ALL) {
    r = H5Sget_simple_extent_dims(space_out, dims, NULL);
  }
  else {
    r = H5Sget_simple_extent_dims(space_in, dims, NULL);
  }
  int size = H5Tget_size(type);

  H5T_class_t t_class;
  t_class = H5Tget_class(dataset->dtype);

  char* buffer_char;
  float* buffer_float;
  double* buffer_double;

  if (size == 1) {
    buffer_char = get_char_buffer(r,dims);
    status = H5Dread(id, H5T_NATIVE_CHAR, space_out, space_in, H5P_DEFAULT, buffer_char);
  }
  else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
    buffer_float = get_float_buffer(r,dims);
    status = H5Dread(id, H5T_NATIVE_FLOAT, space_out, space_in, H5P_DEFAULT, buffer_float);
  }
  else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
    buffer_double = get_double_buffer(r,dims);
    status = H5Dread(id, H5T_NATIVE_DOUBLE, space_out, space_in, H5P_DEFAULT, buffer_double);
  }
  else {
    croak("\nERROR: Unknown float type in _read_double (size= %i).\n",size);
  }
  if (status<0) {
    croak("\nERROR: Failed to read float data set.\n");
  }

  switch(r) {
    case 1 : {
      for (a = 0; a < dims[0]; a++) {
	SV* X;
	if (size == 1) {
	  X = newSVnv(buffer_char[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
	  X = newSVnv(buffer_float[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
	  X = newSVnv(buffer_double[a]);
	}
	av_store(data, a, X);
      }
      break;
    }
    case 2 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  int idx = a*dims[1]+b;
	  SV* X;
	  if (size == 1) {
	    X = newSVnv(buffer_char[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
	    X = newSVnv(buffer_float[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
	    X = newSVnv(buffer_double[idx]);
	  }
	  av_store(Xa, b, X);
	}
      }
      break;
    }
    case 3 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    int idx = a*dims[1]+b*dims[2]+c;
	    SV* X;
	    if (size == 1) {
	      X = newSVnv(buffer_char[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
	      X = newSVnv(buffer_float[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
	      X = newSVnv(buffer_double[idx]);
	    }
	    av_store(Xab, c, X);
	  }
	}
      }
      break;
    }
    case 4 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      int idx = a*dims[1]*dims[2]*dims[3]+b*dims[2]*dims[3]+c*dims[3]+d;
	      SV* X;
	      if (size == 1) {
		X = newSVnv(buffer_char[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
		X = newSVnv(buffer_float[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
		X = newSVnv(buffer_double[idx]);
	      }
	      av_store(Xabc, d, X);
	    }
	  }
	}
      }
      break;
    }
    case 5 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      AV *Xabcd = newAV();
	      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
	      av_store(Xabc, d, Xabcdref);
	      for (e = 0; e < dims[4]; e++) {
		int idx = a*dims[1]*dims[2]*dims[3]*dims[4]+b*dims[2]*dims[3]*dims[4]+c*dims[3]*dims[4]+d*dims[4]+e;
		SV* X;
		if (size == 1) {
		  X = newSViv((int)buffer_char[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_FLOAT)>0) {
		  X = newSVnv(buffer_float[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_DOUBLE)>0) {
		  X = newSVnv(buffer_double[idx]);
		}
		av_store(Xabcd, e, X);
	      }
	    }
	  }
	}
      }
      break;
    }
  }
  dataset->status = status;
}

void _read_integer(dset* dataset, int r, hid_t space_in, AV *data, hid_t space_out) {

  AV *Xa, *Xab;
  int a,b,c,d,e,status,size;
  hid_t id = dataset->id;
  H5T_class_t class;
  class = H5Tget_class(dataset->dtype);
  hid_t type;
  type = H5Tget_native_type(dataset->dtype, H5T_DIR_ASCEND);
  size = H5Tget_size(type);
  hsize_t dims[r];

  if (space_out != H5S_ALL) {
    r = H5Sget_simple_extent_dims(space_out, dims, NULL);
  }
  else {
    r = H5Sget_simple_extent_dims(space_in, dims, NULL);
  }

  char* buffer_char;
  unsigned char* buffer_uchar;
  short* buffer_short;
  unsigned short* buffer_ushort;
  int* buffer_int;
  unsigned int* buffer_uint;
  long* buffer_long;
  unsigned long* buffer_ulong;

  if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
    buffer_char = get_char_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_char);
  }
  else if (H5Tequal(type,H5T_NATIVE_UCHAR)>0) {
    buffer_uchar = get_uchar_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_uchar);
  }
  else if (H5Tequal(type ,H5T_NATIVE_SHORT)>0) {
    buffer_short = get_short_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_short);
  }
  else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
    buffer_ushort = get_ushort_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_ushort);
  }
  else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
    buffer_int = get_int_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_int);
  }
  else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
    buffer_uint = get_uint_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_uint);
  }
  else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
    buffer_long = get_long_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_long);
  }
  else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
    buffer_ulong = get_ulong_buffer(r,dims);
    status = H5Dread(id, type, space_out, space_in, H5P_DEFAULT, buffer_ulong);
  }
  else {
    croak("\nERROR: Unknown integer type in _read_integer (size= %i).\n",size);
  }

  if (status<0) {
    croak("\nERROR: Failed to read integer data set.\n");
  }

  switch(r) {
    case 1 : {
      for (a = 0; a < dims[0]; a++) {
	SV* X;
	if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
	  X = newSVnv(buffer_char[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_UCHAR)>0) {
	  X = newSVnv(buffer_uchar[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_SHORT)>0) {
	  X = newSVnv(buffer_short[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
	  X = newSVnv(buffer_ushort[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
	  X = newSVnv(buffer_int[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
	  X = newSVnv(buffer_uint[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
	  X = newSVnv(buffer_long[a]);
	}
	else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
	  X = newSVnv(buffer_ulong[a]);
	}
	av_store(data, a, X);
      }
      break;
    }
    case 2 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  int idx = a*dims[1]+b;
	  SV* X;
	  if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
	    X = newSVnv(buffer_char[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_UCHAR)>0) {
	    X = newSVnv(buffer_uchar[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_SHORT)>0) {
	    X = newSVnv(buffer_short[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
	    X = newSVnv(buffer_ushort[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
	    X = newSVnv(buffer_int[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
	    X = newSVnv(buffer_uint[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
	    X = newSVnv(buffer_long[idx]);
	  }
	  else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
	    X = newSVnv(buffer_ulong[idx]);
	  }
	  av_store(Xa, b, X);
	}
      }
      break;
    }
    case 3 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    int idx = a*dims[1]*dims[2]+b*dims[2]+c;
	    SV* X;
	    if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
	      X = newSVnv(buffer_char[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_UCHAR)>0) {
	      X = newSVnv(buffer_uchar[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_SHORT)>0) {
	      X = newSVnv(buffer_short[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
	      X = newSVnv(buffer_ushort[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
	      X = newSVnv(buffer_int[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
	      X = newSVnv(buffer_uint[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
	      X = newSVnv(buffer_long[idx]);
	    }
	    else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
	      X = newSVnv(buffer_ulong[idx]);
	    }
	    av_store(Xab, c, X);
	  }
	}
      }
      break;
    }
    case 4 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      int idx = a*dims[1]*dims[2]*dims[3]+b*dims[2]*dims[3]+c*dims[3]+d;
	      SV* X;
	      if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
		X = newSVnv(buffer_char[idx]);
	      }
	      else if (H5Tequal(type, H5T_NATIVE_UCHAR)>0) {
		X = newSVnv(buffer_uchar[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_SHORT)>0) {
		X = newSVnv(buffer_short[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
		X = newSVnv(buffer_ushort[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
		X = newSVnv(buffer_int[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
		X = newSVnv(buffer_uint[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
		X = newSVnv(buffer_long[idx]);
	      }
	      else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
		X = newSVnv(buffer_ulong[idx]);
	      }
	      av_store(Xabc, d, X);
	    }
	  }
	}
      }
      break;
    }
    case 5 : {
      for (a = 0; a < dims[0]; a++) {
	Xa = newAV();
	SV* Xaref = newRV_noinc((SV*)Xa);
	av_store(data, a, Xaref);
	for (b = 0; b < dims[1]; b++) {
	  Xab = newAV();
	  SV* Xabref = newRV_noinc((SV*)Xab);
	  av_store(Xa, b, Xabref);
	  for (c = 0; c < dims[2]; c++) {
	    AV *Xabc = newAV();
	    SV* Xabcref = newRV_noinc((SV*)Xabc);
	    av_store(Xab, c, Xabcref);
	    for (d = 0; d < dims[3]; d++) {
	      AV *Xabcd = newAV();
	      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
	      av_store(Xabc, d, Xabcdref);
	      for (e = 0; e < dims[4]; e++) {
		int idx = a*dims[1]*dims[2]*dims[3]*dims[4]+b*dims[2]*dims[3]*dims[4]+c*dims[3]*dims[4]+d*dims[4]+e;
		SV* X;
		if (H5Tequal(type,H5T_NATIVE_CHAR)>0 || H5Tequal(type,H5T_NATIVE_SCHAR)>0) {
		  X = newSViv((int)buffer_char[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_UCHAR)>0) {
		  X = newSViv((int)buffer_uchar[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_SHORT)>0) {
		  X = newSVnv(buffer_short[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_USHORT)>0) {
		  X = newSVnv(buffer_ushort[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_INT)>0) {
		  X = newSVnv(buffer_int[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_UINT)>0) {
		  X = newSVnv(buffer_uint[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_LONG)>0) {
		  X = newSVnv(buffer_long[idx]);
		}
		else if (H5Tequal(type,H5T_NATIVE_ULONG)>0) {
		  X = newSVnv(buffer_ulong[idx]);
		}
		av_store(Xabcd, e, X);
	      }
	    }
	  }
	}
      }
      break;
    }
  }
  H5Tclose(type);
  dataset->status = status;
}

void _read_enum(dset* dataset, int r, hid_t space_id, AV *data) {

  int a;
  hid_t id = dataset->id;
  hid_t type = H5Tget_native_type(dataset->dtype, H5T_DIR_ASCEND);
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  HV* hash = newHV();
  SV* Href = newRV_noinc((SV*)hash);
  av_store(data, 0, Href);

  int n = H5Tget_nmembers(type);
  for (a=0; a < n; a++) {
    char* name;
    name = H5Tget_member_name(type, a);
    int value;
    H5Tget_member_value(type, a, &value);
    hv_store(hash, name, strlen(name), newSViv(value), 0);
  }

}

void _read_compound(dset* dataset, int r, hid_t space_id, AV *data) {

  AV *Xa, *Xab;
  int a,b,c,d,e,f,status,size;
  hid_t id = dataset->id;
  hid_t type = H5Tget_native_type(dataset->dtype, H5T_DIR_ASCEND);
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);
  if (r>1) {
    croak("\nERROR: More than one dimension not supported for compound datatype.\n");
  }
  HV* hash = newHV();
  /* Discover compound structure */
  int nmembers = H5Tget_nmembers(type);
  for (a = 0; a < nmembers; a++) {
    char* member_name;
    member_name = H5Tget_member_name(type,a);
    hid_t member_type;
    member_type = H5Tget_member_type(type,a);
    hid_t native_type = H5Tget_native_type(member_type, H5T_DIR_ASCEND);
    H5T_class_t member_class;
    member_class = H5Tget_class(member_type);
    AV* array = newAV();
    SV* arrayref = newRV_noinc((SV*)array);
    hv_store(hash, member_name, strlen(member_name), arrayref, 0);
    if (member_class == H5T_COMPOUND) {
      croak("\nERROR: Nested compound data types not supported\n");
    }
    else if (member_class == H5T_STRING) {
      if ( H5Tis_variable_str(member_type) ) {
	typedef struct {
	  char* string;
	} rdata;
	rdata buffer[dims[0]];
	hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVpvf("%s", buffer[b].string));
	}
	H5Tclose(memory_type);
      }
      else {
	typedef struct {
	  char string[1024];
	} rdata;
	rdata buffer[dims[0]];
	hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVpvf("%s", buffer[b].string));
	}
	H5Tclose(memory_type);
      }
    }
    else if (member_class == H5T_INTEGER || member_class == H5T_ENUM) {
      if (member_class == H5T_ENUM) {
	native_type = H5Tget_super(member_type);
      }
      size = H5Tget_size(native_type);
      hid_t memory_type;
      if (size == 1 || H5Tequal(native_type,H5T_NATIVE_CHAR)>0 || H5Tequal(native_type,H5T_NATIVE_SCHAR)>0) {
	char buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(char));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_UCHAR)>0) {
	unsigned char buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(char));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type ,H5T_NATIVE_SHORT)>0) {
	short buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(short));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_USHORT)>0) {
	unsigned short buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(short));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_INT)>0) {
	int buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(int));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_UINT)>0) {
	unsigned int buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(int));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_LONG)>0) {
	long buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(long));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_ULONG)>0) {
	unsigned long buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(long));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else {
	croak("\nERROR: Unknown integer type in _read_compound (size= %i).\n",size);
      }
      H5Tclose(memory_type);
    }
    else if (member_class == H5T_FLOAT) {
      hid_t memory_type;
      if (H5Tequal(native_type,H5T_NATIVE_FLOAT)>0) {
	float buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(float));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else if (H5Tequal(native_type,H5T_NATIVE_DOUBLE)>0) {
	double buffer[dims[0]];
	memory_type = H5Tcreate(H5T_COMPOUND, sizeof(double));
	H5Tinsert(memory_type, member_name, 0, member_type);
	status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	for (b = 0; b<dims[0]; b++) {
	  av_push(array, newSVnv(buffer[b]));
	}
      }
      else {
	size = H5Tget_size(native_type);
	croak("\nERROR: Unknown float type in _read_compound (size= %i).\n",size);
      }
      H5Tclose(memory_type);
    }
    else if (member_class == H5T_ARRAY) {
      int n = H5Tget_array_ndims(member_type);
      hsize_t adims[n];
      status = H5Tget_array_dims2(member_type, adims);
      hid_t base_type = H5Tget_super(member_type);
      hid_t base_class = H5Tget_class(base_type);
      size = H5Tget_size(base_type);
      switch(n) {
	case 1 : {
	  if (base_class == H5T_FLOAT) {
	    hid_t memory_type;
	    if (H5Tequal(base_type,H5T_NATIVE_FLOAT)>0) {
	      typedef struct {
		float ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	    }
	    else if (H5Tequal(base_type,H5T_NATIVE_DOUBLE)>0) {
	      typedef struct {
		double ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_store(Xa, c, X);
		}
	      }
	    }
	    H5Tclose(memory_type);
	  }
	  else {
	    if (size == 1 || H5Tequal(native_type,H5T_NATIVE_CHAR)>0 || H5Tequal(native_type,H5T_NATIVE_SCHAR)>0) {
	      typedef struct {
		char ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UCHAR)>0) {
	      typedef struct {
		unsigned char ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type ,H5T_NATIVE_SHORT)>0) {
	      typedef struct {
		short ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_USHORT)>0) {
	      typedef struct {
		unsigned short ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_INT)>0) {
	      typedef struct {
		int ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UINT)>0) {
	      typedef struct {
		unsigned int ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_push(array, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_push(Xa, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_LONG)>0) {
	      typedef struct {
		long ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_store(Xa, c, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_ULONG)>0) {
	      typedef struct {
		unsigned long ary[adims[0]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  SV* X = newSVnv(buffer[b].ary[c]);
		  av_store(Xa, c, X);
		}
	      }
	      H5Tclose(memory_type);
	    }
	  }
	  break;
	}
        case 2 : {
	  if (base_class == H5T_FLOAT) {
	    if (H5Tequal(native_type,H5T_NATIVE_FLOAT)>0) {
	      typedef struct {
		float ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_DOUBLE)>0) {
	      typedef struct {
		double ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else {
	      size = H5Tget_size(native_type);
	      croak("\nERROR: Unknown float type in _read_compound (size= %i).\n",size);
	    }
	  }
	  else {
	    if (size == 1 || H5Tequal(native_type,H5T_NATIVE_CHAR)>0 || H5Tequal(native_type,H5T_NATIVE_SCHAR)>0) {
	      typedef struct {
		char ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UCHAR)>0) {
	      typedef struct {
		unsigned char ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	    else if (H5Tequal(native_type ,H5T_NATIVE_SHORT)>0) {
	      typedef struct {
		short ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	    else if(H5Tequal(native_type,H5T_NATIVE_USHORT)>0) {
	      typedef struct {
		unsigned short ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_INT)>0) {
	      typedef struct {
		int ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UINT)>0) {
	      typedef struct {
		unsigned int ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_LONG)>0) {
	      typedef struct {
		long ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_ULONG)>0) {
	      typedef struct {
		unsigned long ary[(int)adims[0]][(int)adims[1]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    SV* X = newSVnv(buffer[b].ary[c][d]);
		    av_store(Xab, d, X);
		  }
		}
	      }
	    }
	  }
	  break;
	}
	case 3 : {
	  if (base_class == H5T_FLOAT) {
	    if (H5Tequal(native_type,H5T_NATIVE_FLOAT)>0) {
	      typedef struct {
		float ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_DOUBLE)>0) {
	      typedef struct {
		double ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else {
	      size = H5Tget_size(native_type);
	      croak("\nERROR: Unknown float type in _read_compound (size= %i).\n",size);
	    }
	  }
	  else {
	    if (size == 1 || H5Tequal(native_type,H5T_NATIVE_CHAR)>0 || H5Tequal(native_type,H5T_NATIVE_SCHAR)>0) {
	      typedef struct {
		char ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UCHAR)>0) {
	      typedef struct {
		unsigned char ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type ,H5T_NATIVE_SHORT)>0) {
	      typedef struct {
		short ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_USHORT)>0) {
	      typedef struct {
		unsigned short ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_INT)>0) {
	      typedef struct {
		int ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UINT)>0) {
	      typedef struct {
		unsigned int ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_LONG)>0) {
	      typedef struct {
		long ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_ULONG)>0) {
	      typedef struct {
		unsigned long ary[(int)adims[0]][(int)adims[1]][(int)adims[2]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      SV* X = newSVnv(buffer[b].ary[c][d][e]);
		      av_store(Xabc, e, X);
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	  }
	  break;
	}
	case 4 : {
	  if (base_class == H5T_FLOAT) {
	    if (H5Tequal(native_type,H5T_NATIVE_FLOAT)>0) {
	      typedef struct {
		float ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_DOUBLE)>0) {
	      typedef struct {
		double ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else {
	      size = H5Tget_size(native_type);
	      croak("\nERROR: Unknown float type in _read_compound (size= %i).\n",size);
	    }
	  }
	  else {
	    if (size == 1 || H5Tequal(native_type,H5T_NATIVE_CHAR)>0 || H5Tequal(native_type,H5T_NATIVE_SCHAR)>0) {
	      typedef struct {
		char ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UCHAR)>0) {
	      typedef struct {
		unsigned char ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type ,H5T_NATIVE_SHORT)>0) {
	      typedef struct {
		short ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_USHORT)>0) {
	      typedef struct {
		unsigned short ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_INT)>0) {
	      typedef struct {
		int ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_UINT)>0) {
	      typedef struct {
		unsigned int ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_LONG)>0) {
	      typedef struct {
		long ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	    else if (H5Tequal(native_type,H5T_NATIVE_ULONG)>0) {
	      typedef struct {
		unsigned long ary[(int)adims[0]][(int)adims[1]][(int)adims[2]][(int)adims[3]];
	      } rdata;
	      rdata buffer[dims[0]];
	      hid_t memory_type = H5Tcreate(H5T_COMPOUND, sizeof(rdata));
	      H5Tinsert(memory_type, member_name, 0, member_type);
	      status = H5Dread(id, memory_type, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
	      for (b = 0; b < dims[0]; b++) {
		Xa = newAV();
		SV* Xaref = newRV_noinc((SV*)Xa);
		av_store(array, b, Xaref);
		for (c = 0; c < adims[0]; c++) {
		  Xab = newAV();
		  SV* Xabref = newRV_noinc((SV*)Xab);
		  av_store(Xa, c, Xabref);
		  for(d = 0; d < adims[1]; d++) {
		    AV *Xabc = newAV();
		    SV* Xabcref = newRV_noinc((SV*)Xabc);
		    av_store(Xab, d, Xabcref);
		    for (e = 0; e < dims[2]; e++) {
		      AV *Xabcd = newAV();
		      SV* Xabcdref = newRV_noinc((SV*)Xabcd);
		      av_store(Xabc, e, Xabcdref);
		      for (f = 0; f < dims[3]; f++) {
			SV* X = newSVnv(buffer[b].ary[c][d][e][f]);
			av_store(Xabcd, f, X);
		      }
		    }
		  }
		}
	      }
	      H5Tclose(memory_type);
	    }
	  }
	  break;
	}
      }
    }
    else {
      fprintf(stderr,"\nWARNING: Unsupported data type in compound data set.\n");
    }
    H5Tclose(member_type);
  }
  /* reorganize data into array of hashes */
  for(a = 0; a<dims[0];a++) {
    HV* DataH = newHV();
    SV* DataHref = newRV_noinc((SV*)DataH);
    av_store(data, a, DataHref);
    for (b = 0; b < nmembers; b++) {
      SV* aryref;
      char* key;
      key = H5Tget_member_name(type,b);
      if (hv_exists(hash,key,strlen(key))) {
	aryref = *(hv_fetch(hash,key,strlen(key),0));
	AV* ary = SvRV(aryref);
	SV* value = *(av_fetch(ary,a,0));
	hv_store(DataH,key,strlen(key),value,0);
      }
    }
  }
}

int _read_dataset(SV* set, SV* dataref, SV* tag, int stack_increase) {

  if (stack_increase) {
    int new_limit = raise_stack_limit();
  }

  dset* dataset = (dset*)SvIV(set);
  hid_t space_id = H5Dget_space(dataset->id);
  int r = H5Sget_simple_extent_ndims(space_id);
  hsize_t dims[r];
  r = H5Sget_simple_extent_dims(space_id, dims, NULL);

  hid_t id = dataset->id;
  hid_t type = dataset->dtype;

  AV *data;
  data = (AV*)SvRV(dataref);
  H5T_class_t t_class;
  t_class = H5Tget_class(type);

  if (t_class == H5T_STRING) {
    _read_string(dataset, r, space_id, data, H5S_ALL);
  }
  else if (t_class == H5T_OPAQUE) {
   _read_opaque(dataset, r, space_id, data);
   char *tg = H5Tget_tag(type);
   sv_setpv(tag, tg);
  }
  else if (t_class == H5T_VLEN) {
    _read_vlen(dataset, r, space_id, data);
  }
  else if (t_class == H5T_COMPOUND) {
    _read_compound(dataset, r, space_id, data);
  }
  else if (t_class == H5T_ENUM) {
    _read_enum(dataset, r, space_id, data);
  }
  else if (t_class == H5T_ARRAY) {
    _read_array(dataset, r, space_id, data, H5S_ALL);
  }
  else if (t_class == H5T_INTEGER) {
    _read_integer(dataset, r, space_id, data, H5S_ALL);
  }
  else if (t_class == H5T_FLOAT){
    _read_double(dataset, r, space_id, data, H5S_ALL);
  }
  else {
    croak("\nERROR: Unknown data type in _read_dataset.\n");
  }
  return dataset->status < 0 ? 0:1;
}

int _read_dataset_slice(SV* set, SV* dataref, SV* tag, SV* startref, SV* strideref, SV* countref, SV* blockref) {

  dset* dataset = (dset*)SvIV(set);
  hid_t space_id = H5Dget_space(dataset->id);
  int r = H5Sget_simple_extent_ndims(space_id);

  int i;

  hsize_t start[r];
  AV* strt = (AV*)SvRV(startref);
  for (i = 0; i < r; i++) {
    start[i] = SvNV(*av_fetch(strt,i,0));
  }
  hsize_t stride[r];
  AV* strd = (AV*)SvRV(strideref);
  for (i = 0; i < r; i++) {
    stride[i] = SvNV(*av_fetch(strd,i,0));
  }
  hsize_t count[r];
  AV* cnt = (AV*)SvRV(countref);
  for (i = 0; i < r; i++) {
    count[i] = SvNV(*av_fetch(cnt,i,0));
  }
  hsize_t block[r];
  AV* blck = (AV*)SvRV(blockref);
  for (i = 0; i < r; i++) {
    block[i] = SvNV(*av_fetch(blck,i,0));
  }

  int status = H5Sselect_hyperslab(space_id, H5S_SELECT_SET, start, stride, count, block);

  AV *data;
  data = (AV*)SvRV(dataref);
  hid_t type = dataset->dtype;
  H5T_class_t t_class = H5Tget_class(type);

  hid_t memspace_id = H5Screate_simple(r, count, NULL);

  if (t_class == H5T_STRING) {
    _read_string(dataset, r, space_id, data, memspace_id);
  }
  else if (t_class == H5T_ARRAY) {
    _read_array(dataset, r, space_id, data, memspace_id);
  }
  else if (t_class == H5T_INTEGER) {
    _read_integer(dataset, r, space_id, data, memspace_id);
  }
  else if (t_class == H5T_FLOAT){
    _read_double(dataset, r, space_id, data, memspace_id);
  }
  else {
    croak("\nERROR: Unsupported data type in _read_dataset_slice.\n");
  }
  return dataset->status < 0 ? 0:1;
}


void _cleanup_dataset(SV* d) {

  dset* data = (dset*)SvIV(d);
  if (data->is_open) {
    data->status = H5Dclose(data->id);
    data->is_open = 0;
  }
  Safefree(data);
}
