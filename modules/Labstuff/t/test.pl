#!/usr/bin/perl

use strict;
use warnings;
use Labstuff::Plate;
use Labstuff::Well;
use Labstuff::Sample;
use Labstuff::Treatment;
use Labstuff::Reporter;

# Create a new 8-well plate
my $plate = Labstuff::Plate->new(rows=>2, cols=>4);
my $plname = $plate->name('8-well plate');

# Create some samples
my $cell1 = Labstuff::Sample->new(name=>'HeLa H2B-GFP',
				  description=>'HeLa cells stably expressing H2B-GFP');
my $cell2 = Labstuff::Sample->new(name=>'HeLa CENPA-mCherry',
				  description=>'HeLa cells stably expressing CENPA-mCherry');

# Create some treatments
my $neg_ctrl = Labstuff::Treatment->new(type=>'dsRNA',
					ID=>'XWNeg9',
					refDB=>'bluegecko',
					description=>'Negative control'
				       );
my $ncapd3 = Labstuff::Treatment->new(type=>'dsRNA',
				      ID=>'s23530',
				      refDB=>'bluegecko',
				      description=>'NCAPD3 knockdown'
				     );
my $mcph1 = Labstuff::Treatment->new(type=>'dsRNA',
				     ID=>'s36005',
				     refDB=>'bluegecko',
				     description=>'MCPH1 knockdown'
				    );

# Create some reporters
my $H2B = Labstuff::Reporter->new(type=>'fusion protein',
				  description=>'H2B-GFP'
				 );
my $CENPA = Labstuff::Reporter->new(type=>'fusion protein',
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
print "Plate1:\n";
foreach my $well($plate->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}

# Create a new 12-well plate
my $plate2 = Labstuff::Plate->new(rows=>3, cols=>4);
my $plname2 = $plate2->name('12-well plate');
# Copy a well from the first plate to the new plate
my $w1 = $plate->get_well('A3');
my $w2 = $w1->duplicate($plate2,'C1');
# Look at the new plate content
print "Plate2:\n";
foreach my $well($plate2->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}

# Produce 3 replicates
my @replicates = $plate->replicate(3);
print "Created ",scalar(@replicates)," replicates\n";
# Check one replicate
foreach my $well($replicates[1]->filled_wells) {
  print "\tWell ",$well->position,"\n";
  print "\t\tSamples: ",join(", ",map {$_->name} $well->samples),"\n";
  print "\t\tTreatments: ",join(", ",map {$_->description} $well->treatments),"\n";
  print "\t\tReporters: ",join(", ",map {$_->description} $well->reporters),"\n";
}
