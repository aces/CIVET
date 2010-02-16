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

my $html = "";

my $first = 1;
my $count = 0;
my @header = ();

foreach my $id (@id1) {
  chomp( $id );
  if( !( -e "${dir2}/${id}" ) ) {
    print "Cannot find matching subject in ${dir2}/${id}\n";
  } else {

    my $total = 0;
    my $total1 = 0;
    my $htmlline = "";
    print "Comparing subject $id...\n";

    # Look at native mask volume difference
    my @mask1 = `cd ${dir1}/${id}/mask; ls -1 *skull_mask_native.mnc`;
    my @mask2 = `cd ${dir2}/${id}/mask; ls -1 *skull_mask_native.mnc`;
    chomp( @mask1[0] );
    chomp( @mask2[0] );
    my $mvol1 = `mincstats -quiet -sum ${dir1}/${id}/mask/@mask1[0]`;
    my $mvol2 = `mincstats -quiet -sum ${dir2}/${id}/mask/@mask2[0]`;
    my $val = sprintf( "%d", diff_volume( "${dir1}/${id}/mask/@mask1[0]",
                                          "${dir2}/${id}/mask/@mask2[0]", $tmpdir ) );
    $val = sprintf( "%7.4f", 200.0 * $val / ( $mvol1 + $mvol2 ) );
    $total += $val;
    $total1 += $val;
    $htmlline .= "<td> $val </td>";
    if( $first ) {
      $count++;
      push @header, ("Native mask (%)");
    }

    # Look at stereotaxic mask volume difference
    my @mask1 = `cd ${dir1}/${id}/mask; ls -1 *skull_mask.mnc`;
    my @mask2 = `cd ${dir2}/${id}/mask; ls -1 *skull_mask.mnc`;
    chomp( @mask1[0] );
    chomp( @mask2[0] );
    my $mvol1 = `mincstats -quiet -sum ${dir1}/${id}/mask/@mask1[0]`;
    my $mvol2 = `mincstats -quiet -sum ${dir2}/${id}/mask/@mask2[0]`;
    my $val = sprintf( "%d", diff_volume( "${dir1}/${id}/mask/@mask1[0]",
                                          "${dir2}/${id}/mask/@mask2[0]", $tmpdir ) );
    $val = sprintf( "%7.4f", 200.0 * $val / ( $mvol1 + $mvol2 ) );
    $total += $val;
    $total1 += $val;
    $htmlline .= "<td> $val </td>";
    if( $first ) {
      $count++;
      push @header, ("Stereotaxic mask(%)");
    }

    # Look at tissue classification
    my @cls1 = `cd ${dir1}/${id}/classify; ls -1 *_classify.mnc`;
    my @cls2 = `cd ${dir2}/${id}/classify; ls -1 *_classify.mnc`;
    chomp( @cls1[0] );
    chomp( @cls2[0] );
    $val = sprintf( "%d", diff_volume( "${dir1}/${id}/classify/@cls1[0]",
                                       "${dir2}/${id}/classify/@cls2[0]", $tmpdir ) );
    $val = sprintf( "%7.4f", 200.0 * $val / ( $mvol1 + $mvol2 ) );
    $total += $val;
    $total1 += $val;
    $htmlline .= "<td> $val </td>";
    if( $first ) {
      $count++;
      push @header, ("Classified image (%)");
    }

    # Look at surfaces
    my @surf1 = `cd ${dir1}/${id}/surfaces; ls -1 *.obj`;
    my @surf2 = `cd ${dir2}/${id}/surfaces; ls -1 *.obj`;
    foreach my $surf (@surf1) {
      chomp( $surf );
      if( -e "${dir2}/${id}/surfaces/${surf}" ) {
        my @ret = `diff_surfaces ${dir1}/${id}/surfaces/${surf} ${dir2}/${id}/surfaces/${surf} link`;
        chomp( @ret[0] );
        @ret[0] =~ /points: (.*)/;
        my $rms = sprintf( "%6.2f", $1 );
        chomp( @ret[4] );
        @ret[4] =~ /dist: (.*)/;
        my $max = sprintf( "%6.2f", $1 );
        my $junk = `measure_surface_area ${dir1}/${id}/surfaces/${surf}`;
        chomp( $junk );
        $junk =~ /Area: (.*)/;
        my $a1 = $1;
        $junk = `measure_surface_area ${dir2}/${id}/surfaces/${surf}`;
        chomp( $junk );
        $junk =~ /Area: (.*)/;
        my $a2 = $1;
        my $area = sprintf( "%6.2f", 200.0 * abs( $a1 - $a2 ) / ( $a1 + $a2 ) );
        $total += $rms + $max;
        $htmlline .= "<td> $rms </td> <td> $max </td> <td> $area </td>";
        if( $first ) {
          $count++;
          push @header, ("rms($surf)");
          $count++;
          push @header, ("max($surf)");
          $count++;
          push @header, ("area($surf)");
        }
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
        $ret = sprintf( "%6.2f", $ret );
        $total += $ret;
        $htmlline .= "<td> $ret </td>";
        if( $first ) {
          $count++;
          push @header, ($txt);
        }
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

    # Look at gyrification index on gray surface
    my @gi1 = `cd ${dir1}/${id}/surfaces; ls -1 *.dat |grep _gi_`;
    my @gi2 = `cd ${dir2}/${id}/surfaces; ls -1 *.dat |grep _gi_`;
    foreach my $gi (@gi1) {
      chomp( $gi );
      if( -e "${dir2}/${id}/surfaces/${gi}" ) {
        open( IDFILE, "${dir1}/${id}/surfaces/${gi}" );
        my $idline = <IDFILE>;
        $idline =~ /gyrification index gray: (.*)/;
        my $val1 = $1;
        close (IDFILE);
        open( IDFILE, "${dir2}/${id}/surfaces/${gi}" );
        my $idline = <IDFILE>;
        $idline =~ /gyrification index gray: (.*)/;
        my $val2 = $1;
        close (IDFILE);
        my $err = sprintf( "%7.4f", 200.0 * abs( $val1 - $val2 ) / ( $val1 + $val2 ) );
        $total += $err;
        $htmlline .= "<td> $err </td>";
        if( $first ) {
          $count++;
          push @header, ($gi);
        }
        print "  ${gi}: $err\%\n";
      } else {
        print "  No match for ${gi} in ${dir2}\n";
      }
    }
    foreach my $gi (@gi2) {
      chomp( $gi );
      if( !( -e "${dir1}/${id}/surfaces/${gi}" ) ) {
        print "  No match for ${gi} in ${dir1}\n";
      }
    }

# Colour code the ID by warning colour.
    $first = 0;
    if( $total < 0.0001 ) {
      $htmlline = "<td bgcolor=\"lightgreen\" > $id </td>" . $htmlline;
    } else {
      if( $total1 < 0.0001 ) {
        $htmlline = "<td bgcolor=\"orange\" > $id </td>" . $htmlline;
      } else {
        $htmlline = "<td> $id </td>" . $htmlline;
      }
    }
    $htmlline = "<tr bgcolor=\"\#dddddd\">" . $htmlline . "</tr>\n";


    $html .= $htmlline;
    print "\n";
  }
}

foreach my $id (@id2) {
  chomp( $id );
  if( !( -e "${dir1}/${id}" ) ) {
    print "Cannot find matching subject in ${dir1}/${id}\n";
  }
}

# The abbreviated header line.
my $htmlline = "<tr bgcolor=\"\#cccccc\">";
for( my $i = 0; $i <= $count; $i++ ) {
  $htmlline .= "<td> $i </td>";
}
$htmlline .= "</tr>";

$html = "<table cellspacing=\"2\" bgcolor=\"white\">\n" .
        "$htmlline\n" . $html . 
        "</table>\n";

$html .= "<table>\n";
$html .= "<tr> <td> 0 </td> <td> Subject ID </td> </tr>\n";
for( my $i = 1; $i <= $count; $i++ ) {
  $html .= "<tr> <td> $i </td> <td> @header[$i-1] </td> </tr>\n";
}



open FILE, ">diff_civet.html";
print FILE $html;
close FILE;


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




