# Author: jkh1
# 2013-10-02

=head1 NAME

  Algorithms::Cube

=head1 SYNOPSIS



=head1 DESCRIPTION

 A cube is a third order tensor, represented as an array of matrices of
 identical dimensions.

=head1 SEE ALSO



=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut


package Algorithms::Cube;

our $VERSION = '0.01';
use 5.006;
use strict;
use Carp;
use Algorithms::Matrix;

=head2 new

 Arg: (optional) list of Algorithms::Matrix;
 Description: Creates a new Cube object.
 Returntype: Cube object

=cut

sub new {

  my $class = shift;
  my @data = @_ if (@_);
  my $self = {};
  bless ($self, $class);
  if (@data) {
    $self->{'data'} = \@data;
  }
  else {
    $self->{'data'} = [];
  }

  return $self;
}

=head2 dims

 Description: Gets cube dimensions
 Returntype: list (rows,cols,tubes)

=cut

sub dims {

  my ($self) = @_;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $o = scalar(@{$self->{'data'}});

  return ($m,$n,$o);
}

=head2 get_slice

 Arg: list of int, dimension and index in the dimension along which to get
      the slice
 Description: Extract the slice at the given index position from the cube.
              Note that dimensions are counted from 0 with dim 0 = rows,
              dim 1 = columns and dim 2 = tubes. This is different from modes
              which are counted from 1 with mode-1 fibers = columns, mode-2
              fibers = rows and mode-3 fibers = tubes.
 Returntype: Matrix object

=cut

sub get_slice {

  my ($self,$dim,$idx) = @_;
  my $slice;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  # make sure 0 <= dim <= 2
  $dim = $dim % 3;
  if ($dim == 2) { # Frontal slice
    # make sure 0 <= i <= (tubes-1)
    my $i = $idx % scalar(@{$self->{'data'}});
    $slice = $self->{'data'}->[$i];
  }
  elsif ($dim == 1) { # Lateral slice
    my ($m,$n) = $self->{'data'}->[0]->dims;
    my $o = scalar(@{$self->{'data'}});
    # make sure 0 <= i <= (columns-1)
    $idx = $idx % $n;
    foreach my $i(0..$o-1) {
      if ($i == 0) {
	$slice = $self->{'data'}->[$i]->col($idx);
      }
      else {
	my $col = $self->{'data'}->[$i]->col($idx);
	$slice = $slice->bind($col,column=>1);
      }
    }
  }
  elsif ($dim == 0) { # Horizontal slice
    my ($m,$n) = $self->{'data'}->[0]->dims;
    my $o = scalar(@{$self->{'data'}});
    # make sure 0 <= i <= (rows-1)
    $idx = $idx % $m;
    $slice = Algorithms::Matrix->new($o,$n);
    foreach my $i(0..$n-1) {
      foreach my $j(0..$o-1) {
	my $v = $self->{'data'}->[$j]->get($idx,$i);
	$slice->set($j,$i,$v);
      }
    }
  }
  else {
    croak "\nERROR: incompatible dimension in get_slice().";
  }

  return $slice;
}

=head2 unfold

 Arg: 1, 2 or 3, mode along which to matricize the cube
 Description: Unfold the cube into a matrix along the given mode by
              putting the selected mode fibers into columns of a matrix.
              Note that modes are counted from 1 with mode-1 fibers = columns
              (dim 1), mode-2 fibers = rows (dim 0) and mode-3 fibers =
              tubes (dim 2).
 Returntype: Matrix object

=cut

sub unfold {

  my ($self,$mode) = @_;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $matrix;
  if ($mode == 1) {
    $matrix = $self->{'data'}->[0];
    my $o = scalar(@{$self->{'data'}});
    foreach my $i(1..$o-1) {
      $matrix = $matrix->bind($self->{'data'}->[$i],column=>1);
    }
  }
  elsif ($mode == 2) {
    $matrix = $self->{'data'}->[0]->transpose;
    my $o = scalar(@{$self->{'data'}});
    foreach my $i(1..$o-1) {
      $matrix = $matrix->bind($self->{'data'}->[$i]->transpose,column=>1);
    }
  }
  elsif ($mode == 3) {
    my ($m,$n) = $self->{'data'}->[0]->dims;
    $matrix = $self->get_slice(0,0);
    foreach my $i(1..$m-1) {
      $matrix = $matrix->bind($self->get_slice(0,$i),column=>1);
    }
  }
  else {
    croak "\nERROR: wrong mode in unfold.";
  }

  return $matrix;
}

=head2 fold

 Arg1: Matrix object
 Arg2: 1, 2 or 3, mode along which to fold the matrix into the cube
 Arg3: list of cube dimensions
 Description: Reconstruct a cube from its matricized form along a given mode.
              This reverses the unfold operation.
 Returntype: Cube object

=cut

sub fold {

  my ($self,$matrix,$mode,@dims) = @_;

  if (!@dims || !$dims[2]) {
    croak "\nERROR: Cube dimensions required in fold method";
  }
  my ($m,$n,$o) = @dims;
  my ($M,$N) = $matrix->dims;
  $self->{'data'} = []; # clean up if reusing previously used cube
  if ($mode == 1) {
    if ($N != $n*$o) {
      croak "\nERROR: Incompatible matrix and cube dimensions in fold";
    }
    foreach my $i(0..$o-1) {
      $self->{'data'}->[$i] = $matrix->submatrix(0,$i*$n,$m,$n);
    }
  }
  elsif ($mode == 2) {
    if ($N != $m*$o) {
      croak "\nERROR: Incompatible matrix and cube dimensions in fold";
    }
    foreach my $i(0..$o-1) {
      my $t = $matrix->submatrix(0,$i*$m,$n,$m);
      $self->{'data'}->[$i] = $t->transpose;
    }
  }
  elsif ($mode == 3) {
    if ($N != $m*$n) {
      croak "\nERROR: Incompatible matrix and cube dimensions in fold";
    }
    foreach my $k(0..$M-1) {
      my $v = $matrix->row($k)->transpose;
      $self->{'data'}->[$k] = $v->unvect($n,$m)->transpose;
    }
  }
  else {
    croak "\nERROR: Invalid mode in fold";
  }

  return $self;
}

=head2 vect

 Description: Turn the cube into a vector (one column matrix) by stacking
              all columns one after the other.
 Returntype: Matrix object

=cut

sub vect {

  my $self = shift;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $vec = $self->{'data'}->[0]->col(0);
  foreach my $k(0..$o-1) {
    foreach my $j(0..$n-1) {
      next if ($k == 0 && $j == 0);
      $vec = $vec->bind($self->{'data'}->[$k]->col($j),row=>1);
    }
  }

  return $vec;
}

=head2 unvect

 Arg1: Matrix object (with one column)
 Arg2: list of 3 integers (cube dimensions)
 Description: Turn a vector (one column matrix) into a cube
              of given dimensions i.e reverses the vect operation.
 Returntype: Cube object

=cut

sub unvect {

  my ($self,$vec,@dims) = @_;
  my ($mv,$nv) = $vec->dims;
  if ($nv != 1 ) {
    croak "\nERROR: Vector required as single column matrix in unvect";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n,$o) = @dims;
  $self->{'data'} = []; # clean up if reusing previously used cube
  foreach my $k(0..$o-1) {
    $self->{'data'}->[$k] = Algorithms::Matrix->new($m,$n);
    foreach my $j(0..$n-1) {
      my $col = $vec->submatrix($j*$m,0,$m,1);
      $self->{'data'}->[$k]->set_cols([$j],$col);
    }
  }

  return $self;
}

=head2 add

 Arg: Cube to add
 Description: Addition between 2 cubes of same dimensions or between a cube
              and a scalar.
 Returntype: Cube object

=cut

sub add {

  my ($self,$C) = @_;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $class = ref($self) || $self;
  my $sum = $class->new;
  my $o = scalar(@{$self->{'data'}});
  if (ref($C) && $C->isa("Algorithms::Cube")) {
    my $p = scalar(@{$C->{'data'}});
    my ($m1,$n1) = $self->{'data'}->[0]->dims;
    my ($m2,$n2) = $self->{'data'}->[0]->dims;
    unless ($o==$p && $m1==$m2 && $n1==$n2) {
      croak "\nERROR: Cubes do not have same number of components";
    }
    foreach my $i(0..$o-1) {
      $sum->{'data'}->[$i] = $self->{'data'}->[$i] + $C->{'data'}->[$i];
    }
  }
  else {
    foreach my $i(0..$o-1) {
      $sum->{'data'}->[$i] = $self->{'data'}->[$i] + $C;
    }
  }

  return $sum;
}

=head2 subtract

 Arg: Cube to subtract
 Description: Subtraction between 2 cubes of same dimensions or between a cube
              and a scalar.
 Returntype: Cube object

=cut

sub subtract {

  my ($self,$C,$reverse) = @_;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $class = ref($self) || $self;
  my $diff = $class->new;
  my $o = scalar(@{$self->{'data'}});
  if (ref($C) && $C->isa("Algorithms::Cube")) {
    my $p = scalar(@{$C->{'data'}});
    my ($m1,$n1) = $self->{'data'}->[0]->dims;
    my ($m2,$n2) = $self->{'data'}->[0]->dims;
    unless ($o==$p && $m1==$m2 && $n1==$n2) {
      croak "\nERROR: Cubes do not have same number of components";
    }
    foreach my $i(0..$o-1) {
      $diff->{'data'}->[$i] = $self->{'data'}->[$i] - $C->{'data'}->[$i];
    }
  }
  elsif ($reverse) {
    foreach my $i(0..$o-1) {
      $diff->{'data'}->[$i] = $C - $self->{'data'}->[$i];
    }
  }
  else {
    foreach my $i(0..$o-1) {
      $diff->{'data'}->[$i] = $self->{'data'}->[$i] - $C;
    }
  }

  return $diff;
}

=head2 multiply_elementwise

 Arg: Cube
 Description: Carries out element-wise multiplication of 2 cubes
 Returntype: Cube

=cut

sub multiply_elementwise {

  my ($self,$cube) = @_;
  my $class = ref($self) || $self;
  my $result;
  my ($i,$j,$k) = $self->dims;
  if (defined($cube) && ref($cube) && $cube->isa('Algorithms::Cube')) {
    my ($l,$m,$n) = $cube->dims;
    unless ($i == $l && $j == $m && $k == $n) {
      croak "ERROR: Can't multiply element-wise: Cubes must have same dimensions";
    }
    $result = $class->new();
    foreach my $p(0..$k-1) {
      $result->{'data'}->[$p] = $self->{'data'}->[$p] x $cube->{'data'}->[$p];
    }
  }
  elsif (defined($cube) && !ref($cube)) {
    croak "ERROR: Arg must be a Cube object";
  }

  return $result;
}

=head2 divide_elementwise

 Arg: Cube or double
 Description: Applies division to all elements of the cube
 Returntype: Cube

=cut

sub divide_elementwise {

  my ($self,$scalar,$reverse) = @_;
  my $class = ref($self) || $self;
  my ($i,$j,$k) = $self->dims;
  my $result = $class->new();
  if (ref($scalar) && $scalar->isa("Algorithms::Cube")) {
    croak "\nERROR: Division requires at least one scalar value.";
  }
  elsif ($reverse) {
    foreach my $p(0..$k-1) {
      $result->{'data'}->[$p] = $scalar / $self->{'data'}->[$p];
    }
  }
  else {
    if ($scalar == 0) {
      croak "\nERROR: Can't divide by 0";
    }
    foreach my $p(0..$k-1) {
      $result->{'data'}->[$p] = $self->{'data'}->[$p] / $scalar;
    }
  }
  return $result;
}

=head2 multiply_with_matrix

 Arg1: 1, 2 or 3, mode of the cube to use in the multiplication
 Arg2: Matrix object
 Description: mode-n multiplication of a cube with a matrix
              Note that modes are counted from 1 with mode-1 fibers = columns
              (dim 1), mode-2 fibers = rows (dim 0) and mode-3 fibers =
              tubes (dim 2).
 Returntype: Cube object

=cut

sub multiply_with_matrix {

  my ($self,$mode,$matrix) = @_;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $class = ref($self) || $self;
  my $product = $class->new;
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $o = scalar(@{$self->{'data'}});
  my ($p,$q) = $matrix->dims;
  if ($mode == 3) {
    my @P;
    foreach my $i(0..$m-1) {
      my $slice = $self->get_slice(0,$i);
      $P[$i] = $matrix * $slice;
    }
    foreach my $k(0..$p-1) {
      $product->{'data'}->[$k] = Algorithms::Matrix->new($m,$n);
      foreach my $i(0..$m-1) {
	$product->{'data'}->[$k]->set_rows([$i],$P[$i]->row($k));
      }
    }
  }
  elsif ($mode == 2) {
    my ($m,$n) = $self->{'data'}->[0]->dims;
    my $o = scalar(@{$self->{'data'}});
    foreach my $i(0..$o-1) {
      my $slice = $self->{'data'}->[$i]->transpose;
      $product->{'data'}->[$i] = $matrix * $slice;
      $product->{'data'}->[$i] = $product->{'data'}->[$i]->transpose;
    }
  }
  elsif ($mode == 1) {
    my $o = scalar(@{$self->{'data'}});
    foreach my $i(0..$o-1) {
      my $slice = $self->{'data'}->[$i];
      $product->{'data'}->[$i] = $matrix * $slice;
    }
  }
  else {
    croak "\nERROR: wrong mode in multiplication with matrix";
  }

  return $product;
}

=head2 hosvd

 Description: Performs higher-order singular value decomposition
 Returntype: list of core tensor Z and matrices of orthogonal modes
             U1, U2 and U3

=cut

sub hosvd {

  my $self = shift;
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my @U;
  my $Z = $class->new;
  my @p;
  foreach my $i(1..3) {
    my $X = $self->unfold($i);
    ($U[$i-1], undef) = $X->svd(U=>1,V=>0);
    (undef,$p[$i-1]) = $U[$i-1]->dims;
  }
  # Produce mode-1 unfolding of core tensor
  my $V = $U[2]->kron($U[1]);
  my $Y = $U[0]->transpose * $self->unfold(1) * $V;
  # Fold back into tensor
  foreach my $i(0..$p[2]-1) {
    $Z->{'data'}->[$i] = $Y->submatrix(0,$i*$p[1],$p[0],$p[1]);
  }

  return $Z,@U;
}

=head2 cp

 Arg1: int, number of components k
 Arg2: (optional) options as key => value pairs:
         initialisation => svd to initialise factor matrices by SVD
              (default is random initialization)
         symmetry => 1 to set A=B (i.e. the first two factor matrices
              are equal) e.g. if the frontal slices are symmetric
         norms => 1 to return factor norms (diagonal matrices containing
              the column norms of the factor matrices)
 Description: Performs CP (CANDECOMP/PARAFAC) decompositon using alternating
              least squares. Columns of the returned matrices are normalized
              to length of 1.
 Returntype: list of factor matrices A, B, C (and optionally, matrices of
             column norms)

=cut

sub cp {

  my $self = shift;
  my $r = shift;
  if (!$r) {
    croak "\nERROR: number of components required\n";
  }
  my %param = @_ if (@_);
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $I = $class->new;
  foreach my $i(0..$r-1) {
    $I->{'data'}->[$i] = Algorithms::Matrix->new($r,$r)->zero;
    $I->{'data'}->[$i]->set($i,$i,1);
  }
  my @X;
  $X[0] = $self->unfold(1);
  $X[1] = $self->unfold(2);
  $X[2] = $self->unfold(3);
  # Initialize factor matrices
  my ($A,$B,$C);
  if (defined($param{'initialisation'}) && lc($param{'initialisation'}) eq 'svd') {
    if ($r>$m) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 1 unfolding\n";
    }
    my ($U,$S,undef) = $X[0]->svd(U=>1,V=>0);
    $A = $U->submatrix(0,0,$m,$r);
    if ($r>$n) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 2 unfolding\n";
    }
    ($U,$S,undef) = $X[1]->svd(U=>1,V=>0);
    $B = $U->submatrix(0,0,$n,$r);
    if ($r>$o) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 3 unfolding\n";
    }
    ($U,$S,undef) = $X[2]->svd(U=>1,V=>0);
    $C = $U->submatrix(0,0,$o,$r);
  }
  else {
    $A = Algorithms::Matrix->new($m,$r)->random * ($m*$r);
    $B = Algorithms::Matrix->new($n,$r)->random * ($n*$r);
    $C = Algorithms::Matrix->new($o,$r)->random * ($o*$r);
  }

  my $maxIter = 2500;
  my $iter = 0;
  my $tol = 1e-6;
  my $diff =  0 + "inf";
  my $sse = 0 + "inf";
  my %norms;
  while ($diff>=$tol*$sse && ++$iter<$maxIter) {
    my $previous_sse = $sse;
    my @previous_factors = ($A,$B,$C);
    # Update factor matrices
    my $V = $B->transpose * $B;
    $V = $V x ($C->transpose * $C);
    $V = $V->pseudoinverse(overwrite=>1);
    $A = $X[0] * ($C->khatri_rao_product($B)) * $V;
    my $sq = $A x $A;
    $norms{'A'} = $sq->col_sums->sqrt->diag;
    $A = $A->normalize(type=>'length',overwrite=>1);

    if ($param{'symmetry'}) {
      $B = $A->clone;
      $norms{'B'} = $norms{'A'}->clone;
    }
    else {
      $V = $C->transpose * $C;
      $V = $V x ($A->transpose * $A);
      $V = $V->pseudoinverse(overwrite=>1);
      $B = $X[1] * ($C->khatri_rao_product($A)) * $V;
      $sq = $B x $B;
      $norms{'B'} = $sq->col_sums->sqrt->diag;
      $B = $B->normalize(type=>'length',overwrite=>1);
    }

    $V = $A->transpose * $A;
    $V = $V x ($B->transpose * $B);
    $V = $V->pseudoinverse(overwrite=>1);
    $C = $X[2] * ($B->khatri_rao_product($A)) * $V;
    $sq = $C x $C;
    $norms{'C'} = $sq->col_sums->sqrt->diag;
    $C = $C->normalize(type=>'length',overwrite=>1);

    # Compute fit
    my $Xapp = $I->multiply_with_matrix(1,$A);
    $Xapp = $Xapp->multiply_with_matrix(2,$B);
    $Xapp = $Xapp->multiply_with_matrix(3,$C);
    my $F = $self - $Xapp;
    $sse = $F->frobenius_norm;
    $sse = $sse * $sse;
    $diff = abs($previous_sse - $sse);
  }
  if ($param{'norms'}) {
    return ($A, $B, $C, $norms{'A'}, $norms{'B'}, $norms{'C'});
  }
  else {
    return ($A, $B, $C);
  }
}

=head2 nncp

 Arg1: int, number of components k
 Arg2: (optional) options as key=> value pairs:
         initialisation => svd to initialise factor matrices by SVD
              (default is random initialization)
         symmetry => 1 to set A=B (i.e. the first two factor matrices
              are equal) e.g. if the frontal slices are symmetric
         norms => 1 to return factor norms (diagonal matrices containing
              the column norms of the factor matrices)
 Description: Performs CP decompositon with non-negativity constraint.
              Columns of the returned matrices are normalized to length of 1.
 Returntype: list of factor matrices A, B, C (and optionally, matrices of
             column norms)

=cut

sub nncp {

  my $self = shift;
  my $r = shift;
  if (!$r) {
    croak "\nERROR: number of components required\n";
  }
  my %param = @_ if (@_);
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $I = $class->new;
  foreach my $i(0..$r-1) {
    $I->{'data'}->[$i] = Algorithms::Matrix->new($r,$r)->zero;
    $I->{'data'}->[$i]->set($i,$i,1);
  }
  my @X;
  $X[0] = $self->unfold(1);
  $X[1] = $self->unfold(2);
  $X[2] = $self->unfold(3);
  # Initialize factor matrices
  my ($A,$B,$C);
  if (defined($param{'initialisation'}) && lc($param{'initialisation'}) eq 'svd') {
    if ($r>$m) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 1 unfolding\n";
    }
    my ($U,$S,undef) = $X[0]->svd(U=>1,V=>0);
    $A = $U->submatrix(0,0,$m,$r);
    if ($r>$n) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 2 unfolding\n";
    }
    ($U,$S,undef) = $X[1]->svd(U=>1,V=>0);
    $B = $U->submatrix(0,0,$n,$r);
    if ($r>$o) {
      croak "ERROR: Number of selected components ($r) exceeds number of left singular vectors of mode 3 unfolding\n";
    }
    ($U,$S,undef) = $X[2]->svd(U=>1,V=>0);
    $C = $U->submatrix(0,0,$o,$r);
  }
  else {
    $A = Algorithms::Matrix->new($m,$r)->random * ($m*$r);
    $B = Algorithms::Matrix->new($n,$r)->random * ($n*$r);
    $C = Algorithms::Matrix->new($o,$r)->random * ($o*$r);
  }
  my $maxIter = 2500;
  my $iter = 0;
  my $tol = 1e-6;
  my $diff =  0 + "inf";
  my $sse = 0 + "inf";
  my %norms;
  while ($diff>=$tol*$sse && ++$iter<$maxIter) {
    my $previous_sse = $sse;
    my @previous_factors = ($A,$B,$C);
    # Update factor matrices
    my $VtV = $B->transpose * $B;
    $VtV = $VtV x ($C->transpose * $C);
    my $VtX = $X[0] * ($C->khatri_rao_product($B));
    $VtX = $VtX->transpose;
    my ($m,$n) = $VtX->dims;
    foreach my $i(0..$n-1) {
      my $a = $VtV->fnnls($VtX->col($i));
      $A = $A->set_rows([$i],$a->transpose);
    }
    my $sq = $A x $A;
    $norms{'A'} = $sq->col_sums->sqrt->diag;
    $A = $A->normalize(type=>'length',overwrite=>1);

    if ($param{'symmetry'}) {
      $B = $A->clone;
      $norms{'B'} = $norms{'A'}->clone;
    }
    else {
      $VtV = $C->transpose * $C;
      $VtV = $VtV x ($A->transpose * $A);
      $VtX = $X[1] * ($C->khatri_rao_product($A));
      $VtX = $VtX->transpose;
      ($m,$n) = $VtX->dims;
      foreach my $i(0..$n-1) {
	my $b = $VtV->fnnls($VtX->col($i));
	$B = $B->set_rows([$i],$b->transpose);
      }
      $sq = $B x $B;
      $norms{'B'} = $sq->col_sums->sqrt->diag;
      $B = $B->normalize(type=>'length',overwrite=>1);
    }

    $VtV = $A->transpose * $A;
    $VtV = $VtV x ($B->transpose * $B);
    $VtX = $X[2] * ($B->khatri_rao_product($A));
    $VtX = $VtX->transpose;
    ($m,$n) = $VtX->dims;
    foreach my $i(0..$n-1) {
      my $c = $VtV->fnnls($VtX->col($i));
      $C = $C->set_rows([$i],$c->transpose);
    }
    $sq = $C x $C;
    $norms{'C'} = $sq->col_sums->sqrt->diag;
    $C = $C->normalize(type=>'length',overwrite=>1);

    # Compute fit
    my $Xapp = $I->multiply_with_matrix(1,$A);
    $Xapp = $Xapp->multiply_with_matrix(2,$B);
    $Xapp = $Xapp->multiply_with_matrix(3,$C);
    my $F = $self - $Xapp;
    $sse = $F->frobenius_norm;
    $sse = $sse * $sse;
    $diff = abs($previous_sse - $sse);
  }

  if ($param{'norms'}) {
    return ($A, $B, $C, $norms{'A'}, $norms{'B'}, $norms{'C'});
  }
  else {
    return ($A, $B, $C);
  }
}

=head2 ccd

 Args: list of factor matrices resulting from the CP decomposition
       of the calling tensor
 Description: Computes the core consistency diagnostic of the CP decomposition
              of the calling tensor.
 Returntype: double

=cut

sub ccd {

  my ($self,$A,$B,$C) = @_;

  my ($m,$n) = $A->dims;
  # Scale factor matrices so that every vector within a component
  # has same sum of squares i.e. ||ai||=||bi||=||ci||=1
  my ($scA,$scB,$scC);
  $scA = $A->normalize(type=>'length');
  $scB = $B->normalize(type=>'length');
  $scC = $C->normalize(type=>'length');

  # Compute Tucker3 model core tensor
  my $V = $scC->kron($scB);
  my $G1 = $scA->transpose * $self->unfold(1) * $V;
  my $G = Algorithms::Cube->new;
  $G = $G->fold($G1,1,$n,$n,$n);
  my $g = 0;
  foreach my $k(0..$n-1) {
    my $M = $G->{'data'}->[$k];
    foreach my $j(0..$n-1) {
      foreach my $i(0..$n-1) {
	if ($i == $j && $i == $k) {
	  my $d = $M->get($i,$j) - 1;
	  $g += $d * $d;
	}
	else {
	  my $d = $M->get($i,$j);
	  $g += $d * $d;
	}
      }
    }
  }
  my $ccd = 100 * (1 - ($g / $n));

  return $ccd;
}

=head2 tucker

 Arg: list of int, components p,q and r
 Description: Performs a Tucker3 decompositon using alternating
              least squares
 Returntype: list of core tensor G and factor matrices A, B, C.

=cut

sub tucker {

  my ($self,$p,$q,$r) = @_;
  if (!$r || !$q || !$p) {
    croak "\nERROR: number of components required\n";
  }
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n) = $self->{'data'}->[0]->dims;
  # Initialize factor matrices
  my $A = Algorithms::Matrix->new($m,$p)->random * ($m*$p);
  my $B = Algorithms::Matrix->new($n,$q)->random * ($n*$q);
  my $C = Algorithms::Matrix->new($o,$r)->random * ($o*$r);
  my $G = $class->new();
  my @X;
  $X[0] = $self->unfold(1);
  $X[1] = $self->unfold(2);
  $X[2] = $self->unfold(3);
  my $maxIter = 1000;
  my $iter = 0;
  my $tol = 1e-6;
  my $diff =  0 + "inf";
  my $sse = 0 + "inf";
  my %norms;
  while ($diff>=$tol*$sse && ++$iter<$maxIter) {
    my $previous_sse = $sse;
    my $Z = $X[0] * ($C->kron($B));
    my ($U,$S,$V) = $Z->svd();
    $A = $U->submatrix(0,0,$m,$p);
    $Z = $X[1] * ($C->kron($A));
    ($U,$S,$V) = $Z->svd();
    $B = $U->submatrix(0,0,$n,$q);
    $Z = $X[2] * ($B->kron($A));
    ($U,$S,$V) = $Z->svd();
    $C = $U->submatrix(0,0,$o,$r);

    my $V = $C->kron($B);
    my $G1 = $A->transpose * $self->unfold(1) * $V;
    $G = $G->fold($G1,1,$p,$q,$r);

    # Compute fit
    my $Xapp = $G->multiply_with_matrix(1,$A);
    $Xapp = $Xapp->multiply_with_matrix(2,$B);
    $Xapp = $Xapp->multiply_with_matrix(3,$C);
    my $F = $self - $Xapp;
    $sse = $F->frobenius_norm;
    $sse = $sse * $sse;
    $diff = abs($previous_sse - $sse);
  }

  return ($G, $A, $B, $C);
}

=head2 frobenius_norm

 Description: Computes the Frobenius norm of the cube as the square root of the
              sum of the squared entries of all cube elements.
 Returntype: double

=cut

sub frobenius_norm {

  my $self = shift;
  my $norm = 0;
  my $o = scalar(@{$self->{'data'}});
  foreach my $i(0..$o-1) {
    my $M = $self->{'data'}->[$i]->pow(2);
    my $s = $M->row_sums;
    $norm += $s->col_sum(0);
  }

  return sqrt($norm);
}

=head2 as_string

 Arg: (optional) string, used to separate entries
 Description: Converts the cube to a string of vertically stacked frontal
              slices. By default outputs a tab-delimited table.
 Returntype: string

=cut

sub as_string {

  my $self = shift;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $separator = shift || "\t";
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my $o = scalar(@{$self->{'data'}});
  my $str;
  foreach my $k(0..$o-1) {
    my $X = $self->get_slice(2,$k);
    foreach my $i(0..$m-1) {
      foreach my $j(0..$n-1) {
	croak "i= $i, j= $j, value= nan" if ($X->get($i,$j) eq 'nan');
	$str .="$separator".$X->get($i,$j);
      }
      $str .="\n";
    }
    $str .="\n";
  }
  return $str;
}

=head2 apply

 Arg1: reference to a subroutine
 Arg2:(optional), set overwrite=>1 to reuse original cube
 Description: Apply subroutine to each element of the cube. Subroutine must
              take one scalar argument as input and return a scalar.
 Returntype: Cube

=cut

sub apply {

  my $self = shift;
  my $subroutine = shift;
  my %param = @_ if (@_);
  my $o = scalar(@{$self->{'data'}});
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|^t/i)) {
    foreach my $k(0..$o-1) {
      $self->{'data'}->[$k]->apply($subroutine,overwrite=>1);
    }
    return $self;
  }
  else {
    my $class = ref($self) || $self;
    my $Z = $class->new;
    foreach my $k(0..$o-1) {
      $Z->{'data'}->[$k] = $self->{'data'}->[$k]->apply($subroutine);
    }
    return $Z;
  }
}

=head2 ntd

 Arg1: list of int, components p,q and r
 Arg2: (optional) options as key => value pairs:
       initialisation => nmf to initialise factor matrices by NMF
       (default is random initialization)
 Description: Performs a Tucker3 decompositon under non-negativity
              constraints using multiplicative update rules. See:
              Yong-Deok Kim, Seungjin Choi. Nonnegative Tucker
              Decomposition. CVPR, 2007.
 Returntype: list of core tensor G and factor matrices A, B, C.

=cut

sub ntd {
  my ($self,$p,$q,$r,%param) = @_;
  if (!$r || !$q || !$p) {
    croak "\nERROR: number of components required\n";
  }
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my $o = scalar(@{$self->{'data'}});
  my ($m,$n) = $self->{'data'}->[0]->dims;
  my @X;
  $X[0] = $self->unfold(1);
  $X[1] = $self->unfold(2);
  $X[2] = $self->unfold(3);

  # Initialize factor matrices
  my ($A,$B,$C);
  if (defined($param{'initialisation'}) && lc($param{'initialisation'}) eq 'nmf') {
    ($A,undef) = $X[0]->nmf($p);
    ($B,undef) = $X[1]->nmf($q);
    ($C,undef) = $X[2]->nmf($r);
  }
  else {
    $A = Algorithms::Matrix->new($m,$p)->random; # * ($m*$p);
    $A = $A->normalize(type=>'length',overwrite=>1);
    $B = Algorithms::Matrix->new($n,$q)->random; # * ($n*$q);
    $B = $B->normalize(type=>'length',overwrite=>1);
    $C = Algorithms::Matrix->new($o,$r)->random; # * ($o*$r);
    $C = $C->normalize(type=>'length',overwrite=>1);
  }
  # Initialize core tensor
  my @G;
  foreach my $i(0..$r-1) {
    $G[$i] = Algorithms::Matrix->new($p,$q)->random; # * ($p*$q);
    $G[$i] = $G[$i]->normalize(type=>'length',overwrite=>1);
  }
  my $G = $class->new(@G);
  $G[0] = $G->unfold(1);
  $G[1] = $G->unfold(2);
  $G[2] = $G->unfold(3);

  my $maxIter = 2500;
  my $iter = 0;
  my $tol = 1e-6;
  my $eps = 2.2204e-016;
  my $diff =  0 + "inf";
  my $sse = 0 + "inf";
  my %norms;
  while ($diff>=$tol*$sse && ++$iter<$maxIter) {
    my $previous_sse = $sse;

    # Update A
    my $S = $C->kron($B);
    $S = $G[0] * ($S->transpose);
    my $St = $S->transpose;
    my $T = ($A * $S * $St) + $eps;
    $A = $A x (($X[0] * $St) x (1/$T));
    my $sq = $A x $A;
    $norms{'A'} = $sq->col_sums->sqrt->diag;
    $A = $A->normalize(type=>'length',overwrite=>1);

    # Update B
    $S = $A->kron($C);
    $S = $G[1] * ($S->transpose);
    $St = $S->transpose;
    $T = ($B * $S * $St) + $eps;
    $B = $B x (($X[1] * $St) x (1/$T));
    $sq = $B x $B;
    $norms{'B'} = $sq->col_sums->sqrt->diag;
    $B = $B->normalize(type=>'length',overwrite=>1);

    # Update C
    $S = $B->kron($A);
    $S = $G[2] * ($S->transpose);
    $St = $S->transpose;
    $T = ($C * $S * $St) + $eps;
    $C = $C x (($X[2] * $St) x (1/$T));
    $sq = $C x $C;
    $norms{'C'} = $sq->col_sums->sqrt->diag;
    $C = $C->normalize(type=>'length',overwrite=>1);

    # Update G
    my $g = $self->multiply_with_matrix(1,$A->transpose);
    $g = $g->multiply_with_matrix(2,$B->transpose);
    $g = $g->multiply_with_matrix(3,$C->transpose);
    my $d = $A->transpose * $A;
    $d = $G->multiply_with_matrix(1,$d);
    $d = $d->multiply_with_matrix(2,$B->transpose * $B);
    $d = $d->multiply_with_matrix(3,$C->transpose * $C);
    $d = $d + $eps;
    $d = 1 / $d;
    $g = $g x $d;
    $G = $G x $g;

    # Compute fit
    my $Xapp = $G->multiply_with_matrix(1,$A);
    $Xapp = $Xapp->multiply_with_matrix(2,$B);
    $Xapp = $Xapp->multiply_with_matrix(3,$C);
    my $F = $self - $Xapp;
    $sse = $F->frobenius_norm;
    $sse = $sse * $sse;
    $diff = CORE::abs($previous_sse - $sse);
  }

  return ($G, $A, $B, $C);
}

=head2 max

 Arg: int, mode
 Description: Extracts the maximum values along the given mode.
 Returntype: Algorithms::Matrix

=cut

sub max {
  my ($self,$mode) = @_;
  if (!$mode || $mode<1 || $mode>3) {
    croak "\nERROR: mode required and must be between 1 and 3.\n";
  }
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my ($m,$n,$o) = $self->dims;
  my $max;
  if ($mode == 3) {
    $max = Algorithms::Matrix->new($m,$n);
    foreach my $i(0..$m-1) {
      my $slice = $self->get_slice(0,$i);
      my $row = $slice->col_max;
      $max = $max->set_rows([$i],$row);
    }
  }
  elsif ($mode == 2) {
    $max = Algorithms::Matrix->new($o,$m);
    foreach my $i(0..$o-1) {
      my $slice = $self->get_slice(2,$i);
      my $row = $slice->transpose->col_max;
      $max = $max->set_rows([$i],$row);
    }
    $max = $max->transpose;
  }
  elsif ($mode == 1) {
    $max = Algorithms::Matrix->new($o,$n);
    foreach my $i(0..$o-1) {
      my $slice = $self->get_slice(2,$i);
      my $row = $slice->col_max;
      $max = $max->set_rows([$i],$row);
    }
  }
  return $max;
}

=head2 min

 Arg: int, mode
 Description: Extracts the minimum values along the given mode.
 Returntype: Algorithms::Matrix

=cut

sub min {
  my ($self,$mode) = @_;
  if (!$mode || $mode<1 || $mode>3) {
    croak "\nERROR: mode required and must be between 1 and 3.\n";
  }
  my $class = ref($self) || $self;
  if (!defined($self->{'data'}->[0])) {
    carp "WARNING: Cube doesn't seem to contain data";
  }
  my ($m,$n,$o) = $self->dims;
  my $min;
  if ($mode == 3) {
    $min = Algorithms::Matrix->new($m,$n);
    foreach my $i(0..$m-1) {
      my $slice = $self->get_slice(0,$i);
      my $row = $slice->col_min;
      $min = $min->set_rows([$i],$row);
    }
  }
  elsif ($mode == 2) {
    $min = Algorithms::Matrix->new($o,$m);
    foreach my $i(0..$o-1) {
      my $slice = $self->get_slice(2,$i);
      my $row = $slice->transpose->col_min;
      $min = $min->set_rows([$i],$row);
    }
    $min = $min->transpose;
  }
  elsif ($mode == 1) {
    $min = Algorithms::Matrix->new($o,$n);
    foreach my $i(0..$o-1) {
      my $slice = $self->get_slice(2,$i);
      my $row = $slice->col_min;
      $min = $min->set_rows([$i],$row);
    }
  }
  return $min;
}


# --- overload methods -------------------------------------------

use overload
  '""'   =>  \&as_string,
  '+'    =>  \&add,
  '-'    =>  \&subtract,
  'x'    =>  \&multiply_elementwise,
  '/'    =>  \&divide_elementwise,
;

1;
