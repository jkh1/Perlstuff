#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use CellH5::File;

my $filename = '0013.ch5';
my $plate_name= 'H2b_aTub_MD20x_exp911';
my $well_name ='0';
my $position_idx = '0013';

my (undef,$dir,undef) = fileparse($0,qr/\.t/);

my $file = CellH5::File->open("$dir/$filename");
print STDERR "File is open\n" if $file->is_open;
my $plate = $file->get_plate_by_name($plate_name);
print STDERR "Plate is open\n" if $plate->is_open;
my $well = $plate->get_well($well_name);
print STDERR "Well is open\n" if $well->is_open;
my $position = $well->get_position($position_idx);
print STDERR "Position is open\n" if $position->is_open;
my $image_data = $position->get_image_handle();
print STDERR "Image is open\n" if $image_data->is_open;
my $image = $image_data->get_image(0,4,0);
$image->pgm("ch5.pgm");
my $objh = CellH5::ObjectHandle->new($position);
my $object = $objh->get_object_by_idx(12300);
print STDERR "\nGot object:\n" if $object;
my $img = $object->get_image();
$img->pgm("12300.pgm");
print STDERR "idx: ",$object->idx,"\n";
print STDERR "label id: ",$object->label_id,"\n";
print STDERR "time idx: ",$object->time_idx,"\n";
print STDERR "center: ",join(", ",$object->center),"\n";
print STDERR "bounding box: ",join(", ",$object->bounding_box),"\n";
print STDERR "Class: ",$object->class_idx," (p= ",$object->class_probability,")\n";
#print STDERR "Features: ",join(", ",$object->features),"\n";

my ($parent) = $object->parents;
print STDERR "\nGot parent:\n" if $parent;
print STDERR "idx: ",$parent->idx,"\n";
print STDERR "label id: ",$parent->label_id,"\n";
print STDERR "time idx: ",$parent->time_idx,"\n";
print STDERR "center: ",join(", ",$parent->center),"\n";
print STDERR "bounding box: ",join(", ",$parent->bounding_box),"\n";
print STDERR "Class: ",$parent->class_idx," (p= ",$parent->class_probability,")\n";
$img = $parent->get_image();
$img->pgm("parent.pgm");
my ($child) = $object->children;
print STDERR "\nGot child:\n" if $child;
print STDERR "idx: ",$child->idx,"\n";
print STDERR "label id: ",$child->label_id,"\n";
print STDERR "time idx: ",$child->time_idx,"\n";
print STDERR "center: ",join(", ",$child->center),"\n";
print STDERR "bounding box: ",join(", ",$child->bounding_box),"\n";
print STDERR "Class: ",$child->class_idx," (p= ",$child->class_probability,")\n";
$img = $child->get_image();
$img->pgm("child.pgm");

my $event_handle = $position->get_event_handle;
my $event = $event_handle->get_event_by_id(2);
my $i = 0;
my @images;
foreach my $obj($event->objects) {
  my $img = $obj->get_image(70,70);
  push @images,$img;
  my $file = ++$i.'.pgm';
  $img->pgm($file);
}
my $gallery = $image_data->make_gallery(@images);
$gallery->pgm('gallery.pgm');
