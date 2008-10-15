#!/usr/bin/perl -w

# DETEdit
# DETEdit.pl
# Authors: Jonathan Fiscus
#          Jerome Ajot
#          Martial Michel
# 
# This software was developed at the National Institute of Standards and
# Technology by employees of the Federal Government in the course of
# their official duties.  Pursuant to Title 17 Section 105 of the United
# States Code this software is not subject to copyright protection within
# the United States and is in the public domain. It is an experimental
# system.  NIST assumes no responsibility whatsoever for its use by any
# party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST
# MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER,
# INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Data::Dumper;

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv =  $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

use MetricTV08;
use Trials;

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $ekw = "ERROR";              # Error Key Work
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# DETCurve (part of this tool)
unless (eval "use DETCurve; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"DETCurve\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# DETCurveSet (part of this tool)
unless (eval "use DETCurveSet; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"DETCurveSet\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# Pod::Usage (usualy part of the Perl Core)
unless (eval "use Pod::Usage; 1") {
  &_warn_add
    (
     "\"Pod::Usage\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=pod%3A%3Ausage\" for installation information\n"
    );
  $have_everything = 0;
}

# File::Temp (usualy part of the Perl Core)
unless (eval "use File::Temp qw/ tempdir /; 1") {
  &_warn_add
    (
     "\"File::Temp\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=file%3A%3Atemp\" for installation information\n"
    );
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

my $VERSION = 0.1;
my $man = 0;
my $help = 0;
my $inPlace = 0;
my $title = undef;
my $titleRegex = undef;
my $inputSrl = undef;
my $outputSrl = undef;
my $gzipPROG = "gzip";

Getopt::Long::Configure(qw( no_ignore_case ));

GetOptions
(
	'o|output-srl=s'                       => \$outputSrl,
	'i|input-srl=s'                        => \$inputSrl,
  'I|Inplace'                            => \$inPlace,

  't|title=s'                            => \$title,
  'titleRegex=s'                         => \$titleRegex,

	'Z|ZipPROG=s'                          => \$gzipPROG,
	
	'version'                              => sub { my $name = $0; $name =~ s/.*\/(.+)/$1/; print "$name version $VERSION\n"; exit(0); },
	'h|help'                               => \$help,
	'm|man'                                => \$man,
);

## Docs
pod2usage(1) if $help;
pod2usage(-exitvalue => 0, -verbose => 2) if $man;
##

## Checking inputs
pod2usage("ERROR: An input file must be set.\n") unless defined($inputSrl);
pod2usage("ERROR: The output must be specified as either 'inPlace' or as a file via -o\n")
  if (!defined($outputSrl) && $inPlace == 0);
pod2usage("ERROR: The output must be specified as either 'inPlace' or as a file via -o, but NOT both!\n")
  if (defined($outputSrl) && $inPlace == 1);

my $inDet = DETCurve::readFromFile($inputSrl, $gzipPROG);

##Make the edits
if (defined($title)){
  $inDet->setLineTitle($title);
}
if (defined($titleRegex)){
	my $retitle = $inDet->getLineTitle();
  my ($op, $op1, $op2, $cond) = split(/\//,$titleRegex,4);
  $cond = "" if (! defined($cond)); 
			
  if ($cond eq "g"){
		$retitle =~ s/$op1/$op2/g;
  } elsif ($cond eq "i") {
		$retitle =~ s/$op1/$op2/i;
  } elsif (($cond eq "gi") || ($cond eq "ig")) {
  	$retitle =~ s/$op1/$op2/gi;
  }	else {
  	$retitle =~ s/$op1/$op2/;
	}
  $inDet->setLineTitle($retitle);
}

### Output the new  file
if ($inPlace){
  $inputSrl =~ s/\.gz$//;
  $inDet->serialize($inputSrl);  
} else {
  ### delete the .gz if it's there
  $outputSrl =~ s/\.gz$//;
  $inDet->serialize($outputSrl);
}
exit 0;

#############################################  End of the program #########################################

sub _warn_add
{
	$warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

__END__

=head1 NAME

DETEdit.pl -- Edit properties in a serialized DET Curve.

=head1 SYNOPSIS

B<DETEdit.pl> [ OPTIONS ] -i F<IN_SRL_FILE> ( -I | -o F<OUT_SRL_FILE> ) 

=head1 DESCRIPTION

The script modifies fields in a serialized DET Curve generated by the F4DE package.

=head1 OPTIONS

=head2 Required input file argument:

=over 25

=item B<-i>, B<--input-srl> F<SRL>

Input serialized DET Curve .

=head2 Required output file arguments (Choose one method):

=item B<-I>, B<--Inplace> 

Overwrite the input file with the updated file.

=item B<-o>, B<--output-srl> 

Specifiy the output file.

=head2 Optional arguments:

=item B<-t>, B<--title> S<"title">

Specify a new title.

=item B<--titleRegex>

Modify the title with the regular expression.  If both --title and --titleRegex is used on the commandline, the title is changed, then the Regex is applied.

=item B<-Z>, B<--ZipPROG> F<GZIP_PATH>

Specify the full path name to gzip (default: 'gzip').

=head2 Others:

=item B<-h>, B<--help>

Print the help.

=item B<-m>, B<--man>

Print the manual.

=item B<--version>

Print the version number.

=back

=head1 BUGS

No known bugs.

=head1 NOTES

The default iso-cost ratio coefficients (-R option) and iso-metric coefficients (-Q option) are defined into the metric.

=head1 AUTHOR

 Jonathan Fiscus <jonathan.fiscus@nist.gov>
 Jerome Ajot <jerome.ajot@nist.gov>
 Martial Michel <martial.michel@nist.gov>

=head1 VERSION

DETUtil.pl version 0.4

=head1 COPYRIGHT 

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this software is not subject to copyright protection within the United States and is in the public domain. It is an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

=cut