#!/usr/bin/perl

use strict;
use warnings;
use Labstuff::Core;

my $lab = Labstuff::Core->new();

# Create a new 8-well plate
my $plate = $lab->new_plate(rows=>2, cols=>4);
my $pltype = $plate->type('8-well plate');
my $plname = $plate->name('Plate1');

# Create some samples
my $cell1 = $lab->new_sample(name=>'HeLa H2B-GFP',
			     description=>'HeLa cells stably expressing H2B-GFP');
my $cell2 = $lab->new_sample(name=>'HeLa CENPA-mCherry',
			     description=>'HeLa cells stably expressing CENPA-mCherry');

# Create some treatments
my $neg_ctrl = $lab->new_treatment(type=>'dsRNA',
				   ID=>'XWNeg9',
				   refDB=>'bluegecko',
				   description=>'Negative control'
				  );
my $ncapd3 = $lab->new_treatment(type=>'dsRNA',
				 ID=>'s23530',
				 refDB=>'bluegecko',
				 description=>'NCAPD3 knockdown'
				);
my $mcph1 = $lab->new_treatment(type=>'dsRNA',
				ID=>'s36005',
				refDB=>'bluegecko',
				description=>'MCPH1 knockdown'
			       );

# Create some reporters
my $H2B = $lab->new_reporter(type=>'fusion protein',
			     description=>'H2B-GFP'
			    );
my $CENPA = $lab->new_reporter(type=>'fusion protein',
			       description=>'CENPA-mCherry'
			      );

# Process wells
foreach my $i(1..4) {
  my $well = $plate->get_well("A$i");
  $well->samples($cell1,$cell2);
  $well->reporters($H2B,$CENPA);
  if ($well->position eq 'A1') {
    $well->treatments($neg_ctrl);
  }
  elsif ($well->position eq 'A2') {
    $well->treatments($neg_ctrl,$ncapd3);
  }
  elsif ($well->position eq 'A3') {
    $well->treatments($neg_ctrl,$mcph1);
  }
  elsif ($well->position eq 'A4') {
    $well->treatments($ncapd3,$mcph1);
  }
}

# Look at the plate content
print $plate->name,":\n";
print $plate->type,":\n";
foreach my $well($plate->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}

# Create a new 12-well plate
my $plate2 = Labstuff::Plate->new(rows=>3, cols=>4);
my $pltype2 = $plate2->type('12-well plate');
my $plname2 = $plate2->name('Plate2');
# Copy a well from the first plate to the new plate
my $w1 = $plate->get_well('A3');
my $w2 = $w1->duplicate($plate2,'C1');
# Look at the new plate content
print $plate2->name,":\n";
print $plate2->type,":\n";
foreach my $well($plate2->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}
print "Serializing ",$plate2->name,"...";
my $file2 = $lab->store($plate2);
print "Done.\n";
print "Forgetting about ",$plate2->name,"...";
undef($plate2);
print "Done.\n";
print "Retrieving serialized plate...";
$plate2 = $lab->retrieve($file2);
print "Done.\n";
# Look at the retored plate content
print "Restored plate looks like this:\n";
print "\t",$plate2->name,":\n";
print "\t",$plate2->type,":\n";
foreach my $well($plate2->filled_wells) {
  print "\t\tWell ",$well->position,"\n";
  print "\t\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}

# Produce 3 replicates
my @replicates = $plate->replicate(3);
print "Created ",scalar(@replicates)," replicates of ",$plate->name,"\n";
# Check one replicate
print "Content of one replicate:\n";
foreach my $well($replicates[1]->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}
