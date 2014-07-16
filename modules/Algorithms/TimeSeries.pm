
# Author: jkh1
# 2010-02-08

=head1 NAME

 Algorithms::TimeSeries

=head1 SYNOPSIS



=head1 DESCRIPTION

 A time series is a matrix where rows represent time points and columns
 represent variables.

 Some subroutines were adapted from the econometrics toolbox for Matlab by
 James P. LeSage (http://www.spatial-econometrics.com/).

=head1 CONTACT

 heriche@embl.de

=cut

package Algorithms::TimeSeries;

our $VERSION = '0.01';
use 5.006;
use strict;
use warnings;
use Inline ( C =>'DATA',
	     NAME =>'Algorithms::TimeSeries',
	     DIRECTORY => '',
#	     VERSION => '0.01'
	   );
use Carp;
use base ("Algorithms::Matrix");


=head2 new

 Arg1: integer, number of rows (time points)
 Arg2: integer, number of columns (variables)
 Description: Creates a new TimeSeries object.
 Returntype: TimeSeries object

=cut

sub new {

  my ($class,$m,$n) = @_;
  if (!defined($m) || $m<=0) {
    croak "\nERROR: Number of time points required (m = $m)";
  }
  if (!defined($n) || $n<=0) {
    croak "\nERROR: Number of variables required (n = $n)";
  }
  my $self = Algorithms::Matrix->new($m,$n);
  bless ($self, $class);

  return $self;
}

=head2 new_from_matrix

 Arg: Algorithms::Matrix object
 Description: Turns a Matrix object into a TimeSeries object.
 Returntype: TimeSeries object

=cut

sub new_from_matrix {

  my ($class,$matrix) = @_;

  bless ($matrix, $class);

  return $matrix;
}

=head2 align

 Arg1: TimeSeries object
 Arg2: (optional), set alignment=>1 to return the alignment as a string and
       the corresponding score,
       set algorithm=>'derivative' to use derivative DTW
 Description: Aligns 2 TimeSeries objects with dynamic time warping.
              Implements a symmetric time warping as in: Clote and Straubhaar,
              J Math Biol. 2006 Jul;53(1):135-61 using euclidian distance.
              Derivative dynamic time warping is as in: Keogh and Pazzani
              (2001), Derivative Dynamic Time Warping. In First SIAM
              International Conference on Data Mining (SDM'2001).
 Returntype: double or list (string,double) if alignment requested

=cut

sub align {

  my ($self,$T,%param) = @_;

  my $alignment = $param{'alignment'} || '';
  my $algorithm = $param{'algorithm'} || '';

  my ($m1,$n1) = $self->dims;
  my ($m2,$n2) = $T->dims;
  if ($n1 != $n2) {
    croak "\nERROR: Time series do not have the same number of variables";
  }
  # Padding on both side for symmetric time warping
  my $t0 = $self->row(0);
  my $T1 = $t0->bind($self,row=>1);
  my $tm = $self->row($m1-1);
  $T1 = $T1->bind($tm,row=>1);
  $t0 = $T->row(0);
  my $T2 = $t0->bind($T,row=>1);
  $tm = $T->row($m1-1);
  $T2 = $T2->bind($tm,row=>1);

  my $lx = $m1+1;
  my $ly = $m2+1;
  my $score = Algorithms::Matrix->new($lx,$ly)->zero; # matrix for the scores
  my $trace = Algorithms::Matrix->new($lx,$ly)->zero; # matrix for the traceback
  # Fill first column of the score and traceback matrices
  my $tb = $T2->row(0);
  foreach my $i (1..$lx-1) {
    my $ta = $T1->row($i);
    my $d = $ta->bind($tb,row=>1);
    $d = $d->get_distances('euclidean',overwrite=>1);
    my $s = $score->get($i-1,0) + 0.5 * sqrt($d->get(0,1));
    $score->set($i,0,$s);
    $trace->set($i,0,1); # 1=V, 2=D, 3=H
  }
  # Fill first row of the score and traceback matrices
  $tb = $T1->row(0);
  foreach my $j (1..$ly-1) {
    my $ta = $T2->row($j);
    my $d = $tb->bind($ta,row=>1);
    $d = $d->get_distances('euclidean',overwrite=>1);
    my $s = $score->get(0,$j-1) + 0.5 * sqrt($d->get(0,1));
    $score->set(0,$j,$s);
    $trace->set(0,$j,3); # 1=V, 2=D, 3=H
  }
  # Fill the rest of the matrices
  if ($algorithm eq 'derivative') {
    ddtw($score->{'data'},$trace->{'data'},$T1->{'data'},$T2->{'data'},$n1);
  }
  else {
    dtw($score->{'data'},$trace->{'data'},$T1->{'data'},$T2->{'data'},$n1);
  }
  # Trace back to get alignment
  my $i = $lx-1; # -1 because of padding
  my $j = $ly-1;
  my $S = $score->get($i,$j);
  my @alnX;
  my @alnY;
  my $done = 0;
  while (!$done) {
    if ($i==0) {
      # Time point 0 is same as time point 1 because of padding
      push @alnX,1;
    }
    else {
      push @alnX,$i;
    }
    if ($j==0) {
      push @alnY,1;
    }
    else {
      push @alnY,$j;
    }
    if ($trace->get($i,$j) == 2) {
      $i--;
      $j--;
    }
    elsif ($trace->get($i,$j) == 1) {
      $i--;
    }
    elsif ($trace->get($i,$j) == 3) {
      $j--;
    }
    if ($i<=0 && $j<=0) {
      $done = 1;
    }
  }
  $S = $S/scalar(@alnX);
  if ($alignment) {
    my $aln = join(",",reverse(@alnX))."\n".join(",",reverse(@alnY));
    return ($aln,$S);
  }
  else {
    return $S;
  }
}

=head2 detrend

 Arg: integer, polynomial order p
 Description: Detrends a time-series using regression against a polynomial
              of order given by Arg. Returns time series of residuals from
              the detrending regression.
              Note: each variable is treated independently.
              Adapted from the econometrics toolbox.
 Returntype: TimeSeries object

=cut

sub detrend {

  my ($self,$p) = @_;
  if ($p<0) {
    croak "\nERROR: order p must be non-negative";
  }
  my ($n,undef) = $self->dims;
  my $u = Algorithms::TimeSeries->new($n,1)->one;
  my $xmat;
  if ($p > 0) {
    my $timep = Algorithms::TimeSeries->new($n,$p)->zero;
    my $tp = Algorithms::TimeSeries->new($n,1);
    foreach my $j(0..$p-1) {
      foreach my $i(0..$n-1) {
	$timep->set($i,$j,(($i+1)/$n)**($j+1));
      }
    }
    $xmat = $u->bind($timep,column=>1);
  }
  else {
    $xmat = $u;
  }
  my $xpxi = $xmat->transpose*$xmat;
  $xpxi = $xpxi->inverse(overwrite=>1);
  my $beta = $xpxi*($xmat->transpose*$self);
  my $resid = $self - $xmat*$beta;

  return $resid;
}

=head2 tdiff

 Arg: integer, difference order k
 Description: Performs differencing of order k (X(t) - X(t-k)).
              First k time points become 0.
              Note: each variable is treated independently.
              Adapted from the econometrics toolbox.
 Returntype: TimeSeries object

=cut

sub tdiff {

  my ($self,$k) = @_;
  if ($k<0) {
    croak "\nERROR: order k must be non-negative";
  }
  my ($m,$n) = $self->dims;
  if ($k>=$m) {
    croak "\nERROR: order k must be less than number of time points";
  }
  my $dmat;
  if ($k == 0) {
    $dmat = $self;
  }
  else {
    $dmat = Algorithms::TimeSeries->new($m,$n)->zero;
    diffk($self->{'data'},$dmat->{'data'},$k);
  }

  return $dmat;
}

=head2 autocovariance

 Arg1: integer, maximum lag
 Arg2: (optional), set overwrite=>1 to reuse original matrix
 Description: Computes the autocovariance of the time series.
              Note: each variable is treated independently.
              If overwrite is set to 1, original matrix will be centered.
 Returntype: TimeSeries object

=cut

sub autocovariance {

  my $self = shift;
  my $k = shift;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  if (!defined($k)) {
    $k = $m-1;
  }
  if ($k<0) {
    croak "\nERROR: maximum lag must be non-negative";
  }
  if ($k>=$m) {
    croak "\nERROR: maximum lag must be less than number of time points";
  }
  my $ac = Algorithms::TimeSeries->new($k,$n)->zero;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    autocov($self->{'data'},$k,$ac->{'data'});
  }
  else {
    my $clone = $self->clone;
    # Set last arg=0 for autocovariance
    autocov($clone->{'data'},$k,$ac->{'data'},0);
  }
  return $ac;
}

=head2 autocorrelation

 Arg1: integer, maximum lag
 Arg2: (optional), set overwrite=>1 to reuse original matrix
 Description: Computes the autocorrelation of the time series.
              Note: each variable is treated independently.
              If overwrite is set to 1, original matrix will be standardized.
 Returntype: TimeSeries object

=cut

sub autocorrelation {

  my $self = shift;
  my $k = shift;
  my %param = @_ if (@_);
  my ($m,$n) = $self->dims;
  if (!defined($k)) {
    $k = $m-1;
  }
  if ($k<0) {
    croak "\nERROR: maximum lag must be non-negative";
  }
  if ($k>=$m) {
    croak "\nERROR: maximum lag must be less than number of time points";
  }
  my $ac = Algorithms::TimeSeries->new($k,$n)->zero;
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    autocov($self->{'data'},$k,$ac->{'data'});
  }
  else {
    my $clone = $self->clone;
    # Set last arg=1 for autocorrelation
    autocov($clone->{'data'},$k,$ac->{'data'},1);
  }
  return $ac;
}

=head2 crosscovariance

 Arg1: TimeSeries object
 Arg2: integer, lag
 Arg3: (optional) set wrap=>1 to consider that the time series are circular
 Description: Computes the crosscovariance of two time series for given lag.
              Note: each variable is treated independently and variables of the
              first series are compared to all variables of the second series.
 Returntype: Algorithms::Matrix object

=cut

sub crosscovariance {

  my $self = shift;
  my $B = shift;
  my $lag = shift;
  my %param = @_ if (@_);
  my $wrap = 0;
  if ($param{'wrap'}) {
    $wrap = 1;
  }
  my ($mA,$nA) = $self->dims;
  my ($mB,$nB) = $B->dims;
  my $R = Algorithms::Matrix->new($nA,$nB)->zero;
  # Set arg before last to 0 for crosscovariance
  crosscov($self->{'data'},$B->{'data'},$lag,$R->{'data'},0,$wrap);

  return $R;
}

=head2 crosscorrelation

 Arg1: TimeSeries object
 Arg2: integer, lag
 Arg3: (optional) set wrap=>1 to consider that the time series are circular
 Description: Computes the crosscorrelation of two time series for given lag.
              Note: each variable is treated independently and variables of the
              first series are compared to all variables of the second series.
 Returntype: Algorithms::Matrix object

=cut

sub crosscorrelation {

  my $self = shift;
  my $B = shift;
  my $lag = shift;
  my %param = @_ if (@_);
  my $wrap = 0;
  if ($param{'wrap'}) {
    $wrap = 1;
  }
  my ($mA,$nA) = $self->dims;
  my ($mB,$nB) = $B->dims;
  my $R = Algorithms::Matrix->new($nA,$nB)->zero;
  # Set arg before last to 1 for crosscorrelation
  crosscov($self->{'data'},$B->{'data'},$lag,$R->{'data'},1,$wrap);

  return $R;
}

=head2 moving_average

 Arg: integer, window size w (must be odd number)
 Description: Smooth the time series by taking a moving average
              Note: each variable is treated independently and
              the first and last (w-1)/2 time points are not treated.
 Returntype: Algorithms::TimeSeries object

=cut

sub moving_average {

  my $self = shift;
  my $w = shift;
  unless ($w%2) {
    croak "\nERROR: window size must be odd number";
  }
  my ($m,$n) = $self->dims;
  if ($w>$m) {
    croak "\nERROR: window size must be less than number of time points";
  }
  my $R = Algorithms::TimeSeries->new($m-($w-1),$n)->zero;
  mv_avg($self->{'data'},$R->{'data'},$w);

  return $R;
}

1;

__DATA__
__C__

typedef struct {
  double **data;
  int rows;
  int cols;
} Matrix;

double **deref_matrix(SV* data) {

  Matrix* M = (Matrix*)SvIV(data);
  double **mat = M->data;
  return mat;
}

void dtw(SV *scoreref, SV *traceref, SV *Xref, SV *Yref, int size){

  int i, j, k;
  double dir;
  double dist1, dist2, dist3, dist, d1, d2, d3;
  double **score = deref_matrix(scoreref);
  double **trace = deref_matrix(traceref);
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* Ym = (Matrix*)SvIV(Yref);
  double **Y = Ym->data;
  int lx = Xm->rows;
  int ly = Ym->rows;

  for(i=1; i<lx-1; i++) {
    for(j=1; j<ly-1; j++) {
      dir = 2.0; /* direction: 1= H, 2= D, 3= V */
      d1 = 0.0;
      d2 = 0.0;
      d3 = 0.0;
      /* Euclidean distance between 2 vectors */
      for(k=0; k<size; k++) {
	d1 += (X[i][k]-Y[j][k])*(X[i][k]-Y[j][k]);
	d2 += (X[i][k]-Y[j+1][k])*(X[i][k]-Y[j+1][k]);
	d3 += (X[i+1][k]-Y[j][k])*(X[i+1][k]-Y[j][k]);
      }
      d1 = sqrt(d1);
      d2 = sqrt(d2);
      d3 = sqrt(d3);
      dist1 = score[i-1][j] + 0.25*(d1+d2); /* H i.e. (i-1,j)*/
      dist2 = score[i-1][j-1] + d1;         /* D i.e. (i-1,j-1) */
      dist3 = score[i][j-1] + 0.25*(d1+d3); /* V i.e. (i,j-1) */
      if (dist3 <= dist2 && dist3 <= dist1) {
	dir = 3.0;
	dist = dist3;
      }
      if (dist1 <= dist2 && dist1 <= dist3) {
	dir = 1.0;
	dist = dist1;
      }
      if (dist2 <= dist1 && dist2 <= dist3) {
	dir = 2.0;
	dist = dist2;
      }
      score[i][j] = dist;
      trace[i][j] = dir;
    }
  }
}

void ddtw(SV *scoreref, SV *traceref, SV *Xref, SV *Yref, int size) {

  int i, j, k, a, b;
  double dir;
  double dist1, dist2, dist3, dist, d1, d2, d3;
  double **score = deref_matrix(scoreref);
  double **trace = deref_matrix(traceref);
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* Ym = (Matrix*)SvIV(Yref);
  double **Y = Ym->data;
  int lx = Xm->rows -1;
  int ly = Ym->rows -1;

  for(i=1; i<lx; i++) {
    a = i+2>lx ? lx : i+2;
    for(j=1; j<ly; j++) {
      b = j+2>ly ? ly : j+2;
      dir = 2.0; /* direction: 1= H, 2= D, 3= V */
      d1 = 0.0;
      d2 = 0.0;
      d3 = 0.0;
      /* Derivative distance between 2 vectors */
      for(k=0; k<size; k++) {
	d1 += (( (X[i][k]-X[i-1][k]) + (X[i+1][k]-X[i-1][k])/2 )/2
             - ( (Y[j][k]-Y[j-1][k]) + (Y[j+1][k]-Y[j-1][k])/2 )/2)
             *(( (X[i][k]-X[i-1][k]) + (X[i+1][k]-X[i-1][k])/2 )/2
             - ( (Y[j][k]-Y[j-1][k]) + (Y[j+1][k]-Y[j-1][k])/2 )/2);
	d2 += (( (X[i][k]-X[i-1][k]) + (X[i+1][k]-X[i-1][k])/2 )/2
             - ( (Y[j+1][k]-Y[j][k]) + (Y[b][k]-Y[j][k])/2 )/2)
             *(( (X[i][k]-X[i-1][k]) + (X[i+1][k]-X[i-1][k])/2 )/2
             - ( (Y[j+1][k]-Y[j][k]) + (Y[b][k]-Y[j][k])/2 )/2);
	d3 += (( (X[i+1][k]-X[i][k]) + (X[a][k]-X[i][k])/2 )/2
             - ( (Y[j][k]-Y[j-1][k]) + (Y[j+1][k]-Y[j-1][k])/2 )/2)
             *(( (X[i+1][k]-X[i][k]) + (X[a][k]-X[i][k])/2 )/2
             - ( (Y[j][k]-Y[j-1][k]) + (Y[j+1][k]-Y[j-1][k])/2 )/2);
      }
      d1 = sqrt(d1);
      d2 = sqrt(d2);
      d3 = sqrt(d3);
      dist1 = score[i-1][j] + 0.25*(d1+d2); /* H i.e. (i-1,j)*/
      dist2 = score[i-1][j-1] + d1;         /* D i.e. (i-1,j-1) */
      dist3 = score[i][j-1] + 0.25*(d1+d3); /* V i.e. (i,j-1) */
      if (dist3 <= dist2 && dist3 <= dist1) {
	dir = 3.0;
	dist = dist3;
      }
      if (dist1<= dist2 && dist1 <= dist3) {
	dir = 1.0;
	dist = dist1;
      }
      if (dist2 <= dist1 && dist2 <= dist3) {
	dir = 2.0;
	dist = dist2;
      }
      score[i][j] = dist;
      trace[i][j] = dir;
    }
  }
}

void diffk(SV *Xref, SV *DXref, int k) {

  int i, j;
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* DXm = (Matrix*)SvIV(DXref);
  double **DX = DXm->data;
  int nobs = Xm->rows;
  int nvar = Xm->cols;
  for(i=k; i<nobs; i++) {
    for(j=0; j<nvar; j++) {
      DX[i][j] = X[i][j] - X[i-k][j];
    }
  }
}

void autocov(SV *Xref, int maxlag, SV *ACref, int normalize){

  int i, j, k, t, lag;
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* ACm = (Matrix*)SvIV(ACref);
  double **AC = ACm->data;
  int ni = Xm->rows;
  int nj = Xm->cols;
  double *mean, *stddev, sum;
  double eps = 0.0000000000005;

  mean = (double *) malloc ((unsigned long) nj*sizeof(double));
  if (!mean) {
    croak("Memory allocation failure in autocov");
  }
  /* Calculate mean of column vectors of input data matrix */
  for (j = 0; j < nj; j++) {
    mean[j] = 0.0;
    for (i = 0; i < ni; i++) {
      mean[j] += X[i][j];
    }
    mean[j] /= (double)ni;
  }
  if (normalize) {
    stddev = (double *) malloc ((unsigned long) nj*sizeof(double));
    if (!stddev) {
      croak("Memory allocation failure in autocov");
    }
    /* Calculate standard deviations of columns */
    for (j = 0; j < nj; j++) {
      stddev[j] = 0.0;
      for (i = 0; i < ni; i++) {
	stddev[j] += ( ( X[i][j] - mean[j] ) *
		       ( X[i][j] - mean[j] )  );
      }
      stddev[j] /= ni;
      stddev[j] = sqrt(stddev[j]);
      /* handle near-zero std. dev. values */
      if (stddev[j] <= eps) stddev[j] = 1.0;
    }
    /* Center and reduce the column vectors. */
    for (i = 0; i < ni; i++) {
      for (j = 0; j < nj; j++) {
	X[i][j] = (X[i][j]-mean[j])/(sqrt(ni) * stddev[j]);
      }
    }
    free(stddev);
  }
  else {
    /* Center the column vectors. */
    for (i = 0; i < ni; i++) {
      for (j = 0; j < nj; j++) {
	X[i][j] = X[i][j]-mean[j];
      }
    }
  }
  free(mean);

  for (j=0;j<nj;j++) {
    for (lag=0;lag<maxlag;lag++) {
      sum = 0.0;
      for (t=lag;t<ni;t++) {
	sum += X[t][j]*X[t-lag][j];
      }
      AC[lag][j]=sum;
    }
  }
}

void crosscov(SV *Xref, SV *Yref, int lag, SV *Rref, int normalize, int wrap){

  int i,j,jX,jY;
  double *meanX, *meanY, *varX, *varY;
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* Ym = (Matrix*)SvIV(Yref);
  double **Y = Ym->data;
  Matrix* Rm = (Matrix*)SvIV(Rref);
  double **R = Rm->data;

  int nXi = Xm->rows;
  int nXj = Xm->cols;
  int nYi = Ym->rows;
  int nYj = Ym->cols;

  meanX = (double *) malloc ((unsigned long) nXj*sizeof(double));
  if (!meanX) {
    croak("Memory allocation failure in crosscov");
  }
  varX = (double *) malloc ((unsigned long) nXj*sizeof(double));
  if (!varX) {
    croak("Memory allocation failure in crosscov");
  }
  meanY = (double *) malloc ((unsigned long) nYj*sizeof(double));
  if (!meanY) {
    croak("Memory allocation failure in crosscov");
  }
  varY = (double *) malloc ((unsigned long) nYj*sizeof(double));
  if (!varY) {
    croak("Memory allocation failure in crosscov");
  }

  /* Calculate means and variances of column vectors of matrix X */
  for (j = 0; j < nXj; j++) {
    meanX[j] = 0.0;
    for (i = 0; i < nXi; i++) {
      meanX[j] += X[i][j];
    }
    meanX[j] /= (double)nXi;
  }
  for (j = 0; j < nXj; j++) {
    varX[j] = 0.0;
    for (i = 0; i < nXi; i++) {
      varX[j] += ( ( X[i][j] - meanX[j] ) *
		   ( X[i][j] - meanX[j] )  );
    }
    varX[j] /= (double)nXi;
  }
  /* Calculate means and variances of column vectors of matrix Y */
  for (j = 0; j < nYj; j++) {
    meanY[j] = 0.0;
    for (i = 0; i < nYi; i++) {
      meanY[j] += Y[i][j];
    }
    meanY[j] /= (double)nYi;
  }
  for (j = 0; j < nYj; j++) {
    varY[j] = 0.0;
    for (i = 0; i < nYi; i++) {
      varY[j] += ( ( Y[i][j] - meanY[j] ) *
		   ( Y[i][j] - meanY[j] )  );
    }
    varY[j] /= (double)nYi;
  }

  for (jX = 0; jX < nXj; jX++) {
    for (jY = 0; jY < nYj; jY++) {
      R[jX][jY] = 0.0;
      for (i = 0; i < nXi; i++) {
	j = i+lag;
	if (wrap) {
	  j %= nYi;
	}
	/* if no wrapping and out of range, ignore */
	if (j>=0 && j<nYi) {
	  R[jX][jY] += (X[i][jX]-meanX[jX])*(Y[j][jY]-meanY[jY]);
	}
      }
      R[jX][jY] = R[jX][jY]/nXi;
      if (normalize) {
	R[jX][jY] = R[jX][jY]/sqrt(varX[jX]*varY[jY]);
      }
    }
  }
  free(meanX);
  free(meanY);
  free(varX);
  free(varY);
}

void mv_avg(SV *Xref, SV *Rref, int w) {

  int i, j, k, t;
  Matrix* Xm = (Matrix*)SvIV(Xref);
  double **X = Xm->data;
  Matrix* Rm = (Matrix*)SvIV(Rref);
  double **R = Rm->data;
  int nobs = Xm->rows;
  int nvar = Xm->cols;
  k = (w-1)/2;
  for(i=k; i<(nobs-k); i++) {
    for(j=0; j<nvar; j++) {
      for(t=-k; t<=k; t++) {
	R[i-k][j] += X[i+t][j];
      }
      R[i-k][j] /= w;
    }
  }
}
