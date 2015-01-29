# Author: jkh1
# 2009-02-24

=head1 NAME

  Algorithms::Matrix

=head1 SYNOPSIS

 # Create a 100 x 100 matrix of random numbers
 my $M = Algorithms::Matrix->new(100,100)->random;

 # Read a matrix from a tab-delimited file with row and column headers
 my ($M,$row_labels,$col_labels) = Algorithms::Matrix->load_matrix(filename,'\t',1,1);


=head1 DESCRIPTION

 Matrix object and methods to calculate and manipulate matrices of real numbers.
 Eigen and SVD decomposition routines are taken from the JAMA library.


=head1 SEE ALSO

 JAMA: a JAVA matrix package
 http://math.nist.gov/javanumerics/jama/

=head1 CONTACT

 heriche@embl.de


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Jean-Karim Heriche

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.


=cut


package Algorithms::Matrix;

our $VERSION = '0.01';
use 5.006;
use strict;
use Inline ( C =>'DATA',
	     NAME =>'Algorithms::Matrix',
	     DIRECTORY => '',
#	     VERSION => '0.01'
	   );
use Carp;


=head2 new

 Arg1: integer, number of rows
 Arg2: integer, number of columns
 Description: Creates a new Matrix object.
 Returntype: Matrix object

=cut

sub new {

  my ($class,$m,$n) = @_;
  my $self = {};
  bless ($self, $class);
  $self->{'dims'} = [$m,$n];
  $self->{'data'} = allocate_matrix($m,$n);

  return $self;
}

=head2 load_matrix

 Arg1: string, file name
 Arg2: (optional) string, data separator (default is one or more whitespaces)
 Arg3: (optional) 0 or 1, 1 if first row contains column names (defaut=0)
 Arg4: (optional) 0 or 1, 1 if first column contains row names (defaut=0)
 Description: Reads matrix from file.
 Returntype: list of Matrix object and references to row labels and column labels

=cut

sub load_matrix {

  my ($class,$file,$separator,$colnames,$rownames) = @_;
  $separator ||= '\s+';
  $colnames ||=0;
  $rownames ||=0;
  my $fh;
  my @col_label;
  my @row_label;
  # Find out size of matrix
  my $rows;
  my $cols;
  open $fh,"<",$file or croak "Can't open file $file: $!";
  # Count rows, skipping emtpy lines
  for ($rows=0; <$fh>; $rows++ unless (/^\s*$/)) { }
  close $fh;
  if ($colnames) {
    $rows--;
  }
  open $fh,"<",$file or croak "Can't open file $file: $!";
  my $line = <$fh>;
  close $fh;
  chomp($line);
  @col_label = split(/$separator/,$line);
  $cols = scalar(@col_label);
  if ($rownames) {
    $cols--;
  }
  my $matrix = $class->new($rows,$cols);
  my $i = 0;
  open $fh,"<",$file or croak "Can't open file $file: $!";
  while (<$fh>) {
    next if (/^\s*$/);
    chomp;
    if ($colnames) {
      @col_label = split(/$separator/);
      # first column label is empty if there are row labels
      shift @col_label if ($rownames);
      $colnames = 0;
      next;
    }
    my @row = split /$separator/;
    if ($rownames) {
      push @row_label,shift @row;
    }
    foreach my $j(0..$#row) {
      $matrix->set($i,$j,$row[$j]);
    }
    $i++;
  }
  close $fh;

  return ($matrix,\@row_label,\@col_label);
}

=head2 set

 Arg1: integer, row index i
 Arg2: integer, column index j
 Arg3: double, value of matrix element i,j
 Description: Sets value of matrix element i,j
 Returntype: double, value of matrix element i,j

=cut

sub set {

  my ($self,$i,$j,$v) = @_;
  my ($m,$n) = $self->dims;
  $i = $i % $m;    # make sure 0 <= i <= (rows-1)
  $j = $j % $n;
  return set_element($self->{'data'},$i,$j,$v);
}

=head2 get

 Arg1: integer, row index i
 Arg2: integer, column index j
 Description: Gets value of matrix element i,j
 Returntype: double

=cut

sub get {

  my ($self,$i,$j) = @_;
  my ($m,$n) = $self->dims;
  $i = $i % $m;    # make sure 0 <= i <= (rows-1)
  $j = $j % $n;
  return get_element($self->{'data'},$i,$j);
}

=head2 row

 Arg1: integer, row index i
 Description: Gets a row of a matrix
 Returntype: Matrix

=cut

sub row {

  my ($self,$i) = @_;
  my $class = ref($self) || $self;
  my ($m,$j) = $self->dims;
  $i = $i % $m;
  my $row = Algorithms::Matrix->new(1,$j);
  get_row($self->{'data'},$i,$row->{'data'});
  if ($class ne 'Algorithms::Matrix') {
    bless($row,$class);
  }
  return $row;
}

=head2 col

 Arg1: integer, column index j
 Description: Gets a column of a matrix
 Returntype: Matrix

=cut

sub col {

  my ($self,$j) = @_;
  my $class = ref($self) || $self;
  my ($i,$n) = $self->dims;
  $j = $j % $n;
  my $col = Algorithms::Matrix->new($i,1);
  get_col($self->{'data'},$j,$col->{'data'});
  if ($class ne 'Algorithms::Matrix') {
    bless($col,$class);
  }
  return $col;
}

=head2 rows

 Arg1: arrayref to a list of row indices
 Description: Forms a new matrix from the rows whose indices
              are given in the arrayref.
 Returntype: Matrix

=cut

sub rows {

  my ($self,$listref) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $m = scalar(@{$listref});
  my $M = Algorithms::Matrix->new($m,$j);
  get_rows($self->{'data'},$listref,$m,$M->{'data'});
  if ($class ne 'Algorithms::Matrix') {
    bless($M,$class);
  }
  return $M;
}

=head2 set_rows

 Arg1: arrayref to a list of row indices
 Arg2: Matrix
 Description: Replaces rows whose indices are given in Arg1 by
              those given in Arg2.
 Returntype: Matrix

=cut

sub set_rows {

  my ($self,$listref,$B) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my ($k,$l) = $B->dims;
  if ($j != $l) {
    die "\nERROR: rows do not have the same number of columns";
  }
  my $m = scalar(@{$listref});
  replace_rows($self->{'data'},$listref,$m,$B->{'data'});

  return $self;
}

=head2 cols

 Arg1: arrayref to a list of column indices
 Description: Forms a new matrix from the columns whose indices
              are given in the arrayref.
 Returntype: Matrix

=cut

sub cols {

  my ($self,$listref) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $n = scalar(@{$listref});
  my $M = Algorithms::Matrix->new($i,$n);
  get_cols($self->{'data'},$listref,$n,$M->{'data'});
  if ($class ne 'Algorithms::Matrix') {
    bless($M,$class);
  }
  return $M;
}

=head2 set_cols

 Arg1: arrayref to a list of column indices
 Arg2: Matrix
 Description: Replaces columns whose indices are given in Arg1 by
              columns of matrix given in Arg2.
 Returntype: Matrix

=cut

sub set_cols {

  my ($self,$listref,$B) = @_;
  my ($i,$j) = $self->dims;
  my ($k,$l) = $B->dims;
  if ($i != $k) {
    die "\nERROR: columns do not have the same number of rows";
  }
  my $n = scalar(@{$listref});
  replace_cols($self->{'data'},$listref,$n,$B->{'data'});

  return $self;
}

=head2 extract

 Arg1: arrayref to a list of row indices
 Arg2: arrayref to a list of column indices
 Description: Forms a new matrix from the rows and columns whose indices
              are given in the arrayrefs.
 Returntype: Matrix

=cut

sub extract {

  my ($self,$I,$J) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $m = scalar(@{$I});
  my $n = scalar(@{$J});
  my $M1 = Algorithms::Matrix->new($m,$j);
  get_rows($self->{'data'},$I,$m,$M1->{'data'});
  my $M = Algorithms::Matrix->new($m,$n);
  get_cols($M1->{'data'},$J,$n,$M->{'data'});
  if ($class ne 'Algorithms::Matrix') {
    bless($M,$class);
  }
  return $M;
}

=head2 dims

 Description: Gets dimensions of matrix
 Returntype: list (rows,cols)

=cut

sub dims {

  my ($self) = @_;

  return @{$self->{'dims'}};
}

=head2 diag

 Arg1: (optional) number of rows
 Arg2: (optional) number of columns
 Description: Gets diagonal of matrix as column vector or makes diagonal matrix
              of given dimensions from a 1-row or 1-column matrix.
              If no dimensions are given, the returned matrix is square.
 Returntype: Matrix

=cut

sub diag {

  my $self = shift;
  my ($m,$n) = @_;
  my ($i,$j) = $self->dims;
  my $diag;
  if ($i == 1 || $j == 1) {
    if ($m && $n && $m>1 && $n>1) {
      $diag = Algorithms::Matrix->new($m,$n);
    }
    else {
      my $k = $i > $j ? $i : $j;
      $diag = Algorithms::Matrix->new($k,$k);
    }
    make_diag($self->{'data'},$diag->{'data'});
  }
  else {
    my $k = $i > $j ? $j : $i;
    $diag = Algorithms::Matrix->new($k,1);
    get_diag($self->{'data'},$diag->{'data'});
  }
  return $diag;
}

=head2 zero

 Description: Sets all entries of the matrix to 0
 Returntype: Matrix

=cut

sub zero {

  my $self = shift;
  zero_matrix($self->{'data'});
  return $self;
}

=head2 one

 Description: Sets all entries of the matrix to 1
 Returntype: Matrix

=cut

sub one {

  my $self = shift;
  one_matrix($self->{'data'});
  return $self;
}

=head2 identity

 Description: Sets entries on the diagonal to 1, 0 elsewhere
 Returntype: Matrix

=cut

sub identity {

  my $self = shift;
  identity_matrix($self->{'data'});
  return $self;
}

=head2 random

 Arg: (optional) double, upper limit
 Description: Sets entries to randomly distributed numbers between 0 and value
             given as argument or 1 by default.
 Returntype: Matrix

=cut

sub random {

  my $self = shift;
  my $max = shift if @_;
  $max ||= 1;
  my ($m,$n) = $self->dims;
  foreach my $i(0..$m-1) {
    foreach my $j(0..$n-1) {
      $self->set($i,$j,rand($max));
    }
  }
  return $self;
}

=head2 submatrix

 Arg1: integer, index of the upper left row
 Arg2: integer, index of the upper left column
 Arg3: integer, number of rows of submatrix
 Arg4: integer, number of columns of submatrix
 Description: Gets a submatrix of the matrix. The upper-left element
  of the submatrix is the element (Arg1,Arg2) of the original matrix.
  The submatrix has Arg3 rows and Arg4 columns.
 Returntype: Matrix

=cut

sub submatrix {

  my ($self,$a,$b,$i,$j) = @_;
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  if ($i+$a>$m || $j+$b>$n) {
    croak "\nERROR: submatrix outside original matrix";
  }
  $a = $a % $m;
  $b = $b % $n;
  my $subm = $class->new($i,$j);
  get_submatrix($self->{'data'},$a,$b,$i,$j,$subm->{'data'});

  return $subm;
}

=head2 delete_row

 Arg: integer, index of the row to delete
 Description: Deletes given row from the matrix.
 Returntype: Matrix

=cut

sub delete_row {

  my ($self,$i) = @_;
  my ($m,$n) = $self->dims;
  $i = $i % $m;
  del_row($self->{'data'},$i);
  $self->{'dims'} = [$m-1,$n];

  return $self;
}

=head2 delete_rows

 Arg1: integer, index i of the first row to delete
 Arg2: integer, index j of the last row to delete (j>i)
 Description: Deletes rows i to j from the matrix. j must be greater than i.
 Returntype: Matrix

=cut

sub delete_rows {

  my ($self,$i,$j) = @_;
  my ($m,$n) = $self->dims;
  if ($j<=$i) {
    croak "\nERROR: first index must be lower than second index";
  }
  if ($j>$m-1) {
    croak "\nERROR: can not remove rows beyond end of matrix";
  }
  del_rows($self->{'data'},$i,$j);
  $self->{'dims'} = [$m-($j-$i+1),$n];

  return $self;
}

=head2 delete_col

 Arg: integer, index of the column to delete
 Description: Deletes given column from the matrix.
 Returntype: Matrix

=cut

sub delete_col {

  my ($self,$j) = @_;
  my ($m,$n) = $self->dims;
  $j = $j % $n;
  del_col($self->{'data'},$j);
  $self->{'dims'} = [$m,$n-1];
  return $self;
}

=head2 delete_cols

 Arg1: integer, index i of the first column to delete
 Arg2: integer, index j of the last colum to delete (j>i)
 Description: Deletes columns i to j from the matrix. j must be greater than i.
 Returntype: Matrix

=cut

sub delete_cols {

  my ($self,$i,$j) = @_;
  my ($m,$n) = $self->dims;
  if ($j<=$i) {
    croak "\nERROR: first index must be lower than second index";
  }
  if ($j>$n-1) {
    croak "\nERROR: can not remove columns beyond end of matrix";
  }
  del_cols($self->{'data'},$i,$j);
  $self->{'dims'} = [$m,$n-($j-$i+1)];

  return $self;
}

=head2 add

 Arg1: Matrix
 Description: Gets sum of 2 matrices
 Returntype: Matrix

=cut

sub add {

  my ($self,$matrix) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $sum = $class->new($i,$j);
  if (ref($matrix) && $matrix->isa("Algorithms::Matrix")) {
    add_matrices($self->{'data'},$matrix->{'data'},$i,$j,$sum->{'data'});
  }
  else {
    add_scalar($self->{'data'},$matrix,$i,$j,$sum->{'data'});
  }
  return $sum;
}

=head2 subtract_matrix

 Arg1: Matrix
 Description: Gets difference of 2 matrices
 Returntype: Matrix

=cut

sub subtract_matrix {

  my ($self,$matrix,$reverse) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $diff = $class->new($i,$j);
  if (ref($matrix) && $matrix->isa("Algorithms::Matrix")) {
    subtract_matrices($self->{'data'},$matrix->{'data'},$i,$j,$diff->{'data'});
  }
  elsif ($reverse) {
    subtract_from_scalar($self->{'data'},$matrix,$i,$j,$diff->{'data'});
  }
  else {
    add_scalar($self->{'data'},-$matrix,$i,$j,$diff->{'data'});
  }
  return $diff;
}

=head2 multiply

 Arg: Matrix or double
 Description: Carries out ordinary multiplication of 2 matrices
              If Arg is a number (or a 1x1 matrix), does scalar multiplication
              by Arg
 Returntype: Matrix

=cut

sub multiply {

  my ($self,$matrix) = @_;
  my $class = ref($self) || $self;
  my $result;
  my ($i,$j) = $self->dims;
  if (defined($matrix) && ref($matrix) && $matrix->isa('Algorithms::Matrix')) {
    my ($k,$l) = $matrix->dims;
    if ($k == 1 && $l == 1) { # 1x1 matrix -> scalar multiplication
      my $x = $matrix->get(0,0);
      $result = $class->new($i,$j);
      multiply_scalar($self->{'data'},$x,$result->{'data'});
    }
    elsif ($i == 1 && $j == 1) { # 1x1 matrix -> scalar multiplication
      my $x = $self->get(0,0);
      $result = $class->new($k,$l);
      multiply_scalar($matrix->{'data'},$x,$result->{'data'});
    }
    else {
      if ($j <=> $k) {
	croak "ERROR: Can't multiply: number of columns of A ($j) different from number of rows of B ($k)";
      }
      $result = $class->new($i,$l);
      multiply_matrices($self->{'data'},$matrix->{'data'},$i,$j,$l,$result->{'data'});
    }
  }
  elsif (defined($matrix) && !ref($matrix)) {
    $result = $class->new($i,$j);
    multiply_scalar($self->{'data'},$matrix,$result->{'data'});
  }

  return $result;
}

=head2 divide

 Arg: Matrix or double
 Description: Applies division to all elements of the matrix
 Returntype: Matrix

=cut

sub divide {

  my ($self,$scalar,$reverse) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $div = $class->new($i,$j);
  if (ref($scalar) && $scalar->isa("Algorithms::Matrix")) {
    croak "\nERROR: Division requires at least one scalar value.";
  }
  elsif ($reverse) {
    divide_scalar($self->{'data'},$scalar,$i,$j,$div->{'data'});
  }
  else {
    if ($scalar == 0) {
      croak "\nERROR: Can't divide by 0";
    }
    divide_by_scalar($self->{'data'},$scalar,$i,$j,$div->{'data'});
  }
  return $div;
}

=head2 abs

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Sets each entry of matrix to its absolute value.
 Returntype: Matrix

=cut

sub abs {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    abs_matrix($self->{'data'});
    return $self;
  }
  else {
    my $abs = $self->clone;
    abs_matrix($abs->{'data'});
    return $abs;
  }
}

=head2 exp

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Exponentiates each entry of matrix.
 Returntype: Matrix

=cut

sub exp {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    exp_matrix($self->{'data'});
    return $self;
  }
  else {
    my $exp = $self->clone;
    exp_matrix($exp->{'data'});
    return $exp;
  }
}

=head2 log

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Takes the natural logarithm of each entry of matrix.
 Returntype: Matrix

=cut

sub log {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    log_matrix($self->{'data'});
    return $self;
  }
  else {
    my $log = $self->clone;
    log_matrix($log->{'data'});
    return $log;
  }
}

=head2 sqrt

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Gets square root of each entry of matrix.
 Returntype: Matrix

=cut

sub sqrt {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    sqrt_matrix($self->{'data'});
    return $self;
  }
  else {
    my $sqrt = $self->clone;
    sqrt_matrix($sqrt->{'data'});
    return $sqrt;
  }
}

=head2 pow

 Arg1: double, exponent
 Arg2: (optional), set overwrite=>1 to reuse original matrix
 Description: Raises each entry of matrix to the given exponent power.
 Returntype: Matrix

=cut

sub pow {

  my $self = shift;
  my $exp = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    pow_matrix($self->{'data'},$exp);
    return $self;
  }
  else {
    my $pow = $self->clone;
    pow_matrix($pow->{'data'},$exp);
    return $pow;
  }
}

=head2 sigmoid

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Applies sigmoid function to each entry of matrix.
 Returntype: Matrix

=cut

sub sigmoid {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    sigmoid_matrix($self->{'data'});
    return $self;
  }
  else {
    my $sigmoid = $self->clone;
    sigmoid_matrix($sigmoid->{'data'});
    return $sigmoid;
  }
}

=head2 multiply_elementwise

 Arg: Matrix
 Description: Carries out element-wise multiplication of 2 matrices
 Returntype: Matrix

=cut

sub multiply_elementwise {

  my ($self,$matrix) = @_;
  my $class = ref($self) || $self;
  my $result;
  my ($i,$j) = $self->dims;
  if (defined($matrix) && ref($matrix) && $matrix->isa('Algorithms::Matrix')) {
    my ($k,$l) = $matrix->dims;
    unless ($i == $k && $j == $l) {
      croak "ERROR: Can't multiply element-wise: Matrices must have same dimensions";
      }
      $result = $class->new($i,$j);
      multiply_matrices_elementwise($self->{'data'},$matrix->{'data'},$i,$j,$result->{'data'});
  }
  elsif (defined($matrix) && !ref($matrix)) {
    croak "ERROR: Arg must be a Matrix object";
  }

  return $result;
}

=head2 transpose

 Description: Gets transpose of matrix
 Returntype: Matrix

=cut

sub transpose {

  my ($self) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $transpose = $class->new($j,$i);
  transpose_matrix($self->{'data'},$transpose->{'data'});

  return $transpose;
}

=head2 clone

 Description: Gets a copy of a matrix
 Returntype: Matrix

=cut

sub clone {

  my ($self) = @_;
  my $class = ref($self) || $self;
  my ($i,$j) = $self->dims;
  my $clone = $class->new($i,$j);
  clone_matrix($self->{'data'},$clone->{'data'});
# # Currently not needed
#   foreach my $param(keys %{$self}) {
#     next if ($param eq 'data' || $param eq 'dims');
#     $clone->{$param} = $self->{$param};
#   }

  return $clone;
}

=head2 det

 Description: Calculates determinant of square matrix
 Returntype: double

=cut

sub det {

  my $self = shift;
  my ($m,$n) = $self->dims;
  if ($m != $n) {
    croak "\nERROR: matrix is not square";
  }
  return get_determinant($self->{'data'});
}

=head2 trace

 Description: Calculates trace of square matrix
 Returntype: double

=cut

sub trace {

  my $self = shift;
  my ($m,$n) = $self->dims;
  if ($m != $n) {
    croak "\nERROR: matrix is not square";
  }
  return get_trace($self->{'data'});
}

=head2 spectral_radius

 Description: Calculates spectral radius of a square matrix using power method.
 Returntype: double

=cut

sub spectral_radius {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  if ($n != $m) {
    croak "\nERROR: matrix is not square";
  }
  my $l = 0;
  my $V = $class->new($m,1);
  my $flag = pwm($self->{'data'},$l,$V->{'data'});
  if ($flag == 0) {
    croak "\nERROR: power method can not be applied";
  }
  if ($flag == -1) {
    croak "\nERROR: power method doesn't converge";
  }
  return $l;
}

=head2 norm2

 Description: Calculates 2-norm (or spectral norm) of matrix using SVD
 Returntype: double

=cut

sub norm2 {

  my $self = shift;
  my $S = $self->svd('U'=>0,'V'=>0);
  return $S->get(0,0);
}

=head2 spectral_norm

 Description: Calculates 2-norm (or spectral norm) of matrix using SVD
 Returntype: double

=cut

sub spectral_norm {

  my $self = shift;
  my $S = $self->svd('U'=>0,'V'=>0);
  return $S->get(0,0);
}

=head2 frobenius_norm

 Description: Calculates Frobenius norm of matrix
 Returntype: double

=cut

sub frobenius_norm {

  my $self = shift;
  my $t = $self->transpose * $self;
  my $trace = $t->trace;
  return CORE::sqrt($trace);
}

=head2 is_symmetric

 Description: Determines if matrix is symmetric
 Returntype: 0 or 1

=cut

sub is_symmetric {

  my $self = shift;

  my ($m,$n) = $self->dims;
  if ($n != $m) {
    croak "\nERROR: matrix is not square";
  }
  return is_sym($self->{'data'});
}

=head2 is_SPD

 Description: Tests if the matrix is symmetric positive definite
              (using Cholesky decomposition)
 Returntype: 0 or 1

=cut

sub is_SPD {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($r,$c) = $self->dims;
  my $U = $class->new($r,$c);

  my $isspd = cholesky_decomposition($self->{'data'},$U->{'data'});

  return $isspd;
}

=head2 inverse

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Gets inverse of a square matrix if it exists
 Returntype: Matrix

=cut

sub inverse {

  my ($self) = shift;
  my %param = @_ if (@_);

  my ($i,$j) = $self->dims;
  if ($i != $j) {
    croak "\nERROR: Matrix is not square";
  }
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    my $status = invert_matrix($self->{'data'});
    unless ($status) {
      croak "\nERROR: Matrix is singular";
    }
    return $self;
  }
  else {
    my $inverse = $self->clone;
    my $status = invert_matrix($inverse->{'data'});
    unless ($status) {
      croak "\nERROR: Matrix is singular";
    }
    return $inverse;
  }
}

=head2 power_method

 Description: Extracts eigenvalue with the largest absolute value and
              corresponding eigenvector
 Returntype: list of scalar (eigenvalue) and 1-column Matrix (eigenvector)

=cut

sub power_method {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  if ($n != $m) {
    croak "\nERROR: matrix is not square";
  }
  my $l = 0;
  my $V = $class->new($m,1);
  my $flag = pwm($self->{'data'},$l,$V->{'data'});
  if ($flag == 0) {
    croak "\nERROR: power method can not be applied";
  }
  if ($flag == -1) {
    croak "\nERROR: power method doesn't converge";
  }
  my $norm = $V->norm2;
  $V = $V / $norm;

  return ($l,$V);
}

=head2 eigen

 Arg: (optional) hash, set overwrite=>1 to reuse (overwrite) original matrix
 Description: Calculates eigenvalues and eigenvectors of a square matrix.
              Only the real part of complex eigenvalues is returned.
              In this case, if D is the block diagonal matrix with the real
              eigenvalues in 1x1 blocks, and any complex values u+iv in 2x2
              blocks [u v ; -v u] and V is the matrix of eigenvectors. Then,
              the matrices D and V satisfy A*V = V*D where A is the original
              matrix.
 Returntype: list of Matrix objects: eigenvalues (as 1-column matrix),
             eigenvectors (as matrix of column vectors)

=cut

sub eigen {

  my $self = shift;
  my %param = @_ if (@_);
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  if ($n != $m) {
    croak "\nERROR: matrix is not square";
  }

  my $eigenvectors;
  my $eigenvalues = $class->new($n,1);
  my $symmetric = $self->is_symmetric;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    $eigenvectors = $self;
    if ($symmetric) {
      my $offdiag = $class->new($n,1);
      tred2($eigenvectors->{'data'},$eigenvalues->{'data'},$offdiag->{'data'});
      tql2($eigenvalues->{'data'},$offdiag->{'data'},$eigenvectors->{'data'});
    }
    else {
      my $H = $self->clone;
      my $O = $class->new($n,1);
      my $Im = $class->new($n,1);
      orthes($H->{'data'},$O->{'data'},$eigenvectors->{'data'});
      hqr2($H->{'data'},$O->{'data'},$eigenvectors->{'data'},$eigenvalues->{'data'},$Im->{'data'});
    }
  }
  else {
    $eigenvectors = $self->clone;
    if ($symmetric) {
      my $offdiag = $class->new($n,1);
      tred2($eigenvectors->{'data'},$eigenvalues->{'data'},$offdiag->{'data'});
      tql2($eigenvalues->{'data'},$offdiag->{'data'},$eigenvectors->{'data'});
    }
    else {
      my $H = $self->clone;
      my $O = $class->new($n,1);
      my $Im = $class->new($n,1);
      orthes($H->{'data'},$O->{'data'},$eigenvectors->{'data'});
      hqr2($H->{'data'},$O->{'data'},$eigenvectors->{'data'},$eigenvalues->{'data'},$Im->{'data'});
    }
  }

  return $eigenvalues,$eigenvectors;
}

=head2 solve

 Arg1: Matrix, right hand side of the equation
 Arg2: (optional) hash, set overwrite=>1 to reuse original matrices
 Description: Solves A*X = B
 Returntype: Matrix

=cut

sub solve {

  my $self = shift;
  my $B = shift;
  my $class = ref($self) || $self;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  my ($mb,$nb) = $B->dims;

  if ($mb != $m) {
    croak "\nERROR: Matrix row dimensions must agree";
  }
  my $R = $class->new($n,1);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    QRDecomposition($self->{'data'},$R->{'data'});
    QRSolve($self->{'data'},$R->{'data'},$B->{'data'});
    $B = $B->submatrix(0,0,$n,$nb);
    return $B;
  }
  else {
    my $Q = $self->clone;
    QRDecomposition($Q->{'data'},$R->{'data'});
    my $X = $B->clone;
    QRSolve($Q->{'data'},$R->{'data'},$X->{'data'});
    $X = $X->submatrix(0,0,$n,$nb);
    return $X;
  }
}

=head2 as_array

 Arg: (optional) string, set to 'rag' to only get the lower triangular
      part of the matrix or to 'flat' to flatten the matrix into a simple array.
 Description: Copies content of Matrix object to a Perl array of arrays or,
              if flattened, into an array of concatenated rows.
 Returntype: array

=cut

sub as_array {

  my $self = shift;
  my $arg = shift;
  my @A;
  my($m,$n) = $self->dims;
  if (defined($arg) && $arg eq 'rag') {
    $A[0] = [];
    foreach my $i(1..$m-1) {
      foreach my $j(0..$i-1) {
	$A[$i][$j] = $self->get($i,$j);
      }
    }
  }
  elsif (defined($arg) && $arg eq 'flat') {
    foreach my $i(0..$m-1) {
      foreach my $j(0..$n-1) {
	push @A, $self->get($i,$j);
      }
    }
  }
  else {
    foreach my $i(0..$m-1) {
      foreach my $j(0..$n-1) {
	$A[$i][$j] = $self->get($i,$j);
      }
    }
  }
  return @A;
}

=head2 from_array

 Arg: reference to an array of arrays (2D array)
 Description: Copies content of a Perl array of arrays to a Matrix object.
              Dimensions of array and matrix must match.
 Returntype: Matrix object

=cut

sub from_array {

  my $self = shift;
  my $A = shift;
  if (ref($A) ne 'ARRAY' || !defined($A->[0]) || ref($A->[0]) ne 'ARRAY') {
    croak "\nERROR: Reference to array of array required as argument";
  }
  my ($m,$n) = $self->dims;
  my $ma = scalar(@{$A});
  my $na = scalar(@{$A->[0]});
  if ($ma != $m || $na != $n) {
    croak "\nERROR: Dimensions of array and matrix must match";
  }
  foreach my $i(0..$ma-1) {
    foreach my $j(0..$na-1) {
      $self->set($i,$j,$$A[$i][$j]);
    }
  }
  return $self;

}

=head2 means

 Description: Calculates the mean of each column.
 Returntype: Matrix (with one row)

=cut

sub means {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  my $M = $class->new(1,$n);
  get_means($self->{'data'},$M->{'data'});

  return $M;

}

=head2 variances

 Description: Calculates the variance of each column.
 Returntype: Matrix (with one row)

=cut

sub variances {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  my $V = $class->new(1,$n);
  get_variances($self->{'data'},$V->{'data'});

  return $V;

}

=head2 svd

 Arg: (optional) set U=>0 and V=>0 if not interested in the left and right
              singular vectors, overwrite=>1 to reuse input matrix for computation
 Description: Calculates the singular value decomposition of the matrix.
              For an m-by-n matrix A with m >= n, the singular value
              decomposition is an m-by-n orthogonal matrix U, an n-by-n
              diagonal matrix S, and an n-by-n orthogonal matrix V so that
              A = U*S*V'
 Returntype: list of Matrix objects: U, S, V (depending on Arg) or
             1-column Matrix of singular values if Arg has both U=>0 and V=>0

=cut

sub svd {

  my $self = shift;
  my %param = @_ if (@_>1);
  my $class = ref($self) || $self;
  my $wantU = defined($param{'U'}) && $param{'U'}==0? 0 : 1;
  my $wantV = defined($param{'V'}) && $param{'V'}==0? 0 : 1;

  my ($m,$n) = $self->dims;

  my $min = $m+1<$n ? $m+1 : $n;
  my $nu = $m>$n ? $n : $m;
  my $S = $class->new($min,1);
  my ($U,$V);
  if ($wantU) {
    $U = $class->new($m,$nu);
  }
  else {
    $U = $class->new(1,1);
  }
  if ($wantV) {
    $V = $class->new($n,$n);
  }
  else {
    $V = $class->new(1,1);
  }
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    get_svd($self->{'data'},$U->{'data'},$S->{'data'},$V->{'data'},$wantU,$wantV);
  }
  else {
    my $A = $self->clone;
    get_svd($A->{'data'},$U->{'data'},$S->{'data'},$V->{'data'},$wantU,$wantV);
  }
  if ($wantU && $wantV) {
    $S = $S->diag($nu,$n);
    return($U,$S,$V);
  }
  elsif ($wantU) {
    $S = $S->diag($nu,$n);
    return($U,$S);
  }
  elsif ($wantV) {
    $S = $S->diag($nu,$n);
    return($S,$V);
  }
  else {
    return $S;
  }
}

=head2 nmf

 Arg1: int, number of basis vectors to generate
 Arg2: (optional) Set W => Matrix object and/or H => Matrix object
       to give matrices with which to inititialize W and H.
 Description: Calculates the non-negative matrix factorisation of matrix A
              so that A = W*H using the multiplicative update rule from
              Lee and Seung, Nature. 1999 Oct 21;401(6755):788-91.
 Returntype: list of Matrix objects: (W, H)

=cut

sub nmf {

  my $self = shift;
  my $k = shift;
  my %param = @_ if (@_);
  my $class = ref($self) || $self;

  if (!defined($k)) {
    croak "\nERROR: Number of basis required in nmf";
  }

  my $eps = 2.2204e-016;

  my ($m,$n) = $self->dims;
  my ($W,$H);
  if ($param{'W'}) {
    $W = $param{'W'};
  }
  else {
    $W = $class->new($m,$k)->random * ($m*$k);
  }
  if ($param{'H'}) {
    $H = $param{'H'};
  }
  else {
    $H = $class->new($k,$n)->random * ($n*$k);
  }
  my $error_old = $self->row_sums->col_sum(0);
  foreach my $iter(1..1000) {
    my $a = ($W->transpose * $W) * $H + $eps;
    $H = $H x ($W->transpose * $self)  x ( 1 / $a);
    $a = $H * $self->transpose;
    my $b = $W * ($H * $H->transpose) + $eps;
    $W = ($W  x $a->transpose) x (1 / $b);

    # Check convergence
    if ($iter % 10 == 0) {
      my $diff = $self - $W * $H;
      my $error = $diff->abs->row_sums->col_sum(0) / $self->row_sums->col_sum(0);
      if (CORE::abs($error_old - $error)<1e-5) {
	last;
      }
      $error_old = $error;
    }
  }

  return ($W,$H);

}

=head2 nnls

 Arg: Matrix (B in equation Ax=B)
 Description: Non-negative least squares regression using the
              algorithm by Lawson & Hanson (Lawson and Hanson, "Solving Least
              Squares Problems", Prentice-Hall, 1974) as modified by Bro &
              De Jong, Journal of Chemometrics (1997) 11: 393-401.
              This solves min(||Ax - b||) subject to x>=0. This calls the fnnls
              method that uses A'A and A'b as input. This is faster (than the
              original nnls) when A has more rows than columns.
 Returntype: Matrix

=cut

sub nnls {

  my ($self,$y) = @_;
  my $Xt = $self->transpose;
  my $XtX = $Xt * $self;
  my $Xty = $Xt * $y;

  return $XtX->fnnls($Xty);
}

=head2 fnnls

 Arg: Matrix (A'b with A and b of equation Ax=b)
 Description: Non-negative least squares regression using the
              algorithm by Lawson & Hanson (Lawson and Hanson, "Solving Least
              Squares Problems", Prentice-Hall, 1974) as modified by Bro &
              De Jong, Journal of Chemometrics (1997) 11: 393-401.
              This solves min(||Ax - b||) subject to x>=0 using A'A and A'b
              as input. This is faster (than the original nnls) when A has
              more rows than columns.
              Note that calling matrix should be A'A with A of equation Ax=b.
 Returntype: Matrix

=cut

sub fnnls {

  my ($XtX,$Xty) = @_;
  my $class = ref($XtX) || $XtX;

  my ($m,$n) = $XtX->dims;
  my $eps = 2.2204e-16;
  my $norm1 = $XtX->col_sums->max;
  my $tol = 10 * $eps * $norm1;
  $tol = $m > $n ? $tol * $m : $tol * $n;
  # Use 1-based indices in sets so that we can use 0 as test for false
  my $P = $class->new($n,1)->zero; # Passive set
  my $R = $class->new(1,$n)->from_array([[1..$n]]); # Active set
  $R = $R->transpose;
  my $x = $class->new($n,1)->zero;
  my $RR = $R;
  my $w = $Xty - $XtX * $x;

  my $iter = 0;
  my $maxIter = 30 * $n;

  my $wmax = $w->max;
  my $z = $class->new($n,1)->zero;
  while ($R->count_non_zero_elements && $w->max > $tol) {
    # Find maximum coefficient w in active set
    my ($max,$t);
    foreach my $i(0..$n-1) {
      my $k = $RR->get($i,0);
      next unless $k;
      my $wk = $w->get($k-1,0); # R contains 1-based indices
      if (!defined($max) || $wk>$max) {
	$max = $wk;
	$wmax = $wk;
	$t = $k;
      }
    }
    # Include t in $P and remove it from $R
    $P->set($t-1,0,$t);
    $R->set($t-1,0,0);
    my $zp;
    my $idxP = $P->find_non_zero_elements(0);
    my $idxR = $R->find_non_zero_elements(0);
    if ($idxP) {
      my @idxP = $idxP->as_array('flat');
      my $Xtyp = $Xty->transpose->cols(\@idxP)->transpose;
      my $XtXp = $XtX->extract(\@idxP,\@idxP);
      $zp = $XtXp->solve($Xtyp); # $m rows, 1 column
      $z->set_rows(\@idxP,$zp);
    }
    if ($idxR) {
      my @idxR = $idxR->as_array('flat');
      my $l = scalar(@idxR);
      my $tmp = Algorithms::Matrix->new($l,1)->zero;
      $z->set_rows(\@idxR,$tmp);
    }
    # Inner loop to remove eventual negative coefficients
    while ($zp->min <= $tol && $iter < $maxIter) {
      $iter++;
      my $tmp = Algorithms::Matrix->new($n,1)->one;
      foreach my $i(0..$n-1) {
	if ($z->get($i,0) <= $tol && $P->get($i,0) != 0) {
	  $tmp->set($i,0,0);
	}
      }
      my $qq = $tmp->find_zeros(0);
      if ($qq) {
	my @QQ = $qq->as_array('flat');
	my $xQ = $x->rows(\@QQ);
	my $zQ = $z->rows(\@QQ);
	my $A = $xQ - $zQ;
	$A = 1 / $A;
	$A = $xQ x $A;
	my $alpha = $A->min;
	$x = $x + $alpha * ($z - $x);
	# Update $P and $R
	my $tmp = Algorithms::Matrix->new($n,1)->one;
	foreach my $i(0..$n-1) {
	  if (CORE::abs($x->get($i,0)) < $tol && $P->get($i,0) != 0) {
	    $tmp->set($i,0,0);
	  }
	}
	my $ij = $tmp->find_zeros(0);
	if ($ij) {
	  my @ij = $ij->as_array('flat');
	  $ij = $ij->transpose + 1;
	  $R->set_rows(\@ij,$ij);
	  my $zeros = Algorithms::Matrix->new(scalar(@ij),1)->zero;
	  $P->set_rows(\@ij,$zeros);
	}
	my $idxP= $P->find_non_zero_elements(0);
	if ($idxP) {
	  my @idxP = $idxP->as_array('flat');
	  my $Xtyp = $Xty->transpose->cols(\@idxP)->transpose;
	  my $XtXp = $XtX->extract(\@idxP,\@idxP);
	  my $zp = $XtXp->solve($Xtyp); # $m rows, 1 column
	  $z->set_rows(\@idxP,$zp);
	}
	my $idxR = $R->find_non_zero_elements(0);
	if ($idxR) {
	  my @idxR = $idxR->as_array('flat');
	  my $l = scalar(@idxR);
	  my $zero = Algorithms::Matrix->new($l,1)->zero;
	  $z->set_rows(\@idxR,$zero);
	}
      }
      else {
	last;
      }
    }
    $x = $z->clone;
    $w = $Xty - $XtX * $x;
  } # End main loop

  return $x;
}

=head2 rank

 Description: Calculates the rank of the matrix (as number of non-negligible
              singular values).
 Returntype: integer

=cut

sub rank {

  my $self = shift;
  my $rank = 0;
  my $S = $self->svd('U'=>0,'V'=>0);
  my ($m,$n) = $S->dims;
  my $tol = $m>$n ? $m : $n;
  $tol = $tol * ($S->get(0,0)) * 2**-52;
  foreach my $i(0..$m-1) {
    $rank++ if ($S->get($i,0)>$tol);
  }
  return $rank;

}

=head2 pseudoinverse

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Gets Moore-Penrose pseudoinverse of a matrix using svd.
 Returntype: Matrix

=cut

sub pseudoinverse {

  my $self = shift;
  my %param = @_ if (@_);

  if (!defined($param{'overwrite'})) {
    $param{'overwrite'} = 0;
  }

  my ($M,$N) = $self->dims;

  my ($U,$S,$V) = $self->svd($param{'overwrite'});
  my $rank = 0;
  my ($m,$n) = $S->dims;

  my $tol = $m>$n ? $m : $n;
  $tol = $tol * ($S->get(0,0)) * 2**-52;
  foreach my $i(0..$m-1) {
    foreach my $j(0..$n-1) {
      my $s = $S->get($i,$j);
      if ($s>$tol) {
	$S->set($i,$j,1/$s);
      }
      else {
	$S->set($i,$j,0);
      }
    }
  }

  return $V * $S->transpose * $U->transpose;

}

=head2 max

 Description: Gets the entry with highest value
 Returntype: double

=cut

sub max {

  my $self = shift;
  return get_max($self->{'data'});

}

=head2 min

 Description: Gets the entry with lowest value
 Returntype: double

=cut

sub min {

  my $self = shift;
  return get_min($self->{'data'});

}

=head2 row_sum

 Arg: integer, row index i
 Description: Gets the sum of the values in the given row
 Returntype: double

=cut

sub row_sum {

  my $self = shift;
  my $i = shift;
  my ($m,$j) = $self->dims;
  $i = $i % $m;
  return get_row_sum($self->{'data'},$i);

}

=head2 row_sums

 Description: Gets the sum of each row
 Returntype: Matrix (with one column)

=cut

sub row_sums {

  my $self = shift;
  my ($m,$n) = $self->dims;
  my $S = Algorithms::Matrix->new($m,1);

  get_row_sums($self->{'data'},$S->{'data'});

  return $S;

}

=head2 col_sum

 Arg: integer, column index j
 Description: Gets the sum of the values in the given column
 Returntype: double

=cut

sub col_sum {

  my $self = shift;
  my $j = shift;
  my ($i,$n) = $self->dims;
  $j = $j % $n;
  return get_col_sum($self->{'data'},$j);

}

=head2 col_sums

 Description: Gets the sum of each column
 Returntype: Matrix (with one row)

=cut

sub col_sums {

  my $self = shift;
  my ($m,$n) = $self->dims;
  my $S = Algorithms::Matrix->new(1,$n);

  get_col_sums($self->{'data'},$S->{'data'});

  return $S;

}

=head2 standardize

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Standardizes data column-wise (i.e. such that means are 0
              and standard deviations are 1).
 Returntype: Matrix

=cut

sub standardize {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    standardize_matrix($self->{'data'});
    return $self;
  }
  else {
    my $M = $self->clone;
    standardize_matrix($M->{'data'});
    return $M;
  }
}

=head2 normalize

 Arg1: (optional), set overwrite => 1 to reuse original matrix
 Arg2: (optional), set type => 'sum' (default) or 'length' to specify the
       type of normalization
 Description: Normalizes data column-wise such that the sum of
              each column is 1 if type=>sum (default) or the magnitude
              of each column vector is 1 if type=>length.
 Returntype: Matrix

=cut

sub normalize {

  my $self = shift;
  my %param = @_ if (@_);
  my $flag = 0;
  if ($param{'type'} && $param{'type'} eq 'length') {
    $flag = 1;
  }
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    normalize_matrix($self->{'data'},$flag);
    return $self;
  }
  else {
    my $M = $self->clone;
    normalize_matrix($M->{'data'},$flag);
    return $M;
  }
}

=head2 sym_normalize

 Arg: (optional), set overwrite=>1 to reuse original matrix
 Description: Normalizes data by Aij = Aij/sqrt(Aii*Ajj).
 Returntype: Matrix

=cut

sub sym_normalize {

  my $self = shift;
  my %param = @_ if (@_);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    sym_normalize_matrix($self->{'data'});
    return $self;
  }
  else {
    my $M = $self->clone;
    sym_normalize_matrix($M->{'data'});
    return $M;
  }
}

=head2 bistochastic

 Arg:(optional), set overwrite=>1 to reuse original matrix
 Description: Gets the doubly stochastic matrix that best approximate
              a square matrix in terms of Frobenius norm error (as in:
               Zass, R. and Shashua, A. Neural Information Processing Systems
              (NIPS), Dec. 2006).
 Returntype: Matrix

=cut

sub bistochastic {

  my $self = shift;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  croak "\nERROR: method requires square matrix: n= $n and m= $m" if ($n <=> $m);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    bistochastic_matrix($self->{'data'});
    return $self;
  }
  else {
    my $M = $self->clone;
    bistochastic_matrix($M->{'data'});
    return $M;
  }
}

=head2 sort_rows

 Arg: (optional) integer or 1-column Matrix object
 Description: Sorts given column in descending order and sort rows of the
              matrix accordingly.
              if Arg is integer, it is the index of the matrix column to
              sort on.
 Returntype: Matrix

=cut

sub sort_rows {

  my $self = shift;
  my $col = shift;
  my ($m,$n) = $self->dims;
  if (defined($col) && ref($col) && $col->isa('Algorithms::Matrix')) {
    my ($a,$b) = $col->dims;
    if ($a != $m) {
      croak "\nERROR: Column to sort on has to have same number of rows as matrix";
    }
    sort_matrix_rows_on_vector($self->{'data'},$col->{'data'});
  }
  elsif (defined($col) && !ref($col))  {
    $col = $col % $n;
    sort_matrix_rows_on_col($self->{'data'},$col);
  }
  else {
    croak "\nERROR: Argument can only be an integer or a 1-column Matrix object";
  }
  return $self;

}

=head2 sort_cols

 Arg: (optional) integer or 1-row Matrix object
 Description: Sorts given row in descending order and sort columns of the
              matrix accordingly.
              if Arg is integer, it is the index of the matrix row to
              sort on.
 Returntype: Matrix

=cut

sub sort_cols {

  my $self = shift;
  my $row = shift;
  my ($m,$n) = $self->dims;
  if (defined($row) && ref($row) && $row->isa('Algorithms::Matrix')) {
    my ($a,$b) = $row->dims;
    if ($b != $n) {
      croak "\nERROR: Row to sort on has to have same number of columns as matrix";
    }
    sort_matrix_cols_on_vector($self->{'data'},$row->{'data'});
  }
  elsif (defined($row) && !ref($row))  {
    $row = $row % $m;
    sort_matrix_cols_on_row($self->{'data'},$row);
  }
  else {
    croak "\nERROR: Argument can only be an integer or a 1-row Matrix object";
  }
  return $self;

}

=head2 as_string

 Arg1: (optional) string, used to separate entries
 Arg2: (optional) reference to array of column labels
 Arg3: (optional) reference to array of row labels
 Arg4: (optional) set 'corner' => string to fill top left corner
       cell with string
 Description: Converts the matrix to a string.
              By default outputs a tab-delimited table as a string.
 Returntype: string

=cut

sub as_string {

  my $self = shift;
  my $separator = shift || "\t";
  my $colnames = shift if @_;
  my $rownames = shift if @_;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  my $str;
  if ($colnames) {
    if (defined($param{'corner'})) {
      $str = $param{'corner'};
    }
    if ($rownames) {
      $str .= $separator;
    }
    $str .= join($separator,@{$colnames})."\n";
  }
  foreach my $i(0..$m-1) {
    if ($rownames) {
      $str .= $rownames->[$i];
    }
    foreach my $j(0..$n-1) {
      if ($j == 0 && !$rownames) {
      	$str .= $self->get($i,0);
      }
      else {
      	$str .="$separator".$self->get($i,$j);
      }
    }
    $str .="\n";
  }

  return $str;
}

=head2 to_file

 Arg1: string, file name
 Arg2: (optional) reference to array of column labels
 Arg3: (optional) reference to array of row labels
 Arg4: (optional) character to use as separator (default to tab)
 Arg5: (optional) set 'corner' => string to fill top left corner
       cell with string
 Description: Saves a matrix to a flat file (tab-delimited by default)
 Returntype: 1 on success

=cut

sub to_file {

  my ($self,$file,$colnames,$rownames,$separator,%param) = @_;
  $separator ||= "\t";
  my $str = $self->as_string($separator,$colnames,$rownames,%param);
  open FH,">",$file or croak "\nERROR: Can't write file $file: $!";
  print FH $str;
  close FH;

  return 1;
}

=head2 is_equal

 Arg1: Matrix
 Description: tests for equality
 Returntype: 0 or 1

=cut

sub is_equal {

  my ($self,$matrix) = @_;
  my $tolerance = 1e-12;
  my $eq = 0;
  if (ref($matrix) && $matrix->isa("Algorithms::Matrix")) {
    $eq = test_equality_matrices($self->{'data'},$matrix->{'data'},$tolerance);
  }
  else {
    $eq = test_equality_scalar($self->{'data'},$matrix,$tolerance);
  }
  return $eq;

}

=head2 euclidean_distances

 Arg: Matrix
 Description: Calculates Euclidean distances between column vectors
              of 2 matrices (Note: returns d^2 not d)
 Returntype: Matrix

=cut

sub euclidean_distances {

  my ($self,$matrix) = @_;
  my $class = ref($self) || $self;
  my $result;
  my ($ra,$ca) = $self->dims;
  my ($rb,$cb) = $matrix->dims;
  if ($ra != $rb) {
    croak "ERROR: Matrices must have same number of rows";
  }
  $result = $class->new($ca,$cb);
  eucl_dist($self->{'data'},$matrix->{'data'},$result->{'data'});

  return $result;
}

=head2 covariance

 Arg:(optional), set overwrite=>1 to reuse original matrix
 Description: Calculates the variance-covariance matrix of the data where each
              row is an observation and each column a variable.
              If overwrite is set to 1, original matrix will be centered.
 Returntype: Matrix

=cut

sub covariance {

  my $self = shift;
  my $class = ref($self) || $self;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  my $cov = $class->new($n,$n)->zero;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
   covar($self->{'data'},$cov->{'data'});
  }
  else {
    my $M = $self->clone;
    covar($M->{'data'},$cov->{'data'});
  }

  return $cov;
}

=head2 correlation

 Arg:(optional), set overwrite=>1 to reuse original matrix
 Description: Calculates the correlation matrix of the data where each
              row is an observation and each column a variable.
              If overwrite is set to 1, original matrix will be standardized
              (column-wise).
 Returntype: Matrix

=cut

sub correlation {

  my $self = shift;
  my $class = ref($self) || $self;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  my $cor = $class->new($n,$n)->zero;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    correl($self->{'data'},$cor->{'data'});
  }
  else {
    my $M = $self->clone;
    correl($M->{'data'},$cor->{'data'});
  }

  return $cor;
}

=head2 get_distances

 Arg1: string, distance measure to use
 Arg2:(optional), set overwrite=>1 to reuse original matrix
 Description: Calculates the selected distance/similarity between rows
              of the matrix.
              Available measures are:
                pearson: Pearson's correlation
                cosine: uncentered Pearson's correlation
                mahalanobis: Mahalanobis distance
                jaccard: extended Jaccard coefficient
                manhattan: city block (or L1) distance
                euclidean: euclidean (or L2) distance (Note: this is d^2 not d)
                kendall: Kendall's tau
 Returntype: Matrix

=cut

sub get_distances {

  my $self = shift;
  my $choice = shift;
  my %param = @_ if (@_);
  my $class = ref($self) || $self;
  my ($m,$n) = $self->dims;
  my $D = $class->new($m,$m)->zero;
  my $M;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    $M = $self;
  }
  else {
    $M = $self->clone;
  }
  if ($choice eq 'pearson') {
    pearson_r($M->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'cosine') {
    uncentered_pearson_r($M->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'mahalanobis') {
    my $S = $self->covariance(overwrite=>0)->inverse;
    mahalanobis($M->{'data'},$S->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'jaccard') {
    ext_jaccard($M->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'manhattan') {
    manhattan($M->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'euclidean') {
    euclidean($M->{'data'},$D->{'data'});
  }
  elsif ($choice eq 'kendall') {
    kendall($M->{'data'},$D->{'data'});
  }
  return $D;
}

=head2 bind

 Arg1: Matrix
 Arg2: (optional), row=>1 for row-wise combination,
                   column=>1 for column-wise combination
 Description: Combines 2 matrices row-wise or column-wise.
 Returntype: Matrix

=cut

sub bind {

  my $self = shift;
  my $B = shift;
  my $class = ref($self) || $self;
  my %param = @_ if (@_);
  my ($ra,$ca) = $self->dims;
  my ($rb,$cb) = $B->dims;
  my $C;
  if ($param{'row'}) {
    if ($ca != $cb) {
      croak "\nERROR: The matrices must have same number of columns";
    }
    $C = $class->new($ra+$rb,$ca);
    rbind($self->{'data'},$B->{'data'},$C->{'data'});
  }
  elsif ($param{'column'}) {
    if ($ra != $rb) {
      croak "\nERROR: The matrices must have same number of rows";
    }
    $C = $class->new($ra,$ca+$cb);
    cbind($self->{'data'},$B->{'data'},$C->{'data'});
  }

  return $C;
}


=head2 cholesky

 Description: Cholesky decomposition. Returns an upper triangular matrix U
              such that A = U'*U.
 Returntype: Matrix

=cut

sub cholesky {

  my $self = shift;
  my $class = ref($self) || $self;
  my ($r,$c) = $self->dims;
  my $U = $class->new($r,$c);
  my $isspd = cholesky_decomposition($self->{'data'},$U->{'data'});

  unless ($isspd) {
    carp "WARNING: Matrix is not symmetric positive definite";
  }

  return $U;

}

=head2 apply

 Arg1: reference to a subroutine
 Arg2:(optional), set overwrite=>1 to reuse original matrix
 Description: Apply subroutine to each element of the matrix. Subroutine must
              take one scalar argument as input and return a scalar.
 Returntype: Matrix

=cut

sub apply {

  my $self = shift;
  my $subroutine = shift;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    &apply_to_matrix($self->{'data'},$subroutine);
    return $self;
  }
  else {
    my $M = $self->clone;
    &apply_to_matrix($M->{'data'},$subroutine);
    return $M;
  }
}

=head2 count_non_zero_elements

 Description: Count the number of entries with non-zero (+/- 1e-12) value
 Returntype: int

=cut

sub count_non_zero_elements {

  my $self = shift;
  return nze($self->{'data'});

}

=head2 find_non_zero_elements

 Arg: integer, column index j
 Description: Find indices of rows of column j with non-zero (+/- 1e-12) value
 Returntype: Matrix (with one row)

=cut

sub find_non_zero_elements {

  my $self = shift;
  my $j = shift;
  my $A = $self->col($j);
  my $n = $A->count_non_zero_elements;
  my $B;
  if ($n>0) {
    my $class = ref($self) || $self;
    $B = $class->new(1,$n)->zero;
    find_nze_in_col($A->{'data'},$B->{'data'});
  }
  return $B;
}

=head2 find_zeros

 Arg: integer, column index j
 Description: Find indices of rows of column j with a value of zero (+/- 1e-12)
 Returntype: Matrix (with one row)

=cut

sub find_zeros {

  my $self = shift;
  my $j = shift;
  my ($m,undef) = $self->dims;
  my $A = $self->col($j);
  my $n = $A->count_non_zero_elements;
  my $B;
  if ($n < $m) {
    my $class = ref($self) || $self;
    $B = $class->new(1,$m-$n)->zero;
    find_zeros_in_col($A->{'data'},$B->{'data'});
  }

  return $B;
}

=head2 kronecker_product

 Arg: Matrix
 Description: Compute the Kronecker product of 2 matrices
 Returntype: Matrix

=cut

sub kronecker_product {

  my ($self,$matrix) = @_;
  my ($m,$n) = $self->dims;
  my ($p,$q) = $matrix->dims;
  my $class = ref($self) || $self;
  my $i = $m * $p;
  my $j = $n *$q;
  my $result = $class->new($i,$j);

  kron_product($self->{'data'},$matrix->{'data'},$result->{'data'});

  return $result;
}

*kron = \&kronecker_product;

=head2 khatri_rao_product

 Arg: Matrix
 Description: Compute the Kathri-Rao product of 2 matrices as a
              column-wise Kronecker product of the matrices
 Returntype: Matrix

=cut

sub khatri_rao_product {

  my ($self,$matrix) = @_;
  my ($m,$n) = $self->dims;
  my ($p,$q) = $matrix->dims;
  if ($n != $q) {
    croak "\nERROR: matrices must have the same number of columns";
  }
  my $class = ref($self) || $self;
  my $i = $m * $p;
  my $result = $class->new($i,$n);

  khatrirao_product($self->{'data'},$matrix->{'data'},$result->{'data'});

  return $result;
}

=head2 quantize

 Arg: integer, number of partitions k
 Description: Quantizes columns of the matrix using the k-means algorithm.
              The returned columns are cluster indicators i.e. each cell
              holds the ID (between 0 and k-1) of the cluster it's been
              assigned to.
 Returntype: Matrix

=cut

sub quantize {

  my ($self,$k) = @_;
  my ($m,$n) = $self->dims;
  my $class = ref($self) ? ref($self): $self;
  my $Q = $class->new($m,$n)->zero;
  my $eps = 1e-12;
  my $maxIter = 100;
  foreach my $j(0..$n-1) {
    my $V = $self->col($j);
    # Initialize
    my $centroids = Algorithms::Matrix->new($k,1);
    my $min = $V->min;
    my $max = $V->max;
    foreach my $c(0..$k-1) {
      my $r = int(rand($k));
      my $cent = $V->get($r,0);
      $centroids->set($c,0,$cent);
    }
    my $done = 0;
    my $iter = 0;
    while (!$done) {
      $iter++;
      $centroids->sort_rows(0); # Order partitions by decreasing means
      my $previous_centroids = $centroids->clone;
      my $tmp_centroids = Algorithms::Matrix->new($k,1)->zero;
      my $counts = Algorithms::Matrix->new($k,1)->zero;
      foreach my $i(0..$m-1) {
	my $min = 1e308;
	# Assign to closest centroid
	foreach my $c(0..$k-1) {
	  my $d = $V->get($i,0) - $centroids->get($c,0);
	  $d = $d * $d;
	  if ($d < $min) {
	    $Q->set($i,$j,$c);
	    $min = $d;
	  }
	}
	# Update temporary centroids and counts
	my $g = $Q->get($i,$j);
	my $v = $tmp_centroids->get($g,0) + $V->get($i,0);
	$tmp_centroids->set($g,0,$v);
	my $count = $counts->get($g,0)+1;
	$counts->set($g,0,$count);
      }
      foreach my $c(0..$k-1) {
	my $n = $counts->get($c,0);
	if ($n) {
	  my $new = $tmp_centroids->get($c,0)/$n;
	  $centroids->set($c,0,$new);
	}
      }
      my $diff = $previous_centroids - $centroids;
      if ($diff->abs->max < $eps || $iter > $maxIter) {
	# Stop if centroids do not change any more or
	# max number of iterations reached
	$done = 1;
      }
    }
  }

  return $Q;
}

=head2 vect

 Description: Turn the matrix into a vector (one column matrix) by stacking
              all columns one after the other.
 Returntype: Matrix object

=cut

sub vect {

  my $self = shift;
  my ($m,$n) = $self->dims;
  my $vec = $self->col(0);
  foreach my $i(1..$n-1) {
    $vec = $vec->bind($self->col($i),row=>1);
  }
  return $vec;
}

=head2 unvect

 Arg: list of 2 integers (matrix dimensions)
 Description: Turn a vector (one column matrix) into a matrix
              of given dimensions i.e reverses the vect operation.
 Returntype: Matrix object

=cut

sub unvect {

  my ($self,@dims) = @_;
  my ($mv,$nv) = $self->dims;
  if ($nv != 1 ) {
    croak "\nERROR: Vector required as single column matrix in unvect";
  }

  my ($m,$n) = @dims;
  my $M = Algorithms::Matrix->new($m,$n);
  foreach my $j(0..$n-1) {
    my $col = $self->submatrix($j*$m,0,$m,1);
    $M->set_cols([$j],$col);
  }

  return $M;
}

=head2 flip

 Arg1: v=>1 or h=>1
 Arg2: (optional) set overwrite=>1 to reuse original matrix
 Description: Flips the matrix about the specified axis, i.e.
              Setting h=>1 flips the rows in the vertical direction
              about a horizontal axis. Conversely, setting v=>1 flips
              the columns in the horizontal direction about a vertical axis.
 Returntype: Matrix object

=cut

sub flip {

  my $self = shift;
  my %param = @_ if (@_);
  if (!$param{'v'} && !$param{'h'}) {
    croak "\nERROR: need to specify axis to flip about";
  }
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    if (defined($param{'v'}) && ($param{'v'} == 1 || $param{'v'}=~/true|t/i)) {
      flipv($self->{'data'});
    }
    else {
      fliph($self->{'data'});
    }
    return $self;
  }
  else {
    my $class = ref($self) ? ref($self): $self;
    my ($m,$n) = $self->dims;
    my $flipped = $self->clone;
    if (defined($param{'v'}) && ($param{'v'} == 1 || $param{'v'}=~/true|t/i)) {
      flipv($flipped->{'data'});
    }
    else {
      fliph($flipped->{'data'});
    }
    return $flipped;
  }
}

sub DESTROY {

  my $self = shift;
  free_matrix($self->{'data'},$self->{'dims'}->[0],$self->{'dims'}->[1]);
}

# --- overload methods -------------------------------------------

use overload
  '+'    =>  \&add,
  '*'    =>  \&multiply,
  '-'    =>  \&subtract_matrix,
  '/'    =>  \&divide,
  'x'    =>  \&multiply_elementwise,
  '""'   =>  \&as_string,
  '=='   =>  \&is_equal,
;


1;

__DATA__
__C__


typedef struct {
  double **data;
  int rows;
  int cols;
} Matrix;


SV* allocate_matrix(int ni, int nj) {

  Matrix* matrix = malloc(sizeof(Matrix));
  int i;
  double **mat;

  matrix->rows = ni;
  matrix->cols = nj;

  /* Allocate pointers to rows. */
  mat = (double **) malloc((unsigned long) (ni)*sizeof(double*));
  if (!mat) {
    croak("Memory allocation failure 1 in allocate_matrix()");
  }

  /* Allocate rows and set pointers to them. */
  for (i = 0; i < ni; i++) {
    mat[i] = (double *) malloc((unsigned long) (nj)*sizeof(double));
    if (!mat[i]) {
      croak("Memory allocation failure 2 in allocate_matrix()");
    }
  }

  matrix->data = mat;

  SV* data = newSViv(0);
  sv_setiv( data, (IV)matrix);
  SvREADONLY_on(data);

  return data;
}

void free_matrix(SV *data,int ni,int nj) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat;
  mat = M->data;
  int i,j;
  for (i = 0; i < ni; i++) {
    free(mat[i]);
  }
  free(M->data);
  free(M);
}

double **deref_matrix(SV* data) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  return mat;
}

double set_element(SV* data, int i, int j, double value){

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  mat[i][j] = value;
  return value;
}

double get_element(SV* data, int i, int j) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  return mat[i][j];
}

void get_row(SV *data, int i, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int c = M->cols;
  double **matR = deref_matrix(result);
  int j;
  for (j = 0; j < c; j++) {
    matR[0][j] = mat[i][j];
  }
}

void get_rows(SV *data, SV *indices, int n, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int c = M->cols;
  double **matR = deref_matrix(result);
  AV *idx;
  idx = (AV*)SvRV(indices);
  int i,j,k;
  for (i = 0; i < n; i++) {
    k = SvNV(*av_fetch(idx,i,0));
    for (j = 0; j < c; j++) {
      matR[i][j] = mat[k][j];
    }
  }
}

void replace_rows(SV *data, SV *indices, int n, SV *newrows) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int c = M->cols;
  double **matR = deref_matrix(newrows);
  AV *idx;
  idx = (AV*)SvRV(indices);
  int i,j,k;
  for (i = 0; i < n; i++) {
    k = SvNV(*av_fetch(idx,i,0));
    for (j = 0; j < c; j++) {
      mat[k][j] =  matR[i][j];
    }
  }
}

void get_col(SV *data, int j, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  double **matR = deref_matrix(result);
  int i;
  for (i = 0; i < r; i++) {
    matR[i][0] = mat[i][j];
  }
}

void get_cols(SV *data, SV *indices, int n, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  double **matR = deref_matrix(result);
  AV *idx;
  idx = (AV*)SvRV(indices);
  int i,j,k;
  for (j = 0; j < n; j++) {
    k = SvNV(*av_fetch(idx,j,0));
    for (i = 0; i < r; i++) {
      matR[i][j] = mat[i][k];
    }
  }
}

void replace_cols(SV *data, SV *indices, int n, SV *newcols) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  double **matR = deref_matrix(newcols);
  AV *idx;
  idx = (AV*)SvRV(indices);
  int i,j,k;
  for (j = 0; j < n; j++) {
    k = SvNV(*av_fetch(idx,j,0));
    for (i = 0; i < r; i++) {
       mat[i][k] = matR[i][j];
    }
  }
}

void get_diag(SV *data, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int k = c > r ? r : c;
  double **matR = deref_matrix(result);
  int i;
  for (i = 0; i < k; i++) {
    matR[i][0] = mat[i][i];
  }
}

void make_diag(SV *data, SV *result) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  Matrix* R = (Matrix*)SvIV(result);
  double **matR = R->data;
  int r = M->rows;
  int c = M->cols;
  int k = R->rows;
  int l = R->cols;
  int i,j;
  for (i = 0; i < k; i++) {
    for (j = 0; j < l; j++) {
      if (i != j) {
	matR[i][j] = 0.0;
      }
      else {
	if (r == 1) {
	  matR[i][i] = mat[0][i];
	}
	else {
	  matR[i][i] = mat[i][0];
	}
      }
    }
  }
}

void get_submatrix(SV *data, int a, int b, int i, int j, SV *result) {

  double **mat = deref_matrix(data);
  double **matR = deref_matrix(result);
  int k,l;
  for (k = 0; k < i; k++) {
    for (l = 0; l < j; l++) {
      matR[k][l] = mat[a+k][b+l];
    }
  }
}

void del_row(SV *data, int k) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (i = k; i < r-1; i++) {
    for (j = 0; j < c; j++) {
      mat[i][j] = mat[i+1][j];
    }
  }
  M->rows = r-1;
}

void del_rows(SV *data, int k, int l) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (i = 0; i < r-l-1; i++) {
    for (j = 0; j < c; j++) {
      mat[k+i][j] = mat[l+i+1][j];
    }
  }
  M->rows = r-(l-k+1);
}

void del_col(SV *data, int k) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (j = k; j < c-1; j++) {
    for (i = 0; i < r; i++) {
      mat[i][j] = mat[i][j+1];
    }
  }
  M->cols = c-1;
}

void del_cols(SV *data, int k, int l) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (j = 0; j < c-l-1; j++) {
    for (i = 0; i < r; i++) {
      mat[i][k+j] = mat[i][l+j+1];
    }
  }
  M->cols = c-(l-k+1);
}

void zero_matrix(SV* data){

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      mat[i][j] = 0.0;
    }
  }
}

void one_matrix(SV* data){

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i, j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      mat[i][j] = 1.0;
    }
  }
}

void identity_matrix(SV* data){

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i,j;

  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      if (i == j) {
	mat[i][j] = 1.0;
      }
      else {
	mat[i][j] = 0.0;
      }
    }
  }
}

void add_matrices(SV *dataA, SV *dataB, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matB = deref_matrix(dataB);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = matA[i][j] + matB[i][j];
    }
  }
}

void add_scalar(SV *dataA, double value, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = matA[i][j] + value;
    }
  }
}

void subtract_from_scalar(SV *dataA, double value, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = value - matA[i][j];
    }
  }
}

void subtract_matrices(SV *dataA, SV *dataB, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matB = deref_matrix(dataB);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = matA[i][j] - matB[i][j];
    }
  }
}

void multiply_matrices(SV *dataA, SV *dataB, int r1, int c1, int c2, SV *result) {
  double **A = deref_matrix(dataA);
  double **B = deref_matrix(dataB);
  double **R = deref_matrix(result);
  int i,j,k;

  for(i=0; i < c2; i++) {
    for(j=0; j < r1; j++) {
      R[j][i] = 0.0;
      for(k=0; k < c1; k++) {
	R[j][i] += A[j][k] * B[k][i];
      }
    }
  }
}

void multiply_matrices_elementwise(SV *dataA, SV *dataB, int r, int c, SV *result) {
  double **A = deref_matrix(dataA);
  double **B = deref_matrix(dataB);
  double **R = deref_matrix(result);
  int i,j;

  for(i=0; i < r; i++) {
    for(j=0; j < c; j++) {
      R[i][j] = A[i][j] * B[i][j];
    }
  }
}

void multiply_scalar(SV *dataA, double B, SV *result) {

  Matrix* M = (Matrix*)SvIV(dataA);
  double **matA = M->data;
  int r = M->rows;
  int c = M->cols;
  double **matR = deref_matrix(result);
  int i,j;
  for(i=0; i < r; i++) {
    for(j=0; j < c; j++) {
      matR[i][j] = matA[i][j] * B;
    }
  }
}

void divide_scalar(SV *dataA, double B, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = B/matA[i][j];
    }
  }
}

void divide_by_scalar(SV *dataA, double B, int r, int c, SV *result) {

  double **matA = deref_matrix(dataA);
  double **matR = deref_matrix(result);
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      matR[i][j] = matA[i][j]/B;
    }
  }
}

void abs_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = fabs(M[i][j]);
    }
  }
}

void exp_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = exp(M[i][j]);
    }
  }
}

void log_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = log(M[i][j]);
    }
  }
}

void sqrt_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = sqrt(M[i][j]);
    }
  }
}

void pow_matrix(SV *matrixref, double n) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = pow(M[i][j],n);
    }
  }
}

void sigmoid_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      M[i][j] = 1/(1+exp(-M[i][j]));
    }
  }
}

void transpose_matrix(SV *matrixref, SV *transpref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  Matrix* MT = (Matrix*)SvIV(transpref);
  double **matT = MT->data;
  int i,j;
  for(i = 0; i < c ; i++ ) {
    for(j = 0; j < r; j++) {
      matT[i][j] = mat[j][i];
    }
  }
}

void clone_matrix(SV *matrixref, SV *cloneref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  Matrix* C = (Matrix*)SvIV(cloneref);
  double **matC = C->data;
  int i,j;
  for(i = 0; i < r ; i++ ) {
    for(j = 0; j < c; j++) {
      matC[i][j] = mat[i][j];
    }
  }
}

double get_max(SV *matrixref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  double max = mat[0][0];
  int i,j;
  for(i = 0; i < r ; i++ ) {
    for(j = 0; j < c; j++) {
      if (mat[i][j]>max) {
	max = mat[i][j];
      }
    }
  }

  return max;
}

double get_min(SV *matrixref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  double min = mat[0][0];
  int i,j;
  for(i = 0; i < r ; i++ ) {
    for(j = 0; j < c; j++) {
      if (mat[i][j]<min) {
	min = mat[i][j];
      }
    }
  }
  return min;
}

double get_row_sum(SV *matrixref, int i) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int c = M->cols;
  double sum = 0.0;
  int j;
  for(j = 0; j < c; j++) {
    sum += mat[i][j];
  }

  return sum;
}

void get_row_sums(SV *data, SV *Sref) {

  Matrix* Am = (Matrix*)SvIV(data);
  double **A = Am->data;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;

  int row = Am->rows;
  int col = Am->cols;

  int i,j;

  /* Calculate sum of row vectors of input data matrix */
  for (i = 0; i < row; i++) {
    S[i][0] = 0.0;
    for (j = 0; j < col; j++) {
      S[i][0] += A[i][j];
    }
  }
}

double get_col_sum(SV *matrixref,int j) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  double sum = 0.0;
  int i;
  for(i = 0; i < r; i++) {
    sum += mat[i][j];
  }

  return sum;
}

void get_col_sums(SV *data, SV *Sref) {

  Matrix* Am = (Matrix*)SvIV(data);
  double **A = Am->data;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;

  int row = Am->rows;
  int col = Am->cols;

  int i,j;

  /* Calculate sum of column vectors of input data matrix */
  for (j = 0; j < col; j++) {
    S[0][j] = 0.0;
    for (i = 0; i < row; i++) {
      S[0][j] += A[i][j];
    }
  }
}

int is_sym(SV *matrixref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int i,j;
  int flag = 1;
  for(i = 0; i < c ; i++ ) {
    for(j = 0; j < i; j++) {
      if (fabs(mat[i][j] - mat[j][i])>1e-15) {
	flag = 0;
	break;
      }
    }
    if (flag == 0) {
      break;
    }
  }
  return flag;
}

double *vector_alloc(int n) {
  /* Allocates a vector of size n. */

    double *v;

  v = (double *) malloc ((unsigned long) n*sizeof(double));
  if (!v) {
    croak("Memory allocation failure in vector_alloc()");
  }
  return v;

}

void free_vector(double *v) {
  /* Free a vector allocated by vector_alloc(). */
  free(v);
}

double **matrix_alloc(int ni,int nj) {
  /* Allocate a ni x nj  matrix. */

    int i;
  double **mat;
  /* Allocate pointers to rows. */
    mat = (double **) malloc((unsigned long) (ni)*sizeof(double*));
  if (!mat) {
    croak("Memory allocation failure 1 in matrix_alloc()");
  }

  /* Allocate rows and set pointers to them. */
    for (i = 0; i < ni; i++) {
      mat[i] = (double *) malloc((unsigned long) (nj)*sizeof(double));
      if (!mat[i]) {
	croak("Memory allocation failure 2 in matrix_alloc()");
      }
    }
  /* Return pointer to array of pointers to rows. */
    return mat;

}

void matrix_free(double **mat,int ni,int nj) {
  /* Free a matrix allocated by matrix_alloc(). */
    int i,j;
  for (i = 0; i < ni; i++) {
    free(mat[i]);
  }
  free(mat);
}

int lu_decompose(double **a, int n, double **lu, int *ps) {
/* LU decomposition with partial pivoting and row equilibration.
   taken from a graphviz module */

  int i, j, k;
  int pivotindex = 0;
  double pivot, biggest, mult, tempf;
  double *scales;

  scales = (double *)vector_alloc(n);

  for (i = 0; i < n; i++) {
  /* Find the largest element in each row for row equilibration */
    biggest = 0.0;
    for (j = 0; j < n; j++) {
      if (biggest < (tempf = fabs(lu[i][j] = a[i][j]))) {
	biggest = tempf;
      }
    }
    if (biggest != 0.0) {
      scales[i] = 1.0 / biggest;
    }
    else {
      free_vector(scales);
      return (0);         /* Zero row: singular matrix */
    }
    ps[i] = i;              /* Initialize pivot sequence */
  }

  for (k = 0; k < n - 1; k++) {
  /* Find the largest element in each column to pivot around */
    biggest = 0.0;
    for (i = k; i < n; i++) {
      if (biggest < (tempf = fabs(lu[ps[i]][k]) * scales[ps[i]])) {
	biggest = tempf;
	pivotindex = i;
      }
    }
    if (biggest == 0.0) {
      free_vector(scales);
      return (0);         /* Zero column: singular matrix */
    }
    if (pivotindex != k) {  /* Update pivot sequence */
      j = ps[k];
      ps[k] = ps[pivotindex];
      ps[pivotindex] = j;
    }

    /* Pivot, eliminating an extra variable each time */
    pivot = lu[ps[k]][k];
    for (i = k + 1; i < n; i++) {
      lu[ps[i]][k] = mult = lu[ps[i]][k] / pivot;
      if (mult != 0.0) {
	for (j = k + 1; j < n; j++)
	  lu[ps[i]][j] -= mult * lu[ps[k]][j];
      }
    }
  }

  if (lu[ps[n - 1]][n - 1] == 0.0) {
    free_vector(scales);
    return (0);  /* Singular matrix */
  }

  free_vector(scales);
  return (1);
}

void lu_solve(double **lu, int *ps, double *x, double *b, int n) {
  int i, j;
  double dot;
  /* Vector reduction using U triangular matrix */
  for (i = 0; i < n; i++) {
    dot = 0.0;
    for (j = 0; j < i; j++) {
      dot += lu[ps[i]][j] * x[j];
    }
    x[i] = b[ps[i]] - dot;
  }

  /* Back substitution, in L triangular matrix */
  for (i = n - 1; i >= 0; i--) {
    dot = 0.0;
    for (j = i + 1; j < n; j++) {
      dot += lu[ps[i]][j] * x[j];
    }
    x[i] = (x[i] - dot) / lu[ps[i]][i];
  }
}

int invert_matrix(SV *Aref) {

  Matrix* A = (Matrix*)SvIV(Aref);
  double **a = A->data;
  int n = A->rows;
  int i, j;
  double *col, *X;
  double **lu;
  int *ps;

  col = (double *)vector_alloc(n);
  X = (double *)vector_alloc(n);
  lu = (double **)matrix_alloc(n,n);
  ps = (int *) malloc ((unsigned long) n*sizeof(int));
  if (lu_decompose(a,n,lu,ps)) {
    for (j=0;j<n;j++) {
      for (i=0;i<n;i++) {
	col[i] = 0.0;
      }
      col[j] = 1.0;
      lu_solve(lu,ps,X,col,n);
      for (i=0;i<n;i++) {
	a[i][j] = X[i];
      }
    }
    matrix_free(lu,n,n);
    free(ps);
    free_vector(X);
    free_vector(col);
    return (1);
  }
  else {
    matrix_free(lu,n,n);
    free(ps);
    free_vector(X);
    free_vector(col);
    return (0); /* Matrix is singular */
  }

}

double get_det(double **a,int n) {
/* Recursive definition of determinant using expansion by minors */

  int i,j,j1,j2;
  double det = 0.0;
  double **M;

  if (n < 1) { /* Error */

  }
  else if (n == 1) { /* Shouldn't get used */
    det = a[0][0];
  }
  else if (n == 2) {
    det = a[0][0] * a[1][1] - a[1][0] * a[0][1];
  }
  else {
    det = 0.0;
    for (j1=0;j1<n;j1++) {
      M = (double **)matrix_alloc(n-1,n-1);
      for (i=1;i<n;i++) {
	j2 = 0;
	for (j=0;j<n;j++) {
	  if (j == j1) {
	    continue;
	  }
	  M[i-1][j2] = a[i][j];
	  j2++;
	}
      }
      det += pow(-1.0,1.0+j1+1.0) * a[0][j1] * get_det(M,n-1);
      matrix_free(M,n-1,n-1);
    }
  }
  return(det);
}

double get_determinant(SV *Aref) {
  /* Needed because of recursive use of get_det */
  Matrix* A = (Matrix*)SvIV(Aref);
  double **a = A->data;
  int n = A->rows;

  return get_det(a,n);
}

double get_trace(SV *Aref) {

  Matrix* A = (Matrix*)SvIV(Aref);
  double **a = A->data;
  int n = A->rows;
  int i;
  double trace = a[0][0];
  if (n>1) {
    for (i=1;i<n;i++) {
      trace *= a[i][i];
    }
  }

  return trace;
}

void tred2(SV *Aref, SV *Dref, SV *Eref) {
  /* This is derived from the Algol procedures tred2 by
     Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
     Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
     Fortran subroutine in EISPACK.  */

  int l, k, j, i;
  double scale, hh, h, g, f;

  Matrix* A = (Matrix*)SvIV(Aref);
  double **V = A->data;
  int n = A->rows;
  Matrix* D = (Matrix*)SvIV(Dref);
  double **d = D->data;
  Matrix* E = (Matrix*)SvIV(Eref);
  double **e = E->data;

  for (j = 0; j < n; j++) {
    d[j][0] = V[n-1][j];
  }

  for (i = n-1; i > 0; i--) {
    scale = 0.0;
    h = 0.0;
    for (k = 0; k < i; k++) {
      scale = scale + fabs(d[k][0]);
    }
    if (scale == 0.0) {
      e[i][0] = d[i-1][0];
      for (j = 0; j < i; j++) {
	d[j][0] = V[i-1][j];
	V[i][j] = 0.0;
	V[j][i] = 0.0;
      }
    }
    else {
      for (k = 0; k < i; k++) {
	d[k][0] /= scale;
	h += d[k][0] * d[k][0];
      }
      f = d[i-1][0];
      g = sqrt(h);
      if (f > 0) {
	g = -g;
      }
      e[i][0] = scale * g;
      h = h - f * g;
      d[i-1][0] = f - g;
      for (j = 0; j < i; j++) {
	e[j][0] = 0.0;
      }
      for (j = 0; j < i; j++) {
	f = d[j][0];
	V[j][i] = f;
	g = e[j][0] + V[j][j] * f;
	for (k = j+1; k <= i-1; k++) {
	  g += V[k][j] * d[k][0];
	  e[k][0] += V[k][j] * f;
	}
	e[j][0] = g;
      }
      f = 0.0;
      for (j = 0; j < i; j++) {
	e[j][0] /= h;
	f += e[j][0] * d[j][0];
      }
      double hh = f / (h + h);
      for (j = 0; j < i; j++) {
	e[j][0] -= hh * d[j][0];
      }
      for (j = 0; j < i; j++) {
	f = d[j][0];
	g = e[j][0];
	for (k = j; k <= i-1; k++) {
	  V[k][j] -= (f * e[k][0] + g * d[k][0]);
	}
	d[j][0] = V[i-1][j];
	V[i][j] = 0.0;
      }
    }
    d[i][0] = h;
  }
  for (i = 0; i < n-1; i++) {
    V[n-1][i] = V[i][i];
    V[i][i] = 1.0;
    double h = d[i+1][0];
    if (h != 0.0) {
      for (k = 0; k <= i; k++) {
	d[k][0] = V[k][i+1] / h;
      }
      for (j = 0; j <= i; j++) {
	double g = 0.0;
	for (k = 0; k <= i; k++) {
	  g += V[k][i+1] * V[k][j];
	}
	for (k = 0; k <= i; k++) {
	  V[k][j] -= g * d[k][0];
	}
      }
    }
    for (k = 0; k <= i; k++) {
      V[k][i+1] = 0.0;
    }
  }
  for (j = 0; j < n; j++) {
    d[j][0] = V[n-1][j];
    V[n-1][j] = 0.0;
  }
  V[n-1][n-1] = 1.0;
  e[0][0] = 0.0;
}

void tql2(SV *Dref, SV *Eref, SV *Aref) {
   /* This is derived from the Algol procedures tql2, by
      Bowdler, Martin, Reinsch, and Wilkinson, Handbook for
      Auto. Comp., Vol.ii-Linear Algebra, and the corresponding
      Fortran subroutine in EISPACK. */

  Matrix* D = (Matrix*)SvIV(Dref);
  double **d = D->data;
  Matrix* E = (Matrix*)SvIV(Eref);
  double **e = E->data;
  Matrix* A = (Matrix*)SvIV(Aref);
  double **V = A->data;
  int n = A->rows;
  int i,j,k,l,iter,mm;
  double ss, r, p, g, dd, c, b;
  int max_iter = n*3;

  for (i = 1; i < n; i++) {
    e[i-1][0] = e[i][0];
  }
  e[n-1][0] = 0.0;
  double f = 0.0;
  double tst1 = 0.0;
  double eps = pow(2.0,-52.0);
  for (l = 0; l < n; l++) {
    tst1 = tst1 > fabs(d[l][0]) + fabs(e[l][0]) ? tst1 : fabs(d[l][0]) + fabs(e[l][0]);
    int mm = l;
    while (mm < n) {
      if (fabs(e[mm][0]) <= eps*tst1) {
	break;
      }
      mm++;
    }
    if (mm > l) {
      int iter = 0;
      do {
	if (iter++ == max_iter) {
	  croak("No convergence in tql2");
	}
	double g = d[l][0];
	double p = (d[l+1][0] - g) / (2.0 * e[l][0]);
	double r = sqrt((p * p) + 1.0);
	if (p < 0) {
	  r = -r;
	}
	d[l][0] = e[l][0] / (p + r);
	d[l+1][0] = e[l][0] * (p + r);
	double dl1 = d[l+1][0];
	double h = g - d[l][0];
	for (i = l+2; i < n; i++) {
	  d[i][0] -= h;
	}
	f = f + h;
	p = d[mm][0];
	double c = 1.0;
	double c2 = c;
	double c3 = c;
	double el1 = e[l+1][0];
	double ss = 0.0;
	double s2 = 0.0;
	for (i = mm-1; i >= l; i--) {
	  c3 = c2;
	  c2 = c;
	  s2 = ss;
	  g = c * e[i][0];
	  h = c * p;
	  r = sqrt(p*p+e[i][0]*e[i][0]);
	  e[i+1][0] = ss * r;
	  ss = e[i][0] / r;
	  c = p / r;
	  p = c * d[i][0] - ss * g;
	  d[i+1][0] = h + ss * (c * g + ss * d[i][0]);
	  for (k = 0; k < n; k++) {
	    h = V[k][i+1];
	    V[k][i+1] = ss * V[k][i] + c * h;
	    V[k][i] = c * V[k][i] - ss * h;
	  }
	}
	p = -ss * s2 * c3 * el1 * e[l][0] / dl1;
	e[l][0] = ss * p;
	d[l][0] = c * p;
      } while (fabs(e[l][0]) > eps*tst1);
    }
    d[l][0] = d[l][0] + f;
    e[l][0] = 0.0;
  }
  for (i = 0; i < n-1; i++) {
    int k = i;
    double p = d[i][0];
    for (j = i+1; j < n; j++) {
      if (d[j][0] < p) {
	k = j;
	p = d[j][0];
      }
    }
    if (k != i) {
      d[k][0] = d[i][0];
      d[i][0] = p;
      for (j = 0; j < n; j++) {
	p = V[j][i];
	V[j][i] = V[j][k];
	V[j][k] = p;
      }
    }
  }
}

void orthes (SV *Href, SV *Oref, SV *Vref) {
    /*  This is derived from the Algol procedures orthes and ortran,
        by Martin and Wilkinson, Handbook for Auto. Comp.,
        Vol.ii-Linear Algebra, and the corresponding
        Fortran subroutines in EISPACK. */

  Matrix* Hm = (Matrix*)SvIV(Href);
  double **H = Hm->data;
  Matrix* O = (Matrix*)SvIV(Oref);
  double **ort = O->data;
  Matrix* Vm = (Matrix*)SvIV(Vref);
  double **V = Vm->data;

  int n = Hm->rows;
  int low = 0;
  int high = n-1;
  int mm, i, j;

  for (mm = low+1; mm <= high-1; mm++) {
    double scale = 0.0;
    for (i = mm; i <= high; i++) {
      scale = scale + fabs(H[i][mm-1]);
    }
    if (scale != 0.0) {
      double h = 0.0;
      for (i = high; i >= mm; i--) {
	ort[i][0] = H[i][mm-1]/scale;
	h += ort[i][0] * ort[i][0];
      }
      double g = sqrt(h);
      if (ort[mm][0] > 0) {
	g = -g;
      }
      h = h - ort[mm][0] * g;
      ort[mm][0] = ort[mm][0] - g;
      for (j = mm; j < n; j++) {
	double f = 0.0;
	for (i = high; i >= mm; i--) {
	  f += ort[i][0]*H[i][j];
	}
	f = f/h;
	for (i = mm; i <= high; i++) {
	  H[i][j] -= f*ort[i][0];
	}
      }

      for (i = 0; i <= high; i++) {
	double f = 0.0;
	for (j = high; j >= mm; j--) {
	  f += ort[j][0]*H[i][j];
	}
	f = f/h;
	for (j = mm; j <= high; j++) {
	  H[i][j] -= f*ort[j][0];
	}
      }
      ort[mm][0] = scale*ort[mm][0];
      H[mm][mm-1] = scale*g;
    }
  }

  for (i = 0; i < n; i++) {
    for (j = 0; j < n; j++) {
      V[i][j] = (i == j ? 1.0 : 0.0);
    }
  }

  for (mm = high-1; mm >= low+1; mm--) {
    if (H[mm][mm-1] != 0.0) {
      for (i = mm+1; i <= high; i++) {
	ort[i][0] = H[i][mm-1];
      }
      for (j = mm; j <= high; j++) {
	double g = 0.0;
	for (i = mm; i <= high; i++) {
	  g += ort[i][0] * V[i][j];
	}
	g = (g / ort[mm][0]) / H[mm][mm-1];
	for (i = mm; i <= high; i++) {
	  V[i][j] += g * ort[i][0];
	}
      }
    }
  }
}

void cdiv(double cdivr, double cdivi,double xr, double xi, double yr, double yi) {
  /* Complex scalar division. */
  double r,d;
  if (fabs(yr) > fabs(yi)) {
    r = yi/yr;
    d = yr + r*yi;
    cdivr = (xr + r*xi)/d;
    cdivi = (xi - r*xr)/d;
  }
  else {
    r = yr/yi;
    d = yi + r*yr;
    cdivr = (r*xr + xi)/d;
    cdivi = (r*xi - xr)/d;
  }
}

double dmin(double a, double b) {
  return (a < b ? a : b);
}

double dmax(double a, double b) {
  return (a < b ? b : a);
}

int imin(int a, int b) {
  return (a < b ? a : b);
}

int imax(int a, int b) {
  return (a < b ? b : a);
}

 void hqr2 (SV *Href, SV *Oref, SV *Vref, SV *Dref, SV *Eref) {
   /* This is derived from the Algol procedure hqr2,
      by Martin and Wilkinson, Handbook for Auto. Comp.,
      Vol.ii-Linear Algebra, and the corresponding
      Fortran subroutine in EISPACK. */

   Matrix* Hm = (Matrix*)SvIV(Href);
   double **H = Hm->data;
   Matrix* O = (Matrix*)SvIV(Oref);
   double **ort = O->data;
   Matrix* Vm = (Matrix*)SvIV(Vref);
   double **V = Vm->data;
   Matrix* D = (Matrix*)SvIV(Dref);
   double **d = D->data;
   Matrix* E = (Matrix*)SvIV(Eref);
   double **e = E->data;

   int i, j, k;
   int nn = Hm->rows;
   int n = nn-1;
   int low = 0;
   int high = nn-1;
   double eps = pow(2.0,-52.0);
   double exshift = 0.0;
   double p=0,Q=0,r=0,ss=0,z=0,t,w,xx,yy;

   /* Store roots isolated by balanc and compute matrix norm */
   double norm = 0.0;
   for (i = 0; i < nn; i++) {
     if (i < low | i > high) {
       d[i][0] = H[i][i];
       e[i][0] = 0.0;
     }
     for (j = dmax(i-1,0); j < nn; j++) {
       norm = norm + fabs(H[i][j]);
     }
   }
   /* Outer loop over eigenvalue index */
   int iter = 0;
   while (n >= low) {
     /* Look for single small sub-diagonal element */
     int l = n;
     while (l > low) {
       ss = fabs(H[l-1][l-1]) + fabs(H[l][l]);
       if (ss == 0.0) {
	 ss = norm;
       }
       if (fabs(H[l][l-1]) < eps * ss) {
	 break;
       }
       l--;
     }
     /* Check for convergence
        One root found */
     if (l == n) {
       H[n][n] = H[n][n] + exshift;
       d[n][0] = H[n][n];
       e[n][0] = 0.0;
       n--;
       iter = 0;
     }
     else if (l == n-1) { /* Two roots found */
       w = H[n][n-1] * H[n-1][n];
       p = (H[n-1][n-1] - H[n][n]) / 2.0;
       Q = p * p + w;
       z = sqrt(fabs(Q));
       H[n][n] = H[n][n] + exshift;
       H[n-1][n-1] = H[n-1][n-1] + exshift;
       xx = H[n][n];
       if (Q >= 0) { /* Real pair */
	 if (p >= 0) {
	   z = p + z;
	 } else {
	   z = p - z;
	 }
	 d[n-1][0] = xx + z;
	 d[n][0] = d[n-1][0];
	 if (z != 0.0) {
	   d[n][0] = xx - w / z;
	 }
	 e[n-1][0] = 0.0;
	 e[n][0] = 0.0;
	 xx = H[n][n-1];
	 ss = fabs(xx) + fabs(z);
	 p = xx / ss;
	 Q = z / ss;
	 r = sqrt(p * p+Q * Q);
	 p = p / r;
	 Q = Q / r;
	 /* Row modification */
	 for (j = n-1; j < nn; j++) {
	   z = H[n-1][j];
	   H[n-1][j] = Q * z + p * H[n][j];
	   H[n][j] = Q * H[n][j] - p * z;
	 }
	 /* Column modification */
	 for (i = 0; i <= n; i++) {
	   z = H[i][n-1];
	   H[i][n-1] = Q * z + p * H[i][n];
	   H[i][n] = Q * H[i][n] - p * z;
	 }
	 /* Accumulate transformations */
	 for (i = low; i <= high; i++) {
	   z = V[i][n-1];
	   V[i][n-1] = Q * z + p * V[i][n];
	   V[i][n] = Q * V[i][n] - p * z;
	 }
       }
       else { /* Complex pair */
	 d[n-1][0] = xx + p;
	 d[n][0] = xx + p;
	 e[n-1][0] = z;
	 e[n][0] = -z;
       }
       n = n - 2;
       iter = 0;
     }
     else { /* No convergence yet */
       xx = H[n][n];
       yy = 0.0;
       w = 0.0;
       if (l < n) {
	 yy = H[n-1][n-1];
	 w = H[n][n-1] * H[n-1][n];
       }

       /* Wilkinson's original ad hoc shift */
       if (iter == 10) {
	 exshift += xx;
	 for (i = low; i <= n; i++) {
	   H[i][i] -= xx;
	 }
	 ss = fabs(H[n][n-1]) + fabs(H[n-1][n-2]);
	 xx = yy = 0.75 * ss;
	 w = -0.4375 * ss * ss;
       }

       /* MATLAB's new ad hoc shift */
       if (iter == 30) {
	 ss = (yy - xx) / 2.0;
	 ss = ss * ss + w;
	 if (ss > 0) {
	   ss = sqrt(ss);
	   if (yy < xx) {
	     ss = -ss;
	   }
	   ss = xx - w / ((yy - xx) / 2.0 + ss);
	   for (i = low; i <= n; i++) {
	     H[i][i] -= ss;
	   }
	   exshift += ss;
	   xx = yy = w = 0.964;
	 }
       }
       iter = iter + 1;
       if (iter > 30*nn) {
	 croak("No convergence in hqr2");
       }

       /* Look for two consecutive small sub-diagonal elements */
       int mm = n-2;
       while (mm >= l) {
	 z = H[mm][mm];
	 r = xx - z;
	 ss = yy - z;
	 p = (r * ss - w) / H[mm+1][mm] + H[mm][mm+1];
	 Q = H[mm+1][mm+1] - z - r - ss;
	 r = H[mm+2][mm+1];
	 ss = fabs(p) + fabs(Q) + fabs(r);
	 p = p / ss;
	 Q = Q / ss;
	 r = r / ss;
	 if (mm == l) {
	   break;
	 }
	 if (fabs(H[mm][mm-1]) * (fabs(Q) + fabs(r)) <
	     eps * (fabs(p) * (fabs(H[mm-1][mm-1]) + fabs(z) +
			       fabs(H[mm+1][mm+1])))) {
	   break;
	 }
	 mm--;
       }

       for (i = mm+2; i <= n; i++) {
	 H[i][i-2] = 0.0;
	 if (i > mm+2) {
	   H[i][i-3] = 0.0;
	 }
       }

       /* Double QR step involving rows l:n and columns m:n */
       for (k = mm; k <= n-1; k++) {
	 int notlast = k != n-1 ? 1:0;
	 if (k != mm) {
	   p = H[k][k-1];
	   Q = H[k+1][k-1];
	   r = notlast ? H[k+2][k-1] : 0.0;
	   xx = fabs(p) + fabs(Q) + fabs(r);
	   if (xx != 0.0) {
	     p = p / xx;
	     Q = Q / xx;
	     r = r / xx;
	   }
	 }
	 if (xx == 0.0) {
	   break;
	 }
	 ss = sqrt(p * p + Q * Q + r * r);
	 if (p < 0) {
	   ss = -ss;
	 }
	 if (ss != 0) {
	   if (k != mm) {
	     H[k][k-1] = -ss * xx;
	   }
	   else if (l != mm) {
	     H[k][k-1] = -H[k][k-1];
	   }
	   p = p + ss;
	   xx = p / ss;
	   yy = Q / ss;
	   z = r / ss;
	   Q = Q / p;
	   r = r / p;

	   /* Row modification */
	   for (j = k; j < nn; j++) {
	     p = H[k][j] + Q * H[k+1][j];
	     if (notlast) {
	       p = p + r * H[k+2][j];
	       H[k+2][j] = H[k+2][j] - p * z;
	     }
	     H[k][j] = H[k][j] - p * xx;
	     H[k+1][j] = H[k+1][j] - p * yy;
	   }

	   /* Column modification */
	   for (i = 0; i <= imin(n,k+3); i++) {
	     p = xx * H[i][k] + yy * H[i][k+1];
	     if (notlast) {
	       p = p + z * H[i][k+2];
	       H[i][k+2] = H[i][k+2] - p * r;
	     }
	     H[i][k] = H[i][k] - p;
	     H[i][k+1] = H[i][k+1] - p * Q;
	   }

	   /* Accumulate transformations */
	   for (i = low; i <= high; i++) {
	     p = xx * V[i][k] + yy * V[i][k+1];
	     if (notlast) {
	       p = p + z * V[i][k+2];
	       V[i][k+2] = V[i][k+2] - p * r;
	     }
	     V[i][k] = V[i][k] - p;
	     V[i][k+1] = V[i][k+1] - p * Q;
	   }
	 } /* (s != 0) */
       }  /* k loop */
     }  /* check convergence */
   }  /* while (n >= low) */


   if (norm == 0.0) {
     return;
   }

   for (n = nn-1; n >= 0; n--) {
     p = d[n][0];
     Q = e[n][0];
     /* Real vector */
       if (Q == 0) {
	 int l = n;
	 H[n][n] = 1.0;
	 for (i = n-1; i >= 0; i--) {
	   w = H[i][i] - p;
	   r = 0.0;
	   for (j = l; j <= n; j++) {
	     r = r + H[i][j] * H[j][n];
	   }
	   if (e[i][0] < 0.0) {
	     z = w;
	     ss = r;
	   }
	   else {
	     l = i;
	     if (e[i][0] == 0.0) {
	       if (w != 0.0) {
		 H[i][n] = -r * 1/w;
               }
	       else {
		 H[i][n] = -r * 1/(eps * norm);
	       }
	     } else {
	       xx = H[i][i+1];
	       yy = H[i+1][i];
	       Q = (d[i][0] - p) * (d[i][0] - p) + e[i][0] * e[i][0];
	       t = (xx * ss - z * r) / Q;
	       H[i][n] = t;
	       if (fabs(xx) > fabs(z)) {
		 H[i+1][n] = (-r - w * t) / xx;
	       }
	       else {
		 H[i+1][n] = (-ss - yy * t) / z;
	       }
	     }
	     /* Overflow control */
	       t = fabs(H[i][n]);
	     if ((eps * t) * t > 1) {
	       for (j = i; j <= n; j++) {
		 H[j][n] = H[j][n] / t;
	       }
	     }
	   }
	 }
       }
     else if (Q < 0) {  /* Complex vector */
       int l = n-1;

       /* Last vector component imaginary so matrix is triangular */
       if (fabs(H[n][n-1]) > fabs(H[n-1][n])) {
	 H[n-1][n-1] = Q / H[n][n-1];
	 H[n-1][n] = -(H[n][n] - p) / H[n][n-1];
       }
       else {
	 double cdivr, cdivi;
	 cdiv(cdivr, cdivi, 0.0,-H[n-1][n],H[n-1][n-1]-p,Q);
	 H[n-1][n-1] = cdivr;
	 H[n-1][n] = cdivi;
       }
       H[n][n-1] = 0.0;
       H[n][n] = 1.0;
       for (i = n-2; i >= 0; i--) {
	 double ra,sa,vr,vi;
	 ra = 0.0;
	 sa = 0.0;
	 for (j = l; j <= n; j++) {
	   ra = ra + H[i][j] * H[j][n-1];
	   sa = sa + H[i][j] * H[j][n];
	 }
	 w = H[i][i] - p;
	 if (e[i][0] < 0.0) {
	   z = w;
	   r = ra;
	   ss = sa;
	 } else {
	   l = i;
	   if (e[i][0] == 0) {
	     double cdivr, cdivi;
	     cdiv(cdivr, cdivi,-ra,-sa,w,Q);
	     H[i][n-1] = cdivr;
	     H[i][n] = cdivi;
	   }
	   else {
	     /* Solve complex equations */
	     xx = H[i][i+1];
	     yy = H[i+1][i];
	     vr = (d[i][0] - p) * (d[i][0] - p) + e[i][0] * e[i][0] - Q * Q;
	     vi = (d[i][0] - p) * 2.0 * Q;
	     if (vr == 0.0 && vi == 0.0) {
	       vr = eps * norm * (fabs(w) + fabs(Q) +
				  fabs(xx) + fabs(yy) + fabs(z));
	     }
	     double cdivr, cdivi;
	     cdiv(cdivr, cdivi,xx*r-z*ra+Q*sa,xx*ss-z*sa-Q*ra,vr,vi);
	     H[i][n-1] = cdivr;
	     H[i][n] = cdivi;
	     if (fabs(xx) > (fabs(z) + fabs(Q))) {
	       H[i+1][n-1] = (-ra - w * H[i][n-1] + Q * H[i][n]) / xx;
	       H[i+1][n] = (-sa - w * H[i][n] - Q * H[i][n-1]) / xx;
	     }
	     else {
	       double cdivr, cdivi;
	       cdiv(cdivr, cdivi, -r-yy*H[i][n-1],-ss-yy*H[i][n],z,Q);
	       H[i+1][n-1] = cdivr;
	       H[i+1][n] = cdivi;
	     }
	   }
	   /* Overflow control */
	   t = dmax(fabs(H[i][n-1]),fabs(H[i][n]));
	   if ((eps * t) * t > 1) {
	     for (j = i; j <= n; j++) {
	       H[j][n-1] = H[j][n-1] / t;
	       H[j][n] = H[j][n] / t;
	     }
	   }
	 }
       }
     }
   }

   /* Vectors of isolated roots */
   for (i = 0; i < nn; i++) {
     if (i < low | i > high) {
       for (j = i; j < nn; j++) {
	 V[i][j] = H[i][j];
       }
     }
   }

   /* Back transformation to get eigenvectors of original matrix */
   for (j = nn-1; j >= low; j--) {
     for (i = low; i <= high; i++) {
       z = 0.0;
       for (k = low; k <= imin(j, high); k++) {
	 z = z + V[i][k] * H[k][j];
       }
       V[i][j] = z;
     }
   }
   /* Compute vectors lengths */
   for (j = 0; j < nn; j++) {
     /*
     if (fabs(e[j][0])>eps) {
       fprintf(stderr,"WARNING: eigenvalue %d is complex (e= %.12f).\n",j+1,e[j][0]);
     }
     */
     e[j][0] = 0.0;
     for (i = 0; i < nn; i++) {
       e[j][0] += V[i][j] * V[i][j];
     }
     e[j][0] = sqrt(e[j][0]);
   }
   /* Export unit vectors */
   for (i = 0; i < nn; i++) {
     for (j = 0; j < nn; j++) {
       V[i][j] = V[i][j]/e[j][0];
     }
   }
 }

void QRDecomposition (SV *Qref, SV *Rref) {

  Matrix* Qm = (Matrix*)SvIV(Qref);
  double **QR = Qm->data;
  int mm = Qm->rows;
  int n = Qm->cols;

  Matrix* Rm = (Matrix*)SvIV(Rref);
  double **Rdiag = Rm->data;

  int i, j, k;

  /* Main loop */
  for (k = 0; k < n; k++) {
    /* Compute 2-norm of k-th column */
    double nrm = 0;
    for (i = k; i < mm; i++) {
      nrm = sqrt(nrm*nrm+QR[i][k]*QR[i][k]);
    }

    if (nrm != 0.0) {
      /* Form k-th Householder vector */
      if (QR[k][k] < 0) {
	nrm = -nrm;
      }
      for (i = k; i < mm; i++) {
	QR[i][k] /= nrm;
      }
      QR[k][k] += 1.0;

      /* Apply transformation to remaining columns */
      for (j = k+1; j < n; j++) {
	double ss = 0.0;
	for (i = k; i < mm; i++) {
	  ss += QR[i][k]*QR[i][j];
	}
	ss = -ss/QR[k][k];
	for (i = k; i < mm; i++) {
	  QR[i][j] += ss*QR[i][k];
	}
      }
    }
    Rdiag[k][0] = -nrm;
  }
}

void QRSolve(SV *Qref, SV *Rref, SV *Xref) {

  Matrix* Qm = (Matrix*)SvIV(Qref);
  double **QR = Qm->data;
  int mm = Qm->rows;
  int n = Qm->cols;

  Matrix* Rm = (Matrix*)SvIV(Rref);
  double **Rdiag = Rm->data;

  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  int nx = Xm->cols;

  int i, j, k;

  for (j = 0; j < n; j++) {
    if (Rdiag[j][0] == 0) {
      croak("\nERROR: Matrix is rank deficient");
     }
  }

  /* Compute Y = transpose(Q)*B */
  for (k = 0; k < n; k++) {
    for (j = 0; j < nx; j++) {
      double ss = 0.0;
      for (i = k; i < mm; i++) {
	ss += QR[i][k]*X[i][j];
      }
      ss = -ss/QR[k][k];
      for (i = k; i < mm; i++) {
	X[i][j] += ss*QR[i][k];
      }
    }
  }
  /* Solve R*X = Y */
  for (k = n-1; k >= 0; k--) {
    for (j = 0; j < nx; j++) {
      X[k][j] /= Rdiag[k][0];
    }
    for (i = 0; i < k; i++) {
      for (j = 0; j < nx; j++) {
	X[i][j] -= X[k][j]*QR[i][k];
      }
    }
  }
}

int pwm(SV *matrix, SV* lambdaref, SV* Vref)  {

  double **A = deref_matrix(matrix);
  Matrix* Vm = (Matrix*)SvIV(Vref);
  double **V = Vm->data;

  int N = Vm->rows;
  int i, j, l, max_iter, rnd;
  double eps, precision, flag, lambda;
  double phi, S, v;

  precision = 1e-15;
  eps = 1e-15;
  max_iter = 1000;
  double *V0;
  V0 = (double *)vector_alloc(N+1);

  for (i=0; i<N; i++) {
    rnd = 1 + (int)( (double)N * rand() / ( RAND_MAX + 1.0 ) );
    V0[i]=1.0/rnd;
  }
  flag = -1.0;
  l=1;
  while (flag==-1.0 && l<=max_iter) {
    lambda = 0.0;
    for (i=0; i<N; i++) {
      v = 0.0;
      for (j=0; j<N; j++) {
	v += A[i][j]*V0[j];
      }
      V[i][0] = v;
      if (fabs(v)>fabs(lambda)) lambda = v;
    }
    if (fabs(lambda) < eps) flag=0.0;
    else {
      for (i=0; i<N; i++) {
	v = V[i][0]/lambda;
	V[i][0] = v;
      }
      phi=0.0;
      for (i=0; i<N; i++)  {
        S=fabs(V[i][0]-V0[i]);
        if (S>phi) phi = S;
      }
      if (phi<precision) flag=1.0;
      else {
        for (i=0; i<N; i++) {
	  V0[i]= V[i][0];
	}
        l++;
      }
    }
  }
  sv_setnv(lambdaref,lambda);
  free(V0);
  return flag;
}

void get_means(SV *data, SV *meansdata) {

  Matrix* Am = (Matrix*)SvIV(data);
  double **A = Am->data;
  Matrix* Mm = (Matrix*)SvIV(meansdata);
  double **M = Mm->data;

  int row = Am->rows;
  int col = Am->cols;

  int i,j;

  /* Calculate mean of column vectors of input data matrix */
  for (j = 0; j < col; j++) {
    M[0][j] = 0.0;
    for (i = 0; i < row; i++) {
      M[0][j] += A[i][j];
    }
    M[0][j] = M[0][j]/(double)row;
  }
}

void get_variances(SV *data, SV *vardata) {

  Matrix* Mm = (Matrix*)SvIV(data);
  double **M = Mm->data;
  Matrix* Vm = (Matrix*)SvIV(vardata);
  double **V = Vm->data;

  int r = Mm->rows;
  int c = Mm->cols;

  int i, j;
  double *mean, v;

  mean = (double *)vector_alloc(c);

  /* Calculate mean of column vectors of input data matrix */
  for (j = 0; j < c; j++) {
    mean[j] = 0.0;
    for (i = 0; i < r; i++) {
      mean[j] += M[i][j];
    }
    mean[j] /= (double)r;
  }
  /* Calculate variance of column vectors of input data matrix */
  for (j = 0; j < c; j++) {
    v = 0.0;
    for (i = 0; i < r; i++) {
      v += (M[i][j]-mean[j])*(M[i][j]-mean[j]);
    }
    v /= (r-1);
    V[0][j] = v;
  }
  free_vector(mean);
}

void get_svd(SV *data, SV *Uref, SV *Sref, SV *Vref, int wantu, int wantv) {

  Matrix* Am = (Matrix*)SvIV(data);
  double **A = Am->data;
  Matrix* Um = (Matrix*)SvIV(Uref);
  double **U = Um->data;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;
  Matrix* Vm = (Matrix*)SvIV(Vref);
  double **V = Vm->data;


  int mm = Am->rows;
  int n = Am->cols;
  int nu = Um->cols;

  int i=0,j=0,k=0;

  if (wantu) {
    /* Initialise U to identity matrix */
    for (i = 0; i < mm; i++) {
      for (j = 0; j < nu; j++) {
	if (i == j) {
	  U[i][j] = 1.0;
	}
	else {
	  U[i][j] = 0.0;
	}
      }
    }
  }
  /* Initialise S */
  k = Sm->rows;
  for (i = 0; i < k; i++) {
    S[i][0] = 0.0;
  }

  double *e = (double *)vector_alloc(n);
  double *work = (double *)vector_alloc(mm);

  /* Reduce A to bidiagonal form, storing the diagonal elements
     in S and the super-diagonal elements in e. */

  int nct = imin(mm-1,n);
  int nrt = imax(0,imin(n-2,mm));
  int lu = imax(nct,nrt);
  for (k = 0; k < lu; k++) {
    if (k < nct) {
      /* Compute the transformation for the k-th column and
         place the k-th diagonal in s[k].
         Compute 2-norm of k-th column without under- or over- flow.*/

      S[k][0] = 0.0;
      for (i = k; i < mm; i++) {
	S[k][0] = sqrt(S[k][0]*S[k][0]+A[i][k]*A[i][k]);
      }
      if (S[k][0] != 0.0) {
	if (A[k][k] < 0.0) {
	  S[k][0] = -S[k][0];
	}
	for (i = k; i < mm; i++) {
	  A[i][k] /= S[k][0];
	}
	A[k][k] += 1.0;
      }
      S[k][0] = -S[k][0];
    }
    for (j = k+1; j < n; j++) {
      if ((k < nct) && (S[k][0] != 0.0))  {
	/* Apply the transformation.*/
	double tt = 0.0;
	for (i = k; i < mm; i++) {
	  tt += A[i][k]*A[i][j];
	}
	tt = -tt/A[k][k];
	for (i = k; i < mm; i++) {
	  A[i][j] += tt*A[i][k];
	}
      }

      /* Place the k-th row of A into e for the
         subsequent calculation of the row transformation. */

      e[j] = A[k][j];
    }
    if (wantu && (k < nct)) {
      /* Place the transformation in U for subsequent back multiplication.*/
      for (i = k; i < mm; i++) {
	U[i][k] = A[i][k];
      }
    }
    if (k < nrt) {
      /* Compute the k-th row transformation and place the
         k-th super-diagonal in e[k].
         Compute 2-norm without under- or over- flow. */
      e[k] = 0.0;
      for (i = k+1; i < n; i++) {
	e[k] = sqrt(e[k]*e[k]+e[i]*e[i]);
      }
      if (e[k] != 0.0) {
	if (e[k+1] < 0.0) {
	  e[k] = -e[k];
	}
	for (i = k+1; i < n; i++) {
	  e[i] /= e[k];
	}
	e[k+1] += 1.0;
      }
      e[k] = -e[k];
      if ((k+1 < mm) && (e[k] != 0.0)) {
        /* Apply the transformation. */

	for (i = k+1; i < mm; i++) {
	  work[i] = 0.0;
	}
	for (j = k+1; j < n; j++) {
	  for (i = k+1; i < mm; i++) {
	    work[i] += e[j]*A[i][j];
	  }
	}
	for (j = k+1; j < n; j++) {
	  double t = -e[j]/e[k+1];
	  for (i = k+1; i < mm; i++) {
	    A[i][j] += t*work[i];
	  }
	}
      }
      if (wantv) {
	/* Place the transformation in V for subsequent back multiplication. */

	for (i = k+1; i < n; i++) {
	  V[i][k] = e[i];
	}
      }
    }
  }
  /* Set up the final bidiagonal matrix of order p.*/

  int p = imin(n,mm+1);
  if (nct < n) {
    S[nct][0] = A[nct][nct];
  }
  if (mm < p) {
    S[p-1][0] = 0.0;
  }
  if (nrt+1 < p) {
    e[nrt] = A[nrt][p-1];
  }
  e[p-1] = 0.0;

  if (wantu) {
    /* If required, generate U.*/
    for (j = nct; j < nu; j++) {
      for (i = 0; i < mm; i++) {
	U[i][j] = 0.0;
      }
      U[j][j] = 1.0;
    }
    if (nct >= 1) {
      for (k = nct-1; k >= 0; k--) {
	if (S[k][0] != 0.0) {
	  for (j = k+1; j < nu; j++) {
	    double tt = 0.0;
	    for (i = k; i < mm; i++) {
	      tt += U[i][k]*U[i][j];
	    }
	    tt = -tt/U[k][k];
	    for (i = k; i < mm; i++) {
	      U[i][j] += tt*U[i][k];
	    }
	  }
	  for (i = k; i < mm; i++ ) {
	    U[i][k] = -U[i][k];
	  }
	  U[k][k] = 1.0 + U[k][k];
	  for (i = 0; i < k-1; i++) {
	    U[i][k] = 0.0;
	  }
	}
	else {
	  for (i = 0; i < mm; i++) {
	    U[i][k] = 0.0;
	  }
	  U[k][k] = 1.0;
	}
      }
    }
  }
  if (wantv) {
    /* If required, generate V.*/
    for (k = n-1; k >= 0; k--) {
      if ((k < nrt) && (e[k] != 0.0)) {
	for (j = k+1; j < n; j++) {
	  double tt = 0;
	  for (i = k+1; i < n; i++) {
	    tt += V[i][k]*V[i][j];
	  }
	  tt = -tt/V[k+1][k];
	  for (i = k+1; i < n; i++) {
	    V[i][j] += tt*V[i][k];
	  }
	}
      }
      for (i = 0; i < n; i++) {
	V[i][k] = 0.0;
      }
      V[k][k] = 1.0;
    }
  }
  /* Main iteration loop for the singular values.*/

  int pp = p-1;
  int iter = 0;
  double eps = pow(2.0,-52.0);
  double tiny = pow(2.0,-966.0);

  while (p > 0) {
    int k=0,kase=0;

    /* Here is where a test for too many iterations would go.

       This section of the program inspects for negligible elements
       in the S and e arrays. On completion the variables kase and k
       are set as follows:

       kase = 1     if S(p) and e[k-1] are negligible and k<p
       kase = 2     if S(k) is negligible and k<p
       kase = 3     if e[k-1] is negligible, k<p, and
                        S(k), ..., S(p) are not negligible (qr step).
       kase = 4     if e(p-1) is negligible (convergence). */

    for (k = p-2; k >= -1; k--) {
      if (k == -1) {
	break;
      }
      if (fabs(e[k]) <= tiny + eps*(fabs(S[k][0]) + fabs(S[k+1][0]))) {
	e[k] = 0.0;
	break;
      }
    }
    if (k == p-2) {
      kase = 4;
    }
    else {
      int ks;
      for (ks = p-1; ks >= k; ks--) {
	if (ks == k) {
	  break;
	}
	double t = (ks != p ? fabs(e[ks]) : 0.0) +
	           (ks != k+1 ? fabs(e[ks-1]) : 0.0);
	if (fabs(S[ks][0]) <= tiny + eps*t)  {
	  S[ks][0] = 0.0;
	  break;
	}
      }
      if (ks == k) {
	kase = 3;
      }
      else if (ks == p-1) {
	kase = 1;
      }
      else {
	kase = 2;
	k = ks;
      }
    }
    k++;
    /* Perform the task indicated by kase.*/

    switch (kase) {

      /* Deflate negligible S(p).*/

      case 1: {
	double f = e[p-2];
	e[p-2] = 0.0;
	for (j = p-2; j >= k; j--) {
	  double t = sqrt(S[j][0]*S[j][0]+f*f);
	  double cs = S[j][0]/t;
	  double sn = f/t;
	  S[j][0] = t;
	  if (j != k) {
	    f = -sn*e[j-1];
	    e[j-1] = cs*e[j-1];
	  }
	  if (wantv) {
	    for (i = 0; i < n; i++) {
	      t = cs*V[i][j] + sn*V[i][p-1];
	      V[i][p-1] = -sn*V[i][j] + cs*V[i][p-1];
	      V[i][j] = t;
	    }
	  }
	}
      }
      break;

      /* Split at negligible S(k).*/

      case 2: {
	double f = e[k-1];
	e[k-1] = 0.0;
	for (j = k; j < p; j++) {
	  double t = sqrt(S[j][0]*S[j][0]+f*f);
	  double cs = S[j][0]/t;
	  double sn = f/t;
	  S[j][0] = t;
	  f = -sn*e[j];
	  e[j] = cs*e[j];
	  if (wantu) {
	    for (i = 0; i < mm; i++) {
	      t = cs*U[i][j] + sn*U[i][k-1];
	      U[i][k-1] = -sn*U[i][j] + cs*U[i][k-1];
	      U[i][j] = t;
	    }
	  }
	}
      }
      break;

      /* Perform one QR step.*/

      case 3: {

	/* Calculate the shift.*/
        double scale = dmax(dmax(dmax(dmax(fabs(S[p-1][0]),fabs(S[p-2][0])),fabs(e[p-2])),fabs(S[k][0])),fabs(e[k]));
	double sp = S[p-1][0]/scale;
	double spm1 = S[p-2][0]/scale;
	double epm1 = e[p-2]/scale;
	double sk = S[k][0]/scale;
	double ek = e[k]/scale;
	double b = ((spm1 + sp)*(spm1 - sp) + epm1*epm1)/2.0;
	double c = (sp*epm1)*(sp*epm1);
	double sh = 0.0;
	if ((b != 0.0) || (c != 0.0)) {
	  sh = sqrt(b*b + c);
	  if (b < 0.0) {
	    sh = -sh;
	  }
	  sh = c/(b + sh);
	}
	double f = (sk + sp)*(sk - sp) + sh;
	double g = sk*ek;

	/* Chase zeros.*/
	for (j = k; j < p-1; j++) {
	  double t = sqrt(f*f+g*g);
	  double cs = f/t;
	  double sn = g/t;
	  if (j != k) {
	    e[j-1] = t;
	  }
	  f = cs*S[j][0] + sn*e[j];
	  e[j] = cs*e[j] - sn*S[j][0];
	  g = sn*S[j+1][0];
	  S[j+1][0] = cs*S[j+1][0];
	  if (wantv) {
	    for (i = 0; i < n; i++) {
	      t = cs*V[i][j] + sn*V[i][j+1];
	      V[i][j+1] = -sn*V[i][j] + cs*V[i][j+1];
	      V[i][j] = t;
	    }
	  }
	  t = sqrt(f*f+g*g);
	  cs = f/t;
	  sn = g/t;
	  S[j][0] = t;
	  f = cs*e[j] + sn*S[j+1][0];
	  S[j+1][0] = -sn*e[j] + cs*S[j+1][0];
	  g = sn*e[j+1];
	  e[j+1] = cs*e[j+1];
	  if (wantu && (j < mm-1)) {
	    for (i = 0; i < mm; i++) {
	      t = cs*U[i][j] + sn*U[i][j+1];
	      U[i][j+1] = -sn*U[i][j] + cs*U[i][j+1];
	      U[i][j] = t;
	    }
	  }
	}
	e[p-2] = f;
	iter++;
      }
      break;

      /* Convergence.*/

      case 4: {

	/* Make the singular values positive.*/

        if (S[k][0] <= 0.0) {
	  S[k][0] = (S[k][0] < 0.0 ? -S[k][0] : 0.0);
	  if (wantv) {
	    for (i = 0; i <= pp; i++) {
	      V[i][k] = -V[i][k];
	    }
	  }
	}

	/* Order the singular values.*/
	while (k < pp) {
	  if (S[k][0] >= S[k+1][0]) {
	    break;
	  }
	  double t = S[k][0];
	  S[k][0] = S[k+1][0];
	  S[k+1][0] = t;
	  if (wantv && (k < n-1)) {
	    for (i = 0; i < n; i++) {
	      t = V[i][k+1]; V[i][k+1] = V[i][k]; V[i][k] = t;
	    }
	  }
	  if (wantu && (k < mm-1)) {
	    for (i = 0; i < mm; i++) {
	      t = U[i][k+1]; U[i][k+1] = U[i][k]; U[i][k] = t;
	    }
	  }
	  k++;
	}
	iter = 0;
	p--;
      }
	break;
    }
  }
  free_vector(e);
  free_vector(work);
}

void standardize_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int rows = Mm->rows;
  int cols = Mm->cols;
  int i,j,k;
  double eps = 1e-16;
  double sum;
  double *mean, *var;
  double dev, newM;

  mean = (double *)vector_alloc(cols);
  var = (double *)vector_alloc(cols);
  /* Calculate mean of column vectors of input data matrix */
    for (j = 0; j < cols; j++) {
      mean[j] = 0.0;
      for (i = 0; i < rows; i++) {
	mean[j] += M[i][j];
      }
      mean[j] /= (double)rows;
    }
  /* Calculate variance of column vectors of input data matrix */
    for (j = 0; j < cols; j++) {
      var[j] = 0.0;
      for (i = 0; i < rows; i++) {
	dev = M[i][j]-mean[j];
	var[j] += dev*dev;
      }
      var[j] = var[j]/(rows-1);
    }
  /* Standardize data */
    for (j = 0; j < cols; j++) {
      for (i = 0; i < rows; i++) {
	M[i][j] = (M[i][j]-mean[j])/sqrt(var[j]);
	if (fabs(M[i][j])<eps) {
	  M[i][j] = 0.0;
	}
      }
    }
  free_vector(mean);
  free_vector(var);
}

void normalize_matrix(SV *matrixref, int flag) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int rows = Mm->rows;
  int cols = Mm->cols;
  int i,j,k;
  double eps = 1e-16;
  double *sum;
  sum = (double *)vector_alloc(cols);
  for (j = 0; j < cols; j++) {
    sum[j] = 0.0;
    for (i = 0; i < rows; i++) {
      if (flag) {
	sum[j] += M[i][j] * M[i][j];
      }
      else {
	sum[j] += M[i][j];
      }
    }
    if (flag) {
      sum[j] = sqrt(sum[j]);
    }
  }
  for (j = 0; j < cols; j++) {
    for (i = 0; i < rows; i++) {
      if (sum[j] != 0.0) {
	M[i][j] /= sum[j];
	if (fabs(M[i][j])<eps) {
	  M[i][j] = 0.0;
	}
      }
      else {
	M[i][j] = 0.0;
      }
    }
  }
  free_vector(sum);
}

void sym_normalize_matrix(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int rows = Mm->rows;
  int cols = Mm->cols;
  int i,j,k;
  double eps = 1e-16;
  double *D;
  k = cols > rows ? rows : cols;
  D = (double *)vector_alloc(k);
  for (i = 0; i < k; i++) {
    D[i] = M[i][i];
  }
  for (i = 0; i < rows; i++) {
    for (j = 0; j < cols; j++) {
      if (D[j] != 0.0 && D[i] != 0.0) {
	M[i][j] /= sqrt(D[i]*D[j]);
	if (fabs(M[i][j])<eps) {
	  M[i][j] = 0.0;
	}
      }
      else {
	M[i][j] = 0.0;
      }
    }
  }
  free_vector(D);
}

double get_col_max(double **M, int col, int rows) {
  int i;
  double max = M[0][0];
  for (i = 0; i < rows; i++) {
    if (M[i][col]>max) {
      max = M[i][col];
    }
  }
  return max;
}

void swap_matrix_rows(double **M, int a, int b, int cols) {

  int j;
  double tmp;
  for (j = 0; j < cols; j++) {
    tmp = M[a][j];
    M[a][j] = M[b][j];
    M[b][j] = tmp;
  }
}

void swap_matrix_cols(double **M, int a, int b, int rows) {

  int i;
  double tmp;
  for (i = 0; i < rows; i++) {
    tmp = M[i][a];
    M[i][a] = M[i][b];
    M[i][b] = tmp;
  }
}

void sort_matrix_rows_on_vector(SV *matrixref, SV *vectorref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  Matrix* Vm = (Matrix*)SvIV(vectorref);
  double **V = Vm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;

  /* Bubble sort */
  j = 0;
  int notdone;
  do {
    notdone = 0;
    for (i = 0; i < r-1; i++) {
      if (V[i][0]<V[i+1][0]) {
	swap_matrix_rows(M,i,i+1,c);
	swap_matrix_rows(V,i,i+1,1);
	notdone = 1;
      }
    }
  } while (++j<=r && notdone);
}

void sort_matrix_cols_on_vector(SV *matrixref, SV *vectorref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  Matrix* Vm = (Matrix*)SvIV(vectorref);
  double **V = Vm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;

  /* Bubble sort */
  j = 0;
  int notdone;
  do {
    notdone = 0;
    for (j = 0; j < c-1; j++) {
      if (V[0][j]<V[0][j+1]) {
	swap_matrix_cols(M,j,j+1,r);
	swap_matrix_cols(V,j,j+1,1);
	notdone = 1;
      }
    }
  } while (++j<=c && notdone);
}

void sort_matrix_rows_on_col(SV *matrixref, int col) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;

  /* Bubble sort */
  j = 0;
  int notdone;
  do {
    notdone = 0;
    for (i = 0; i < r-1; i++) {
      if (M[i][col]<M[i+1][col]) {
	swap_matrix_rows(M,i,i+1,c);
	notdone = 1;
      }
    }
  } while (++j<=r && notdone);
}

void sort_matrix_cols_on_row(SV *matrixref, int row) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  int i,j;

  /* Bubble sort */
  j = 0;
  int notdone;
  do {
    notdone = 0;
    for (j = 0; j < c-1; j++) {
      if (M[row][j]<M[row][j+1]) {
	swap_matrix_cols(M,j,j+1,r);
	notdone = 1;
      }
    }
  } while (++j<=c && notdone);
}

void flipv(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int i;
  int r = Mm->rows;
  int c = Mm->cols;
  int n = (int) floor((c-1)/2);
  double tmp;
  for (i = 0; i <= n; i++) {
    swap_matrix_cols(M, i, c-1-i, r);
  }
}
void fliph(SV *matrixref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int i;
  int r = Mm->rows;
  int c = Mm->cols;
  int n = (int) floor((r-1)/2);
  double tmp;
  for (i = 0; i <= n; i++) {
    swap_matrix_rows(M, i, r-1-i, c);
  }
}

void eucl_dist(SV *dataA, SV *dataB, SV *result) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **A = Am->data;
  int ra = Am->rows;
  int ca = Am->cols;
  Matrix* Bm = (Matrix*)SvIV(dataB);
  double **B = Bm->data;
  int cb = Bm->cols;
  Matrix* Rm = (Matrix*)SvIV(result);
  double **R = Rm->data;
  int i,j,k;

  for (k=0;k<cb; k++) {
    for(j=0; j<ca; j++) {
      R[j][k] = 0.0;
      for(i=0; i<ra; i++) {
	R[j][k] += (A[i][j]-B[i][k])*(A[i][j]-B[i][k]);
      }
     /* R[j][k] = sqrt(R[j][k]); */
    }
  }
}

void bistochastic_matrix(SV *matrixref) {

  Matrix* Xm = (Matrix*)SvIV(matrixref);
  double **X = Xm->data;
  int r = Xm->rows;

  int i,j,k,iter;
  double **K, *Sr, *Sc, ss, min;

  K = (double **)matrix_alloc(r,r);
  Sr = vector_alloc(r);
  Sc = vector_alloc(r);
  min = 0.0;
  k = 0;
  iter = 1;

  do {
    ss = 0.0;
    k++;
    for (i = 0; i < r; i++) {
      for (j = 0; j < r; j++) {
	ss += X[i][j];
      }
    }
    ss /= r*r;
    for (i = 0; i < r; i++) {
      for (j = 0; j < r; j++) {
	if (i == j) {
	  K[i][j] = 1.0/(double)r;
	}
	else {
	  K[i][j] = 0.0;
	}
	if (j == 0) {
	  K[i][j] += ss;
	}
	K[i][j] -= X[i][j]/r;
      }
    }
    for (i = 0; i < r; i++) {
      Sr[i] = 0.0;
      Sc[i] = 0.0;
      for (j = 0; j < r; j++) {
	Sr[i] += K[i][j];
	Sc[i] += X[i][j]/r;
      }
    }
    min = 0.0;
    for (i = 0; i < r; i++) {
      for (j = 0; j < r; j++) {
	K[i][j] = X[i][j] + Sr[i] - Sc[j];
	if (K[i][j] < min) {
	  min = K[i][j];
	}
	if (K[i][j] < 0) {
	  K[i][j] = 0.0;
	}
	X[i][j] = K[i][j];
      }
    }
    iter++;
  } while (min<0 && iter<=100);

  free(Sr);
  free(Sc);
  matrix_free(K,r,r);
}

void covar(SV *matrixref, SV *covref) {

  Matrix* Mm = (Matrix*)SvIV(matrixref);
  double **M = Mm->data;
  int ni = Mm->rows;
  int nj = Mm->cols;
  Matrix* Cm = (Matrix*)SvIV(covref);
  double **C = Cm->data;

  double *mean;
  int i, j, k;
  mean = (double *)vector_alloc(nj);

  /* Calculate mean of column vectors of input data matrix */
  for (j = 0; j < nj; j++) {
    mean[j] = 0.0;
    for (i = 0; i < ni; i++) {
      mean[j] += M[i][j];
    }
    mean[j] /= (double)ni;
  }

  /* Center the column vectors. */
  for (i = 0; i < ni; i++) {
    for (j = 0; j < nj; j++) {
      M[i][j] = M[i][j]-mean[j];
    }
  }
  free(mean);

  /* Calculate the nj * nj covariance matrix. */
  for (j = 0; j < nj; j++) {
    for (k = j; k < nj; k++) {
      for (i = 0; i < ni; i++) {
	C[j][k] = C[j][k]+M[i][j]*M[i][k];
      }
      C[k][j] = C[j][k];
    }
  }
  if (ni > 1) {
    for (j = 0; j < nj; j++) {
      for (k = j; k < nj; k++) {
	C[j][k] = C[j][k]/(ni-1);
	C[k][j] = C[j][k];
      }
    }
  }
}

void correl(SV *dataref, SV *corref) {

  Matrix* Mm = (Matrix*)SvIV(dataref);
  double **M = Mm->data;
  int ni = Mm->rows;
  int nj = Mm->cols;
  Matrix* Cm = (Matrix*)SvIV(corref);
  double **C = Cm->data;

  double *mean,*stddev, x;
  double eps = 0.0000000000005;
  int i, j, k;

  mean = (double *)vector_alloc(nj);
  stddev = vector_alloc(nj);

  /* Calculate means of column vectors of input data matrix */
  for (j = 0; j < nj; j++) {
    mean[j] = 0.0;
    for (i = 0; i < ni; i++) {
      mean[j] += M[i][j];
    }
    mean[j] /= (double)ni;
  }

  /* Calculate standard deviations of columns */
  for (j = 0; j < nj; j++) {
    stddev[j] = 0.0;
    for (i = 0; i < ni; i++) {
      stddev[j] += ( ( M[i][j] - mean[j] ) *
		     ( M[i][j] - mean[j] )  );
    }
    stddev[j] /= ni;
    stddev[j] = sqrt(stddev[j]);
    /* handle near-zero std. dev. values */
      if (stddev[j] <= eps) stddev[j] = 1.0;
  }

  /* Center and reduce the column vectors. */
  for (i = 0; i < ni; i++) {
    for (j = 0; j < nj; j++) {
      M[i][j] = (M[i][j]-mean[j])/(sqrt(ni) * stddev[j]);
    }
  }

  free(mean);
  free(stddev);

  /* Calculate the nj * nj correlation matrix. */
  for (j = 0; j < nj; j++) {
    C[j][j] = 1.0;
    for (k = j+1; k < nj; k++) {
      for (i = 0; i < ni; i++) {
	C[j][k] = C[j][k] + M[i][j]*M[i][k];
      }
      C[k][j] = C[j][k];
    }
  }
  C[nj-1][nj-1] = 1.0;

}

void pearson_r(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;
  double xt,yt;
  double xm, ym, sxx, syy, sxy;
  int i,j,k;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      xm = 0.0;
      ym = 0.0;
      sxx = 0.0;
      syy = 0.0;
      sxy = 0.0;
      for(i=0; i<c; i++) {
	xm += M[j][i];
	ym += M[k][i];
      }
      xm /= c; /* mean */
      ym /= c;

      for(i=0; i<c; i++) {
	xt = M[j][i]-xm;
	yt = M[k][i]-ym;
	sxx += xt*xt;
	syy += yt*yt;
	sxy += xt*yt;
      }
      D[j][k] = sxy ? sxy/sqrt(sxx*syy) : 1.0;
      D[k][j] = D[j][k];
    }
  }
}

void uncentered_pearson_r(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;
  double sxx, syy, sxy;
  int i,j,k;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      sxx = 0.0;
      syy = 0.0;
      sxy = 0.0;
      for(i=0; i<c; i++) {
	sxx += M[j][i] * M[j][i];
	syy += M[k][i] * M[k][i];
	sxy += M[j][i] * M[k][i];
      }
      D[j][k] = sxy ? sxy/sqrt(sxx*syy) : 1.0;
      D[k][j] = D[j][k];
    }
  }
}

void mahalanobis(SV *Mref, SV *Sref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;

  double *B, *C;
  B = (double *)vector_alloc(c);
  C = (double *)vector_alloc(c);

  int i,j,k,l;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      /* X-Y */
      for( i = 0; i < c; i++ ) {
	C[i] = M[j][i] - M[k][i];
      }
      /* (X-Y)'S */
      for( i = 0; i < c; i++) {
	B[i] = 0.0;
	for( l = 0; l< c; l++ ) {
	  B[i] += C[l] * S[l][i];
	}
      }
      /* (X-Y)'S(X-Y) */
      D[j][k] = 0.0;
      for( i = 0; i < c; i++ ) {
	D[j][k] += B[i] * C[i];
	D[k][j] = D[j][k];
      }
    }
  }
  free(B);
  free(C);
}


void ext_jaccard(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;

  double xt,yt;
  double xm, ym, sxx, syy, sxy;
  int i,j,k;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      xm = 0.0;
      ym = 0.0;
      sxx = 0.0;
      syy = 0.0;
      sxy = 0.0;
      for(i=0; i<c; i++) {
	xm += M[j][i];
	ym += M[k][i];
      }
      for(i=0; i<c; i++) {
	xt = M[j][i]-xm;
	yt = M[k][i]-ym;
	sxx += xt*xt;
	syy += yt*yt;
	sxy += xt*yt;
      }
      D[j][k] = sxy/(sxx+syy-sxy);
      D[k][j] = D[j][k];
    }
  }
}

void manhattan(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;
  int i,j,k;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      D[j][k] = 0.0;
      for(i=0; i<c; i++) {
	D[j][k] += abs(M[j][i] - M[k][i]);
      }
      D[k][j] = D[j][k];
    }
  }
}

void euclidean(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;
  int i,j,k;
  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      D[j][k] = 0.0;
      for(i=0; i<c; i++) {
	D[j][k] += (M[j][i] - M[k][i]) * (M[j][i] - M[k][i]);
      }
      /* D[j][k] = sqrt(D[j][k]); */
      D[k][j] = D[j][k];
    }
  }

}

void kendall(SV *Mref, SV *Dref) {

  Matrix* Mm = (Matrix*)SvIV(Mref);
  double **M = Mm->data;
  int r = Mm->rows;
  int c = Mm->cols;
  Matrix* Dm = (Matrix*)SvIV(Dref);
  double **D = Dm->data;
  int i,j,k,l,con,dis,exx,exy;
  double denomx;
  double denomy;

  for(j=0; j<r; j++) {
    for(k=0; k<=j; k++) {
      D[j][k] = 0.0;
      con = 0;
      dis = 0;
      exx = 0;
      exy = 0;
      for(i=0; i<c; i++) {
	for (l = 0; l < i; l++) {
	  double x1 = M[j][i];
	  double x2 = M[j][l];
	  double y1 = M[k][i];
	  double y2 = M[k][l];
	  if (x1 < x2 && y1 < y2) con++;
	  if (x1 > x2 && y1 > y2) con++;
	  if (x1 < x2 && y1 > y2) dis++;
	  if (x1 > x2 && y1 < y2) dis++;
	  if (x1 == x2 && y1 != y2) exx++;
	  if (x1 != x2 && y1 == y2) exy++;
	}
      }
      denomx = con + dis + exx;
      denomy = con + dis + exy;
      if (denomx==0 || denomy==0) {
	D[j][k] = 1.0;
	D[k][j] = 1.0;
      }
      else {
	D[j][k] = (con-dis)/sqrt(denomx*denomy);
	D[k][j] = D[j][k];
      }
    }
  }
}

int test_equality_matrices(SV *dataA, SV *dataB, double tol) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **matA = Am->data;
  Matrix* Bm = (Matrix*)SvIV(dataB);
  double **matB = Bm->data;
  int ra = Am->rows;
  int ca = Am->cols;
  int rb = Bm->rows;
  int cb = Bm->cols;
  if (ra != rb | ca != cb) {
    return 0;
  }
  int i,j;
  int equal = 1;
  for (i = 0; i < ra; i++) {
    for (j = 0; j < ca; j++) {
      if (fabs(matA[i][j]-matB[i][j])>tol) {
	equal = 0;
	break;
      }
    }
    if (equal == 0) {
      break;
    }
  }
  return equal;
}

int test_equality_scalar(SV *dataA, double value, double tol) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **matA = Am->data;
  int r = Am->rows;
  int c = Am->cols;
  int i,j;
  int equal = 1;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      if (fabs(matA[i][j] - value)>tol) {
	equal = 0;
	break;
      }
    }
    if (equal == 0) {
      break;
    }
  }
  return equal;
}

void rbind(SV *dataA, SV *dataB, SV *dataC) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **matA = Am->data;
  Matrix* Bm = (Matrix*)SvIV(dataB);
  double **matB = Bm->data;
  Matrix* Cm = (Matrix*)SvIV(dataC);
  double **matC = Cm->data;
  int r = Cm->rows;
  int c = Cm->cols;
  int ra = Am->rows;

  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      if (i<ra) {
	matC[i][j] = matA[i][j];
      }
      else {
	matC[i][j] = matB[i-ra][j];
      }
    }
  }
}

void cbind(SV *dataA, SV *dataB, SV *dataC) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **matA = Am->data;
  Matrix* Bm = (Matrix*)SvIV(dataB);
  double **matB = Bm->data;
  Matrix* Cm = (Matrix*)SvIV(dataC);
  double **matC = Cm->data;
  int r = Cm->rows;
  int c = Cm->cols;
  int ca = Am->cols;

  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      if (j<ca) {
	matC[i][j] = matA[i][j];
      }
      else {
	matC[i][j] = matB[i][j-ca];
      }
    }
  }
}

int cholesky_decomposition(SV* dataA, SV *dataU) {

/* Cholesky decomposition in upper triangular matrix such that A = U'*U.
   This computes U with the algorithm used in LINPACK and MATLAB. */

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **A = Am->data;
  Matrix* Um = (Matrix*)SvIV(dataU);
  double **U = Um->data;
  int n = Am->rows;
  int c = Am->cols;
  int i,j,k,isspd;
  double d,ss;

  isspd = n == c ? 1:0;

  for (j = 0; j < n; j++) {
    d = 0.0;
    for (k = 0; k < j; k++) {
      ss = A[k][j];
      for (i = 0; i < k; i++) {
	ss = ss - U[i][k]*U[i][j];
      }
      U[k][j] = ss = ss/U[k][k];
      d = d + ss*ss;
      if (fabs(A[k][j] - A[j][k]) > 1e-12) {
	isspd = 0;
      }
    }
    d = A[j][j] - d;
    if (d<=0.0) {
      isspd = 0;
    }
    U[j][j] = sqrt(dmax(d,0.0));
    for (k = j+1; k < n; k++) {
      U[k][j] = 0.0;
    }
  }
  return isspd;
}

void apply_to_matrix(SV* dataA, SV *subroutine) {

  Matrix* Am = (Matrix*)SvIV(dataA);
  double **A = Am->data;
  int r = Am->rows;
  int c = Am->cols;
  int i,j;
  for (i = 0; i < r; i++) {
    for (j = 0; j < c; j++) {
      int count = 0;
      dSP;
      ENTER;
      SAVETMPS;
      PUSHMARK(SP);
      XPUSHs(sv_2mortal(newSVnv(A[i][j])));
      PUTBACK;
      count = call_sv(subroutine, G_ARRAY);
      SPAGAIN;
      if (count != 1) {
	croak("\nERROR: Subroutine doesn't return a scalar value");
      }
      A[i][j] = POPn;
      PUTBACK;
      FREETMPS;
      LEAVE;
    }
  }
}

int nze(SV *matrixref) {

  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  int r = M->rows;
  int c = M->cols;
  int count = 0;
  double eps = 1e-12;
  int i,j;
  for(i = 0; i < r; i++) {
    for(j = 0; j < c; j++) {
      if (fabs(mat[i][j])>eps) {
	count++;
      }
    }
  }

  return count;
}

void find_nze_in_col(SV *matrixref,SV *Sref) {
  /* Get row indices of non-zero elements of a column */
  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;
  int r = M->rows;
  double eps = 1e-12;
  int i;
  int k = 0;
  for(i = 0; i < r; i++) {
    if (fabs(mat[i][0])>eps) {
      S[0][k] = i;
      k++;
    }
  }
}

void find_zeros_in_col(SV *matrixref,SV *Sref) {
  /* Get row indices of elements of a column with a value of zero */
  Matrix* M = (Matrix*)SvIV(matrixref);
  double **mat = M->data;
  Matrix* Sm = (Matrix*)SvIV(Sref);
  double **S = Sm->data;
  int r = M->rows;
  double eps = 1e-12;
  int i;
  int k = 0;
  for(i = 0; i < r; i++) {
    if (fabs(mat[i][0])<=eps) {
      S[0][k] = i;
      k++;
    }
  }
}

void kron_product(SV *dataA, SV *dataB, SV *dataR) {

  Matrix* matA = (Matrix*)SvIV(dataA);
  double **A = matA->data;
  Matrix* matB = (Matrix*)SvIV(dataB);
  double **B = matB->data;
  Matrix* matR = (Matrix*)SvIV(dataR);
  double **R = matR->data;

  int rowA = matA->rows;
  int colA = matA->cols;
  int rowB = matB->rows;
  int colB = matB->cols;

  int i,j,k,l;

  for(i=0; i < rowA; i++) {
    int iOffset = i * rowB;
    for(j=0; j < colA; j++) {
      int jOffset = j * colB;
      for(k=0; k < rowB; k++) {
	for(l=0; l < colB; l++) {
	  R[iOffset+k][jOffset+l] = A[i][j] * B[k][l];
	}
      }
    }
  }
}

void khatrirao_product(SV *dataA, SV *dataB, SV *dataR) {

  Matrix* matA = (Matrix*)SvIV(dataA);
  double **A = matA->data;
  Matrix* matB = (Matrix*)SvIV(dataB);
  double **B = matB->data;
  Matrix* matR = (Matrix*)SvIV(dataR);
  double **R = matR->data;

  int rowA = matA->rows;
  int colA = matA->cols;
  int rowB = matB->rows;
  int colB = matB->cols;

  int i,j,k,l;

  for(i=0; i < rowA; i++) {
    int iOffset = i * rowB;
    for(j=0; j < colA; j++) {
      for(k=0; k < rowB; k++) {
	R[iOffset+k][j] = A[i][j] * B[k][j];
      }
    }
  }
}

