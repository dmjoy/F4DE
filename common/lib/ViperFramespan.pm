package ViperFramespan;

# Viper Framespan
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "ViperFramespan.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.


# $Id$

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "ViperFramespan.pm Version: $version";

my %error_msgs =
  (
   # from 'new'
   "NotFramespan"      => "Entry is not a valid framespan",
   "EmptyValue"        => "Must provide a non empty \'value\'",
   "BadRangePair"      => "Badly formed range pair",
   "NegativeValue"     => "Framespan range pair values can not be negative",
   "NotOrdered"        => "Framespan range pair is not ordered",
   "StartAt0"          => "Framespan can not start at 0",
   "WeirdValue"        => "Strange value provided",
   # Other
   "NoFramespanSet"    => "No framespan set",
   # 'fps'
   "negFPS"            => "FPS can not negative",
   "zeroFPS"           => "FPS can not be equal to 0",
   "FPSNotSet"         => "FPS not set, can not perform time based operations",
   "NotAFrame"         => "Value is no a single frame value",
  );

## Constructor
sub new {
  my ($class) = shift @_;

  my $tmp = shift @_;
  my ($value, $errmsg) = &_fs_check_and_optimize_value($tmp, 1);
  my $errormsg = &_set_errormsg_txt("", $errmsg);

  my $self =
    {
     value => $value,
     original_value => $tmp,
     fps => -1,
     errormsg => $errormsg,
    };

  bless $self;
  return($self);
}

####################

sub get_version {
  my ($self) = @_;

  return($versionid);
}

####################

sub _fs_check_pair {
  my ($b, $e) = @_;

  return($error_msgs{"BadRangePair"})
    if ((&_is_blank($b)) || (&_is_blank($e)));

  return($error_msgs{"NegativeValue"})
    if (($b < 0) || ($e < 0));

  return($error_msgs{"NotOrdered"})
    if ($e < $b);

  return($error_msgs{"StartAt0"})
    if ($b == 0);

  return("");
}

#####

sub _fs_split_pair {
  my ($pair) = shift @_;

  return($error_msgs{"NotFramespan"}, 0, 0)
    if ($pair !~ m%^\d+\:\d+$%);

  my ($b, $e) = ($pair =~ m%^(\d+)\:(\d+)$%);

  return("", $b, $e);
}

#####

sub _fs_split_line {
  my $line = shift @_;

  my @o = split(/[\s|\t]+/, $line);

  return(@o);
}

#####

sub _fs_split_line_count {
  my $line = shift @_;

  return(scalar &_fs_split_line($line));
}

#####

sub _fs_check_value {
  my $value = shift @_;
  my $from_new = shift @_;

  if ($value eq "") {
    # If called from new, it is ok
    return($value, "") if ($from_new);
    # Otherwise it should not happen
    return("", $error_msgs{"EmptyValue"});
  }

  # Process pair per pair
  my @todo = &_fs_split_line($value);
  foreach my $key (@todo) {
    my ($txt, $b, $e) = &_fs_split_pair($key);
    return("", $txt) if (! &_is_blank($txt));
    $txt = &_fs_check_pair($b, $e);
    return("", $txt) if (! &_is_blank($txt));
  }

  # Recreate a usable string
  $value = join(" ", @todo);

  return($value, "");
}

##########

sub _fs_make_uniques {
  my @a = @_;

  my %tmp;
  foreach my $key (@a) {
    $tmp{$key}++;
  }

  return(keys %tmp);
}

#####

sub _fs_reorder_value {
  my $fs = shift @_;

  # Only 1 element, nothing to do
  return($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than 1 element, reorder
  my @ftodo = &_fs_split_line($fs);
  @ftodo = &_fs_make_uniques(@ftodo); # ex: '1:2 1:2' -> '1:2'
  my @o = sort _fs_sort @ftodo;
  return($fs, "WEIRD: While reordering frames, did not find the same number of elements between the original array and the result array")
    if (scalar @ftodo != scalar @o);

  $fs = join(" ", @o);

  return($fs, "");
}

##########

sub _fs_shorten_value {
  my $fs = shift @_;

  my ($b, $e, $errormsg);

  ($fs, $errormsg) = &_fs_reorder_value($fs);
  return($fs, $errormsg) if (! &_is_blank($errormsg));

  # Only 1 element, nothing to do
  return($fs, "") if (&_fs_split_line_count($fs) == 1);

  # More than one element: compute
  my @o = ();

  my @ftodo = &_fs_split_line($fs);
  my $ftc = scalar @ftodo;

  # Get the first element
  my $entry = shift @ftodo;
  ($errormsg, $b, $e) = &_fs_split_pair($entry);
  return($fs, $errormsg) if (! &_is_blank($errormsg));

  my ($nb, $ne);
  foreach $entry (@ftodo) {
    ($errormsg, $nb, $ne) = &_fs_split_pair($entry);
    return($fs, $errormsg) if (! &_is_blank($errormsg));

    if ($nb == $e) { # ex: 1:2 2:6 -> 1:6
      $e = $ne;
    } elsif ($nb == 1 + $e) { # ex: 1:1 2:3 -> 1:3
      $e = $ne;
    } elsif ($nb == $b) { # ex: 1:2 1:3 -> 1:3
      $e = $ne;
      # Works because we can not have multiple same entries (ex: '1:2 1:2' was fixed in _fs_reorder_value)
      # and because the reorder insure that '1:2 1:3' is fully ordered properly (ex: no '1:3 1:2' possible)
    } elsif ($nb < $e) {
      # All this also work because we have an insured a full re-ordering of pairs
      if ($ne >= $e) {  # ex: 10:30 20:40 -> 10:40
	$e = $ne;
      }
      # The else here would be ex: 10:30 20:25 -> 10:30
      # Do nothing, simply forget this value
    } else { # ex: 1:2 12:24 -> 1:2 12:24
      push @o, "$b:$e";
      ($b, $e) = ($nb, $ne);
    }
  }
  push @o, "$b:$e";

  $fs = join(" ", @o);

  return($fs, "");
}

#####

sub _fs_check_and_optimize_value {
  my $value = shift @_;
  my $from_new = shift @_;

  my $errormsg = "";

  # Check the value
  ($value, $errormsg) = &_fs_check_value($value, $from_new);
  return($value, $errormsg) if (! &_is_blank($errormsg));

  # Then optimize it (if a value is present)
  if ($value ne "") {
    ($value, $errormsg) = &_fs_shorten_value($value);
    return($value, $errormsg) if (! &_is_blank($errormsg));
  }

  return($value, $errormsg);
}

##########

sub set_value {
  my ($self, $tmp) = @_;

  return(0) if ($self->error());

  my $ok = 1;

  my ($value, $errormsg) = &_fs_check_and_optimize_value($tmp, 0);
  if (! &_is_blank($errormsg)) {
    $self->_set_errormsg($errormsg);
    $ok = 0;
  }

  $self->{value} = $value;
  $self->{original_value} = $tmp;

  return($ok);
}

#####

sub set_value_beg_end {
  my ($self, $beg, $end) = @_;

  if (($beg !~ m%^\d+$%) || ($end !~ m%^\d+$%)) {
    $self->_set_errormsg($error_msgs{"WeirdValue"});
    return(0);
  }

  my $fs = "$beg:$end";

  return($self->set_value($fs));
}

#####

sub set_value_from_beg_to {
  my ($self, $v) = @_;

  return($self->set_value_beg_end(1, $v));
}


#####

sub add_fs_to_value {
  my ($self, $v) = @_;

  return(0) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  my $value = $self->get_value();

  $value .= " $v";

  return($self->set_value($value));
}

#########

sub union {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $cfs = $other->get_value();

  return($self->add_fs_to_value($cfs));
}

#####

sub intersection {
  my ($self, $other) = @_;

  return($self->get_overlap($other));
}

########## 'fps'

sub set_fps {
  my ($self, $fps) = @_;

  return(0) if ($self->error());

  if ($fps =~ m%^pal$%i) {
    $fps = 25;
  } elsif ($fps =~ m%^ntsc$%i) {
    $fps = 30000 / 1001;
  } elsif ($fps < 0) {
    $self->_set_errormsg($error_msgs{"negFPS"});
    return(0);
  } elsif ($fps == 0) {
    $self->_set_errormsg($error_msgs{"zeroFPS"});
    return(0);
  }

  $self->{fps} = $fps;
  return(1);
}

#####

sub is_fps_set {
  my ($self) = @_;

  return(0) if ($self->error());

  return(1) if ($self->{fps} != -1);

  return(0);
}

#####

sub get_fps {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(0);
  }

  return($self->{fps});
}

##########

sub _set_errormsg_txt {
  my ($oh, $add) = @_;

  my $txt = "$oh$add";

  $txt =~ s%\[ViperFramespan\]\s+%%g;

  return("") if (&_is_blank($txt));

  $txt = "[ViperFramespan] $txt";

  return($txt);
}

#####

sub _set_errormsg {
  my ($self, $txt) = @_;

  $self->{errormsg} = &_set_errormsg_txt($self->{errormsg}, $txt);
}

##########

sub get_value {
  my ($self) = @_;

  return($self->{value});
}

#####

sub get_original_value {
  my ($self) = @_;

  return($self->{original_value});
}

##########

sub get_errormsg {
  my ($self) = @_;

  return($self->{errormsg});
}

##########

sub is_value_set {
  my ($self) = @_;

  return(0) if ($self->error());

  my $v = $self->get_value();

  return(0) if (&_is_blank($v));

  return(0) if (&_fs_split_line_count($v) == 0);

  return(1);
}

##########

sub error {
  my ($self) = @_;

  return(1) if (! &_is_blank($self->get_errormsg()));

  return(0);
}

####################

sub _fs_get_begend {
  my $fs = shift @_;

  my ($bf) = ($fs =~ m%^(\d+)\:%);
  my ($ef) = ($fs =~ m%\:(\d+)$%);

  return($bf, $ef);
}

#####

sub _fs_sort {
  return(&_fs_sort_core($a, $b));
}

#####

sub _fs_sort_core {
  my ($a, $b) = @_;

  my ($b1, $e1) = &_fs_get_begend($a);
  my ($b2, $e2) = &_fs_get_begend($b);

  # Order by beginning first
  return($b1 <=> $b2) if ($b1 != $b2);
  # by end if the beginning is the same
  return($e1 <=> $e2);
}

##########

sub sort_cmp {
  my ($self, $other) = @_;

  return(_fs_sort_core($self->get_value(), $other->get_value()));
}


##########

sub count_pairs_in_value {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $value = $self->get_value();

  return(&_fs_split_line_count($value));
}

##########

sub get_list_of_framespans {
  my ($self) = @_;

  my @list = ();
  return(undef) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(undef);
  }

  my $value = $self->get_value();
  my $fps = undef;
  $fps = $self->get_fps() if ($self->is_fps_set());
  foreach my $p(&_fs_split_line($value)){
    my $nfs = new ViperFramespan();
    if (! $nfs->set_value($p)){
       $self->_set_errormsg("Failed to set sub framespan value '$p'");
       return(undef); 
    }
    if (defined($fps) && (! $nfs->set_fps($fps))){
       $self->_set_errormsg("Failed to set sub framespan fps '$fps'");
       return(undef); 
    }
    push @list, $nfs;
  }
  return(\@list);
}

#####

sub count_pairs_in_original_value {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $ovalue = $self->get_original_value();

  return(&_fs_split_line_count($ovalue));
}

##########

sub _does_overlap {
  my ($ifs, $cfs) = @_;

  my ($i_beg, $i_end) = &_fs_get_begend($ifs);
  my ($c_beg, $c_end) = &_fs_get_begend($cfs);

  # No overlap possible
  return(0) if (($c_end < $i_beg) || ($i_end < $c_beg));

  # Othwise: Overlap
  return(1);
}

#####

sub check_if_overlap {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $ifs = $self->get_value();
  my $cfs = $other->get_value();

  return(&_does_overlap($ifs, $cfs));
}

##########

sub _get_overlap {
  my ($ifs, $cfs) = @_;

  # return if no overlap possible
  return(undef) if (! _does_overlap($ifs, $cfs));

  my ($i_beg, $i_end) = &_fs_get_begend($ifs);
  my ($c_beg, $c_end) = &_fs_get_begend($cfs);

  if (($c_beg >= $i_beg) && ($c_beg <= $i_end)) {
    if ($c_end >= $i_end) {
      #  ib----------ie
      #     cb--------------ce
      #ov:    -------
      return("$c_beg:$i_end");
    } else {
      #  ib----------ie
      #     cb-----ce
      #ov:    -----
      return("$c_beg:$c_end");
    }
  } elsif ($c_beg < $i_end) {
    if ($c_end < $i_end) {
      #        ib----------ie
      #     cb---------ce
      #ov:       ------
      return("$i_beg:$c_end");
    } else {
      #        ib----------ie
      #     cb------------------ce
      #ov:       ----------
      return("$i_beg:$i_end");
    }
  }

  # No idea what else is left since we already treated the no overlap case
  return("WEIRD"); # sure to make it crash
}

#####

sub get_overlap {
  my ($self, $other) = @_;

  # We only need to worry about overlap if there is even one possible
  return(undef) if (! $self->check_if_overlap($other));
  return(undef) if ($self->error());

  # Now in order to compute the overlap we work pair per pair
  my $sv = $self->get_value();
  my $ov = $other->get_value();

  my @spl = &_fs_split_line($sv);
  my @opl = &_fs_split_line($ov);

  my @ov;
  foreach my $sp (@spl) {
    foreach my $op (@opl) {
      my $pair = &_get_overlap($sp, $op);
      next if (! defined $pair);
      push @ov, $pair;
    }
  }

  return(undef) if (scalar @ov == 0);

  my $ovp = join(" ", @ov);

  my $tmp = new ViperFramespan($ovp);
  if ($tmp->error()) {
    $self->_set_errormsg("Problem creating new ViperFramespan for overlap value (" . $tmp->get_errormsg() . ")");
    return(undef);
  }

  return($tmp);
}

##########

sub get_beg_end_fs {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $v = $self->get_value();

  return(&_fs_get_begend($v));
}

#####

sub is_within {
  my ($self, $other) = @_;

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(-1) if ($self->error());

  my ($r_beg, $r_end) = $other->get_beg_end_fs();
  if ($other->error()) {
    $self->_set_errormsg($other->get_errormsg());
    return(-1);
  }

  # is within
  return(1) if (($v_beg >= $r_beg) && ($v_end <= $r_end));

  # is not within
  return(0);
}

##########

sub extent_middlepoint {
  my ($self) = @_;

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(-1) if ($self->error());

  my $d = $self->extent_duration();
  return($d) if ($self->error());

  return($v_beg + ($d / 2));
}

#####

sub extent_middlepoint_distance {
  my ($self, $other) = @_;

  return(-1) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  if (! $other->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(-1);
  }

  my $m1 = $self->extent_middlepoint();
  my $m2 = $other->extent_middlepoint();

  return($m2 - $m1);
}


#####

sub extent_duration {
  my ($self) = @_;

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(-1) if ($self->error());

  # 1:3 is 1:2:3 so duration 3, and
  # 1:1 is 1, so duration 1
  # therefore end - beg + 1
  my $d = 1 + $v_end - $v_beg;

  return($d);
}

#####

sub get_beg_fs {
  my ($self) = @_;

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->error());

  return($v_beg);
}

#####

sub get_end_fs {
  my ($self) = @_;

  my ($v_beg, $v_end) = $self->get_beg_end_fs();
  return(0) if ($self->error());

  return($v_end);
}

##########

sub duration {
  my ($self) = @_;

  return(0) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  my $v = $self->get_value();

  my @pairs = &_fs_split_line($v);

  my $d = 0;
  foreach my $p (@pairs) {
    my ($err, $b, $e) = &_fs_split_pair($p);
    if (! &_is_blank($err)) {
      $self->_set_errormsg($err);
      return(0);
    }

    # As for extent_duration:
    # 1:3 is 1:2:3 so duration 3, and
    # 1:1 is 1, so duration 1
    # therefore end - beg + 1
    $d += 1 + $e - $b;
  }

  return($d);
}

######################################## 'ts' functions

sub frame_to_ts {
  my ($self, $frame) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(0);
  }


  if ($frame !~ m%^[\d\.]+$%) {
    $self->_set_errormsg($error_msgs{"NotAFrame"});
    return(0);
  }

  my $fps = $self->get_fps();

  return ($frame / $fps);
}

##########

sub _get_begend_ts_core {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(0);
  }
  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  my $v = $self->get_value();

  my ($beg, $end) = &_fs_get_begend($v);

  # Rule 1: Frames start at 1 but ts start at 0
  $beg -= 1;

  # For 'end' we ought to add 1 because the frame is valid until
  # the end of the framespan end value (example "1:1" is from beginning of 1
  # to end of 1), but we still apply rule #1 so we ought to have
  # $end = $end + 1 - 1;
  # Therefore we do not touch $end

  return($beg, $end);
}

#####

sub get_beg_ts {
  my ($self) = @_;

  my ($beg, $end) = $self->_get_begend_ts_core();
  return($beg) if ($self->error());

  return($self->frame_to_ts($beg));
}

#####

sub get_end_ts {
  my ($self) = @_;

  my ($beg, $end) = $self->_get_begend_ts_core();
  return($beg) if ($self->error());

  return($self->frame_to_ts($end));
}

#####

sub get_beg_end_ts {
  my ($self) = @_;

  my ($beg, $end) = $self->_get_begend_ts_core();
  return($beg) if ($self->error());

  my $beg_ts = $self->frame_to_ts($beg);
  my $end_ts = $self->frame_to_ts($end);

  return($beg_ts, $end_ts);
}

##########

sub extent_middlepoint_ts {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(-1);
  }

  my $mf = $self->extent_middlepoint();
  return($mf) if ($self->error());

  return($self->frame_to_ts($mf));
}

#####

sub extent_middlepoint_distance_ts {
  my ($self, $other) = @_;

  my $m1 = $self->extent_middlepoint_ts();
  return($m1) if ($self->error());

  my $m2 = $other->extent_middlepoint_ts();
  if ($other->error()) {
    $self->_set_errormsg($other->get_errormsg());
    return($m2);
  }

  return($m2 - $m1);
}

#####

sub extent_duration_ts {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(-1);
  }

  my $d = $self->extent_duration();
  return($d) if ($self->error());

  return($self->frame_to_ts($d));
}

#####

sub duration_ts {
  my ($self) = @_;

  return(-1) if ($self->error());

  if (! $self->is_fps_set()) {
    $self->_set_errormsg($error_msgs{"FPSNotSet"});
    return(-1);
  }

  my $d = $self->duration();
  return($d) if ($self->error());

  return($self->frame_to_ts($d));
}

######################################## framespan shift function

sub value_shift {
  my ($self, $val) = @_;

  return(0) if ($self->error());

  if (! $self->is_value_set()) {
    $self->_set_errormsg($error_msgs{"NoFramespanSet"});
    return(0);
  }

  my $fs = $self->get_value();

  my @in = &_fs_split_line($fs);
  my @out = ();
  foreach my $entry (@in) {
    my ($errormsg, $b, $e) = &_fs_split_pair($entry);

    if (! &_is_blank($errormsg)) {
      $self->_set_errormsg($errormsg);
      return(0);
    }

    $b += $val;
    $e += $val;

    push @out, "$b:$e";
  }

  $fs = join(" ", @out);

  return($self->set_value($fs));
}

########################################

sub unit_test { # Xtreme coding and us ;)
  my ($self) = @_;
  # We get $self and ignore it entirely (unless we encounter an error of course ;) )
  
  my $eh = "unit_test:";
  my $otxt = "";

  # Let us try to set a bad value
  my $fs_tmp1 = new ViperFramespan("Not a framespan");
  my $err1 = $fs_tmp1->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[1] ($err1). "
    if ($err1 ne &_set_errormsg_txt("", $error_msgs{"NotFramespan"}));

  # Or an empty framespan
  my $fs_tmp2 = new ViperFramespan();
  $fs_tmp2->set_value("");
  my $err2 = $fs_tmp2->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[2] ($err2). "
    if ($err2 ne &_set_errormsg_txt("", $error_msgs{"EmptyValue"}));

  # Not ordered framespan
  my $in3 = "5:4";
  my $fs_tmp3 = new ViperFramespan($in3);
  my $err3 = $fs_tmp3->get_errormsg();
  $otxt .= "$eh Error while checking \'set_value\'[3] ($err3). "
    if ($err3 ne &_set_errormsg_txt("", $error_msgs{"NotOrdered"}));

  # Start a 0
  my $in4 = "0:1";
  my $fs_tmp4 = new ViperFramespan();
  $fs_tmp4->set_value($in4);
  my $err4 = $fs_tmp4->get_errormsg();
  $otxt .= "$eh Error while checking \'new\'[4] ($err4). "
    if ($err4 ne &_set_errormsg_txt("", $error_msgs{"StartAt0"}));

  # Reorder
  my $in5 = "4:5 1:2 12:26 8:8";
  my $exp_out5 = "1:2 4:5 8:8 12:26";
  my $fs_tmp5 = new ViperFramespan();
  $fs_tmp5->set_value($in5);
  my $out5 = $fs_tmp5->get_value();
  $otxt .= "$eh Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5). "
    if ($out5 ne $exp_out5);

  # Reorder (2)
  $in5 = "4:7 1:2 1:2";
  $exp_out5 = "1:2 4:7";
  $fs_tmp5->set_value($in5);
  $out5 = $fs_tmp5->get_value();
  $otxt .= "$eh Error while checking \'new\'[reorder] (expected: $exp_out5 / Got: $out5). "
    if ($out5 ne $exp_out5);

  # Shorten
  my $in6 = "1:2 2:3 4:5";
  my $exp_out6 = "1:5";
  my $fs_tmp6 = new ViperFramespan();
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  $otxt .= "$eh Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6). "
    if ($out6 ne $exp_out6);

  # Shorten (2)
  $in6 = "1:3 1:2";
  $exp_out6 = "1:3";
  $fs_tmp6->set_value($in6);
  my $out6 = $fs_tmp6->get_value();
  $otxt .= "$eh Error while checking \'new\'[shorten] (expected: $exp_out6 / Got: $out6). "
    if ($out6 ne $exp_out6);

  # No Framespan Set
  my $fs_tmp7 = new ViperFramespan();
  my $test7 = $fs_tmp7->check_if_overlap(); # We are checking against nothing here
  my $err7 = $fs_tmp7->get_errormsg();
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($err7). "
    if ($err7 ne &_set_errormsg_txt("", $error_msgs{"NoFramespanSet"}));

  # Overlap & Within
  my $in8  = "1:10";
  my $in9  = "4:16";
  my $in10 = "11:15";
  my $fs_tmp8  = new ViperFramespan();
  my $fs_tmp9  = new ViperFramespan();
  my $fs_tmp10 = new ViperFramespan();
  $fs_tmp8->set_value($in8);
  $fs_tmp9->set_value($in9);
  $fs_tmp10->set_value($in10);

  my $testa = $fs_tmp8->check_if_overlap($fs_tmp9);
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($in8 and $in9 do overlap, but test says otherwise). "
  if (! $testa);

  my $testb = $fs_tmp8->check_if_overlap($fs_tmp10);
  $otxt .= "$eh Error while checking \'check_if_overlap\' ($in8 and $in10 do not overlap, but test says otherwise). "
  if ($testb);

  my $testc = $fs_tmp10->is_within($fs_tmp9);
  $otxt .= "$eh Error while checking \'is_within\' ($in10 is within $in9, but test says otherwise). "
  if (! $testc);

  my $testd = $fs_tmp9->is_within($fs_tmp10);
  $otxt .= "$eh Error while checking \'is_within\' ($in9 is not within $in10, but test says otherwise). "
  if ($testd);

  # optimize + count_pairs
  my $in11 = "20:40 1:2 1:1 2:6 8:12 20:40"; # 6 pairs (not optimized)
  my $exp_out11 = "1:6 8:12 20:40"; # 3 pairs (once optimized)
  my $fs_tmp11 = new ViperFramespan();
  $fs_tmp11->set_value($in11);
  my $out11 = $fs_tmp11->get_value();
  $otxt .= "$eh Error while checking \'new\'[count_pairs] (expected: $exp_out11 / Got: $out11). "
    if ($out11 ne $exp_out11);

  my $etmp11a = &_fs_split_line_count($in11);
  my $tmp11a = $fs_tmp11->count_pairs_in_original_value();
  $otxt .= "$eh Error while checking \'count_pairs_in_original_value\' (expected: $etmp11a / Got: $tmp11a). "
    if ($etmp11a != $tmp11a);

  my $etmp11b = &_fs_split_line_count($exp_out11);
  my $tmp11b = $fs_tmp11->count_pairs_in_value();
  $otxt .= "$eh Error while checking \'count_pairs_in_value\' (expected: $etmp11b / Got: $tmp11b). "
    if ($etmp11b != $tmp11b);

  # extent_middlepoint + extent_middlepoint_distance
  my $in12 = "20:39";
  my $fs_tmp12 = new ViperFramespan($in12);
  my $exp_out12 = 30; # = 20 + (((39+1) - 20) / 2)
  my $out12 = $fs_tmp12->extent_middlepoint();
  $otxt .= "$eh Error while checking \'extent_middlepoint\' (expected: $exp_out12 / Got: $out12). "
    if ($exp_out12 != $out12);

  my $in13 = "100:199"; # extent_middlepoint: 150
  my $fs_tmp13 = new ViperFramespan($in13);

  my $out13 = $fs_tmp12->extent_middlepoint_distance($fs_tmp13);
  my $exp_out13 = 120; # from 30 to 150 : +120
  $otxt .= "$eh Error while checking \'extent_middlepoint_distance\'[1] (expected: $exp_out13 / Got: $out13). "
    if ($exp_out13 != $out13);

  my $out14 = $fs_tmp13->extent_middlepoint_distance($fs_tmp12);
  my $exp_out14 = -120; # from 150 to 30 : -120
  $otxt .= "$eh Error while checking \'extent_middlepoint_distance\'[2] (expected: $exp_out14 / Got: $out14). "
    if ($exp_out14 != $out14);

  my $out15 = $fs_tmp12->extent_duration();
  my $exp_out15 = 20; # 20 [0] to 39 [19] = 20
  $otxt .= "$eh Error while checking \'extent_duration\' (expected: $exp_out15 / Got: $out15). "
    if ($exp_out15 != $out15);

  my $out15 = $fs_tmp12->duration();
  my $exp_out15 = 20; # 20 [0] to 39 [19] = 20 (same as extent_duration because there is no gap in the framespan)
  $otxt .= "$eh Error while checking \'duration\' (expected: $exp_out15 / Got: $out15). "
    if ($exp_out15 != $out15);

  my $out16 = $fs_tmp11->get_list_of_framespans();
  $otxt .= "$eh Error getting a list of framespan expected: 3 / got: ".scalar(@$out16) 
    if (3 != scalar(@$out16));
  my @expSub = split(/ /, $exp_out11);
  for (my $_i=0; $_i<@expSub; $_i++){
      $otxt .= "$eh Error get_list_of_framespan list[$_i] incorrect.  expected '$expSub[$_i]' / got '".$out16->[$_i]->get_value()."'. " 
          if ($expSub[$_i] ne $out16->[$_i]->get_value())
  }

  ### unit test overlap
  my $fs_tmp17 = new ViperFramespan();
  my $fs_tmp18 = new ViperFramespan();
  my @pairs = ( [ "3:6", "3:6", "3:6" ], 
                [ "3:6", "4:6", "4:6" ], 
                [ "3:6", "6:6", "6:6" ], 
                [ "3:6", "4:7", "4:6" ], 
                [ "3:6", "6:7", "6:6" ], 
                [ "3:6", "7:6", undef ] );
  for (my $p=0; $p<@pairs; $p++){
    $fs_tmp17->set_value($pairs[$p][0]);
    $fs_tmp18->set_value($pairs[$p][1]);
    my $fs_new = $fs_tmp17->get_overlap($fs_tmp18);
    if (!defined($fs_new) && !defined($pairs[$p][2])){ 
        ;
    } else {
        my $ret = $fs_tmp17->get_overlap($fs_tmp18)->get_value();
        $otxt .= "$eh Error overlap calc for (".join(", ",@{ $pairs[$p] }).") returned ".$ret."\n" 
            if ($ret ne $pairs[$p][2]);
    }
  }
    
    
  ########## TODO: unit_test for all 'fps' functions ##########

  #####
  # End
  if (! &_is_blank($otxt)) {
    $self->_set_errormsg($otxt);
    return(0);
  }
 
  # return 1 if no error found
  return(1);
}

############################################################

sub _is_blank {
  my $txt = shift @_;
  return(($txt =~ m%^\s*$%));
}

################################################################################

1;
