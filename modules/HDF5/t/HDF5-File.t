# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Algorithms-Matrix.t'

#########################

use Test::Simple tests => 53;
use HDF5::File;
ok(1,'Load module'); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $OK = 0;
my $file = HDF5::File->new('test1.h5');
$OK = 1 if ($file && $file->is_open);
ok($OK,'File: new'); # Test 2
$OK = 0;
my $status = $file->close();
$OK = 1 unless (!$status || $file->is_open);
ok($OK,'File: close'); # Test 3
$OK = 0;
$OK = 1 if ($file->name eq 'test1.h5');
ok($OK,'File: name'); # Test 4
$OK = 0;
my $file1 = HDF5::File->open('test1.h5');
$OK = 1 if ($file1->is_open);
ok($OK,'File: open'); # Test 5
$OK = 0;
my $gr1 = $file1->create_group("/G1");
$OK = 1 if ($gr1 && $gr1->is_open);
ok($OK,'File: create group'); # Test 6
$OK = 0;
my $gr2 = $file1->create_group("/G1/G2");
$OK = 1 if ($gr2 && $gr2->is_open);
ok($OK,'File: create another group'); # Test 7
$OK = 0;
# 4D string data
my $A = [
	 [
	  [
	   ['a','bc'],
	   ['def','ghij']
	  ],
	  [
	   ['qwert','yuiop'],
	   ['asdfg','hjkl;:']
	  ]
	 ],
	 [
	  [
	   ['klmno','pqrstu'],
	   ['vwxyz01','23456789']
	  ],
	  [
	   ['zxcv','bnm,'],
	   ['<>?":}{','+_*&^%$']
	  ]
	 ]
	];
my $dataset1 = HDF5::Dataset->new($gr2,'D1',[2,2,2,2],'string');
$OK = 1 if ($dataset1 && $dataset1->name eq 'D1' && $dataset1->is_open);
ok($OK,'Dataset: new, string type'); # Test 8
$OK = 0;
$status = $dataset1->write_data($A);
$OK = 1 if ($status);
ok($OK,'Dataset: write, string type'); # Test 9
$OK = 0;
my $file2 = HDF5::File->new('test2.h5');
$OK = 1 if ($file2 && $file2->is_open);
ok($OK,'File: new'); # Test 10
$OK = 0;
my $B = [
	 [
	  [
	   [0.242352214235,12.5431566548,10002.342],
	   [1e-5,6e-4,9.433253e-11]
	  ],
	  [
	   [1.3434e22,3.54e9,93284823.4823],
	   [98.34323,0.1234567890123456789,1345565]
	  ]
	 ],
	 [
	  [
	   [1.00,2.00,3.00],
	   [4.00,5.00,6.00]
	  ],
	  [
	   [7.001e-2,8.0002e-3,9.123e-4],
	   [rand,rand(12),rand(132)]
	  ]
	 ]
	];
my $dataset2 = HDF5::Dataset->new($file2,'D2',[2,2,2,3]);
$OK = 1 if ($dataset2 && $dataset2->name eq 'D2' && $dataset2->is_open);
ok($OK,'Dataset: new, float type'); # Test 11
$OK = 0;
$status = $dataset2->write_data($B);
$OK = 1 if ($status);
ok($OK,'Dataset: write, float type'); # Test 12
$OK = 0;
$status = $dataset2->close();
$OK = 1 if ($status);
ok($OK,'Dataset: close'); # Test 13
$OK = 0;
my $gr3 = $file1->create_group("/G1/G3");
$OK = 1 if ($gr3 && $gr3->is_open);
ok($OK,'File: create group'); # Test 14
$OK = 0;
$status = $dataset1->move($gr3,'DX');
$OK = 1 if ($status);
ok($OK,'Dataset: move'); # Test 15
$OK = 0;
$status = $file1->mount($file1,"/G1/G2",$file2);
$OK = 1 if ($status);
ok($OK,'File: mount'); # Test 16
$OK = 0;
$status = $file1->flush();
$OK = 1 if ($status);
ok($OK,'File: flush'); # Test 17
$OK = 0;
$status = $dataset1->close();
$OK = 1 if ($status);
ok($OK,'Dataset: close'); # Test 18
$OK = 0;
$dataset1 = $dataset1->open($file1,"/G1/G3/DX");
$OK = 1 if ($dataset1 && $dataset1->is_open && $dataset1->name eq '/G1/G3/DX' && $dataset1->datatype eq 'string');
ok($OK,'Dataset: open (moved dataset)'); # Test 19
$OK = 0;
my @dims1 = $dataset1->dims;
foreach my $d(0..$#dims1) {
  if ($dims1[$d] != 2) {
    $OK = 0;
    last;
  }
  else {
    $OK = 1;
  }
}
ok($OK,'Dataset: dims'); # Test 20
$OK = 0;
my $failed = 0;
my $R1 = $dataset1->read_data();
foreach my $i(0..$dims1[0]-1) {
  foreach my $j(0..$dims1[1]-1) {
    foreach my $k(0..$dims1[2]-1) {
      foreach my $l(0..$dims1[3]-1) {
	if ($R1->[$i][$j][$k][$l] ne $A->[$i][$j][$k][$l]) {
	  $failed++;
	}
      }
    }
  }
}
$OK = 1 unless ($failed);
ok($OK,'Dataset: read, string type'); # Test 21
$OK = 0;
$OK = 1 if ($dataset1->group->name eq '/G1/G3');
ok($OK,'Group: name'); # Test 22
$OK = 0;
$dataset2 = $dataset2->open($file1,"/G1/G2/D2"); # file2 is still mounted on file 1
$OK = 1 if ($dataset2 && $dataset2->is_open && $dataset2->name eq '/G1/G2/D2');
ok($OK,'Dataset: open (mounted)'); # Test 23
$OK = 0;
$OK = 1 if ($dataset2->datatype eq 'float');
ok($OK,'Dataset: type'); # Test 24
$OK = 0;
my @dims2 = $dataset2->dims;
foreach my $d(0..$#dims2) {
  if ($d<$#dims2 && $dims2[$d] != 2) {
    $OK = 0;
    last;
  }
  elsif ($d == $#dims2 && $dims2[$d] != 3) {
   $OK = 0;
    last;
  }
  else {
    $OK = 1;
  }
}
ok($OK,'Dataset: dims'); # Test 25
$OK = 0;
my $failed = 0;
my $R2 = $dataset2->read_data();
foreach my $i(0..$dims2[0]-1) {
  foreach my $j(0..$dims2[1]-1) {
    foreach my $k(0..$dims2[2]-1) {
      foreach my $l(0..$dims2[3]-1) {
	if ($R2->[$i][$j][$k][$l] != $B->[$i][$j][$k][$l]) {
	  $failed++;
	}
      }
    }
  }
}
$OK = 1 unless ($failed);
ok($OK,'Dataset: read, float type'); # Test 26
$OK = 0;
$status = $file1->unmount($file2,"/G1/G2");
$OK = 1 if ($status);
ok($OK,'File: unmount'); # Test 27
$OK = 0;
$status = $dataset1->close();
$OK = 1 if ($status);
ok($OK,'Dataset: close'); # Test 28
$OK = 0;
my $slice = $dataset2->read_data_slice([1,0,0,0],[1,1,1,1],[1,1,2,3],[1,1,1,1]);
my @ary = @{$slice};
my $idx = 0;
my $status = 'OK';
foreach my $i(0..$#{$ary[0][0]}) {
  foreach my $j(0..$#{$ary[0][0][$i]}) {
    $idx++;
    if ($ary[0][0][$i][$j] != $idx) {
      $status = 'Failed';
      last;
    }
  }
  last if ($status ne 'OK');
}
if ($status eq 'OK') {
  $OK = 1;
}
ok($OK,'Dataset: read data slice, float type'); # Test 29
$status = $dataset2->close();
$OK = 1 if ($status);
ok($OK,'Dataset: close'); # Test 30
$OK = 0;
$status = $gr3->close();
$OK = 1 if ($status);
ok($OK,'Group: close'); # Test 31
$OK = 0;
$status = $gr2->close();
$OK = 1 if ($status);
ok($OK,'Group: close'); # Test 32
$OK = 0;
$status = $gr1->close();
$OK = 1 if ($status);
ok($OK,'Group: close'); # Test 33
$OK = 0;
$status = $file2->close;
$OK = 1 if ($status);
ok($OK,'File: close'); # Test 34
$OK = 0;
$status = $file1->close;
$OK = 1 if ($status);
ok($OK,'File: close'); # Test 35
$OK = 0;
my $file3 = HDF5::File->new('test3.h5');
$OK = 1 if ($file3 && $file3->name eq 'test3.h5' && $file3->is_open);
ok($OK,'File: new'); # Test 36
$OK = 0;
my $C;
my @images = ('test1.png','test2.png');
foreach my $i(0..$#images) {
  open( my $fh, "<", $images[$i] ) || die "\nERROR: Can't open $images[$i]: $!\n";
  binmode($fh);
  my $buffer;
  while(read($fh,$buffer,4096)) {
    $C->[$i] .= $buffer;
  }
  close $fh;
}
my $n = scalar(@images);
my $dataset3 = HDF5::Dataset->new($file3,'D3',[$n],'opaque','PNG');
$OK = 1 if ($dataset3 && $dataset3->name eq 'D3' && $dataset3->is_open);
ok($OK,'Dataset: new, opaque type'); # Test 37
$OK = 0;
$status = $dataset3->write_data($C);
$OK = 1 if ($status);
ok($OK,'Dataset: write, opaque type'); # Test 38
$OK = 0;
$status = $dataset3->close();
$OK = 1 if ($status);
ok($OK,'Dataset: close'); # Test 39
$OK = 0;
$status = $file3->close;
$OK = 1 if ($status && !$file3->is_open);
ok($OK,'File: close'); # Test 40
$OK = 0;
$file3 = HDF5::File->open('test3.h5');
$OK = 1 if ($file3 && $file3->is_open);
ok($OK,'File: open'); # Test 41
$OK = 0;
my $root = $file3->open_group('/');
$OK = 1 if ($root && $root->is_open && $root->name eq '/');
ok($OK,'File: open group'); # Test 42
$OK = 0;
$dataset3 = $root->open_dataset('D3');
$OK = 1 if ($dataset3 && $dataset3->is_open && $dataset3->name eq 'D3');
ok($OK,'Group: open dataset'); # Test 43
$OK = 0;
$OK = 1 if ($dataset3->datatype eq 'vlen of integer');
ok($OK,'Dataset: type'); # Test 44
$OK = 0;
my @dims3 = $dataset3->dims;
my $R3 = $dataset3->read_data();
foreach my $i(0..$#images) {
  if ($R3->[$i] ne $C->[$i]) {
    $OK = 0;
    last;
  }
  else {
    $OK = 1;
  }
}
ok($OK,'Dataset: read, vlen of int'); # Test 45
$OK = 0;
my $file4 = HDF5::File->open('opaque.h5');
$OK = 1 if ($file4 && $file4->is_open);
ok($OK,'File: open'); # Test 46
$OK = 0;
my $dataset4 = HDF5::Dataset->open($file4,'DS1');
$OK = 1 if ($dataset4 && $dataset4->is_open);
ok($OK,'Dataset: open'); # Test 47
$OK = 0;
my @dims4 = $dataset4->dims;
$OK = 1 if ($dims4[0] == 4 && $dims4[1] == 7);
ok($OK,'Dataset: dims'); # Test 48
$OK = 0;
my $status = 'OK';
my $R4 = $dataset4->read_data();
my $val = 48;
foreach my $i(0..$dims4[0]-1) {
  if ($R4->[$i][0] != 79 || $R4->[$i][1] != 80 || $R4->[$i][2] != 65 || $R4->[$i][3] != 81 ||  $R4->[$i][4] != 85 || $R4->[$i][5] != 69) {
    $status = 'Failed';
    last;
  }
  if ($R4->[$i][6] != $val++) {
    $status = 'Failed';
  }
  last if ($status ne 'OK');
}
$OK = 1 if ($status eq 'OK');
ok($OK,'Dataset: read, opaque type'); # Test 49
$OK = 0;
my $file5 = HDF5::File->open('test4.h5');
my $group = $file5->open_group('/G1');
my @datasets = $group->get_datasets;
$OK = 1 if (@datasets && scalar(@datasets) == 3);
ok($OK,'Group: read datasets'); # Test 50
foreach my $ds(@datasets) {
  my $test_name;
  my $d = $group->open_dataset($ds);
  my $data = $d->read_data();
  my $type = $d->datatype;
  if ($type eq 'compound') {
    my $status = 'OK';
    my ($n) = $d->dims;
    my @letters = qw(a b c d e f g h i j);
    foreach my $i(0..$n-1) {
      my $hashref = $data->[$i];
      foreach my $key(keys %{$hashref}) {
	my $values = $hashref->{$key};
	if (ref($values) eq 'ARRAY') {
	  $test_name = 'Dataset: read, compound type (with array members)';
	  foreach my $j(0..$#{$values}) {
	    if ($values->[$j] != $i+$j) {
	      $status = 'Failed';
	      last;
	    }
      	  }
	}
	else {
	  $test_name = 'Dataset: read, compound type';
	  if ($key eq 'name' && $values ne $letters[$i]) {
	    $status = 'Failed';
	    last;
	  }
	}
	last if ($status ne 'OK');
      }
      last if ($status ne 'OK');
    }
    $OK = 1 if ($status eq 'OK');
    ok($OK,$test_name); # Test 51/52
  }
  if ($type eq 'array') {
    my $status = 'OK';
    foreach my $i(0..$#{$data}) {
      my @ary = @{$data->[$i]};
      foreach my $j(0..$#ary) {
	foreach my $k(0..$#{$ary[$j]}) {
	  if ($ary[$j][$k] != $i) {
	    $status = 'Failed';
	    last;
	  }
	}
	last if ($status ne 'OK');
      }
      last if ($status ne 'OK');
    }
    $OK = 1 if ($status eq 'OK');
    ok($OK,'Dataset: read, array type'); # Test 53
  }
}
