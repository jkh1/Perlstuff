# Author: jkh1
# 2009-03-03

=head1 NAME

  Algorithms::Kernel

=head1 SYNOPSIS


 use Algorithms::Matrix;
 use Algorithms::Kernel;

 my $M = Algorithms::Matrix->new(4,3)->random;
 my $C = $M->get_distances('cosine','overwrite'=>0);
 my $K1 = Algorithms::Kernel->new_from_matrix($C);
 my $K2 = Algorithms::Kernel->compute_from_matrix($M,'RBF',245);



=head1 DESCRIPTION

 Kernel object and methods to calculate and manipulate kernels

=head1 CONTACT

 heriche@embl.de

=cut

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

package Algorithms::Kernel;

our $VERSION = '0.01';
use 5.006;
use strict;
use warnings;
use Carp;

use base ("Algorithms::Matrix");
# use Algorithms::Matrix;
# our @ISA = ("Algorithms::Matrix");

=head2 new

 Arg: integer, number of rows and columns
 Description: Creates a new Kernel object.
 Returntype: Kernel object

=cut

sub new {

  my ($class,$m,$n) = @_;
  if (!defined($m) || $m<=0) {
    croak "\nERROR: Kernel size required";
  }
  if (!defined($n) || $n<=0) {
    $n = $m;
  }
  my $self = Algorithms::Matrix->new($m,$n);
  bless ($self, $class);

  return $self;
}

=head2 new_from_matrix

 Description: Turns a Matrix object into a Kernel object. Matrix must be square.
 Returntype: Kernel object

=cut

sub new_from_matrix {

  my ($class,$matrix) = @_;
  my ($m,$n) = $matrix->dims;
  if ($m != $n) {
    croak "\nERROR: Matrix must be square to be a Kernel";
  }
  bless ($matrix, $class);

  return $matrix;
}

=head2 compute_from_matrix

 Arg1: Matrix
 Arg2: string, type of kernel to compute
 Arg3: (optional)
 Description: Compute the selected kernel from the given matrix.
              Available kernels are:
                General kernels:
                  linear : dot product of row vectors
                  RBF    : Gaussian radial basis function (sigma = Arg3)
                Graph kernels (assumes input matrix is an adjacency matrix):
                  CT  : commute time
                  VN  : Von Neumann diffusion (gamma = Arg3)
                  RF  : random forest
                  RWR : random walk with restart (alpha = Arg3)
                  RCT : regularized commute time (alpha = Arg3)
 Returntype: Kernel

=cut

sub compute_from_matrix {

  my $class = shift;
  my $matrix = shift;
  my $choice = shift;
  my $kernel;
  my ($m,$n) = $matrix->dims;
  if ($m != $n && ($choice eq 'CT' || $choice eq 'VN' || $choice eq 'RF') ) {
    croak "\nERROR: Matrix must be square to compute graph kernels";
  }
  if ($choice eq 'linear') {
    $kernel = $matrix * $matrix->transpose;
  }
  elsif ($choice eq 'RBF') {
    my $sigma = shift;
    $kernel = $matrix->get_distances('euclidean');
    $sigma = -1/$sigma;
    $kernel = $kernel * $sigma;
    $kernel = $kernel->exp;
  }
  elsif ($choice eq 'CT') {
    my $D = $matrix->means;
    $D = $D * $m;
    $D = $D->diag;
    my $L = $D - $matrix;
    $kernel = $L->pseudoinverse(overwrite=>1);
  }
  elsif ($choice eq 'VN') {
    my $gamma = shift;
    if (!defined($gamma)) {
      my $rho = $matrix->spectral_radius;
      $gamma = 1/(2 * $rho); # make $gamma < 1/$rho
    }
    $kernel = Algorithms::Matrix->new($m,$n)->identity;
    $kernel = $kernel - $gamma * $matrix;
    $kernel = $kernel->inverse(overwrite=>1);
  }
  elsif ($choice eq 'RF') {
    my $I = Algorithms::Matrix->new($m,$n)->identity;
    my $D = $matrix->means;
    $D = $D * $m;
    $D = $D->diag;
    my $L = $I + $D - $matrix;
    $kernel = $L->inverse(overwrite=>1);
  }
  elsif ($choice eq 'RWR' || $choice eq 'RCT') {
    my $alpha = shift || 0.99; # Restart probability = 1 - alpha
    my $D = $matrix->means;
    $D = $D * $m;
    $D = $D->diag;
    $kernel = $D - $alpha * $matrix;
    $kernel = $kernel->inverse(overwrite=>1);
    if ($choice eq 'RWR') {
      $kernel = $kernel * $D;
    }
  }

  bless ($kernel, $class);

  return $kernel;
}

=head2 compute_from_graph

 Arg1: Algorithms::Graph object
 Arg2: string, type of kernel to compute
 Arg3: (optional)
 Description: Compute the selected kernel from the given connected (unweighted)
              graph.
              Available kernels are:
                  CT  : commute time
                  VN  : von Neumann diffusion (gamma = Arg3)
                  RF  : random forest
                  RWR : random walk with restart (alpha = Arg3)
 Returntype: Kernel

=cut

sub compute_from_graph {

  my $class = shift;
  my $G = shift;
  if (!ref($G) || (ref($G) && !$G->isa('Algorithms::Graph'))) {
    croak "\nERROR: Argument must be an Algorithms::Graph object";
  }
  my $choice = shift;
  unless ($G->is_connected) {
    croak "\nERROR: Graph must be connected";
  }
  my @V = $G->vertices;
  my $ne = scalar(@V);
  my $K = Algorithms::Kernel->new($ne,$ne);
  if ($choice eq 'CT') {
    # Calculate commute time kernel as pseudoinverse of the graph Laplacian
    foreach my $i(0..$ne-1) {
      $K->set($i,$i,$G->degree($V[$i])+1/$ne);
      foreach my $j(0..$ne-1) {
	next if ($j == $i);
	if ($G->has_edge($V[$i],$V[$j])) {
	  my $w = $G->get_edge_weight($V[$i],$V[$j]);
	  $K->set($i,$j,-$w+1/$ne);
	}
	else {
	  $K->set($i,$j,1/$ne);
	}
      }
    }
    $K = $K->inverse(overwrite=>1);
    $K = $K - 1/$ne;
  }
  elsif ($choice eq 'VN') {
    # Calculate von Neumann diffusion kernel
    # K = (I-gA)^(-1)
    my $gamma = shift;
    if (!defined($gamma)) {
      # Form adjacency matrix
      my $A = Algorithms::Matrix->new($ne,$ne);
      foreach my $i(0..$ne-1) {
	foreach my $j(0..$i) {
	  if ($G->has_edge($V[$i],$V[$j])) {
	    my $w = $G->get_edge_weight($V[$i],$V[$j]);
	    $A->set($i,$j,$w);
	    $A->set($j,$i,$w);
	  }
	  else {
	    $A->set($i,$j,0);
	    $A->set($j,$i,0);
	  }
	}
      }
      my $rho = $A->spectral_radius;
      $gamma = 0.5 * (1/$rho); # make $gamma < 1/$rho
    }
    $K->set(0,0,1);
    foreach my $i(1..$ne-1) {
      $K->set($i,$i,1);
      foreach my $j(0..$i-1) {
	if ($G->has_edge($V[$i],$V[$j])) {
	  my $w = $G->get_edge_weight($V[$i],$V[$j]);
	  $K->set($i,$j,-$gamma * $w);
	  $K->set($j,$i,-$gamma * $w);
	}
	else {
	  $K->set($i,$j,0);
	  $K->set($j,$i,0);
	}
      }
    }
    $K = $K->inverse(overwrite=>1);
  }
  elsif ($choice eq 'RF') {
    foreach my $i(0..$ne-1) {
      $K->set($i,$i,1+$G->degree($V[$i]));
      foreach my $j(0..$ne-1) {
	next if ($j == $i);
	if ($G->has_edge($V[$i],$V[$j])) {
	  my $w = $G->get_edge_weight($V[$i],$V[$j]);
	  $K->set($i,$j,-$w);
	}
	else {
	  $K->set($i,$j,0);
	}
      }
    }
    $K = $K->inverse(overwrite=>1);
  }
  elsif ($choice eq 'RWR') {
    my $alpha = shift || 0.99; # Restart probability = 1 - alpha
    my $A = Algorithms::Matrix->new($ne,$ne);
    foreach my $i(0..$ne-1) {
      foreach my $j(0..$i) {
	if ($G->has_edge($V[$i],$V[$j])) {
	  my $w = $G->get_edge_weight($V[$i],$V[$j]);
	  $A->set($i,$j,$w);
	  $A->set($j,$i,$w);
	}
	else {
	  $A->set($i,$j,0);
	  $A->set($j,$i,0);
	}
      }
    }
    my $D = $A->means;
    $D = $D * $ne;
    $K = $D->diag - $alpha * $A;
    $K = $K->inverse(overwrite=>1);
    $K = $K * $D->diag;
  }

  return $K;
}

=head2 get_distance_matrix

 Description: Turns a kernel/similarity matrix into a distance matrix using
              (Dij)^2 = Kii+Kjj-2*Kij
 Returntype:  Matrix object

=cut

sub get_distance_matrix {

  my $self = shift;
  my ($m,$n) = $self->dims;

  my $D = Algorithms::Matrix->new($n,$n)->zero;
  foreach my $i(0..$n-1) {
    my $a = $self->get($i,$i);
    foreach my $j(0..$i) {
      my $d = $a + $self->get($j,$j) - 2 * $self->get($i,$j);
      $D->set($i,$j,$d);
      $D->set($j,$i,$d);
    }
  }
  return $D;
}

=head2 center

 Arg: set overwrite=>1 to reuse input matrix
 Description: Center the kernel in feature space
 Returntype:  Kernel object

=cut

sub center {

  my $self = shift;
  my %param = @_ if (@_);

  my ($m,$n) = $self->dims;
  my $J = Algorithms::Matrix->new(1,$n)->one;
  my $means = $self->means;
  my $x = $means->transpose->means->get(0,0);
  if (defined($param{'overwrite'}) && ($param{'overwrite'} == 1 || $param{'overwrite'}=~/true|t/i)) {
    $self = $self - ($means->transpose * $J) - ($J->transpose * $means) + $x;
    return $self;
  }
  else {
    my $K = $self - ($means->transpose * $J) - ($J->transpose * $means) + $x;
    return $K;
  }
}


1;

