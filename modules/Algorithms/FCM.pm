# Author: jkh1
# 2007-06-24

=head1 NAME

 Algorithms::FCM

=head1 SYNOPSIS



=head1 DESCRIPTION

 Fuzzy C-means

=head1 CONTACT

 jkh1@sanger.ac.uk

=cut

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut


package Algorithms::FCM;

use strict;
use warnings;
use Inline ( C =>'DATA',
	     NAME =>'Algorithms::FCM',
	     DIRECTORY => '',
	   );
use Exporter;

our @ISA = ('Exporter');
our @EXPORT = qw(initialize_partition_matrix get_prototypes get_distances update_partition fuzzy_cmeans);


=head2 initialize_partition_matrix

 Arg1: integer, number of clusters
 Arg2: integer, number of objects
 Description: Initializes the partition matrix
 Returntype: reference to partition matrix

=cut

sub initialize_partition_matrix {

  my $C = shift;
  my $n = shift;
  my @partition_matrix;

#   for (my $j = 0; $j < $C; $j++){
#     for (my $i = 0; $i < $n; $i++){
#       $partition_matrix[$j][$i] = 0;
#     }
#   }
#   initialize($C,$n,\@partition_matrix);

  srand;
  my @column_sum;
  for (my $i = 0; $i < $C; $i++){
    for (my $j = 0; $j < $n; $j++){
      $partition_matrix[$i][$j] = rand;
      $column_sum[$j] += $partition_matrix[$i][$j];
    }
  }
  for (my $i = 0; $i < $C; $i++){
    for (my $j = 0; $j < $n; $j++){
      die "column [$j] sum is equal to zero\n"
        unless $column_sum[$j];
      $partition_matrix[$i][$j] /= $column_sum[$j];
    }
  }

  return \@partition_matrix;
}

=head2 get_prototypes

 Arg1: reference to data matrix (2D array)
 Arg2: reference to partition matrix
 Arg3: double, fuzzyfication factor (default: 2)
 Description: Calculates prototype of each cluster
 Returntype: reference to prototype matrix

=cut

sub get_prototypes {

  my $matrix = shift;
  my $partition = shift;
  my $fuzz = shift;
  $fuzz ||= 2;
  my $n = scalar(@$matrix);
  my $m = scalar(@{$matrix->[0]});
  my $c = scalar(@{$partition});
  my @prototypes;
  # allocate memory for matrix
  foreach my $j(0..$c-1) {
    foreach my $f(0..$m-1) {
      $prototypes[$j][$f] = 0;
    }
  }
  prototypes($matrix,$partition,$n,$m,$c,\@prototypes,$fuzz);

  return \@prototypes;

}

=head2 get_distances

 Arg1: reference to data matrix (2D array)
 Arg2: reference to partition matrix
 Arg3: reference to prototypes matrix
 Arg4: integer, distance measure to use:
       0: euclidean distance (default)
       1: Mahalanobis distance
       2: sum of partial (standardized) distances
 Description: Calculates distance matrix
 Returntype: reference to distance matrix

=cut

sub get_distances {

  my $data = shift;
  my $partition = shift;
  my $prototypes = shift;
  my $measure = shift;
  $measure ||= 0;
  my $n = scalar(@$data);
  my $m = scalar(@{$data->[0]});
  my $c = scalar(@{$partition});
  my @distances;
  # allocate memory for matrix
  foreach my $j(0..$c-1) {
    foreach my $i(0..$n-1) {
      $distances[$i][$j] = 0;
    }
  }

  if ($measure==1) {
    mahal_distances($data,$partition,$prototypes,$n,$m,$c,\@distances);
  }
  elsif ($measure==2) {
    sum_of_distances($data,$partition,$prototypes,$n,$m,$c,\@distances);
  }
  else {
    eucl_distances($data,$prototypes,$n,$m,$c,\@distances);
  }
  return \@distances;

}

=head2 update_partition

 Arg1: reference to distance matrix (2D array)
 Arg2: reference to partition matrix
 Arg3: double, tolerance for convergence (default:0.01)
 Arg4: double, fuzzification factor (default:2)
 Description: Calculates new partition matrix and checks if
              the new one is different from the previous one
 Returntype: reference to new partition matrix and
             integer: 1 if partition hasn't changed,
                      0 otherwise

=cut

sub update_partition {

  my $distance = shift;
  my $partition = shift;
  my $tolerance = shift;
  my $fuzz = shift;
  $tolerance ||= 0.01;
  $fuzz ||= 2;
  my $c = scalar(@{$partition});
  my $n = scalar(@{$partition->[0]});
  my @new_partition;
  foreach my $j(0..$c-1) {
    foreach my $i(0..$n-1) {
      $new_partition[$j][$i] = $$partition[$j][$i];
    }
  }
  my $term_flag = update($distance,$partition,$n,$c,\@new_partition,$tolerance,$fuzz);

  return (\@new_partition,$term_flag);

}

=head2 fuzzy_cmeans

 Arg1: reference to data matrix
 Arg2: integer, number of clusters (default=2)
 Arg3: integer, distance measure to use:
       0: euclidean distance (default)
       1: Mahalanobis distance
       2: sum of partial (standardized) distances
 Arg4: integer, maximum number of iterations, (default: 1000)
 Arg5: double, tolerance for convergence (default:0.01)
 Arg6: double, fuzzyfication factor (default:2)
 Description: fuzzy c-means clustering
 Returntype: list: reference to partition matrix,
             reference to prototypes matrix and
             number of iterations

=cut

sub fuzzy_cmeans {

  my $data = shift;
  my $number_of_clusters = shift;
  my $measure = shift;
  my $max_iter = shift;
  my $tolerance = shift;
  my $fuzz = shift;
  $number_of_clusters ||= 2;
  $measure ||= 0;
  $max_iter ||= 1000;
  $fuzz ||=2;
  my $N = scalar(@$data);
  my $m = scalar(@{$data->[0]});

  my ($partition,$prototypes,$distances);

  my $term_flag = 0;
  my $iter = 1;
  $partition = initialize_partition_matrix($number_of_clusters,$N);

  until ($term_flag) {
    $prototypes = get_prototypes($data,$partition,$fuzz);
    $distances = get_distances($data,$partition,$prototypes,$measure);
    ($partition,$term_flag) = update_partition($distances,$partition,$tolerance,$fuzz);
    $iter++;
    if ($iter>$max_iter) {
      $term_flag = 1;
    }
  }
  return ($partition,$prototypes,$iter);
}

1;

__DATA__
__C__

double *vector_alloc(int n) {
  /* Allocates a vector of size n. */

    double *v;

  v = (double *) malloc ((unsigned long) n*sizeof(double));
  if (!v) {
    fprintf(stderr,"Allocation failure in vector_alloc().");
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
    fprintf(stderr,"Memory allocation failure 1 in matrix_alloc().");
    exit(1);
  }

  /* Allocate rows and set pointers to them. */
    for (i = 0; i < ni; i++) {
      mat[i] = (double *) malloc((unsigned long) (nj)*sizeof(double));
      if (!mat[i]) {
	fprintf(stderr,"Memory allocation failure 2 in matrix_alloc().");
	exit(1);
      }
    }
  /* Return pointer to array of pointers to rows. */
    return mat;

}

void free_matrix(double **mat,int ni,int nj) {
  /* Free a matrix allocated by matrix_alloc(). */
    int i,j;
  for (i = 0; i < ni; i++) {
    free(mat[i]);
  }
  free(mat);
}

void initialize(int C, int n, SV* uref) {

  int i,j,f;
  AV *u;
  u = (AV*)SvRV(uref);
  SV **Uji;
  AV *Uj;
  double *sum;
  sum = (double *)vector_alloc(n);
  srand(1000);
  for(j = 0; j < C; j++) {
    Uj = (AV*)SvRV(*av_fetch(u, j, 0));
    for (i = 0; i < n; i++) {
      Uji = av_fetch(Uj, i, 0);
      double r = (   (double)rand() / ((double)(RAND_MAX)+1.0) );
      sv_setnv(*Uji,r);
      sum[i] += r;
    }
  }
  for(j = 0; j < C; j++) {
    Uj = (AV*)SvRV(*av_fetch(u, j, 0));
    for (i = 0; i < n; i++) { 
      Uji = av_fetch(Uj, i, 0);
      double tmp = SvNV(*Uji)/sum[i];
      sv_setnv(*Uji,tmp);
    }
  }
  free_vector(sum);
}


void prototypes(SV *dataref, SV *partitionref, int row, int col, int C, SV *prototyperef, double fuzz) {

  int i,j,f;
  AV *data, *prototype, *partition;
  SV **Xif, **Uji, **Pjf;
  AV *Xi, *Uj, *Pj;
  double sum_num, sum_den;
  data = (AV*)SvRV(dataref);
  partition = (AV*)SvRV(partitionref);
  prototype = (AV*)SvRV(prototyperef);

  for(j = 0; j < C; j++) {
    Uj = (AV*)SvRV(*av_fetch(partition, j, 0));
    Pj = (AV*)SvRV(*av_fetch(prototype, j, 0));
    for (f = 0; f < col; f++) {
      sum_num = 0.0;
      sum_den = 0.0;
      for (i = 0; i < row; i++) {
	Xi = (AV*)SvRV(*av_fetch(data, i, 0));
	Xif = av_fetch(Xi, f,0);
	Uji = av_fetch(Uj, i, 0);
	sum_num += pow(SvNV(*Uji),fuzz)*SvNV(*Xif); /*SvNV(*Uji)*SvNV(*Uji)*SvNV(*Xif);*/
	sum_den += pow(SvNV(*Uji),fuzz); /*SvNV(*Uji)*SvNV(*Uji);*/
      }
      Pjf = av_fetch(Pj,f,0);
      sv_setnv(*Pjf,sum_num/sum_den);
    }
  }
}

void covariance(SV *dataref, AV *partition, AV *prototype, int ni, int nj, double **cov) {

  AV *data;
  SV **Mij, **Mik, **Cjk, **Ckj, **Ui, **Pj;
  AV *Mi, *Cj, *Ck;
  double **centered;
  int i, j, k;
  data = (AV*)SvRV(dataref);
  centered = (double **)matrix_alloc(ni,nj);
  double sum = 0.0;

  /* Center the column vectors. */
  for (i = 0; i < ni; i++) {
    Mi = (AV*)SvRV(*av_fetch(data, i, 0));
    Ui = av_fetch(partition, i,0);
    sum += SvNV(*Ui)*SvNV(*Ui);

    for (j = 0; j < nj; j++) {
      Mij = av_fetch(Mi, j,0);
      Pj = av_fetch(prototype, j,0);
      centered[i][j] = SvNV(*Mij)-SvNV(*Pj);
    }
  }

  /* Calculate the nj * nj covariance matrix. */
  for (j = 0; j < nj; j++) {
    for (k = j; k < nj; k++) {
      for (i = 0; i < ni; i++) {
	Ui = av_fetch(partition, i,0);
	cov[j][k] += SvNV(*Ui)*SvNV(*Ui)*centered[i][j]*centered[i][k];
      }
      cov[j][k] /= sum;
      cov[k][j] = cov[j][k];
    }
  }
  free_matrix(centered,ni,nj);
}

double invert_matrix(double **M, int size) {

  int i, j, k, n;
  double D = 1.0;
  n = size;

  for(k=0; k<n; k++) {
    for(i=0; i<n; i++) {
      for(j=0; j<n; j++) {
	if( i!=k && j!=k ) {
	  M[i][j] -= M[k][j]*M[i][k]/M[k][k];
	}
      }
    }

    for(i=0; i<n; i++) {
      for(j=0; j<n; j++) {
	if( i==k && i!=j ) {
	  M[i][j] = -M[i][j]/M[k][k];
	}
      }
    }

    for(i=0; i<n; i++) {
      for(j=0; j<n; j++) {
	if( j==k && i!=j ) {
	  M[i][j] /= M[k][k];
	}
      }
    }
    D *= M[k][k];
    M[k][k] = 1.0/M[k][k];
  }

 return D;
}

double mahalanobis(AV *vectorX, AV *vectorY, double **invcov, int size) {

  int i,j,k;
  int row=1,col=size;
  double *C, *D, *M;
  double d = 0.0;

  C = (double *)vector_alloc(col);
  M = (double *)vector_alloc(col);

  /* X-Y */
  for( i = 0; i < col; i++ ) {
    double Xi = SvNV(*av_fetch(vectorX,i,0));
    double Yi = SvNV(*av_fetch(vectorY,i,0));
    C[i] = Xi-Yi;
  }

  /* (X-Y)'S */
  for( j = 0; j < col; j++) {
    M[j] = 0.0;
    for( k = 0; k < col; k++ ) {
      M[j] += (C[k] * invcov[k][j]);
    }
  }

  /* (X-Y)'S(X-Y) */
  for( k = 0; k < col; k++ ) {
    d += M[k] * C[k];
  }

  free_vector(C);
  free_vector(M);

  return(d);
}

void eucl_distances(SV *dataref, SV *prototyperef, int rows, int cols, int C, SV *distanceref) {
  int i,j, k;
  AV *Xi, *Di, *Pj, *Uj, *data, *prototype, *distance;
  SV **Dij;
  double xk, yk, dist;
  data = (AV*)SvRV(dataref);
  prototype = (AV*)SvRV(prototyperef);
  distance = (AV*)SvRV(distanceref);

  for (j = 0; j < C; j++) {
    Pj = (AV*)SvRV(*av_fetch(prototype,j,0));
    for (i = 0; i < rows; i++) {
      Di = (AV*)SvRV(*av_fetch(distance,i,0));
      Dij = av_fetch(Di, j,0);
      Xi = (AV*)SvRV(*av_fetch(data,i,0));
      dist = 0.0;
      for(k=0; k<cols; k++) {
	double xk = SvNV(*av_fetch(Xi,k,0));
	double yk = SvNV(*av_fetch(Pj,k,0));
	dist += (xk-yk)*(xk-yk);
      }
      sv_setnv(*Dij,sqrt(dist));
    }
  }
}

void mahal_distances(SV *dataref, SV *partitionref, SV *prototyperef, int rows, int cols, int C, SV *distanceref) {

  int i,j;
  AV *data, *partition, *prototype, *dist;
  AV *Xi,*Di, *Pj, *Uj;
  SV **Dij;
  double **cov;
  double det, tmp;
  data = (AV*)SvRV(dataref);
  partition= (AV*)SvRV(partitionref);
  prototype = (AV*)SvRV(prototyperef);
  dist = (AV*)SvRV(distanceref);
  cov = (double **)matrix_alloc(cols,cols);

  for (j = 0; j < C; j++) {
    Pj = (AV*)SvRV(*av_fetch(prototype,j,0));
    Uj = (AV*)SvRV(*av_fetch(partition,j,0));
    covariance(dataref,Uj,Pj,rows,cols,cov);
    det = invert_matrix(cov,cols);
    if (det<=0 || isnan(det)) {
      /* fprintf(stderr,"Covariance matrix of cluster %d is not positive definite.\n",j); */
      j++;
    }
    else {
      for (i = 0; i < rows; i++) {
	Xi = (AV*)SvRV(*av_fetch(data,i,0));
	tmp = sqrt(det)*mahalanobis(Xi,Pj,cov,cols);
	Di = (AV*)SvRV(*av_fetch(dist,i,0));
	Dij = av_fetch(Di, j,0);
	sv_setnv(*Dij,tmp);
      }
    }
  }
  free_matrix(cov,cols,cols);
}

void sum_of_distances(SV *dataref, SV *partitionref, SV *prototyperef, int rows, int cols, int C, SV *distanceref) {

  /* uses sum of partial distances */
  int f,i,j;
  double **var;
  double sum, usum, tmp;
  double eps = 0.00000000000005;
  AV *data, *cluster, *membership, *distance;
  SV **Xif,**Cjf, **Uji, **Dij;
  AV *Xi, *Uj, *Cj, *Di;
  data = (AV*)SvRV(dataref);
  cluster = (AV*)SvRV(prototyperef);
  membership = (AV*)SvRV(partitionref);
  distance = (AV*)SvRV(distanceref);
  var = (double **)matrix_alloc(C,cols);

  /* Calculate fuzzy variance of each feature in each cluster */
  for(j = 0; j < C; j++) {
    Uj = (AV*)SvRV(*av_fetch(membership, j, 0));
    Cj = (AV*)SvRV(*av_fetch(cluster, j, 0));
    usum = 0;
    for (f = 0; f < cols; f++) {
      sum = 0.0;
      var[j][f] = 0.0;
      for (i = 0; i < rows; i++) {
	Xi = (AV*)SvRV(*av_fetch(data, i, 0));
	Xif = av_fetch(Xi, f,0);
	Cjf = av_fetch(Cj, f,0);
	Uji = av_fetch(Uj, i,0);
	var[j][f] += SvNV(*Uji)*SvNV(*Uji)*(SvNV(*Xif)-SvNV(*Cjf))*(SvNV(*Xif)-SvNV(*Cjf));
	usum += SvNV(*Uji)*SvNV(*Uji);
      }
      if (usum == 0.0) {
	var[j][f] = 0.0;
      }
      else {
	var[j][f] /= (double)usum;
      }
    }
  }

  for (j = 0; j < C; j++) {
    Cj = (AV*)SvRV(*av_fetch(cluster,j,0));
    for (i = 0; i < rows; i++) {
      tmp = 0.0;
      /* getting partial distances */
      for(f=0; f<cols; f++) {
	Xi = (AV*)SvRV(*av_fetch(data,i,0));
	Xif = av_fetch(Xi, f,0);
	Cjf = av_fetch(Cj, f,0);
	if (var[j][f] <= eps) var[j][f] = eps; /* for near-zero variances */
	tmp += sqrt((SvNV(*Xif)-SvNV(*Cjf))*(SvNV(*Xif)-SvNV(*Cjf))/var[j][f]);
      }
      Di = (AV*)SvRV(*av_fetch(distance,i,0));
      Dij = av_fetch(Di, j,0);
      sv_setnv(*Dij,tmp/cols);
    }
  }
  free_matrix(var,C,cols);
}


int update(SV *distanceref, SV *oldpartitionref, int n, int C, SV *partitionref, double tolerance, double fuzz) {

  int i,j,k;
  int term_flag = 0;
  AV *oldpartition, *distance, *partition;
  SV **oUji, **Dij, **Dik, **Uji;
  AV *oUj, *Uj, *Di;
  double sum, dif, max_dif;
  oldpartition = (AV*)SvRV(oldpartitionref);
  partition = (AV*)SvRV(partitionref);
  distance = (AV*)SvRV(distanceref);
  fuzz = 2.0/(fuzz-1.0);

  for (j = 0; j < C; j++) {
    Uj = (AV*)SvRV(*av_fetch(partition, j, 0));
    for (i = 0; i < n; i++) {
      sum = 0.0;
      Uji = av_fetch(Uj, i,0);
      Di = (AV*)SvRV(*av_fetch(distance,i,0));
      Dij= av_fetch(Di, j,0);
      if ( SvNV(*Dij) == 0.0 ) {
	sv_setnv(*Uji,1.0);
      }
      else {
	for (k = 0; k < C; k++) {
	  Dik= av_fetch(Di, k,0);
	  if ( SvNV(*Dik) != 0.0 ) {
	    double tmp = SvNV(*Dij)/SvNV(*Dik);
	    sum += pow(tmp,fuzz); /*(SvNV(*Dij)*SvNV(*Dij)) (SvNV(*Dik)*SvNV(*Dik));*/
	  }
	}
	if (sum != 0.0) {
	  sv_setnv(*Uji,1.0/sum);
	}
      }
    }
  }

  /*check if partition hasn't changed */
  max_dif = 0.0;
  for (j = 0; j < C; j++){
    Uj = (AV*)SvRV(*av_fetch(partition, j, 0));
    oUj = (AV*)SvRV(*av_fetch(oldpartition, j, 0));
    for (i = 0; i < n; i++){
      Uji = av_fetch(Uj, i,0);
      oUji = av_fetch(oUj, i,0);
      dif = fabs( SvNV(*Uji) - SvNV(*oUji) );
      if (dif > max_dif) {
	max_dif = dif;
      }
      if ( max_dif >= tolerance ) {
	j = C;
      }
    }
  }
  if (max_dif< tolerance) term_flag = 1;
  return term_flag;
}


