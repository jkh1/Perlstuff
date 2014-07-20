# Author: jkh1
# 2010-01-07, last modified 2010-07-05

=head1 NAME

 Algorithms::Graph

=head1 SYNOPSIS

 use Algorithms::Graph;
 my $G = Algorithms::Graph->new();
 $G->read_from_file($ARGV[0]);
 my @query = (qw(ENSG00000178999 ENSG00000137812));
 my $RG = $G->get_relevant_subgraph(\@query,0.0001);
 $RG->export();

=head1 DESCRIPTION

 This module extends the Graph::Undirected module. It assumes graphs to be
 weighted, using a default weight of 1 if no weight is provided.

 Uses Algorithms::Matrix


=head1 CONTACT

 heriche@embl.de

=cut

package Algorithms::Graph;

use strict;
use warnings;
use Inline ( C =>'DATA',
	     NAME =>'Algorithms::Graph',
	     DIRECTORY => '',
#	     VERSION => '0.01'
	   );
use Algorithms::Matrix;
use Carp;

use base ("Graph::Undirected");

=head2 new

 Description: Creates a new Graph object
 Returntype: Graph object

=cut

sub new {

  my $class = shift;

  my $self = Graph::Undirected->new();
  bless ($self, $class);

  return $self;
}

=head2 get_relevant_subgraph

 Arg1: listref of nodes of interest
 Arg2: (optional) double, probability threshold for keeping edges,
       default is 0.001
 Arg3: (optional) int, consider walks up to this length, default to 50
 Arg4: (optional) int, set to 1 to get verbose mode
 Description: Extracts relevant subgraph from limited random walks as in:
              P. Dupont, J. Callut, G. Dooms, J.-N. Monette, and Y. Deville.
              Relevant subgraph extraction from random walks in a graph.
              Technical Report RR 2006-07, INGI, UCL, 2006
 Returntype: Algorithms::Graph object

=cut

sub get_relevant_subgraph {

  my ($self,$nodes_ref,$threshold,$Lmax,$verbose) = @_;
  if (!defined($nodes_ref) || scalar(@{$nodes_ref})<2) {
    croak "\nAt least 2 nodes of interest are required";
  }
  # Check if all query nodes are connected
  my @cc = $self->connected_components();
  my %cc;
  foreach my $node(@$nodes_ref) {
    my $i = $self->connected_component_by_vertex($node);
    if (!defined($i)) {
      carp "\nWARNING: Query node $node is not in graph" if $verbose;
      next;
    }
    push @{$cc{$i}},$node;
  }
  if (scalar(keys %cc)>1) {
    # Query nodes are in different connected components
    # Keep those in the component most represented
    my ($i,undef) = sort {scalar(@{$cc{$b}}) <=> scalar(@{$cc{$a}})} keys %cc;
    $nodes_ref = $cc{$i};
    carp "\nWARNING: Query nodes are not connected.\nKeeping only the following nodes: ",join(", ",@$nodes_ref) if $verbose;
  }
  undef(@cc);
  $threshold ||= 0.001;
  $Lmax ||= 50;
  $verbose ||= 0;
  my @V = $self->vertices;
  my %idx;
  foreach my $i(0..$#V) {
    $idx{$V[$i]} = $i;
  }
  my $ne = scalar(@V);
  # Convert graph to array structure to pass to C function
  my @A;
  foreach my $i(0..$#V) {
    my @neighbours = $self->neighbours($V[$i]);
    @neighbours = sort {$idx{$a}<=>$idx{$b}} @neighbours;
    foreach my $neighbour(@neighbours) {
      my $j = $idx{$neighbour};
      my $w = 0;
      if ($self->has_edge_weight($V[$i],$neighbour)) {
	$w = $self->get_edge_weight($V[$i],$neighbour);
      }
      else {
	$w = 1;
      }
      push @{$A[$i]},[$j,$w];
    }
  }
  my $k = scalar(@{$nodes_ref});
  my $Knodes;
  foreach my $i(0..$k-1) {
    if (defined($idx{${$nodes_ref}[$i]})) {
      push @{$Knodes},$idx{${$nodes_ref}[$i]};
    }
  }
  my $G = Algorithms::Graph->new();
  if (defined($Knodes)) {
    $k = scalar(@{$Knodes});
    &lkwalk(\@A,$Knodes,$Lmax,$ne,$k,$verbose);
    # @A now contains the relevant subgraph
    # Convert it to a Graph object
    foreach my $i(0..$#V) {
      my @neighbours;
      if (defined($A[$i])) {
	@neighbours = @{$A[$i]};
	foreach my $neighbour(@neighbours) {
	  my ($j,$w) = @$neighbour;
	  if ($w>$threshold) {
	    $G->add_weighted_edge($V[$i],$V[$j],$w);
	  }
	}
      }
    }
    # Label query nodes
    foreach my $n(@{$nodes_ref}) {
      $G->set_vertex_attribute($n,'NODECLASS', 3);
    }
  }
  return $G;
}

=head2 get_adjacency_matrix

 Description: Extracts the graph adjacency matrix (as a dense matrix)
 Returntype: Algorithms::Matrix object

=cut

sub get_adjacency_matrix {

  my $self = shift;

  my @V = $self->vertices;
  my $ne = scalar(@V);
  my $A = Algorithms::Matrix->new($ne,$ne);
  foreach my $i(0..$ne-1) {
    foreach my $j(0..$i) {
      if ($self->has_edge($V[$i],$V[$j])) {
	if ($self->has_edge_weight($V[$i],$V[$j])) { # Weighted graph
	  my $Wij = $self->get_edge_weight($V[$i],$V[$j]);
	  if ($Wij) { # Non-zero weight
	    $A->set($i,$j,$Wij);
	    $A->set($j,$i,$Wij);
	  }
	  else {
	    $A->set($i,$j,0);
	    $A->set($j,$i,0);
	  }
	}
	else { # Unweighted graph, default to 1
	  $A->set($i,$j,1);
	  $A->set($j,$i,1);
	}
      }
      else { # No edge
	$A->set($i,$j,0);
	$A->set($j,$i,0);
      }
    }
  }
  return $A;
}

=head2 export

 Arg1: string, file format to export to. Currently supported options:
              layout: Biolayout format
              dot: dot/Graphviz format
 Arg2: string, file name without format extension
 Arg3: (optional) parameters as a list of key=>value pairs.
       Currently supported attributes are:
         for dot graph: size, orientation.
         for dot nodes: width, height, shape, color, fontsize, fontcolor, URL.
         for Biolayout, only the NODECLASS attribute is supported.
 Description: Saves graph to file in the specified format.
 Returntype: none

=cut

sub export {

  my $self = shift;
  my ($format,$filename,@parameters) = @_;
  if (!defined($format)) {
    croak "\nERROR: format must be provided";
  }
  if ($format ne 'dot') {
    $format = 'layout';
  }
  if (!defined($filename)) {
    croak "\nERROR: filename must be provided";
  }
  if ($filename!~/\.$format$/i) {
    # Add extension
    $filename .=".$format";
  }
  my %param;
  if (@parameters) {
    %param = (@parameters);
  }
  my @E = $self->edges;
  open FH,">",$filename or croak "\nERROR: Can't create file $filename: $!\n";
  if ($format eq 'dot') {
    print FH "graph MEPN {\n";
    print FH "rankdir=LR;\n";
    if (defined($param{'size'})) {
      print FH "size=\"$param{'size'}\";\n";
    }
    else {
      print FH "size=\"8,5\";\n";
    }
    if (defined($param{'orientation'})) {
      print FH "orientation=$param{'orientation'};\n";
    }
    else {
      print FH "orientation=portrait;\n";
    }
    print FH "overlap=orthoyx;\n";
    if (defined($param{'splines'})) {
      print FH "splines=true;\n";
    }
    print FH "node [shape = ellipse,fontcolor=blue];\n";
    my @N = $self->vertices;
    # List of supported node attributes
    my @supported_attributes = qw(width height shape color fontsize fontcolor URL);
    foreach my $n(@N) {
      my $dot_attribute;
      foreach my $i (0..$#supported_attributes) {
	my $attribute = $supported_attributes[$i];
	if ($self->has_vertex_attribute($n,$attribute)) {
	  if (!defined($dot_attribute)) {
	    $dot_attribute = "[";
	  }
	  my $value = $self->get_vertex_attributes($n,$attribute);
	  if ($i == 0) {
	    $dot_attribute .= "\"$attribute\" = \"$value\"";
	  }
	  else {
	    $dot_attribute .= ", \"$attribute\" = \"$value\"";
	  }
	  if ($i == $#supported_attributes) {
	    $dot_attribute .= "];\n";
	  }
	}
      }
    }
    foreach my $e (@E) {
      my ($n1,$n2) = @$e;
      my $w = 0;
      if (defined($param{'edge_labels'}) && $self->has_edge_weight($n1,$n2)) {
	$w = $self->get_edge_weight($n1,$n2);
	print FH "\"$n1\" -- \"$n2\" [label = \"$w\"];\n";
      }
      else {
	print FH "\"$n1\" -- \"$n2\";\n";
      }
    }
    print FH "}\n";
  }
  else {
    foreach my $e (@E) {
      my ($n1,$n2) = @$e;
      my $w = 0;
      if ($self->has_edge_weight($n1,$n2)) {
	$w = $self->get_edge_weight($n1,$n2);
	print FH "$n1\t$n2\t$w\n";
      }
      else {
	print FH "$n1\t$n2\n";
      }
    }
    my @N = $self->vertices;
    # Choice of high contrast colours for node classes
    # Order is red green blue yellow purple brown grey, 3 shades of each
    # from dark to light
    my @colours = ('#8B0000', '#FF0000', '#F08080',
		   '#228B22', '#32CD32', '#7FFF00',
		   '#0000FF', '#87CEEB', '#00FFFF',
		   '#BDB76B', '#FFD700', '#FFFF00',
		   '#7B68EE', '#8A2BE2', '#FF00FF',
		   '#8B4513', '#A0522D', '#D2B48C',
		   '#708090', '#A9A9A9', '#D3D3D3', '#FFFFFF');
    my %classcolor;
    my $i = 0;
    foreach my $n(@N) {
      if ($self->has_vertex_attribute($n,'NODECLASS')) {
	my $value = $self->get_vertex_attribute($n,'NODECLASS');
	print FH "//NODECLASS\t$n\t$value\n";
	if (!defined($classcolor{$value})) {
	  $classcolor{$value} = $i;
	  $i += 3; # Alternate colours
	  if ($i == 21) {
	    $i = 1; # Go through colours again but using lighter shades
	  }
	  elsif ($i == 22) {
	    $i = 2;
	  }
	  elsif ($i >= 23) {
	    # Ran out of colours, use white
	    $i = 21;
	  }
	}
      }
    }
    foreach my $class(keys %classcolor) {
      print FH "//NODECLASSCOLOR\t$class\t$colours[$classcolor{$class}]\n";
    }
  }
  close FH;
}

=head2 read_from_file

 Arg1: string, path of file to read graph from
 Arg2: (optional) set to 1 to keep self links
 Arg3: (optional) format used to encode the graph in the file.
                  options are biolayout and matrix
 Arg4: (optional) character used as data separator in the file (default to tab)
 Description: Reads a weighted undirected graph from a file.
              If no weight has been given to an edge, the default value of 1
              is assigned.
              By default, assumes the graph is in biolayout format.
              Currently only supports the NODECLASS attribute for nodes.
              The matrix format expects an adjacency matrix with row and
              column labels.
 Returntype: Algorithms::Graph

=cut

sub read_from_file {

  my ($class,$filename,$keep_self,$format,$separator) = @_;
  $format ||= 'biolayout';
  $keep_self ||= 0;
  $separator ||= "\t";

  my $G = $class->new;

  open FH,"<",$filename or croak "\nERROR: Can't read file $filename: $!\n";
  if ($format eq 'biolayout') {
    while(my $line=<FH>) {
      chomp $line;
      if ($line=~/^\/\//) {
	# Currently only support NODECLASS attribute
	$line=~s/^\/\///;
	my ($attribute,$n,$value) = split(/\s+/,$line);
	if ($attribute eq 'NODECLASS' && defined($n) && defined($value)) {
	  $G->set_vertex_attribute($n,'NODECLASS', $value);
	}
      }
      else {
	my ($n1,$n2,$w) = split(/\t/,$line);
	next if ($n1 eq $n2 && !$keep_self);
	if (defined($w)) {
	  if ($w) { # No edge if weight = 0
	    $G->add_weighted_edge($n1,$n2,$w);
	  }
	}
	else {
	  $G->add_weighted_edge($n1,$n2,1);
	}
      }
    }
  }
  elsif ($format eq 'matrix') {
    my $header = <FH>;
    chomp($header);
    my @col_label = split(/$separator/,$header);
    shift @col_label;
    my $n = scalar(@col_label);
    while(my $line=<FH>) {
      chomp $line;
      my @row = split(/$separator/,$line);
      my $nodeA = $row[0];
      foreach my $i(1..$n-1) {
	my $nodeB = $col_label[$i];
	if ($row[$i]) {
	  $G->add_weighted_edge($nodeA,$nodeB,$row[$i]);
	}
      }
    }
  }
  else {
    croak "\nERROR: Unknown format $format";
  }
  close FH;

  return $G;
}

=head2 degree

 Arg: string, node name
 Description: Gets the degree of a node as the sum of the weights of the edges
              at this node. If no weight has been assigned to an edge, a default
              of 1 is assumed.
 Returntype: double

=cut

sub degree {

  my $self = shift;
  my $node = shift;

  my @neighbours = $self->neighbours($node);
  my $d = 0;
  foreach my $v(@neighbours) {
    $d += $self->get_edge_weight($node,$v) || 1;
  }
  return $d;
}

=head2 file_to_matrix

 Arg1: string, path of file to read graph from
 Arg2: (optional) set to 1 to keep self links
 Description: Reads a weighted undirected graph from a file in layout format
              and returns the corresponding adjacency matrix and list of nodes.
              If no weight has been given to an edge, the default value of 1
              is assigned. Edges not present in the file get a weight of 0.
              Currently only supports the NODECLASS attribute for nodes.
 Returntype: list of (Algorithms::Matrix, arrayref of node names)

=cut

sub file_to_matrix {

  my $class = shift;
  my $filename = shift;
  my $keep_self = shift if @_;
  $keep_self ||= 0;

  my %seen;
  my %weight;
  open FH,"<",$filename or die "\nERROR: Can't read $filename: $!\n";
  while (my $line=<FH>) {
    next if ($line=~/^\/\//);
    chomp($line);
    my ($a,$b,$w) = split(/\t/,$line);
    $seen{$a}++;
    $seen{$b}++;
    if (defined($w)) {
      $weight{"$a\t$b"} = $w;
    }
    else {
      $weight{"$a\t$b"} = 1;
    }
  }
  close FH;
  my @item = keys %seen;
  my $A = Algorithms::Matrix->new(scalar(@item),scalar(@item))->zero;
  if ($keep_self) {
    $A->set(0,0,$weight{"$item[0]\t$item[0]"}) if (defined($weight{"$item[0]\t$item[0]"}));
  }
  foreach my $i(1..$#item) {
    if ($keep_self) {
      $A->set($i,$i,$weight{"$item[$i]\t$item[$i]"}) if (defined($weight{"$item[$i]\t$item[$i]"}));
    }
    foreach my $j(0..$i-1) {
      if (defined($weight{"$item[$i]\t$item[$j]"})) {
	$A->set($i,$j,$weight{"$item[$i]\t$item[$j]"});
	$A->set($j,$i,$weight{"$item[$i]\t$item[$j]"});
      }
      elsif(defined($weight{"$item[$j]\t$item[$i]"})) {
	$A->set($i,$j,$weight{"$item[$j]\t$item[$i]"});
	$A->set($j,$i,$weight{"$item[$j]\t$item[$i]"});
      }
    }
  }

  return $A,\@item;
}

=head2 community

 Description: Cluster graph nodes with the Louvain algorithm described in
              "Fast unfolding of community hierarchies in large networks"
              Vincent D. Blondel, Jean-Loup Guillaume, Renaud Lambiotte,
              Etienne Lefebvre. http://arxiv.org/abs/0803.0476.
              Adapted from C++ implementation by A. Scherrer
              Only performs the first part (local modularity optimization) of
              the Louvain algorithm
 Returntype: list of reference to a hash of community IDs keyed by nodes and corresponding modularity coefficient

=cut

sub community {

  my $self = shift;
  my @V = $self->vertices;
  my $A = $self->get_adjacency_matrix();
  my ($N,undef) = $A->dims; # Number of nodes
  my $B;
  @{$B} = $A->as_array('flat');
  my $com; # $com->[$i] = id of community node $i belongs to
  @{$com} = (0) x $N;
  my $modularity = find_community($B,$com,$N);
  my %com;
  foreach my $i(0..$#V) {
    $com{$V[$i]} = $com->[$i];
  }
  return \%com, $modularity;
}

1;

__DATA__
__C__

#define PROB_EPS 1e-4
#define ABS(x) (((x) < 0) ? -(x) : (x))

typedef struct SparseDim {
    int    nbElems;
    int    absorbing;
    double starting;
    double sum;
    struct SparseElem *first;
    struct SparseElem *last;
    struct Elem *firstAbs;
    struct Elem *lastAbs;
} SparseDim;

typedef struct SparseElem {
    int    l;
    int    c;
    double val;
    double ept;
    double cur;
    double diff;
    struct SparseElem *nextL;
    struct SparseElem *nextC;
} SparseElem;

typedef struct Elem {
    struct SparseElem *selem;
    struct Elem *next;
} Elem;

typedef struct DegStat {
    int    minDeg;
    int    maxDeg;
    double meanDeg;
} DegStat;

/* Allocate a vector of doubles */
double *vec_alloc(int n) {
  double *v;
  v=(double *) calloc(n,sizeof(double));
  if(v==NULL) {
    croak("could not allocate memory");
  }
  return v;
}

/* Allocate a matrix of doubles */
double **mat_alloc(int n, int k) {
  int i;
  double **mat;
  mat=(double **) calloc(n,sizeof(double *));
  if(mat == NULL) {
    croak("could not allocate memory");
  }
  for(i=0; i<n; i++) {
    mat[i]=(double *) calloc(k,sizeof(double));
    if(mat[i] == NULL) {
      croak("could not allocate memory");
    }
  }
  return mat;
}
/* Deallocate a matrix of doubles*/
void free_mat(double **matrix, int dim1) {
    int i;
    for (i=0; i<dim1; i++)
        free(matrix[i]);
    free(matrix);
}

/* Initialize a vector of doubles with zeros */
void init_vec(double *vector, int dim1) {
  int i;
  for(i=0; i < dim1; i++)
    vector[i] = 0.0;
}

/* Initialize a matrix of doubles with zeros */
void init_mat(double **matrix, int dim1, int dim2){
  int i, j;
  for (i=0; i<dim1; i++)
    for(j=0; j<dim2; j++)
      matrix[i][j] = 0.0;
}

/* Allocate a matrix of integers */
int **int_mat_alloc(int n, int k) {
  int i, **mat;
  mat=(int **) calloc(n,sizeof(int *));
  if(mat == NULL) {
    croak("could not allocate memory");
  }
  for(i=0; i<n; i++) {
    mat[i]=(int *) calloc(k,sizeof(int));
    if(mat[i] == NULL) {
      croak("could not allocate memory");
    }
  }
  return mat;
}

/* Deallocate a matrix of integers */
void free_int_mat(int **matrix, int dim1){
  int i;
  for (i=dim1-1; i>=0; i--)
    free(matrix[i]);
  free(matrix);
}

/* Initialize a vector of integers with zeros */
void init_int_vec(int *vector, int dim){
  int i;
  for (i=0; i<dim; i++)
    vector[i] = 0;
}


/*Initialize an array of SparseDim*/
void init_SparseDims(SparseDim* sdim,int dim1){
  int i;
  for(i=0;i<dim1;i++){
    sdim[i].nbElems   = 0;
    sdim[i].starting  = 0;
    sdim[i].absorbing = 0;
    sdim[i].sum       = 0.0;
    sdim[i].first     = NULL;
    sdim[i].last      = NULL;
    sdim[i].firstAbs  = NULL;
    sdim[i].lastAbs   = NULL;
  }
}

/* Compute the sum of a vector of doubles */
double vecSum(double* vec,int n){
  int i;
  double sum =0.0;

  for(i=0;i<n;i++){
    sum += vec[i];
  }
  return sum;
}

/* Enforce the stochasticity of a vector of positive double */
double stochVector(double* vec,int n){
  int i;
  double sum = vecSum(vec,n);

  if (sum>0){
    for(i=0;i<n;++i)
      vec[i] = vec[i]/sum;
  }
  return sum;
}

/* Enforce the stochasticity of a sparse matrix of positive double */
void stochMat_sparse(SparseDim* rows,int n){
  int i;
  SparseElem* elem;
  for(i=0;i<n;i++){
    elem = rows[i].first;
    while(elem){
      elem->val /= rows[i].sum;
      elem = elem->nextC;
    }
  }
}

/* Build a forward lattice up to wlen */
void buildLatticeForward_sparse(double** lat,int wlen,int* kgroup,double* kgproba,SparseDim* cols,int n){

  int j,k;
  SparseElem* elem;

  /* Clean the lattice */
  init_mat(lat,n,wlen+1);

  /* Initialization for time 0 */
  for(j=1;j<=kgroup[0];j++){
    lat[kgroup[j]][0] = kgproba[j];
  }

  /* Propagate probabilities in the lattice */
  for (k=1;k<=wlen;++k){
    for (j=0;j<n;j++){
      elem = cols[j].first;
      while(elem){
	if(!cols[elem->l].absorbing)
	  lat[j][k] += lat[elem->l][k-1]*(elem->val);
	elem = elem->nextL;
      }
    }
  }
}

/* Build a backward lattice up to wlen */
void buildLatticeBackward_sparse(double** lat,int wlen,SparseDim* rows,int n){

  int i,k;
  SparseElem* elem;

  /* Clean the lattice */
  init_mat(lat,n,wlen+1);

  /* Initialization for time wlen */
  for(i=0;i<n;i++){
    if(rows[i].absorbing)
      lat[i][wlen] = 1;
  }

  /* Propagate probabilities in the lattice */
  for (k=wlen;k>=1;--k){
    for(i=0;i<n;i++){
      if(!rows[i].absorbing){
	elem = rows[i].first;
	while(elem){
	  lat[i][k-1] += lat[elem->c][k]*(elem->val);
	  elem = elem->nextC;
	}
      }
    }
  }
}

/* Set all the groups being absorbing except the starting group */
void setAbsStates_sparse(SparseDim* rows,SparseDim* cols,int n,int** kgroups,double** kgprobas,int nbGroups,int start){
  int i,j;
  Elem* elem;
  SparseElem* selem;

  /* Reset the absorbing and starting states */
  for(i=0;i<n;i++){
    rows[i].absorbing  = 0;
    cols[i].absorbing  = 0;
    rows[i].starting   = 0;
    cols[i].starting   = 0;
    rows[i].firstAbs   = NULL; /* Controlled memory leak */
    rows[i].lastAbs    = NULL; /* Controlled memory leak */
  }

  /* Set all the groups being absorbing except the starting group */
  for(i=0;i<nbGroups;i++){     /* Set the starting group */
    for(j=1;j<=kgroups[i][0];j++){
      if(i != start){
	rows[kgroups[i][j]].absorbing = 1;
	cols[kgroups[i][j]].absorbing = 1;
	selem = cols[kgroups[i][j]].first;
	while(selem){
	  if(selem->l != selem->c){
	    if(!rows[selem->l].firstAbs){
	      rows[selem->l].firstAbs = malloc(sizeof(Elem));
	      rows[selem->l].lastAbs  = rows[selem->l].firstAbs;
	    }
	    else{
	      rows[selem->l].lastAbs->next = malloc(sizeof(Elem));
	      rows[selem->l].lastAbs = rows[selem->l].lastAbs->next;
	    }
	    rows[selem->l].lastAbs->selem = selem;
	    rows[selem->l].lastAbs->next = NULL;
	  }
	  selem = selem->nextL;
	}
      }
      else {
	rows[kgroups[i][j]].starting = kgprobas[i][j];
	cols[kgroups[i][j]].starting = kgprobas[i][j];
      }
    }
  }
}

/* Compute the absolute EPT difference : |E_ij - E_ji| */
void diffEPT_sparse(SparseDim* rows,SparseDim* cols,int n){

  int i,j;
  double diff;
  SparseElem* elemL;
  SparseElem* elemC;

  for(i=0;i<n;i++){
    elemL = rows[i].first;
    elemC = cols[i].first;
    /* Scan the two lists in parallel */
    while(elemL && elemC){
      if(elemL->c >= i){
	diff = ABS((elemL->cur) - (elemC->cur));
	elemL->diff += diff;
	elemC->diff += diff;
	elemL->cur   = 0;
	elemC->cur   = 0;
      }
      elemL = elemL->nextC;
      elemC = elemC->nextL;
    }
  }
}

/* Get the number of non-null elements in a matrix */
void matrixNNZ_sparse(SparseDim* rows,int n,int* nnz,int* nnr){
  int i;
  int *touched = malloc(n*sizeof(int));
  SparseElem* elem;
  *nnz=0,*nnr=0;

  init_int_vec(touched,n);
  for(i=0;i<n;i++){
    elem = rows[i].first;
    while(elem){
      if(elem->ept > 0){
	if (!touched[i]){
	  touched[i]=1;
	  (*nnr)++;
	}
	if (!touched[elem->c]){
	  touched[elem->c]=1;
	  (*nnr)++;
	}
	(*nnz)++;
      }
      elem = elem->nextC;
    }
  }
  free(touched);
}

void lkwalk (SV* Aref, SV* nodes_ref, int wlen, int nbNodes,int nbKnodes, int verbose) {

    /* Working variables */
    int         i,j,k,t,l;
    int         undirected = 1;
    int         outfile = 0;
    int         nnz,nnr;
    int         sumDeg = 0;
    int         nbEdges = 0;
    double      p_wlen;
    double      pabs;
    double      tmp,accF,accB;
    double      update;
    double      mass_i=0.0;
    double      mass_abs=0.0;
    double      expWlen=0.0;
    double*     N;
    double**    latF;
    double**    latB;
    SparseDim*  rows;
    SparseDim*  cols;
    SparseElem* selem;
    Elem*       elem;
    DegStat    degStat;
    /* We keep the data structures to deal with multiple groups although we only use one and will use as many groups as nodes of interest */
    int**     kgroups;
    double**  kgprobas;
    int       maxNPG = 1;
    int       nbGroups;
    /* For access to Perl arrays */
    AV *A, *Ai, *Aij;
    A = (AV*)SvRV(Aref);
    SV **nb, **w;
    double val, Nneighbours;
    int from, to;
    AV *nodes;
    nodes = (AV*)SvRV(nodes_ref);
    SV **Node;
    int idx;

    /* Allocate data structures */
    N    = vec_alloc(nbNodes);
    latF = mat_alloc(nbNodes,wlen+1);
    latB = mat_alloc(nbNodes,wlen+1);
    rows = malloc(sizeof(SparseDim)*nbNodes);
    cols = malloc(sizeof(SparseDim)*nbNodes);

    /* Initialize the sparse transition matrix */
    init_SparseDims(rows,nbNodes);
    init_SparseDims(cols,nbNodes);

    /* Initialize the N vector */
    init_vec(N,nbNodes);

    /* Initialize the degree statistics */
    degStat.minDeg  = nbNodes;
    degStat.maxDeg  = 0;
    degStat.meanDeg = 0.0;

    /* Fill sparse matrix data structure */
    for (i = 0; i < nbNodes; i++) {
      from = i;
      Ai = (AV*)SvRV(*av_fetch(A, i, 0));
      Nneighbours = av_len(Ai);
      for (j = 0; j <= Nneighbours; j++) {
	Aij = (AV*)SvRV(*av_fetch(Ai, j, 0));
	nb = av_fetch(Aij, 0,0);
	to = SvNV(*nb);
	w = av_fetch(Aij, 1,0);
	val = SvNV(*w);
	/* Add the element in the row "from" */
	if (!rows[from].last){
	  rows[from].first = malloc(sizeof(SparseElem));
	  rows[from].last  = rows[from].first;
	}
	else {
	  rows[from].last->nextC  = malloc(sizeof(SparseElem));
	  rows[from].last         = rows[from].last->nextC;
	}
	/* Put the value in the element */
	rows[from].last->l     = from;
	rows[from].last->c     = to;
	rows[from].last->val   = val;
	rows[from].last->ept   = 0;
	rows[from].last->cur   = 0;
	rows[from].last->diff  = 0;
	rows[from].last->nextL = NULL;
	rows[from].last->nextC = NULL;
	rows[from].nbElems    += 1;
	rows[from].sum        += val;

	/* Add the element in the column "to" */
	if (!cols[to].last){
	  cols[to].first  = rows[from].last;
	  cols[to].last   = rows[from].last;
	}
	else {
	  cols[to].last->nextL = rows[from].last;
	  cols[to].last = rows[from].last;
	}
	cols[to].nbElems += 1;
	cols[to].sum += val;
	/* Update the number of edges */
	nbEdges += 1;
      } /* End neighbours loop */
	if (rows[from].nbElems > degStat.maxDeg)
	  degStat.maxDeg = rows[from].nbElems;
      if (rows[from].nbElems < degStat.minDeg)
	degStat.minDeg = rows[from].nbElems;
      sumDeg += rows[from].nbElems;
    } /* End nodes loop */
    degStat.meanDeg = (double)sumDeg/(double)nbNodes;

    /* Set all edge weights to 0 in Perl array */
    for (i = 0; i < nbNodes; i++) {
      Ai = (AV*)SvRV(*av_fetch(A, i, 0));
      Nneighbours = av_len(Ai);
      for (j = 0; j <= Nneighbours; j++) {
	Aij = (AV*)SvRV(*av_fetch(Ai, j, 0));
	nb = av_fetch(Aij, 0,0);
	w = av_fetch(Aij, 1,0);
	sv_setnv(*w,0);
      }
    }

    /* Make matrix stochastic */
    stochMat_sparse(rows,nbNodes);

    if (verbose) {
      /* Print statistics about the graph */
      printf("-------------------------------------------------------\n");
      printf("Statistics about the graph:\n");
      printf("\nNumber of nodes : %i\n",nbNodes);
      printf("Number of edges : %i\n",nbEdges);
      printf("Directed        : %s\n",(undirected)?"no":"yes");
      printf("Mean degree     : %2.2f\n",degStat.meanDeg);
      printf("Min  degree     : %i\n",degStat.minDeg);
      printf("Max  degree     : %i\n",degStat.maxDeg);
      printf("-------------------------------------------------------\n");
    }

    nbGroups = nbKnodes;
    kgroups = int_mat_alloc(nbGroups,maxNPG+1);

    /* Get the nodes of interest */
    for (i = 0; i < nbKnodes; i++) {
      Node = av_fetch(nodes, i,0);
      idx = SvNV(*Node);
      kgroups[i][0] = 1; /* Number of nodes in the group */
      kgroups[i][1] = idx; /* One group per node of interest */
    }

    /* Set a uniform distribution for starting probabilities */
    kgprobas = mat_alloc(nbGroups,maxNPG+1);
    /* Use uniform distribution */
    for(i=0;i<nbGroups;i++){
      kgprobas[i][0] = kgroups[i][0];
      for(j=1;j<=kgroups[i][0];j++){
	kgprobas[i][j] = 1.0/(double)nbKnodes;
      }
    }

    /* Loop on the relevant nodes */
    for(i=0;i<nbGroups;i++){
      /* Normalize the initial distribution */
      mass_i = stochVector(kgprobas[i]+1,kgprobas[i][0]);

      /* Build the transition matrix w.r.t group i and set the starting states */
      setAbsStates_sparse(rows,cols,nbNodes,kgroups,kgprobas,nbGroups,i);

      /* Build the forward-backward lattices up to length wlen */
      buildLatticeForward_sparse(latF,wlen,kgroups[i],kgprobas[i],cols,nbNodes);
      buildLatticeBackward_sparse(latB,wlen,rows,nbNodes);

      /* Use linear up-to mode as opposed to fixed length walks */
      for(k=0;k<nbNodes;k++){
	accB = 0;
	accF = 0;
	for(l=wlen-1;l>=0;l--){
	  if(!rows[k].absorbing){
	    accB += latB[k][l];
	    accF += latF[k][l];
	    if(l > 0){
	      /* Transient to Transient */
	      selem = cols[k].first;
	      while (selem){
		if(!cols[selem->l].absorbing){
		  update = mass_i*(selem->val)*latF[selem->l][l-1]*accB;
		  selem->cur   += update;
		  selem->ept   += update;
		  expWlen      += update;
		  N[selem->l]  += update;
		}
		selem = selem->nextL;
	      }
	    }
	    else{
	      /* Absorbing from Transient */
	      elem = rows[k].firstAbs;
	      while(elem){
		update = mass_i*accF*(elem->selem->val);
		elem->selem->cur  += update;
		elem->selem->ept  += update;
		expWlen           += update;
		N[k]              += update;
		elem = elem->next;
	      }
	      /* Absorption Mass */
	      if(rows[k].starting){
		mass_abs += mass_i*rows[k].starting*accB;
	      }
	    }
	  }
	}
      }
    } /* End loop on relevant nodes */

    diffEPT_sparse(rows,cols,nbNodes); /* The graph is undirected compute |E_ij - E_ji| */
    if (verbose) {
      printf("Subgraph statistics:\n");
      printf("Absorption probability ratio    : %.3f\n",mass_abs);
      printf("Expected walk length            : %.3f\n",expWlen);
      matrixNNZ_sparse(rows,nbNodes,&nnz,&nnr);
      printf("Subgraph size (#edges)          : %i\n",nnz);
      printf("Subgraph size (#nodes)          : %i\n",nnr);
      printf("Subgraph relative size (#edges) : %.3f\n",(double)nnz/(double)nbEdges);
      printf("-------------------------------------------------------\n");
    }
    SparseElem* elemOut;
    /* Export to Perl array by changing the edge weights */
    for(i=0;i<nbNodes;i++){
      elemOut = rows[i].first;
      Ai = (AV*)SvRV(*av_fetch(A, i, 0));
      Nneighbours = av_len(Ai);
      while (elemOut && elemOut->c <= i){
	if (elemOut->diff > 0){ /* Keep this edge */
	  for (j = 0; j <= Nneighbours; j++) {
	    Aij = (AV*)SvRV(*av_fetch(Ai, j, 0));
	    nb = av_fetch(Aij, 0,0);
	    to = SvNV(*nb);
	    if (elemOut->c == to) {
	      w = av_fetch(Aij, 1,0);
	      sv_setnv(*w,elemOut->diff);
	      break;
	    }
	  }
	}
	elemOut = elemOut->nextC;
      }
    }
    free(N);
    free_mat(latF,wlen+1);
    free_mat(latB,wlen+1);
    free(rows);
    free(cols);
}

double find_community(SV* INref, SV* OUTref, int N) {

  /* For access to Perl arrays */
  AV *in, *out;
  in = (AV*)SvRV(INref);
  out = (AV*)SvRV(OUTref);

  double *COM = malloc(N*sizeof(double));
  int *CSize = malloc(N*sizeof(int));
  double* DeltaQ;
  double* K;
  double* Cost;
  double* SumIn;
  double* SumTot;
  double* Self;

  DeltaQ = vec_alloc(N);
  K = vec_alloc(N);
  Cost = vec_alloc(N);
  SumIn = vec_alloc(N);
  SumTot = vec_alloc(N);
  Self = vec_alloc(N);

  double min_increase = 0.0;
  int max_pass = 100;
  int i, j, k, l;

  for (i = 0;i < N; i++) {
    SumIn[i] = SvNV(*av_fetch(in,i*N+i,0));
    SumTot[i] = 0.0;
    DeltaQ[i] = 0.0;
    K[i] = 0.0;
    Cost[i] = 0.0;
    COM[i] = i;
    Self[i] = 0.0;
    CSize[i] = 1;
  }

  double m1 = 0.0;
  double m2 = 0.0;
  for (i = 0;i < N; i++){
    double mt = 0.0;
    for (j = 0;j < N; j++){
      m2 += SvNV(*av_fetch(in,i*N+j,0));
      mt += SvNV(*av_fetch(in,i*N+j,0));
      if (i==j)
	Self[i] = SvNV(*av_fetch(in,i*N+j,0));
    }
    K[i] = mt;
    SumTot[i] = mt;
  }
  m1 = m2 / 2;

  int gain = 1;
  int Niter = 0;

  double sum_g = 0.0;
  double mod_exp = 0.0;

  double init_mod = 0.0;
  for (k = 0; k < N; k++){
    init_mod += SumIn[k]/m2 - (SumTot[k]/m2)*(SumTot[k]/m2);
  }

  double new_mod = init_mod;
  double cur_mod = init_mod;

  /* Main loop */
  while (gain && Niter < max_pass){
    cur_mod = new_mod;
    sum_g = 0.0;
    mod_exp = 0.0;
    gain = 0;

    /* Loop over all nodes */
    for (i = 0; i < N; i++){
      int Ci = COM[i];
      double best_increase = 0.0;
      int best_com = Ci;
      for (l = 0; l < N; l++){
	DeltaQ[l] = 0.0;
      }

      /* Delete i from its community */
      COM[i] = -1;
      for (k = 0; k < N; k++){
	if (COM[k] == Ci){
	  double z = SvNV(*av_fetch(in,i*N+k,0));
	  SumIn[Ci] -= 2.0*z;
	}
      }
      SumIn[Ci] -= Self[i];
      SumTot[Ci] -= K[i];
      CSize[Ci]--;

      /* Loop over neighbours */
      for (j = 0; j < N; j++){
	/* Check if neighbour and different com */
	int Cj = COM[j];
	double z = SvNV(*av_fetch(in,i*N+j,0));
	if (z != 0 && DeltaQ[Cj] == 0 && Cj != -1){
	  /* Compute Ki_in */
	  double Ki_in = 0.0;
	  for (k = 0; k < N; k++){
	    if (COM[k] == Cj){
	      z = SvNV(*av_fetch(in,i*N+k,0));
	      Ki_in += 2.0*z;
	    }
	  }
	  DeltaQ[Cj] = (Ki_in)/m2 - (2.0 * K[i] * SumTot[Cj]) / (m2*m2);

	  if (DeltaQ[Cj] > best_increase){
	    best_increase = DeltaQ[Cj];
	    best_com = Cj;
	  }
	}
      }

      if (best_increase > 0){
	/* Move i in highest gain community */
	if (best_com < 0 || best_com > N-1){
	  printf("Internal ERROR (%d)\n",best_com);
	}
	sum_g += best_increase;
	Cost[i] = best_increase;
	mod_exp += best_increase;

	if (best_com != Ci){
	  gain = 1;
	}
      }  else {
	best_com = Ci;
      }

      /* Update com */
      for (k = 0; k < N; k++){
	if (COM[k] == best_com){
	  double z = SvNV(*av_fetch(in,i*N+k,0));
	  SumIn[best_com] += 2.0*z;
	}
      }
      SumIn[best_com] += Self[i];
      SumTot[best_com] += K[i];
      COM[i] = best_com;
      CSize[best_com]++;

    }

    new_mod = 0.0;
    for (k = 0; k < N; k++){
      if (SumTot[k] > 0) {
	new_mod += SumIn[k]/m2 - (SumTot[k]/m2)*(SumTot[k]/m2);
      }
    }

    if (new_mod-cur_mod <= min_increase){
      gain = 0;
    }

    Niter++;

  }

  /* return result */
  for (k = 0; k < N; k++){
    SV* svNewVal;
    svNewVal = newSViv(COM[k]);
    av_store(out,k,svNewVal);
  }

  /* clean up*/
  free(COM);
  free(CSize);
  free(DeltaQ);
  free(K);
  free(Cost);
  free(SumIn);
  free(SumTot);
  free(Self);

  return new_mod;
}
