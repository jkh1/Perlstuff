# Author: jkh1
# 2016-01-13

=head1 NAME

 Algorithms::GMM

=head1 SYNOPSIS

 # Read data set from tab-delimited file with row and column headers
 my ($data,$row_labels,$col_labels) = Algorithms::Matrix->load_matrix("data_file.txt","\t",1,1);

 # Create GMM object
 my $gmm = Algorithms::GMM->new('data'=>$data, 'k'=>3, 'covariance'=>'full');

 # k-means clustering
 my @cluster_idx = $gmm->kmeans();

 # GMM-based clustering
 $gmm->initialize('kmeans');
 $gmm->expectation_maximization();
 my @cluster_idx = $gmm->naive_Bayes_classifier();

=head1 DESCRIPTION

 Gaussian mixture modeling with the expectation-maximization algorithm.

=head1 CONTACT

 heriche@embl.de

=cut

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

package Algorithms::GMM;

our $VERSION = '0.01';
use 5.006;
use strict;
use warnings;
use Algorithms::Matrix;
use Carp;

my $PI = 3.1415926535897932384626;
my $eps = 1e-16;

=head2 new

 Arg: hash with the following parameters:
      data       => Algorithms::Matrix, data (required)
      k          => integer, number of clusters (required)
      priors     => Algorithms::Matrix (with one row, k columns),
                    cluster priors (default to uniform 1/k)
      covariance => string, structure of the covariance matrices,
                    one of 'full' (default) or 'diagonal'
      maxIter    => integer, maximum number of iterations for the EM
                    and k-means algorithms (default: 100)
 Description: Creates a new GMM object.
 Returntype: Algorithms::GMM object

=cut

sub new {

  my ($class,%params) = @_;
  unless ($params{'data'} && $params{'k'}) {
    croak "\nERROR: Data and number of clusters required.\n";
  }
  my ($m,$n) = $params{'data'}->dims;
  if ($n<2) {
    croak "\nERROR: Data must be multivariate.\n";
  }
  my $limit = 2 * $params{'k'}**2;
  if ( $m < $limit ) {
    carp "WARNING: Small sample size: number of data points should be greater than $limit for $params{'k'} clusters.\n";
  }
  my $self = {};
  $self->{'data'} = $params{'data'};
  $self->{'k'} = $params{'k'};
  $self->{'maxIter'} = $params{'maxIter'} || 100;
  bless ($self, $class);
  if (defined($params{'priors'})) {
    if ($params{'priors'}->row_sum(0) < 0.999999) {
      croak "\nERROR: Cluster priors don't sum to 1.\n";
    }
    $self->cluster_priors($params{'priors'});
  }
  else {
    $self->cluster_priors(Algorithms::Matrix->new(1,$params{'k'})->one * 1/$params{'k'});
  }
  $self->{'diagonal_covariance'} = 0;
  if ($params{'covariance'} && $params{'covariance'} eq 'diagonal') {
    $self->{'diagonal_covariance'} = 1;
  }
  $self->{'initialized'} = 0;
  $self->{'EM_has_run'} = 0;
  return $self;
}

=head2 initialize

 Description: Initializes the clusters with random data points
 Returntype: GMM object

=cut

sub initialize {
  my $self = shift;
  my $mode = shift || 'random';
  my $k = $self->{'k'};
  my ($m,$n) = $self->{'data'}->dims;
  $self->{'cluster_means'} = Algorithms::Matrix->new($k,$n);
  if ($mode eq 'random') {
    foreach my $c(0..$k-1) {
      # Select random data points as cluster means
      my $r = int(rand($m));
      my $mean = $self->{'data'}->row($r);
      $self->{'cluster_means'}->set_rows([$c],$mean);
      # Use data covariance as cluster covariance
      my $cov = $self->{'data'}->covariance();
      if ($self->{'diagonal_covariance'}) {
	$cov = $cov->diag->diag;
      }
      push @{$self->{'cluster_covariances'}},$cov;
    }
  }
  elsif ($mode eq 'kmeans') {
    $self->kmeans;
    foreach my $c(0..$k-1) {
      # Get cluster covariance
      my $cov = Algorithms::Matrix->new($n,$n)->zero;
      my $mean = $self->{'cluster_means'}->row($c);
      foreach my $i(0..$m-1) {
	my $r = $self->{'data'}->row($i) - $mean;
	if ($self->{'diagonal_covariance'}) {
	  my $var = $self->{'cluster_memberships'}->get($i,$c) * ($r x $r);
	  $cov += $var->diag;
	}
	else {
	  $cov += $self->{'cluster_memberships'}->get($i,$c) * ($r->transpose * $r);
	}
      }
      $self->{'cluster_covariances'}->[$c] = $cov / $self->{'cluster_memberships'}->col_sum($c);
    }
  }
  else {
    croak "\nERROR: Unknown initialization mode. Use either random or kmeans.\n";
  }
  $self->{'initialized'} = 1;
  return $self;
}

=head2 cluster_means

 Arg: (optional) Algorithms::Matrix with one row
 Description: Gets/sets mean of each cluster
 Returntype: Algorithms::Matrix (with one row)

=cut

sub cluster_means {
  my $self = shift;
  if (@_) {
    $self->{'cluster_means'} = shift;
  }
  return $self->{'cluster_means'};
}

=head2 cluster_covariances

 Arg: (optional) list of Algorithms::Matrix
 Description: Gets/sets covariance matrices of all clusters
 Returntype: list of Algorithms::Matrix

=cut

sub cluster_covariances {
  my $self = shift;
  if (@_) {
    @{$self->{'cluster_covariances'}} = @_;
  }
  return @{$self->{'cluster_covariances'}};
}

=head2 cluster_priors

 Arg: (optional) Algorithms::Matrix with one row
 Description: Gets/sets priors for the clusters. They represent the
              probabilities that a random data point was generated by
              each cluster.
 Returntype: Algorithms::Matrix (with one row)

=cut

sub cluster_priors {
  my $self = shift;
  if (@_) {
    $self->{'cluster_priors'} = shift;
  }
  return $self->{'cluster_priors'};
}

=head2 cluster_memberships

 Arg: (optional) Algorithms::Matrix
 Description: Gets/sets the cluster memberships of all data point
 Returntype: Algorithms::Matrix

=cut

sub cluster_memberships {
  my $self = shift;
  if (@_) {
    $self->{'cluster_memberships'} = shift;
  }
  return $self->{'cluster_memberships'};
}

=head2 expectation_maximization

 Description: EM algorithm.
 Returntype: Algorithms::GMM

=cut

sub expectation_maximization {

  my $self = shift;
  unless ($self->{'initialized'}) {
    croak "\nERROR: GMM must be initialized first.\n";
  }
  my $maxIter = $self->{'maxIter'};
  my $iter = 0;
  my ($m,$n) = $self->{'data'}->dims;
  my $k = $self->{'k'};
  $self->{'cluster_probabilities'} = Algorithms::Matrix->new($m,$k)->zero;
  $self->{'cluster_memberships'} = Algorithms::Matrix->new($m,$k)->zero;
  my $previous_means;
  my $old_likelihood;
  my $done = 0;
  while (!$done) {
    $iter++;
    # E-step: get probability of each point belonging to each cluster
    foreach my $c(0..$k-1) {
      my $mean = $self->{'cluster_means'}->row($c);
      my $cov = $self->{'cluster_covariances'}->[$c];
      my $det = $cov->det();
      if ($det<=$eps) {
	# Fix covariance matrix by adding 10% of the max diagonal element
	# to the diagonal
	my $max = $cov->diag->max;
	my $I = Algorithms::Matrix->new($n,$n)->identity * 0.1 * $max;
	$cov = $cov + $I;
	$det = $cov->det();
      }
      my $invcov = $cov->inverse();
      foreach my $i(0..$m-1) {
	my $row = $self->{'data'}->row($i) - $mean;
	my $exp = -0.5*($row * $invcov * $row->transpose);
	my $coef = 1/sqrt( ((2 * $PI)**$n) * $det );
	my $p = $coef * exp($exp->get(0,0));
	$self->{'cluster_probabilities'}->set($i,$c,$p);
      }
    }
    # Get cluster membership for each data point
    foreach my $i(0..$m-1) {
      my $p = $self->{'cluster_probabilities'}->row($i) x $self->{'cluster_priors'};
      my $s = $p->row_sum(0);
      $p = $p / $s;
      $self->{'cluster_memberships'}->set_rows([$i],$p);
    }
    # M-step: update parameters
    # Update priors
    $self->{'cluster_priors'} = $self->{'cluster_memberships'}->col_sums / $m;
    # Update means and covariances
    my $means = $self->{'cluster_memberships'}->transpose * $self->{'data'};
    foreach my $c(0..$k-1) {
      # Update cluster mean
      my $mean = $means->row($c);
      $mean = $mean / $self->{'cluster_memberships'}->col_sum($c);
      $self->{'cluster_means'}->set_rows([$c],$mean);
      # Update cluster covariance
      my $cov = Algorithms::Matrix->new($n,$n)->zero;
      foreach my $i(0..$m-1) {
	my $r = $self->{'data'}->row($i) - $mean;
	if ($self->{'diagonal_covariance'}) {
	  my $var = $self->{'cluster_memberships'}->get($i,$c) * ($r x $r);
	  $cov += $var->diag;
	}
	else {
	  $cov += $self->{'cluster_memberships'}->get($i,$c) * ($r->transpose * $r);
	}
      }
      $self->{'cluster_covariances'}->[$c] = $cov / $self->{'cluster_memberships'}->col_sum($c);
    }
    # Check convergence
    my $likelihood = $self->log_likelihood;
    if ($iter>1) {
      my $diff = 1 - ($likelihood / $old_likelihood);
      if ($diff<=1e-9 || $iter>=$maxIter) {
      	$done = 1;
      }
    }
    $old_likelihood = $likelihood;
  }
  $self->{'EM_has_run'} = 1;
  return $self;
}

=head2 log_likelihood

 Description: Gets log-likelihood of the data
 Returntype: double

=cut

sub log_likelihood {
  my $self = shift;
  unless ($self->{'EM_has_run'}) {
    croak "\nERROR: EM algorithm must be run before calling log_likelihood().\n";
  }
  my ($m,$n) = $self->{'data'}->dims;
  my $k = $self->{'k'};
  my $log_likelihood = 0;
  my @invcov;
  my @det;
  foreach my $c(0..$k-1) {
    my $cov = $self->{'cluster_covariances'}->[$c];
    my $det = $cov->det();
    if ($det<=$eps) {
      my $max = $cov->diag->max;
      my $I = Algorithms::Matrix->new($n,$n)->identity * 0.1 * $max;
      $cov = $cov + $I;
      $det = $cov->det();
    }
    push @det,$det;
    push @invcov,$cov->inverse();
  }
  foreach my $i(0..$m-1) {
    my $l = 0;
    foreach my $c(0..$k-1) {
      my $mean = $self->{'cluster_means'}->row($c);
      my $row = $self->{'data'}->row($i) - $mean;
      my $exp = -0.5*($row * $invcov[$c] * $row->transpose);
      my $coef = 1/sqrt(((2 * $PI)**$n)*$det[$c]);
      my $p = $coef * exp($exp->get(0,0));
      $l += $p * $self->{'cluster_priors'}->get(0,$c);
    }
    $log_likelihood += log($l);
  }
  return $log_likelihood;
}

=head2 get_posterior_log_likelihoods

 Description: Gets posterior log-likelihood of each data point
 Returntype: list of Algorithms::Matrix (with one row)

=cut

sub get_posterior_log_likelihoods {
  my $self = shift;
  unless ($self->{'EM_has_run'}) {
    croak "\nERROR: EM algorithm must be run before calling get_posterior_log_likelihoods().\n";
  }
  my ($m,$n) = $self->{'data'}->dims;
  my $k = $self->{'k'};
  my @posterior_log_likelihoods;
  my @invcov;
  foreach my $c(0..$k-1) {
    my $cov = $self->{'cluster_covariances'}->[$c];
    my $det = $cov->det();
    if ($det<=$eps) {
      my $max = $cov->diag->max;
      my $I = Algorithms::Matrix->new($n,$n)->identity * 0.1 * $max;
      $cov = $cov + $I;
      $det = $cov->det();
    }
    push @invcov,$cov->inverse();
  }
  foreach my $i(0..$m-1) {
    my $loglikelihoods = Algorithms::Matrix->new(1,$k)->zero;
    foreach my $c(0..$k-1) {
      my $mean = $self->{'cluster_means'}->row($c);
      my $r = $self->{'data'}->row($i) - $mean;
      my $ll = -0.5*($r * $invcov[$c] * $r->transpose);
      $ll = $ll->get(0,0) + log($self->{'cluster_priors'}->get(0,$c));
      $loglikelihoods->set(0,$c,$ll);
    }
    push @posterior_log_likelihoods, $loglikelihoods;
  }
  return @posterior_log_likelihoods;
}

=head2 naive_Bayes_classifier

 Description: Hard clustering of data points using naive Bayes classifier.
              Returns index of cluster for each data point.
 Returntype: list of integers

=cut

sub naive_Bayes_classifier {
  my $self = shift;
  unless ($self->{'EM_has_run'}) {
    croak "\nERROR: EM algorithm must be run before calling naive_Bayes_classifier().\n";
  }
  my $k = $self->{'k'};
  my @cluster_indices;
  my @posterior_log_likelihoods = $self->get_posterior_log_likelihoods();
  foreach my $i(0..$#posterior_log_likelihoods) {
    my $ll = $posterior_log_likelihoods[$i];
    my $max = $ll->get(0,0);
    my $idx = 0;
    foreach my $c(1..$k-1) {
      if ($ll->get(0,$c)>$max) {
	$max = $ll->get(0,$c);
	$idx = $c;
      }
    }
    push @cluster_indices, $idx;
  }
  return @cluster_indices;
}

=head2 kmeans

 Description: k-means clustering. Returns index of cluster for each data point.
 Returntype: list of integers

=cut

sub kmeans {
  my $self = shift;
  my ($m,$n) = $self->{'data'}->dims;
  my $k = $self->{'k'};
  my $maxIter = $self->{'maxIter'};
  my $previous_means;
  $self->{'cluster_means'} = Algorithms::Matrix->new($k,$n);
  $self->{'cluster_memberships'} = Algorithms::Matrix->new($m,$k)->zero;
  # Initialize
  foreach my $c(0..$k-1) {
    # Select random data point as cluster mean
    my $r = int(rand($m));
    my $mean = $self->{'data'}->row($r);
    $self->{'cluster_means'}->set_rows([$c],$mean);
  }
  my $done = 0;
  my $iter = 0;
  my @cluster_indices;
  while (!$done) {
    $iter++;
    foreach my $i(0..$m-1) {
      # Assign point to closest mean
      my $x = $self->{'data'}->row($i)->transpose;
      my $min = 1e308;
      foreach my $c(0..$k-1) {
	my $y = $self->{'cluster_means'}->row($c)->transpose;
	my $d = $x->euclidean_distances($y)->get(0,0);
	if ($d < $min) {
	  $cluster_indices[$i] = $c;
	  $min = $d;
	}
      }
    }
    # Update means
    $previous_means = $self->{'cluster_means'}->clone;
    foreach my $c(0..$k-1) {
      my $sum = Algorithms::Matrix->new(1,$n)->zero;
      my $count = 0;
      foreach my $i(0..$m-1) {
	if ($cluster_indices[$i] == $c) {
	  $sum = $sum + $self->{'data'}->row($i);
	  $count++;
	}
      }
      if ($count) {
	$sum = $sum / $count;
      }
      $self->{'cluster_means'}->set_rows([$c],$sum);
    }
    # Check convergence
    my $diff = $previous_means - $self->{'cluster_means'};
    if ($diff->abs->max < $eps || $iter > $maxIter) {
      # Stop if means do not change any more or
      # max number of iterations reached
      $done = 1;
    }
  }
  foreach my $i(0..$m-1) {
    $self->{'cluster_memberships'}->set($i,$cluster_indices[$i],1);
  }
  return @cluster_indices;
}

1;
