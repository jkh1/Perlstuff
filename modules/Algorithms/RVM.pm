# Author: jkh1
# 2009-09-15

=head1 NAME

 Algorithms::RVM

=head1 SYNOPSIS

 my $RVM = Algorithms::RVM->new($training_data,$classes);
 my ($W,$used,$marginal,$bias) = $RVM->train($PHItrain,$classes,$a,$usebias);
 my $rv = $RVM->get_relevance_vectors();
 my $predicted_classes = $RVM->classify($PHItest);

=head1 DESCRIPTION

 Relevance vector machine for classification.
 See: Tipping, M. E. (2001). Sparse Bayesian learning and the relevance vector
 machine. Journal of Machine Learning Research  1, 211–244.

 Follows Tipping's V1 implementation.

=head1 CONTACT

 heriche@embl.de

=cut

package Algorithms::RVM;

our $VERSION = '0.01';
use 5.006;
use strict;
use warnings;
use Algorithms::Matrix;
use Carp;

=head2 new

 Arg1: (optional) Algorithms::Matrix object, training data set as row vectors
 Arg2: (required if Arg1) Algorithms::Matrix object, classes of the training set
 Description: Creates a new RVM object.
 Returntype: RVM object

=cut

sub new {

  my $class = shift;
  my ($data,$target) = @_ if (@_);
  my $self = {};
  $self->{'training_set'} = $data if (defined($data));
  $self->{'training_classes'} = $target if (defined($target));
  bless ($self, $class);

  return $self;
}

=head2 train

 Arg1: Algorithms::Matrix object, design (kernel) matrix
 Arg2: Algorithms::Matrix object, target vector (classes indicated as 0 or 1)
 Arg3: (optional) double, initial value for alpha parameters
 Arg4: (optional) int, set to 1 to use a 'bias' offset
 Description: Estimates model parameters
 Returntype: list, estimated weights (Algorithms::Matrix) of relevant basis,
             indices of relevant basis vectors (array ref),
             marginal likelihood (scalar) of the model
             and bias vector (Algorithms::Matrix) if using bias offset.

=cut

sub train {

  my ($self,$PHIo,$t,$a,$usebias) = @_;
  my ($n,$m) = $PHIo->dims;

  if (!defined($a)) {
    $a = 1/($n*$n);
  }

  if ($usebias) {
    my $ones = Algorithms::Matrix->new($n,1)->one;
    $PHIo = $PHIo->bind($ones,column=>1);
    $m++;
  }

  # Parameters
  my $alpha_max = 1e9; # prune basis function if alpha>alpha_max
  my $min_delta_log_alpha = 1e-3; # convergence criterion
  my $max_iter = 10000; # maximum iterations

  my $converge = 0;
  my $iter = 0;
  my $basis_used = Algorithms::Matrix->new($m,1)->one;
  my $Ao = $a * $basis_used;
  my $Wo = Algorithms::Matrix->new($m,1)->zero;
  my ($marginal,$gamma);
  while (!$converge && $iter++<$max_iter) {
    # Pruning
    my $PHI;
    my $A;
    my $W;
    foreach my $i(0..$m-1) {
      my $Ai = $Ao->get($i,0);
      if ($Ai<$alpha_max) {
	if (!defined($A)) {
	  $A = $Ao->row($i);
	}
	else {
	  $A = $A->bind($Ao->row($i),row=>1);
	}
	if (!defined($PHI)) {
	  $PHI = $PHIo->col($i);
	}
	else {
	  $PHI = $PHI->bind($PHIo->col($i),column=>1);
	}
	if (!defined($W)) {
	  $W = $Wo->row($i);
	}
	else {
	  $W = $W->bind($Wo->row($i),row=>1);
	}
      }
      else {
	$basis_used->set($i,0,0);
	$Wo->set($i,0,0);
      }
    }
    if (!defined($PHI)) {
      $PHI = $PHIo->clone;
      $W = $Wo->clone;
      $A = $Ao->clone;
    }

    # Find mode of posterior distribution
    my ($Ui,$data_likely);
    ($W,$Ui,$data_likely) = $self->posterior_mode($PHI,$t,$W,$A);
    my ($nu,undef) = $Ui->dims;
    my $log_det_H = -2* ($Ui->diag->log->col_sum(0));
    my $diagS = $Ui->pow(2,overwrite=>0) * Algorithms::Matrix->new($nu,1)->one;

    $gamma = 1 - $A x $diagS;

    $marginal = $data_likely - 0.5 * ($log_det_H - $A->log(overwrite=>0)->col_sum(0)) + ($W->pow(2,overwrite=>0)->transpose * $A);

    if ($iter<$max_iter) {
      my $log_old_alpha = $A->log(overwrite=>0);
      # Update alphas
      $A = $gamma x (1/$W->pow(2,overwrite=>0));
      my $j = 0;
      foreach my $i(0..$m-1) {
	if ($basis_used->get($i,0) != 0) {
	  $Ao->set($i,0,$A->get($j,0));
	  $Wo->set($i,0,$W->get($j,0));
	  $j++;
	}
	else {
	  $Ao->set($i,0,$alpha_max+1);
	  $Wo->set($i,0,0);
	}
      }

      # Check convergence
      my $log_alpha = $A->log(overwrite=>0);
      my $log_diff = $log_alpha - $log_old_alpha;
      my $max_d = $log_diff->abs->max;
      if ($max_d<$min_delta_log_alpha) {
	$converge = 1;
      }
    }
  }
  if (!$converge) {
    print STDERR "WARNING: Maximum iterations reached. No convergence.\n";
  }
  my @used;
  my $rv;
  my $bias = 0;
  my $Wused;
#  my $Aused;
  foreach my $i(0..$m-1) {
    if ($basis_used->get($i,0) != 0) {
      push @used,$i;
    }
  }
  if (!@used) {
    print STDERR "No basis found.\n";
    exit(1);
  }
  if ($usebias) {
    my $bias_idx = $used[-1];
    if ($bias_idx == $m-1) {
      pop @used;
      $bias = $Wo->get($bias_idx,0);
    }
  }
  foreach my $i(@used) {
    if (!defined($Wused)) {
      $Wused = $Wo->row($i);
    }
    else {
      $Wused = $Wused->bind($Wo->row($i),row=>1);
    }
#     if (!defined($Aused)) {
#       $Aused = $Ao->row($i);
#     }
#     else {
#       $Aused = $Aused->bind($Ao->row($i),row=>1);
#     }
  }

  $self->{'weights'} = $Wused;
  $self->{'basis_used'} = \@used;
  $self->{'bias'} = $bias;
  $self->{'marginal'} = $marginal;

  return ($self->{'weights'},$self->{'basis_used'},$self->{'marginal'},$self->{'bias'});

}

=head2 posterior_mode

 Arg1: Algorithms::Matrix object, basis currently used
 Arg2: Algorithms::Matrix object, target vector (classes indicated as 0 or 1)
 Arg3: Algorithms::Matrix object, weights
 Arg4: Algorithms::Matrix object, alpha parameters
 Description: Finds mode of posterior distribution
 Returntype: list, weights values at mode (Algorithms::Matrix),
             inverse Cholesky factors of Hessian (Algorithms::Matrix)
             and log likelihood of the data at mode (scalar)

=cut

sub posterior_mode {

  my ($self,$PHI,$t,$w,$A) = @_;

  # Parameters
  my $max_iter = 25;
  my $grad_stop = 1e-6;
  my $lambda_min = 2**(-8);

  # Output
  # $w   : weights values at mode
  # $U   : inverse Cholesky factors of Hessian
  # $lm  : log likelihood of the data at mode
  my ($U,$lm);

  my ($N,$d) = $PHI->dims;
  my ($M,undef) = $w->dims;
  my $PHIw = $PHI * $w;
  my $y = $PHIw->sigmoid(overwrite=>0);
  my ($n,undef) = $y->dims;
  my $errs = Algorithms::Matrix->new($max_iter,1);

  my $data_term = 0;
  foreach my $i(0..$n-1) {
    my $class = $t->get($i,0);
    my $val = $y->get($i,0);
    if ($class == 1) {
      if ($val == 0) {
	$data_term += -12;
      }
      else {
	$data_term += log($val);
      }
    }
    else {
      if ($val == 1) {
#	warn "Hessian may be ill-conditionned.\n";
	$data_term += -12; # Subtract 1e-12 from 1 to try and go on
      }
      else {
	$data_term += log(1-$val);
      }
    }
  }
  $data_term = -$data_term/$N;

  my $regulariser = $A->diag * ($w x $w);
  $regulariser = $regulariser->get(0,0)/(2*$N);
  my $err_new = $data_term + $regulariser;

  my $iter = 0;
  while ($iter++<$max_iter) {
    my $yvar = $y->apply(\&Algorithms::RVM::Bernoulli,overwrite=>0);
    $yvar = $yvar * Algorithms::Matrix->new(1,$d)->one;
    my $PHIV = $PHI x $yvar;
    my $e = $t-$y;

    # Compute gradient vector
    my $g = $PHI->transpose * $e - $A x $w;
    # Compute Hessian
    my $H = $PHIV->transpose * $PHI + $A->diag;

    if ($iter == 1) {
      # Test if Hessian is ill-conditionned
      # Condition number is ratio of largest to smallest singular value
      my $S = $H->svd(U=>0,V=>0);
      my $max = $S->max;
      my $min = $S->min;
      if ($min == 0) {
	croak "\nERROR: Hessian is ill-conditionned (smallest singular value=0). Try using another kernel";
      }
      my $R = $max/$min;
      if ($R>1e12) {
	croak "\nERROR: Hessian is ill-conditionned (R= $R). Try using another kernel";
      }
    }
    $errs->set($iter,0,$err_new);

    # Test convergence
    my $norm = $g->norm2;
    if ($iter>=2 && $norm/$M<$grad_stop) {
      # Convergence
#      print STDERR "Convergence in posterior mode after $iter iterations.\n";
      last;
    }

    # Take "Newton step" and check for reduction in error
    $U = $H->cholesky();
    my $delta_w = $U->transpose->solve($g,overwrite=>0);
    $delta_w = $U->solve($delta_w,overwrite=>0);
    my $lambda = 1;
    while ($lambda>$lambda_min) {
      my $w_new = $w + $lambda * $delta_w;
      $PHIw = $PHI * $w_new;
      $y = $PHIw->sigmoid(overwrite=>0);

      # New error
      my $err_new;
      foreach my $i(0..$n-1) {
	my $class = $t->get($i,0);
	my $val = $y->get($i,0);
	if ($class) {
	  if ($val == 0) {
	    $data_term += -12;
	  }
	  else {
	    $data_term += log($val);
	  }
	}
	else {
	  if ($val == 1) {
	    $data_term += -12;
	  }
	  else {
	    $data_term += log(1-$val);
	  }
	}
      }
      $data_term = -$data_term/$N;
      $regulariser = $A->diag * ($w_new x $w_new);
      $regulariser = $regulariser->get(0,0)/(2*$N);
      $err_new = $data_term + $regulariser;

      if ($err_new>$errs->get($iter,0)) {
	# Error has increased
	# Reduce lambda
	$lambda = $lambda/2;
      }
      else {
	$w = $w_new;
	$lambda = 0;
      }
    }
    if ($lambda) {
      # We couldn't take a small enough downhill step,
      # we must be close to a minimum
#      print STDERR "Convergence close to minimum in posterior mode.\n";
      last;
    }
  }

  # Output
  $U = $U->inverse;
  $lm = -$N * $data_term;

  return ($w,$U,$lm);

}

=head2 Bernoulli

 Arg: double
 Description: Gets variance of Bernoulli variable
 Returntype: double

=cut

sub Bernoulli {

  my $x = shift;
  my $y = $x *(1-$x);
  return $y;

}

=head2 get_relevance_vectors

 Arg1: (optional) array ref, indices of relevant basis
 Arg2: (optional) Algorithms::Matrix, training data as row vectors
 Description: Gets the relevance vectors
 Returntype: Algorithms::Matrix

=cut

sub get_relevance_vectors {

  my $self = shift;
  my $used = shift if @_;
  $self->{'basis_used'} = $used if (defined($used));
  if (!defined($self->{'basis_used'})) {
    croak "\nERROR: No indices. Provide indices of relevance vectors";
  }
  my $data = shift if @_;
  $self->{'training_set'} = $data if (defined($data));
  if (!defined($self->{'training_set'}) || !$self->{'training_set'}->isa('Algorithms::Matrix')) {
    croak "\nERROR: No data. Provide matrix of training data";
  }
  my $D = $self->{'training_set'};
  my $rv;
  foreach my $i(@{$self->{'basis_used'}}) {
    if (!defined($rv)) {
      $rv = $D->row($i);
    }
    else {
      $rv = $rv->bind($D->row($i),row=>1);
    }
  }
  return $rv;

}

=head2 classify

 Arg1: Algorithms::Matrix, kernel of test data to relevance vectors
 Arg2: (optional) Algorithms::Matrix, weights of relevant basis
 Arg3: (optional) Algorithms::Matrix, bias vector
 Description: Gets classification of test data using previously trained RVM
 Returntype: Algorithms::Matrix, 2-columns matrix with predicted classes (0/1)
             in first column and associated probabilities in second column

=cut

sub classify {

  my $self = shift;
  my $PHI = shift if @_;
  my $W = shift if @_;
  my $bias = shift if @_;
  $self->{'weights'} = $W if (defined($W));
  if (!defined($self->{'weights'}) || !$self->{'weights'}->isa('Algorithms::Matrix')) {
    croak "\nERROR: No weights. Provide matrix of weights for relevant basis";
  }
  $self->{'bias'} = $bias if (defined($bias));

  my $y_rvm = $PHI * $self->{'weights'} + $self->{'bias'};
  my $p = $y_rvm->sigmoid;
  my ($n,undef) = $PHI->dims;
  my $predicted_classes = Algorithms::Matrix->new($n,1);
  foreach my $i(0..$n-1) {
    my $prediction = $y_rvm->get($i,0);
    if ($prediction<=0) {
      $predicted_classes->set($i,0,0);
      $p->set($i,0,1-$p->get($i,0));
    }
    else {
      $predicted_classes->set($i,0,1);
    }
  }
  $predicted_classes = $predicted_classes->bind($p,column=>1);

  return $predicted_classes;
}


1;
