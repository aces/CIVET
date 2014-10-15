#! /usr/bin/env perl
#
# non-linear fitting using parameters, inspired by Steve Robbins,
# optimised by Claude Lepage, using a brain mask for the source and 
# the target.
#
# Claude Lepage - claude@bic.mni.mcgill.ca
# Andrew Janke - rotor@cmr.uq.edu.au
# Center for Magnetic Resonance
# The University of Queensland
# http://www.cmr.uq.edu.au/~rotor
#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#

use strict;
use warnings "all";
use Getopt::Tabular;
use POSIX qw/floor/;
use File::Basename;
use File::Temp qw/ tempdir /;

# default minctracc parameters
my @def_minctracc_args = (
#   '-debug',
   '-clobber',
   '-nonlinear', 'corrcoeff',
   '-stiffness', 0.962962,  # = 26/27 in 3-D
   );

my @conf = (

   {'step'         => 24,
    'blur_fwhm'    => 12,   
    'iterations'   => 20,
    'similarity'   => 0.50,
    'weight'       => 1,
    'lattice'      => 12,
    },

   {'step'         => 16,
    'blur_fwhm'    => 8,
    'iterations'   => 20,
    'similarity'   => 0.45,
    'weight'       => 1,
    'lattice'      => 12,
    },

   {'step'         => 12,
    'blur_fwhm'    => 6,
    'iterations'   => 25,
    'similarity'   => 0.40,
    'weight'       => 1.0,
    'lattice'      => 12,
    },

   {'step'         => 8,
    'blur_fwhm'    => 4,
    'iterations'   => 30,
    'similarity'   => 0.35,
    'weight'       => 1.0,
    'lattice'      => 12,
    },

   {'step'         => 6,
    'blur_fwhm'    => 3,
    'iterations'   => 20,
    'similarity'   => 0.30,
    'weight'       => 1.0,
    'lattice'      => 12,
    },

   {'step'         => 4,
    'blur_fwhm'    => 2,
    'iterations'   => 20,
    'similarity'   => 0.25,
    'weight'       => 1.0,
    'lattice'      => 12,
    },

   {'step'         => 2,     # gets expensive
    'blur_fwhm'    => 2,
    'iterations'   => 10,
    'similarity'   => 0.20,
    'weight'       => 0.75,
    'lattice'      => 6,
   }

   );

my($Help, $Usage, $me);
my(@opt_table, %opt, $source, $target, $outxfm, $outfile, @args, $tmpdir);

$me = &basename($0);
%opt = (
   'verbose'   => 0,
   'clobber'   => 0,
   'fake'      => 0,
   'normalize' => 0,
   'init_xfm'  => undef,
   'source_mask' => undef,
   'target_mask' => undef,
   );

$Help = <<HELP;
| $me does hierachial non-linear fitting between two files
|    you will have to edit the script itself to modify the
|    fitting levels themselves
| 
| Problems or comments should be sent to: rotor\@cmr.uq.edu.au
HELP

$Usage = "Usage: $me [options] source.mnc target.mnc output.xfm [output.mnc]\n".
         "       $me -help to list options\n\n";

@opt_table = (
   ["-verbose", "boolean", 0, \$opt{verbose},
      "be verbose" ],
   ["-clobber", "boolean", 0, \$opt{clobber},
      "clobber existing check files" ],
   ["-fake", "boolean", 0, \$opt{fake},
      "do a dry run, (echo cmds only)" ],
   ["-normalize", "boolean", 0, \$opt{normalize},
      "do intensity normalization on source to match intensity of target" ],
   ["-init_xfm", "string", 1, \$opt{init_xfm},
      "initial transformation (default identity)" ],
   ["-source_mask", "string", 1, \$opt{source_mask},
      "source mask to use during fitting" ],
   ["-target_mask", "string", 1, \$opt{target_mask},
      "target mask to use during fitting" ],
   );

# Check arguments
&Getopt::Tabular::SetHelp($Help, $Usage);
&GetOptions (\@opt_table, \@ARGV) || exit 1;
die $Usage if(! ($#ARGV == 2 || $#ARGV == 3));
$source = shift(@ARGV);
$target = shift(@ARGV);
$outxfm = shift(@ARGV);
$outfile = (defined($ARGV[0])) ? shift(@ARGV) : undef;

# check for files
die "$me: Couldn't find input file: $source\n\n" if (!-e $source);
die "$me: Couldn't find input file: $target\n\n" if (!-e $target);
if(-e $outxfm && !$opt{clobber}){
   die "$me: $outxfm exists, -clobber to overwrite\n\n";
   }
if(defined($outfile) && -e $outfile && !$opt{clobber}){
   die "$me: $outfile exists, -clobber to overwrite\n\n";
}

# make tmpdir
$tmpdir = &tempdir( "$me-XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );

# set up filename base
my($i, $s_base, $t_base, $tmp_xfm, $tmp_source, $tmp_target, $prev_xfm);
$s_base = &basename($source);
$s_base =~ s/\.mnc(.gz)?$//;
$s_base = "S${s_base}";
$t_base = &basename($target);
$t_base =~ s/\.mnc(.gz)?$//;
$t_base = "T${t_base}";

# Run inormalize if required. minctracc likes it better when the
# intensities of the source and target are similar, but honestly
# this step may be completely useless in CIVET. (Must make sure
# that source and target are sampled in the same way - only needed
# by inormalize but not for minctracc).

my $original_source = $source;
if( $opt{normalize} ) {
  my $inorm_source = "$tmpdir/${s_base}_inorm.mnc";
  my $inorm_target = "$tmpdir/${t_base}_inorm.mnc";
  &do_cmd( "mincresample", "-clobber", "-like", $source, $target, $inorm_target );
  &do_cmd( 'inormalize', '-clobber', '-model', $inorm_target, $source, $inorm_source );
  &do_cmd( 'rm', '-rf', $inorm_target );
  $source = $inorm_source;
}

# mask the images before fitting only if both masks exists.
if( defined($opt{source_mask}) and defined($opt{target_mask}) ) {
  my $source_masked = "$tmpdir/${s_base}_masked.mnc";
  &do_cmd( 'minccalc', '-clobber',
           '-expression', 'if(A[1]>0.5){out=A[0];}else{0;}',
           $source, $opt{source_mask}, $source_masked );
  $source = $source_masked;

  my $target_masked = "$tmpdir/${t_base}_masked.mnc";
  &do_cmd( 'minccalc', '-clobber',
           '-expression', 'if(A[1]>0.5){out=A[0];}else{0;}',
           $target, $opt{target_mask}, $target_masked );
  $target = $target_masked;
}

# a fitting we shall go...
for ($i=0; $i<=$#conf; $i++){

   # remove blurred image at previous iteration, if no longer needed.
   if( $i > 0 ) {
     if( $conf[$i]{blur_fwhm} != $conf[$i-1]{blur_fwhm} ) {
       unlink( "$tmp_source\_blur.mnc" ) if( -e "$tmp_source\_blur.mnc" );
       unlink( "$tmp_target\_blur.mnc" ) if( -e "$tmp_target\_blur.mnc" );
     }
   }
   
   # set up intermediate files
   $tmp_xfm = "$tmpdir/$s_base\_$i.xfm";
   $tmp_source = "$tmpdir/$s_base\_$conf[$i]{blur_fwhm}";
   $tmp_target = "$tmpdir/$t_base\_$conf[$i]{blur_fwhm}";
   
   print STDOUT "-+-[$i]\n".
                " | step:           $conf[$i]{step}\n".
                " | similarity:     $conf[$i]{similarity}\n".
                " | weight:         $conf[$i]{weight}\n".
                " | blur_fwhm:      $conf[$i]{blur_fwhm}\n".
                " | iterations:     $conf[$i]{iterations}\n".
                " | source:         $tmp_source\n".
                " | target:         $tmp_target\n".
                " | xfm:            $tmp_xfm\n".
                "\n";
   
   # blur the source and target files if required.
   if( $conf[$i]{blur_fwhm} > 0 ) {
     if(!-e "${tmp_source}_blur.mnc"){
       &do_cmd('mincblur', '-no_apodize', '-fwhm', $conf[$i]{blur_fwhm},
               $source, $tmp_source);
     }
   } else {
     &do_cmd('cp', '-f', $source, "${tmp_source}_blur.mnc" );
   }
   if( $conf[$i]{blur_fwhm} > 0 ) {
     if(!-e "${tmp_target}_blur.mnc"){
       &do_cmd('mincblur', '-no_apodize', '-fwhm', $conf[$i]{blur_fwhm},
               $target, $tmp_target);
     }
   } else {
     &do_cmd('cp', '-f', $target, "${tmp_target}_blur.mnc" );
   }

   # set up registration
   @args = ('minctracc',  @def_minctracc_args,
            '-iterations', $conf[$i]{iterations},
            '-step', $conf[$i]{step}, $conf[$i]{step}, $conf[$i]{step},
            '-similarity', $conf[$i]{similarity},
            '-weight', $conf[$i]{weight},
            '-sub_lattice', $conf[$i]{lattice},
            '-lattice_diam', $conf[$i]{step} * 3, 
                             $conf[$i]{step} * 3, 
                             $conf[$i]{step} * 3);
   
   # transformation
   if($i == 0) {
      push(@args, (defined $opt{init_xfm}) ? ('-transformation', $opt{init_xfm}) : '-identity')
   } else {
      push(@args, '-transformation', $prev_xfm);
   }

   # masking
   if( defined($opt{source_mask}) && defined($opt{target_mask}) ) {
     # if both masks are supplied, then apply masking on all stages.
     push(@args, '-source_mask', $opt{source_mask} );
     push(@args, '-model_mask', $opt{target_mask} );
   } else {
     if( defined($opt{source_mask}) ) {
       push(@args, '-source_mask', $opt{source_mask} );
     }
     if( defined($opt{target_mask}) ) {
       push(@args, '-model_mask', $opt{target_mask} );
     }
   }
   
   # add files and run registration
   push(@args, "${tmp_source}_blur.mnc", "${tmp_target}_blur.mnc", 
        ($i == $#conf) ? $outxfm : $tmp_xfm);
   &do_cmd(@args);
  
   # remove previous xfm to keep tmpdir usage to a minimum.
   # (could also remove the previous blurred images).

   if($i > 0) {
     unlink( $prev_xfm );
     $prev_xfm =~ s/\.xfm/_grid_0.mnc/;
     unlink( $prev_xfm );
   }

   # reduce current grid to minimal size.

   if( $i > 0 ) {
     my $current_grid = ($i == $#conf) ? $outxfm : $tmp_xfm;
     $current_grid =~ s/\.xfm/_grid_0.mnc/;
     shrink_grid( "${tmp_source}_blur.mnc", "${tmp_target}_blur.mnc",
                  defined($opt{source_mask}) ? $opt{source_mask} : "none",
                  defined($opt{target_mask}) ? $opt{target_mask} : "none",
                  $conf[$i]{step}, $current_grid,
                  "${tmpdir}/nl_rsl_grid_0.mnc" );
     &do_cmd( 'mv', '-f', "${tmpdir}/nl_rsl_grid_0.mnc", $current_grid );
   }

   # define starting xfm for next iteration. 

   $prev_xfm = ($i == $#conf) ? $outxfm : $tmp_xfm;
}

# resample if required
if(defined($outfile)){
   print STDOUT "-+- creating $outfile using $outxfm\n".
   &do_cmd('mincresample', '-clobber', '-like', $target, '-trilinear',
           '-transformation', $outxfm, $original_source, $outfile);
}


sub do_cmd { 
   print STDOUT "@_\n" if $opt{verbose};
   if(!$opt{fake}){
      system(@_) == 0 or die;
   }
}

sub shrink_grid {

   my $source = shift;
   my $target = shift;
   my $source_mask = shift;
   my $target_mask = shift;
   my $step = shift;
   my $ingrid = shift;
   my $outgrid = shift;

   my $tmpxfm = "${tmpdir}/fake_nlfit.xfm";
   my $tmpgrid = "${tmpdir}/fake_nlfit_grid_0.mnc";

   # masking
   my @mask_args = ();
   if( $source_mask ne "none" && -e $source_mask ) {
     push(@mask_args, '-source_mask', $source_mask );
   }
   if( $target_mask ne "none" && -e $target_mask ) {
     push(@mask_args, '-model_mask', $target_mask );
   }
   
   # fake registration to obtain grid size
   &do_cmd( 'minctracc',  @def_minctracc_args, @mask_args,
            '-iterations', 0, '-step', $step, $step, $step,
            '-similarity', 0.5, '-weight', 0.9, '-sub_lattice', 6,
            '-lattice_diam', $step * 3, $step * 3, $step * 3,
            $source, $target, $tmpxfm );

   my $dx = `mincinfo -attvalue xspace:step $ingrid`; chomp($dx), $dx+=0;
   my $dy = `mincinfo -attvalue yspace:step $ingrid`; chomp($dy), $dy+=0;
   my $dz = `mincinfo -attvalue zspace:step $ingrid`; chomp($dz), $dz+=0;
   my $nx = `mincinfo -attvalue xspace:length $ingrid`; chomp($nx), $nx+=0;
   my $ny = `mincinfo -attvalue yspace:length $ingrid`; chomp($ny), $ny+=0;
   my $nz = `mincinfo -attvalue zspace:length $ingrid`; chomp($nz), $nz+=0;
   my $sx = `mincinfo -attvalue xspace:start $ingrid`; chomp($sx), $sx+=0;
   my $sy = `mincinfo -attvalue yspace:start $ingrid`; chomp($sy), $sy+=0;
   my $sz = `mincinfo -attvalue zspace:start $ingrid`; chomp($sz), $sz+=0;

   my $tnx = `mincinfo -attvalue xspace:length $tmpgrid`; chomp($tnx), $tnx+=0;
   my $tny = `mincinfo -attvalue yspace:length $tmpgrid`; chomp($tny), $tny+=0;
   my $tnz = `mincinfo -attvalue zspace:length $tmpgrid`; chomp($tnz), $tnz+=0;
   unlink( $tmpxfm );
   unlink( $tmpgrid );

   # assume that reduction will be symmetric (is this always safe?)
   my $diffx = floor( ( $nx - $tnx - 4 ) / 2 );
   if( $diffx > 0 ) {
     $sx += $diffx * $dx;
     $nx -= 2 * $diffx;
   }

   my $diffy = floor( ( $ny - $tny - 4 ) / 2 );
   if( $diffy > 0 ) {
     $sy += $diffy * $dy;
     $ny -= 2 * $diffy;
   }

   my $diffz = floor( ( $nz - $tnz - 4 ) / 2 );
   $diffz = 0 if( $diffz < 0 );
   if( $diffz > 0 ) {
     $sz += $diffz * $dz;
     $nz -= 2 * $diffz;
   }

   &do_cmd( 'mincresample', '-clobber', '-quiet', '-nelements', 
            $nx, $ny, $nz, '-start', $sx, $sy, $sz, '-nearest',
            $ingrid, $outgrid );

}

