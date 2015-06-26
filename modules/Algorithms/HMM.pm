# Author: jkh1
# 2015-01-27

=head1 NAME

 Algorithms::HMM

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 CONTACT

 heriche@embl.de

=cut

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

package Algorithms::HMM;

our $VERSION = '0.01';
use 5.006;
use strict;
use warnings;
use Algorithms::Matrix;
use Carp;

=head2 new

 Arg1: Arrayref (list of states) or integer, number of states
 Arg2: Arrayref (alphabet i.e. list of observation symbols) or
       integer, size of the alphabet i.e. number of observation symbols
 Arg3: (optional) Algorithms::Matrix, state transition probabilities
                  (number of states x number of states)
 Arg4: (optional) Algorithms::Matrix, emission probabilities
                  (number of states x size of alphabet)
 Arg5: (optional) Algorithms::Matrix, initial state probabilities
                  (1 x number of states)
 Description: Initializes a new HMM object.
 Returntype: HMM object

=cut

sub new {

  my $class = shift;
  my ($states,$alphabet,$transitions,$emissions,$p) = @_ if @_;
  my $self = {};
  if (ref($states)) {  # We have a list of states
    $self->{states} = $states;
    foreach my $i(0..$#{$states}) {
      $self->{state_idx}->{$states->[$i]} = $i;
    }
    $self->{Nstates} = scalar(@{$states});
  }
  else {
    $self->{Nstates} = $states;
  }
  if (ref($alphabet)) {  # We have a list of symbols
    $self->{alphabet} = $alphabet;
    foreach my $i(0..$#{$alphabet}) {
      $self->{symbol_idx}->{$alphabet->[$i]} = $i;
    }
    $self->{Nalphabet} = scalar(@{$alphabet});
  }
  else {
    $self->{Nalphabet} = $alphabet;
  }
  my $Nstates = $self->{Nstates};
  my $Nalphabet = $self->{Nalphabet};
  unless ($p) {
    # Initialize pi and make sure it's row-stochastic
    $self->{pi} = Algorithms::Matrix->new($Nstates,1)->random();
    $self->{pi} = $self->{pi}->normalize(type=>'sum')->transpose;
  }
  else {
    $self->{pi} = $p;
  }

  unless ($transitions) {
    # Initialize transition probabilities and
    # make sure matrix is row-stochastic
    $self->{transitions} = Algorithms::Matrix->new($Nstates,$Nstates)->random();
    $self->{transitions} = $self->{transitions}->normalize(type=>'sum');
  }
  else {
    $self->{transitions} = $transitions;
  }

  unless ($emissions) {
    # Initialize emission probabilities and
    # make sure matrix is row-stochastic
    $self->{emissions} = Algorithms::Matrix->new($Nalphabet,$Nstates)->random();
    $self->{emissions} = $self->{emissions}->normalize(type=>'sum')->transpose;
  }
  else {
    $self->{emissions} = $emissions;
  }

  bless ($self, $class);

  return $self;
}

=head2 train

 Arg1: Arrayref of arrays, training data, list of sequences.
       Each element of a sequence is the index of the symbol
       in the alphabet, e.g. if the alphabet of symbols is
       (H,M,L) then a valid sequence would be (0,2,1,1,2,0)
 Arg2: (optional) integer, maximum number of iterations (default = 500)
 Arg3: (optional) double, tolerance (default = 1e-15)
 Description: Estimates HMM parameters (transition and emission probabilities)
              using the Baum-Welch algorithm
 Returntype: double, log-likelihood of the model

=cut

sub train {

  my ($self,$observations,$maxIter,$tol) = @_;

  $maxIter ||= 500;
  $tol ||= 1e-15;

  my $Nstates = $self->{Nstates};
  my $Nalphabet = $self->{Nalphabet};
  my $N = scalar(@{$observations});

  my $pi = $self->{pi};
  my $A = $self->{transitions};
  my $B = $self->{emissions};

  my $stop = 0;
  my $iter = 1;
  my $newLogP = 0;
  my $oldLogP = -inf;

  while (!$stop) {

    my @fwd;
    my @bwd;
    my @gamma;
    my @Xi;
    foreach my $o(0..$N-1) {
      next unless ($observations->[$o]);

      my $sequence = $observations->[$o];
      my $T = scalar(@{$sequence});

      # Forward and backward probabilities
      $fwd[$o] = $self->forward($sequence);  # $Nstates x $T matrix
      $bwd[$o] = $self->backward($sequence);  # $Nstates x $T matrix

      # Gamma
      foreach my $t(0..$T-1) {
	my $sum = 0;
	foreach my $i(0..$Nstates-1) {
	  $gamma[$o][$i][$t] = $fwd[$o]->get($i,$t) * $bwd[$o]->get($i,$t);
	  $sum += $gamma[$o][$i][$t];
	}
	if ($sum) {
	  foreach my $i(0..$Nstates-1) {
	    $gamma[$o][$i][$t] /= $sum;
	  }
	}
      }

      # Calculate Xi
      foreach my $t(0..$T-2) {
	my $sum = 0;
	foreach my $i(0..$Nstates-1) {
	  foreach my $j(0..$Nstates-1) {
	    $Xi[$o][$i][$j][$t] = $fwd[$o]->get($i,$t) * $A->get($i,$j) * $B->get($j,$sequence->[$t+1]) * $bwd[$o]->get($j,$t+1);
	    $sum += $Xi[$o][$i][$j][$t];
	  }
	}
	if ($sum) {
	  foreach my $i(0..$Nstates-1) {
	    foreach my $j(0..$Nstates-1) {
	      $Xi[$o][$i][$j][$t] /= $sum;
	    }
	  }
	}
      }

     # Compute log-likelihood of the sequence
      my $logP = 0;
      my $c = $self->{scaling}; # defined after calling forward()
      foreach my $t(0..$T-1) {
	if ($c->get(0,$t)) {
	  $logP += log($c->get(0,$t));
	}
	else {
	  $logP += -1e52
	}
      }
      $newLogP += $logP;
    } # End processing sequences

    $newLogP /= $N; # Average logP for all sequences
    # Check convergence
    my $delta = $newLogP-$oldLogP;
    $oldLogP = $newLogP;
    $newLogP = 0;
    $iter++; print STDERR "iter = $iter (delta = $delta)\n";
    if ($iter>$maxIter || $delta < $tol) {
      $stop =1;
    }
    else {
      # Re-estimate initial state probabilities
      foreach my $i(0..$Nstates-1) {
	my $sum = 0;
	foreach my $o(0..$N-1) {
	  $sum += $gamma[$o][$i][0];
	}
	$sum /= $N;
	$pi->set(0,$i,$sum);
      }

      # Re-estimate transition probabilities
      foreach my $i(0..$Nstates-1) {
	foreach my $j(0..$Nstates-1) {
	  my $num = 0;
	  my $denom = 0;
	  foreach my $o(0..$N-1) {
	    my $T = scalar(@{$observations->[$o]});
	    foreach my $t(0..$T-2) {
	      $num += $Xi[$o][$i][$j][$t];
	      $denom += $gamma[$o][$i][$t];
	    }
	  }
	  if ($denom) {
	    my $val = $num/$denom;
	    $A->set($i,$j,$val);
	  }
	  else {
	    $A->set($i,$j,0);
	  }
	}
      }

      # Re-estimate emission probabilities
      foreach my $i(0..$Nstates-1) {
	foreach my $j(0..$Nalphabet -1) {
	  my $num = 0;
	  my $denom = 0;
	  foreach my $o(0..$N-1) {
	    my $seq = $observations->[$o];
	    my $T = scalar(@{$seq});
	    foreach my $t(0..$T-1) {
	      if ($seq->[$t] == $j) {
		$num += $gamma[$o][$i][$t];
	      }
	      $denom += $gamma[$o][$i][$t];
	    }
	  }
	  if ($num && $denom) {
	    my $val = $num/$denom;
	    $B->set($i,$j,$val);
	  }
	  else {
	    $B->set($i,$j,1e-10); # Avoid setting to 0
	  }
	}
      }

    } # End else
  } # End while

  return $oldLogP;
}

=head2 forward

 Arg: Arrayref, sequence of observations
 Description: Calculates the forward probability of each state
 Returntype: Algorithms:Matrix

=cut

sub forward {

  my ($self,$sequence) = @_;
  my $T = scalar(@{$sequence});
  my $Nstates = $self->{Nstates};
  my $A = $self->{transitions};
  my $B = $self->{emissions};
  my $pi = $self->{pi};
  my $fwd = Algorithms::Matrix->new($Nstates,$T)->zero;
  my $c = Algorithms::Matrix->new(1,$T)->zero;

  # Initialization
  my $c0 = 0;
  foreach my $i(0..$Nstates-1) {
    my $val = $pi->get(0,$i) * $B->get($i,$sequence->[0]);
    $fwd->set($i,0,$val);
    $c0 += $val;
  }
  $c->set(0,0,$c0);
  if ($c0 != 0) {
    # Scaling
    foreach my $i(0..$Nstates-1) {
      my $f = $fwd->get($i,0)/$c0;
      $fwd->set($i,0,$f);
    }
  }

  foreach my $t(1..$T-1) {
    my $ct = 0;
    foreach my $i(0..$Nstates-1) {
      my $p = $B->get($i,$sequence->[$t]);
      my $sum = 0;
      foreach my $j(0..$Nstates-1) {
	$sum += $fwd->get($j,$t-1) * $A->get($j,$i);
      }
      my $f = $sum * $p;
      $fwd->set($i,$t,$f);
      # Scaling coefficient
      $ct += $fwd->get($i,$t);
    }
    $c->set(0,$t,$ct);
    if ($ct != 0) {
      # Scaling
      foreach my $i(0..$Nstates-1) {
	my $f = $fwd->get($i,$t)/$ct;
	$fwd->set($i,$t,$f);
      }
    }
  }
  $self->{scaling} = $c;
  return $fwd;
}

=head2 backward

 Arg: Arrayref, sequence
 Description: Calculates the backward probability of each state
 Returntype: Algorithms:Matrix

=cut

sub backward {

  my ($self,$sequence) = @_;
  my $T = scalar(@{$sequence});
  my $Nstates = $self->{Nstates};
  my $A = $self->{transitions};
  my $B = $self->{emissions};
  my $bwd = Algorithms::Matrix->new($Nstates,$T)->zero;
  my $c = $self->{scaling};

  # Initialization
  foreach my $i(0..$Nstates-1) {
    my $ct = $c->get(0,$T-1);
    if ($ct != 0) {
      $bwd->set($i,$T-1,1/$ct);
    }
    else {
      $bwd->set($i,$T-1,1);
    }
  }

  for (my $t = $T-2; $t >= 0; $t--) {
    foreach my $i(0..$Nstates-1) {
      my $sum = 0;
      foreach my $j(0..$Nstates-1) {
	$sum += $bwd->get($j,$t+1) * $A->get($i,$j) * $B->get($j,$sequence->[$t+1]);
      }
      # Scaling
      my $ct = $c->get(0,$t);
      if ($ct != 0) {
	$sum = $sum * 1/$ct;
      }
      $bwd->set($i,$t,$sum);
    }
  }
  return $bwd;
}

=head2 gamma

 Arg1: integer, state index
 Arg2: integer, time index
 Arg3: Algorithms::Matrix, forward probabilities
 Arg4: Algorithms::Matrix, backward probabilities
 Description: Calculates the probability of state s at time t given
              the observed sequence
 Returntype: double

=cut

sub gamma {

  my ($self,$s,$t,$fwd,$bwd) = @_;
  my ($Nstates,undef) = $fwd->dims;
  my $g = $fwd->get($s,$t) * $bwd->get($s,$t);
  my $sum = 0;
  foreach my $j(0..$Nstates-1) {
    $sum += $fwd->get($j,$t) * $bwd->get($j,$t);
  }
  if ($sum) {
    return $g/$sum;
  }
  else {
    return 0;
  }
}

=head2 Xi

 Arg1: integer, time index
 Arg2: integer, state index
 Arg3: integer, state index
 Arg4: Arrayref, sequence of observations
 Arg5: Algorithms::Matrix, forward probabilities
 Arg6: Algorithms::Matrix, backward probabilities
 Description: Calculates the probability of states i and j at time t and t+1
              given the observed sequence
 Returntype: double

=cut

sub Xi {

  my ($self,$t,$i,$j,$sequence,$fwd,$bwd) = @_;
  my ($Nstates,$T) = $fwd->dims;
  my $A = $self->{transitions};
  my $B = $self->{emissions};
  my $xi;
  if ($t == $T-1) {
    $xi = $fwd->get($i,$t) * $A->get($i,$j);
  }
  else {
    $xi = $fwd->get($i,$t) * $A->get($i,$j) * $B->get($j,$sequence->[$t+1]) * $bwd->get($j,$t+1);
  }
  my $sum = 0;
  foreach my $k(0..$Nstates-1) {
    foreach my $l(0..$Nstates-1) {
      $sum += $fwd->get($k,$t) * $A->get($k,$l) * $B->get($l,$sequence->[$t+1]) * $bwd->get($l,$t+1);
    }
  }
  if ($sum) {
    return $xi/$sum;
  }
  else {
    return 0;
  }
}

=head2 likelihood

 Arg: Arrayref, sequence of observations
 Description: Calculates the likelihood that the sequence has been generated
              by this model
 Returntype: double

=cut

sub likelihood {

  my ($self,$sequence) = @_;

  my $fwd = $self->forward($sequence);
  my $c = $self->{scaling};
  my $logP = 0;
  my ($N,$T) = $fwd->dims;
  foreach my $i(0..$N-1) {
    $logP += log($c->get(0,$i));
  }
  return exp($logP);
}

=head2 viterbi

 Arg: Arrayref, sequence of observations
 Description: Gets the sequence of states that most likely produced the
              observed sequence
 Returntype: list of arrayref to sequence of states and double, associated
             probability

=cut

sub viterbi {

  my ($self,$sequence) = @_;

  my $T = scalar(@{$sequence});
  my $Nstates = $self->{Nstates};
  my $A = $self->{transitions};
  my $B = $self->{emissions};
  my $pi = $self->{pi};
  my ($minState,$minweight,$weight);
  my @s;
  my @a;

  foreach my $i(0..$Nstates-1) {
    my $val;
    if ($pi->get(0,$i) && $B->get($i,$sequence->[0])) {
      $val = 0 - log($pi->get(0,$i)) - log($B->get($i,$sequence->[0]));
    }
    else {
      $val = 1e52;
    }
    $a[$i][0] = $val;
  }

  foreach my $t(1..$T-1) {
    foreach my $j(0..$Nstates-1) {
      $minState = 0;
      if ($A->get(0,$j)) {
	$minweight = $a[0][$t-1] - log($A->get(0,$j));
      }
      else {
	$minweight = $a[0][$t-1] + 1e52;
      }
      foreach my $i(1..$Nstates-1) {
	if ($A->get($i,$j)) {
	  $weight = $a[$i][$t-1] - log($A->get($i,$j));
	}
	else {
	  $weight = $a[$i][$t-1] + 1e52;
	}
	if ($weight < $minweight) {
	  $minState = $i;
	  $minweight = $weight;
	}
      }
      my $val;
      if ($B->get($j,$sequence->[$t])) {
	$val = $minweight - log($B->get($j,$sequence->[$t]));
      }
      else {
	$val = $minweight + 1e52;
      }
      $a[$j][$t] = $val;
      $s[$j][$t] = $minState;
    }
  }

  # Find value for time $T-1
  $minState = 0;
  $minweight = $a[0][$T-1];
  foreach my $i(1..$Nstates-1) {
    if ($a[$i][$T-1]<$minweight) {
      $minState = $i;
      $minweight = $a[$i][$T-1];
    }
  }

  # Traceback
  my @path;
  $path[$T-1] = $minState;
  for (my $t = $T-2; $t>=0; $t--) {
    $path[$t] = $s[$path[$t+1]][$t+1];
  }

  return \@path, exp(-$minweight);
}

=head2 transitions

 Arg: (optional) Algorithms::Matrix
 Description: Gets/sets the matrix of transition probabilities
 Returntype: Algorithms::Matrix

=cut

sub transitions {

  my $self = shift;
  if (@_) {
    $self->{transitions} = shift;
  }
  return $self->{transitions};
}

=head2 emissions

 Arg: (optional) Algorithms::Matrix
 Description: Gets/sets the matrix of emission probabilities
 Returntype: Algorithms::Matrix

=cut

sub emissions {

  my $self = shift;
  if (@_) {
    $self->{emissions} = shift;
  }
  return $self->{emissions};
}

=head2 idx_to_states

 Arg: Array, list of state indices
 Description: Converts state indices to state names
 Returntype: Array, list of states

=cut

sub idx_to_states {

  my $self = shift;
  my @indices = @_ if @_;
  my @states;
  my $states = $self->{states};
  foreach my $i(0..$#indices) {
    $states[$i] = $states->[$indices[$i]];
  }
  return @states;
}

=head2 states_to_idx

 Arg: Array, list of states
 Description: Converts states to indices
 Returntype: Array, list of indices

=cut

sub states_to_idx {

  my $self = shift;
  my @states = @_ if @_;
  my @idx;
  foreach my $i(0..$#states) {
    $idx[$i] = $self->{state_idx}->{$states[$i]};
  }
  return @idx;
}

=head2 idx_to_symbols

 Arg: Array, list of symbol indices
 Description: Converts symbol indices to symbols
 Returntype: Array, list of symbols

=cut

sub idx_to_symbols {

  my $self = shift;
  my @indices = @_ if @_;
  my @symbols;
  my $alphabet = $self->{alphabet};
  foreach my $i(0..$#indices) {
    $symbols[$i] = $alphabet->[$indices[$i]];
  }
  return @symbols;
}

=head2 symbols_to_idx

 Arg: Array, list of symbols
 Description: Converts symbols to indices
 Returntype: Array, list of indices

=cut

sub symbols_to_idx {

  my $self = shift;
  my @symbols = @_ if @_;
  my @idx;
  foreach my $i(0..$#symbols) {
    $idx[$i] = $self->{symbol_idx}->{$symbols[$i]};
  }
  return @idx;
}

=head2 generate_sequence

 Arg: integer, sequence length
 Description: Generates a sequence of observation symbols drawn from the model
 Returntype: Array, list of symbol indices

=cut

sub generate_sequence {

  my $self = shift;
  my $T = shift if @_;
  my @seq;
  my $Nstates = $self->{Nstates};

  # Get initial state
  my $state = $Nstates - 1;
  my $accum = 0;
  my $r = rand();
  foreach my $i(0..$Nstates-1) {
    if ($r < ($self->{pi}->get(0,$i) + $accum)) {
      $state = $i;
      last;
    }
    else {
      $accum += $self->{pi}->get(0,$i);
    }
  }
  # Emit symbol
  push @seq, $self->generate_symbol($state);

  # Get next states and emit symbols
  my $previousState = $state;
  foreach my $t(1..$T-1) {
    my $accum = 0;
    my $r = rand();
    my $nextState = $Nstates - 1;
    foreach my $i(0..$Nstates-1) {
      if ($r < ($self->{transitions}->get($previousState,$i) + $accum)) {
	$nextState = $i;
	last;
      }
      else {
	$accum += $self->{transitions}->get($state,$i);
      }
    }
    push @seq, $self->generate_symbol($nextState);
    $previousState = $nextState;
  }
  return @seq;
}

=head2 generate_symbol

 Arg: integer, index of a state
 Description: Generates a symbol from the given state
 Returntype: integer, index of a symbol

=cut

sub generate_symbol {

  my $self = shift;
  my $state = shift if @_;
  my $Nstates = $self->{Nstates};
  my $Nalphabet = $self->{Nalphabet};

  my $r = rand();
  my $accum = 0;
  my $symbol = $Nalphabet-1;
  foreach my $i(0..$Nalphabet-1) {
    if ($r < ($self->{emissions}->get($state,$i) + $accum)) {
      $symbol = $i;
      last;
    }
    else {
      $accum += $self->{emissions}->get($state,$i);
    }
  }
  return $symbol;
}


1;
