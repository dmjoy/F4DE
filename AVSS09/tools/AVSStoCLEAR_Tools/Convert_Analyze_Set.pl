#!/usr/bin/env perl

# AVSS ViPER Files to CLEAR ViPER Files converter and analyzer
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Viper XML Validator" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "AVSS ViPER Files to CLEAR ViPER Files converter and analyzer: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $avpl, $avplv, $clearpl, $clearplv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = (defined $ENV{$f4b}) ? $ENV{$f4b} . "/lib": "/lib";
  $avpl = "AVSS09_PERL_LIB";
  $avplv = $ENV{$avpl} || "../../lib";
  $clearpl = "CLEAR_PERL_LIB";
  $clearplv = $ENV{$clearpl} || "../../../CLEAR07/lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib";  # Default is relative to this tool's default path
}
use lib ($avplv, $clearplv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR"; # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $avpl, $clearpl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# AVSStoCLEAR (part of this tool)
unless (eval "use AVSStoCLEAR; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"AVSStoCLEAR\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# CSVHelper (part of this tool)
unless (eval "use CSVHelper; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"CSVHelper\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

use strict;

########################################

my $usage = "$0 input_dir output_dir\n\nConvert all the files within the input_dir directory from AVSS to CLEAR ViPER files and print some detailled on files seen within this file set such as camera information and associated file, PERSON (target) information, order of appearance of target in cameras.\nWill also generate a CSV file with these data\n";

my $in = shift @ARGV;
my $out = shift @ARGV;

MMisc::error_quit("No input_dir provided.\n $usage")
  if (MMisc::is_blank($out));
MMisc::error_quit("No output_dir provided.\n $usage")
  if (MMisc::is_blank($out));

my $err = MMisc::check_dir_r($in);
MMisc::error_quit("input_dir problem: $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_dir_w($out);
MMisc::error_quit("output_dir problem: $err")
  if (! MMisc::is_blank($err));

my @fl = MMisc::get_files_list($in);
MMisc::error_quit("No files in input_dir\n")
  if (! defined @fl);

my $avcl = new AVSStoCLEAR();
my @keys = ();

foreach my $file (sort @fl) {
  my $ff = "$in/$file";
  print "\n--------------------\n### FILE: $ff\n";
  my $off = "$out/$file";
  open OUT, ">$off"
    or MMisc::error_quit("Problem creating output file [$off]: $!");

  my ($ok, $res) = $avcl->load_ViPER_AVSS($ff);
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());
  MMisc::error_quit("\'load_ViPER_AVSS\' did not complete succesfully")
      if (! $ok);
  print $res;

  my $xmlc = $avcl->create_CLEAR_ViPER($ff);
  MMisc::error_quit($avcl->get_errormsg())
      if ($avcl->error());
  MMisc::error_quit("\'create_CLEAR_ViPER\' did not create any XML")
      if (MMisc::is_blank($xmlc));
  print OUT $xmlc;
  
  close OUT;
  print "\n==> Wrote: $off\n";
  push @keys, $ff;
}

####################

print "\nCamera list:\n";
foreach my $key (@keys) {
  my $cid = $avcl->get_cam_id($key);
  MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
      if ($avcl->error());
  print "|-> Camera $cid -- Associated file: $key\n";
}

#####

print "\nUsable pairs:\n";
foreach my $key1 (@keys) {
  my $cid1 = $avcl->get_cam_id($key1);
  MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
      if ($avcl->error());
  print "* Camera $cid1\n";
  foreach my $key2 (@keys) {
    next if ($key1 eq $key2);

    my $cid2 = $avcl->get_cam_id($key2);
    MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
        if ($avcl->error());
    
    my $rcomp = $avcl->get_comparables($key1, $key2);
    MMisc::error_quit("Problem while obtaining comparables: " . $avcl->get_errormsg())
        if ($avcl->error());

    if (! defined $rcomp) {
      print "|-> Camera $cid2 : NONE\n";
      next;
    }

    print "|-> Camera $cid2 : YES\n";
    foreach my $id (sort _num keys %$rcomp) {
      my $ov = $$rcomp{$id};
      print "|   |-> ID: $id / Overlap (short form): $ov\n"; 
    }
  }
  print "|\n";
}

####################

print "\nOrder of appearance:\n";
my ($rresk, $rresbf) = $avcl->get_appear_order(@keys);
MMisc::error_quit("Problem while obtaining order of appearance: " . $avcl->get_errormsg())
  if ($avcl->error());

my %cam_seqstr = ();
foreach my $id (sort _num keys %$rresk) {
  print "* ID: $id\n";
  $cam_seqstr{$id} .= "";

  my $inc = 0;
  for (my $i = 0; $i < scalar @{$$rresk{$id}}; $i++) {
    my $key = ${$$rresk{$id}}[$i];
    my $cid = $avcl->get_cam_id($key);
    MMisc::error_quit("Problem getting camera ID information: " . $avcl->get_errormsg())
        if ($avcl->error());
    printf("  %02d ) Camera %d [beginning frame: %d]\n",
           1 + $i, $cid , ${$$rresbf{$id}}[$i]);
    $cam_seqstr{$id} .= "$cid ";
  }

  $cam_seqstr{$id} =~ s%\s$%%;
}

####################

print "\nGenerate CSV\n";

my $of = "$out/setdetails.csv";
open OFILE, ">$of"
  or MMisc::error_quit("Could not create CSV file [$of] : $!");

my @header = ();
push @header, "Directory", "File ID", "Excerpt Set", "Camera ID";

my $csvh = CSVHelper::get_csv_handler();
MMisc::error_quit("Problem getting CSV handler")
  if (! defined $csvh);

my @idl = sort _num keys %$rresk;

my @clip_headers = ();
my @obj_headers  = ();
my @ooa = ();
my $wrote_header = 0;
foreach my $key (sort @keys) {
  my @content_hd = ();

  {
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($key);
    MMisc::error_quit("Problem splitting file into dir/file/ext [$key] : $err")
        if (! MMisc::is_blank($err));
    $dir =~ s%\/$%%;
    my $set = $dir;
    $set =~ s%^.+/%%;
    push @content_hd, $dir, MMisc::concat_dir_file_ext("", $file, $ext), $set;
  }

  my $cid = $avcl->get_cam_id($key);
  MMisc::error_quit("Problem obtaining camera ID :" . $avcl->get_errormsg())
      if ($avcl->error());
  push @content_hd, $cid;

  if (scalar @clip_headers == 0) {
    @clip_headers = $avcl->get_clip_csv_data_headers($key);
    MMisc::error_quit("Problem getting clip CSV data headers :" . $avcl->get_errormsg())
        if ($avcl->error());
    push @header, @clip_headers;
  }

  my @values = $avcl->get_clip_csv_data($key);
  MMisc::error_quit("Problem getting clip CSV data headers :" . $avcl->get_errormsg())
      if ($avcl->error());
  push @content_hd, @values;

  foreach my $id (@idl) {
    my @content_id = ();

    if (scalar @obj_headers == 0) {
      @obj_headers = $avcl->get_obj_csv_data_headers($key);
      MMisc::error_quit("Problem getting object CSV data headers :" . $avcl->get_errormsg())
          if ($avcl->error());
      push @header, @obj_headers;
    }

    my @values = $avcl->get_obj_csv_data($key, $id);
    MMisc::error_quit("Problem getting object CSV data headers :" . $avcl->get_errormsg())
        if ($avcl->error());
    push @content_id, @values;
    
    # Order of appearance
    if (scalar @ooa == 0) {
      push @ooa, "Order of Appearance", "Camera Sequence";
      push @header, @ooa;
    }
    my $res = "Never";
    for (my $i = 0; $i < scalar @{$$rresk{$id}}; $i++) {
      my $in = ${$$rresk{$id}}[$i];
      $res = 1 + $i if ($key eq $in);
    }
    push @content_id, $res;
    push @content_id, $cam_seqstr{$id};

    if (! $wrote_header) {
      my $txt = CSVHelper::array2csvtxt($csvh, @header);
      MMisc::error_quit("Problem creating CSV header")
          if (! defined $txt);
      print OFILE $txt . "\n";
      $wrote_header = 1;
    }

    my @content = ();
    push @content, @content_hd;
    push @content, @content_id;

    MMisc::error_quit("Different number of columns in data (" . scalar @content . ") than in header (" . scalar @header . "), refusing to write")
        if (scalar @header != scalar @content);

    my $line = CSVHelper::array2csvtxt($csvh, @content);
    MMisc::error_quit("Problem creating CSV content")
        if (! defined $line);
    print OFILE $line . "\n";
  }
}
close OFILE;
print " => Wrote set CSV file: $of\n";

MMisc::ok_quit("\nDone\n");

############################################################

sub _num { $a <=> $b; }

#####

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}