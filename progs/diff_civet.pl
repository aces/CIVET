#! /usr/bin/env perl

#
# Compare outputs for two runs of CIVET.
#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#

use strict;
use File::Basename;
use File::Spec;
use File::Temp qw/ tempdir /;

my $me = &basename($0);
my $Usage = "Usage: $me <dir1> <dir2>\n\n";

die $Usage if( $#ARGV != 1 );

# make tmpdir
my $tmpdir = &tempdir( "$me-XXXXXX", TMPDIR => 1, CLEANUP => 1 );

my $dir1 = shift(@ARGV);
my $dir2 = shift(@ARGV);

my @id1 = `cd $dir1; ls -1`;
my @id2 = `cd $dir2; ls -1`;

my ($str, $tmp);

foreach my $id (@id1) {
  chomp( $id );
  if( !( -e "${dir2}/${id}" ) ) {
    print "Cannot find matching subject in ${dir2}/${id}\n";
  } else {
    print "Comparing subject $id...\n";

    # Look at disk usage
    my $du1 = `du -sh ${dir1}/${id}`;
    my $du2 = `du -sh ${dir2}/${id}`;
    chomp( $du1 );
    chomp( $du2 );
    print "  Disk usage:  $du1     vs     $du2\n";

    # Look at stereotaxic mask volume difference
    my @mask1 = `cd ${dir1}/${id}/mask; ls -1 *skull_mask.mnc`;
    my @mask2 = `cd ${dir2}/${id}/mask; ls -1 *skull_mask.mnc`;
    chomp( @mask1[0] );
    chomp( @mask2[0] );
    print "  Stereotaxic mask volume difference: " . 
          sprintf( "%d", diff_volume( "${dir1}/${id}/mask/@mask1[0]", 
                                      "${dir2}/${id}/mask/@mask2[0]", $tmpdir ) ) . "\n";

    # Look at tissue classification
    my @cls1 = `cd ${dir1}/${id}/classify; ls -1 *_classify.mnc`;
    my @cls2 = `cd ${dir2}/${id}/classify; ls -1 *_classify.mnc`;
    chomp( @cls1[0] );
    chomp( @cls2[0] );
    print "  Stereotaxic classified volume difference: " . 
          sprintf( "%d", diff_volume( "${dir1}/${id}/classify/@cls1[0]", 
                                      "${dir2}/${id}/classify/@cls2[0]", $tmpdir ) ) ."\n";

    # Look at surfaces
    my @surf1 = `cd ${dir1}/${id}/surfaces; ls -1 *.obj`;
    my @surf2 = `cd ${dir2}/${id}/surfaces; ls -1 *.obj`;
    foreach my $surf (@surf1) {
      chomp( $surf );
      if( -e "${dir2}/${id}/surfaces/${surf}" ) {
        my @ret = `diff_surfaces ${dir1}/${id}/surfaces/${surf} ${dir2}/${id}/surfaces/${surf} link`;
        chomp( @ret[0] );
        print "  ${surf}: @ret[0]\n";
      } else {
        print "  No match for surface ${surf} in ${dir2}\n";
      }
    }
    foreach my $surf (@surf2) {
      chomp( $surf );
      if( !( -e "${dir1}/${id}/surfaces/${surf}" ) ) {
        print "  No match for surface ${surf} in ${dir1}\n";
      }
    }

    # Look at vertex-based surface measures
    my @txt1 = `cd ${dir1}/${id}/thickness; ls -1 *.txt`;
    my @txt2 = `cd ${dir2}/${id}/thickness; ls -1 *.txt`;
    foreach my $txt (@txt1) {
      chomp( $txt );
      if( -e "${dir2}/${id}/thickness/${txt}" ) {
        my $ret = diff_txt( "${dir1}/${id}/thickness/${txt}", "${dir2}/${id}/thickness/${txt}" );
        print "  ${txt}: $ret\n";
      } else {
        print "  No match for ${txt} in ${dir2}\n";
      }
    }
    foreach my $txt (@txt2) {
      chomp( $txt );
      if( !( -e "${dir1}/${id}/thickness/${txt}" ) ) {
        print "  No match for ${txt} in ${dir1}\n";
      }
    }

  }
}

foreach my $id (@id2) {
  chomp( $id );
  if( !( -e "${dir1}/${id}" ) ) {
    print "Cannot find matching subject in ${dir1}/${id}\n";
  }
}

print "All done!\n";

sub diff_txt {

  my $f1 = shift;
  my $f2 = shift;

  open( DATA, $f1 ) || die "Could not open file $f1";
  my @txt1 = <DATA>;
  close( DATA );

  open( DATA, $f2 ) || die "Could not open file $f2";
  my @txt2 = <DATA>;
  close( DATA );

  my $diff = 0;

  if( $#txt1 == $#txt2 ) {
    for( my $i = 0; $i <= $#txt1; $i++ ) {
      my $val = abs( @txt1[$i] - @txt2[$i] );
      $diff = $val if( $val > $diff );
    }
  } else {
    $diff = 9999999;
  }

  return $diff;
}

sub diff_volume {

  my $v1 = shift;
  my $v2 = shift;
  my $tmpdir = shift;

  my $diff_vol = "$tmpdir/volume_diff.mnc";

  system( "minccalc -quiet -clobber -byte -expression 'abs(A[0]-A[1])' $v1 $v2 $diff_vol" );
  my $str = `mincstats -sum $diff_vol`;
  (my $tmp,my $diff) = split( ' ', $str );

  unlink $diff_vol;

  return $diff;
}




