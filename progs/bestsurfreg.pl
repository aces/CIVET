#!/usr/bin/env perl

#
# Surface registration using surftracc and Maxime's data term.
#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#

use strict;
use FindBin;
use List::Util qw[min max];
use lib "$FindBin::Bin";

use MNI::Startup;
use Getopt::Tabular;
use MNI::Spawn;
use MNI::DataDir;
use MNI::FileUtilities qw(test_file);
use File::Temp qw/ tempdir /;
use File::Basename;
my($Help, $Usage, $me);
my(@opt_table, $source, $target, $outxfm, $tmpdir);
$me = &basename($0);

# make tmpdir
my $tmpdir = &tempdir( "$me-XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );

my $verbose   = 0;
my $clobber   = 0;
my $control_mesh_min = 20;
my $control_mesh_max = 10000000;
my $mesh_smooth = 0.75;  # 0.95;
my $blur_coef = 1.25;
my $neighbourhood_radius = 2.3;
my $max_fwhm = undef;
my $Mode = 'stiff';  # stiff for white surface, soft for mid surface

#
# search_radius = allowable movement per iteration
#                 - go slowly to avoid mesh tangling
#                 - fit may not be as good since converging at slower rate
# penalty_ratio = mesh stiffness constraint
#                 - high value improves mesh quality (equal area triangles)
#                 - high value decreases fit properties
# neighbourhood_radius = factor multiplying average edge length on unit
#                        sphere, making a disk in which the dataterm 
#                        is sampled (1 point at zero, 8 points at r/2 
#                        and 16 at r).

#
# To prevent self-intersections, favour small search_radius and high
# penalty_ratio, but if those values go too far, the fit will suffer.
# It's not obvious if it's better to take large steps with stiff mesh
# or to take small steps with a loose mesh, or somewhere in between.
# Importantly, we don't want to mess of the mesh properties in the
# early stages.
#

my @conf = (
   { control_size     => 320,
     target_size      => 5120,
     alpha            => 0.05,
     search_radius    => { stiff => 0.20, soft => 0.10 },
     ## penalty_ratio    => { stiff => 0.15, soft => 0.10 },
     penalty_ratio    => { stiff => 0.0125, soft => 0.10 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-03",
     max_iters        => 200,
     conv_control     => 2,
     conv_thresh      => 0.0001 },

   { control_size     => 1280,
     target_size      => 5120,
     alpha            => 0.05,
     search_radius    => { stiff => 0.15, soft => 0.15 },
     ## penalty_ratio    => { stiff => 0.15, soft => 0.10 },
     penalty_ratio    => { stiff => 0.0125, soft => 0.10 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-03",
     max_iters        => 150,
     conv_control     => 2,
     conv_thresh      => 0.0001 },

   { control_size     => 5120,
     target_size      => 20480,
     alpha            => 0.05,
     search_radius    => { stiff => 0.15, soft => 0.20 },
     ## penalty_ratio    => { stiff => 0.10, soft => 0.10 },
     penalty_ratio    => { stiff => 0.025, soft => 0.10 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-03",
     max_iters        => 150,
     conv_control     => 2,
     conv_thresh      => 0.0001 },

# There is a trend to increase search_radius with control_size.

   { control_size     => 20480,
     target_size      => 81920,
     alpha            => 0.05,
     search_radius    => { stiff => 0.15, soft => 0.225 },
     # penalty_ratio    => { stiff => 0.10, soft => 0.10 },
     penalty_ratio    => { stiff => 0.05, soft => 0.10 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-04",
     max_iters        => 200,
     conv_control     => 2,
     conv_thresh      => 0.0001 },

   { control_size     => 81920,
     target_size      => 81920,
     alpha            => 0.025,
     search_radius    => { stiff => 0.15, soft => 0.250 },
     penalty_ratio    => { stiff => 0.10, soft => 0.15 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-04",
     max_iters        => 100,
     conv_control     => 2,
     conv_thresh      => 0.00005 },

   { control_size     => 327680,
     target_size      => 327680,
     alpha            => 0.05,
     search_radius    => { stiff => 0.20, soft => 0.20 },
     penalty_ratio    => { stiff => 0.10, soft => 0.10 },
     max_ngh_rad      => undef,
     abs_tol          => "1e-06",
     max_iters        => 10,
     conv_control     => 2,
     conv_thresh      => 0.00005 },

);


$Help = <<HELP;
|    $me fully configurable hierachical surface fitting...
| 
| Problems or comments should be sent to: claude\@bic.mni.mcgill.ca
HELP

$Usage = "Usage: $me [options]  source.obj source.txt target.obj target.txt output.sm\n".
         "       $me -help to list options\n\n";

@opt_table = (
   ["-verbose", "const", "1", \$verbose,
      "be verbose" ],
   ["-clobber", "const", "1", \$clobber,
      "clobber existing files" ],
   ["-mesh_smooth", "string", 1, \$mesh_smooth,
      "neighbour weight in smoothing step" ],      
   ["-neighbourhood_radius", "string",1,\$neighbourhood_radius, 
      "neighbourhood radius" ],
   ["-min_control_mesh", "string",1,\$control_mesh_min,
       "control mesh must be no less than X nodes..." ],
   ["-max_control_mesh", "string",1,\$control_mesh_max,
       "control mesh must be no greater than X nodes..." ],
   ["-blur_coef", "string",1,\$blur_coef,
       "factor to increase/decrease blurring" ],     
   ["-maximum_blur", "string","1",\$max_fwhm, 
      "specify target spacing" ],
   ["-mode", "string", "1", \$Mode, 
      "\'stiff\' for white surface, \'soft\' for mid surface" ],
   );    

# Check arguments
&Getopt::Tabular::SetHelp($Help, $Usage);
&GetOptions (\@opt_table, \@ARGV) || exit 1;
die "usage: $0 source_obj target_obj smap_out" unless @ARGV==3;
my( $source_obj, $target_obj, $map_final ) = @ARGV;


# The programs used.  
# Must load quarantine in path first.
#
RegisterPrograms( [qw(create_tetra
                      initial-surface-map
                      surftracc
                      refine-surface-map
                      surface-stats
                      depth_potential
                      mv
                      cp)] );

my $old_surface_mapping = "${tmpdir}/old_map.sm";
my $surface_mapping = "${tmpdir}/map.sm";

# do the registration
 
if ($control_mesh_max<20||$control_mesh_max<$control_mesh_min){
  die("You can't specify a control mesh max less than 20, things start at 20");
}
if ($control_mesh_max<$control_mesh_min){
  die("You can't specify a control mesh max less than control mesh min");
}

my $source_area = `measure_surface_area $source_obj`;
$source_area =~ /Area: (.*)/;
$source_area = $1;

my $target_area = `measure_surface_area $target_obj`;
$target_area =~ /Area: (.*)/;
$target_area = $1;

if( CheckFlipOrientation( $target_obj ) ) {
  print "Flipping $target_obj for proper orientation...\n";
  my $flipped_target = "$tmpdir/flipped_target.obj";
  &do_cmd( "param2xfm", '-clobber', '-scales', -1, 1, 1,
          "${tmpdir}/flip.xfm" );
  &do_cmd( "transform_objects", $target_obj,
          "${tmpdir}/flip.xfm", $flipped_target );
  unlink( "${tmpdir}/flip.xfm" );
  $target_obj = $flipped_target;
}

if( CheckFlipOrientation( $source_obj ) ) {
  print "Flipping $source_obj for proper orientation...\n";
  my $flipped_source = "$tmpdir/flipped_source.obj";
  &do_cmd( "param2xfm", '-clobber', '-scales', -1, 1, 1,
          "${tmpdir}/flip.xfm" );
  &do_cmd( "transform_objects", $source_obj,
          "${tmpdir}/flip.xfm", $flipped_source );
  unlink( "${tmpdir}/flip.xfm" );
  $source_obj = $flipped_source;
}

my $source_fwhm = undef;
my $target_fwhm = undef;
my $temp_nr = undef;

my $i;

for ($i=0; $i<=$#conf; $i++) {

  next if( $control_mesh_max < $conf[$i]{control_size} );
  ## next if( 81920 < $conf[$i]{control_size} );

  # Fancy printout of options.

  print STDOUT "\n-+-------------------------[$i]-------------------------\n".
                 " | control mesh size:              $conf[$i]{control_size}\n".
                 " | target mesh size:               $conf[$i]{target_size}\n";

  if( $control_mesh_min<=$conf[$i]{control_size} && 
      $control_mesh_max>=$conf[$i]{control_size} ) {

    # common blurring for source + target based on source_obj.
    my $source_edge_len = sqrt( ( $source_area / $conf[$i]{control_size} ) * 
                                 4.0 / sqrt( 3.0 ) );
    my $common_fwhm = $blur_coef * $neighbourhood_radius * $source_edge_len;

    $source_fwhm = $common_fwhm;
    $target_fwhm = $common_fwhm;
    if( defined( $max_fwhm ) ) {
      if ($source_fwhm>$max_fwhm){$source_fwhm = $max_fwhm};
      if ($target_fwhm>$max_fwhm){$target_fwhm = $max_fwhm};
    }

    $temp_nr = $neighbourhood_radius;
    if( defined $conf[$i]{max_ngh_rad} ) {
      if( $neighbourhood_radius > $conf[$i]{max_ngh_rad} ) {
        $temp_nr = $conf[$i]{max_ngh_rad};
      }
    }

    print STDOUT " | search radius:                  $conf[$i]{search_radius}{$Mode}\n".
                 " | depth potential alpha:          $conf[$i]{alpha}\n".
                 " | penalty ratio:                  $conf[$i]{penalty_ratio}{$Mode}\n".
                 " | source fwhm:                    $source_fwhm mm\n".
                 " | target fwhm:                    $target_fwhm mm\n".
                 " | max neighbourhood radius:       $temp_nr\n".
                 " | convergence params:             $conf[$i]{conv_control}:$conf[$i]{conv_thresh}\n".
                 "-+-----------------------------------------------------\n".
                  "\n";
  } else {
    print STDOUT "-+-----------------------------------------------------\n".
                "\n";
  }

  my $control_sphere = "${tmpdir}/control_sphere.obj";
  my $target_sphere = "${tmpdir}/target_sphere.obj";
  &do_cmd( "create_tetra",$control_sphere,0,0,0,1,1,1,$conf[$i]{control_size});
  &do_cmd( "create_tetra",$target_sphere,0,0,0,1,1,1,$conf[$i]{target_size});
  if( $i == 0 ) {
    &do_cmd("initial-surface-map", $control_sphere, $target_sphere, 
            $surface_mapping);
  } else {
    &do_cmd("refine-surface-map", $surface_mapping, $control_sphere, 
            $target_sphere, $old_surface_mapping);
    &do_cmd("cp", $old_surface_mapping, $surface_mapping);
  }
  unlink( $control_sphere );
  unlink( $target_sphere );

  if( $control_mesh_min<=$conf[$i]{control_size} && 
      $control_mesh_max>=$conf[$i]{control_size} ) {
    &do_cmd("mv", $surface_mapping, $old_surface_mapping);

    &surface_register_smartest( "-alpha", $conf[$i]{alpha},
            "-source_fwhm", $source_fwhm,"-target_fwhm" ,$target_fwhm ,
            "-mesh_smooth", $mesh_smooth,
            "-penalty_ratio", $conf[$i]{penalty_ratio}{$Mode},
            "-neighbourhood_radius", $temp_nr,
            "-search_radius", $conf[$i]{search_radius}{$Mode},
            "-abs_tolerance", $conf[$i]{abs_tol},
            "-max_iterations", $conf[$i]{max_iters},
            "-convergence_control", $conf[$i]{conv_control},
            "-convergence_threshold", $conf[$i]{conv_thresh},
            $old_surface_mapping, $source_obj, $target_obj, 
            $surface_mapping);
  }
}

&do_cmd("cp", $surface_mapping, $map_final);

#  the end of main script

#
# Configurable surface register: perform one stage
#

sub surface_register_smartest {

  my $mesh_smooth = 0.95;
  my $penalty_ratio = 0.05;
  my $source_fwhm = 0;
  my $target_fwhm = 0;
  my $neighbourhood_radius = 2.8;
  my $search_radius = 0.30;
  my $alpha = 0.05;
  my $abs_tolerance = 1.0e-06;
  my $max_iterations = 100;
  my $convergence_control = 2;
  my $convergence_threshold = 0.0001;

  my @opt_table = (
     ["-mesh_smooth", "string", 1, \$mesh_smooth,
      "neighbour weight in smoothing step (default 1)" ],      
     ["-penalty_ratio", "string", 1, \$penalty_ratio,
      "penalty ratio in smoothing step (default 0.05)" ],      
     ["-source_fwhm", "string",1,\$source_fwhm, 
      "optional source blurring kernel" ],
     ["-target_fwhm", "string",1,\$target_fwhm, 
      "optional target blurring kernel" ],
     ["-neighbourhood_radius", "string",1,\$neighbourhood_radius, 
      "neighbourhood radius" ], 
     ["-search_radius", "string",1,\$search_radius, 
      "search radius" ],  
     ["-alpha", "string",1,\$alpha, "depth potential alpha" ],  
     ["-abs_tolerance", "string", 1, \$abs_tolerance, 
      "tolerence for inner iterations in surftracc" ],
     ["-max_iterations", "string", 1, \$max_iterations, 
      "maximum number of global iterations" ],
     ["-convergence_control", "string",1,\$convergence_control, 
      "0 static, 1 inter-field distance, 2 node movement" ],
     ["-convergence_threshold", "string",1,\$convergence_threshold, 
      "for static control = num iterations, for non-static convergence control % change (0.01 =1%)" ],
  );    

  # Check arguments
  my @localArgs = @_;
  &GetOptions (\@opt_table, \@localArgs) || exit 1;
  die "Incorrect number of arguments to surface_register_smartest\n"
    if($#localArgs != 3);

  my $initial_sm = shift(@localArgs);
  my $source_obj = shift(@localArgs);
  my $target_obj = shift(@localArgs);
  my $output_sm = shift(@localArgs);

  # check for files
  die "Couldn't find input file: $initial_sm\n" if (!-e $initial_sm);
  die "Couldn't find input file: $source_obj\n" if (!-e $source_obj);
  die "Couldn't find input file: $target_obj\n" if (!-e $target_obj);

  # We make the control sphere.

  open INOBJ,$initial_sm;
  my @inobjarray = <INOBJ>;
  my $control_mapping_mesh_size = $inobjarray[2]*2-4;
  my $target_mapping_mesh_size = $inobjarray[3]*2-4;
  close(INOBJ);
  my $control_sphere = "${tmpdir}/control_sphere.obj";
  &do_cmd('create_tetra',$control_sphere,0,0,0,1,1,1,$control_mapping_mesh_size);
  my $target_sphere = "${tmpdir}/target_sphere.obj";
  &do_cmd('create_tetra',$target_sphere,0,0,0,1,1,1,$target_mapping_mesh_size);

  # We blur the source and target depth potential fields using diffusion smoothing

  my $source_field = "${tmpdir}/source_field_$conf[$i]{alpha}.txt";
  my $target_field = "${tmpdir}/target_field_$conf[$i]{alpha}.txt";

  &fast_field_blur( $control_mapping_mesh_size,
                    $source_obj, $alpha, $source_fwhm, $source_field );

  &fast_field_blur( $target_mapping_mesh_size,
                    $target_obj, $alpha, $target_fwhm, $target_field );

  # Compute an absolute ngh_radius based on the total area of
  # the unit control sphere. Assume isolateral triangles. Determine
  # the characteristic edge length. Multiply it by the scaling 
  # factor given by neighbourhood_radius. Project it on the plane
  # parallel to the tangent plane to the control point.
  # NOTE: Unused now with surfreg-0.6.4.

  my $PI = 3.1415926535897932384626;
  my $sphere_area = 4.0 * $PI;   # Radius = 1.0
  my $edge_len = sqrt( ( $sphere_area / $control_mapping_mesh_size ) * 
                       4.0 / sqrt( 3.0 ) );
  my $abs_ngh_radius = $neighbourhood_radius * $edge_len;
  if( $abs_ngh_radius < $PI/2.0 ) {
    $abs_ngh_radius = sin( $abs_ngh_radius );
  } else {
    $abs_ngh_radius = 0.99;
  }

  # register surfaces at this control mapping size
  my $doneflag = 0;
  my $iteration=0;
  my $firstsum = 10000000000000;
  my $sum = undef;
  my $fielddif =0;
  my $current_sm ="${tmpdir}/current_sm.sm";
  &do_cmd('cp',$initial_sm,$current_sm);

  my $initial_distance = &get_inter_field_distance($initial_sm,
                         $source_field,$target_field);

  print "Fit Diagnostics,iteration: ${iteration}, Field Dif:${initial_distance} \n";

  my @conv_hist = (1.0) x 3;

  while(!$doneflag) {
    $iteration=$iteration+1;

    my @cmd = ( 'surftracc', '-debug', '2', '-outer_iter_max', 1,
                '-smoothing_weight', $mesh_smooth, '-nc_method', 1,
                '-penalty_ratio', $penalty_ratio, '-abs_tolerance', 
                $abs_tolerance,
                '-neighbourhood_radius', $neighbourhood_radius,
                '-search_radius', $search_radius, $control_sphere, 
                $source_field, $target_sphere, $target_field,
                $control_sphere, $current_sm, $output_sm, '2>&1' );
    my $out_text = `@cmd`;

    $out_text =~ /TOTAL.*mean\s=(.*)\(.*\n/;   ## given by -debug 2
    my $movement = ${1};
    $out_text =~ /OPTIMIZE.*mean\s=(.*)\(.*\n/;   ## given by -debug 2
    my $fitting = ${1};
    $out_text =~ /SMOOTHING.*mean\s=(.*)\(.*\n/;   ## given by -debug 2
    my $smoothing = ${1};

    if( $iteration >= $max_iterations ) {
      $doneflag =1;
    }

    if( $convergence_control==0 ) {
      # static number of iterations
      print "Fit Diagnostics,Iteration: ${iteration}, Fitting:${fitting}, " .
            "Smoothing:${smoothing}, Movement:${movement}\n";
    } else {
      if ($convergence_control==1) {
        $fielddif = &get_inter_field_distance($output_sm,$source_field,
                                              $target_field);
        $sum = $fielddif;
      }
      if ($convergence_control==2) {
        $sum = $movement;
      }
  
      if( $iteration==1 ) {
        $firstsum = $sum;
      }

      $conv_hist[(${iteration}%3)] = $movement;
      my $avg_rel_err = ( $conv_hist[0] + $conv_hist[1] + $conv_hist[2] ) / 3.0;

      # Taking average over last 3 iterations will account for non 
      # monotonic convergence.
      if( $avg_rel_err < $convergence_threshold ) {
        #replace the new mapping with the old one... 
        $fielddif = &get_inter_field_distance($output_sm,$source_field,
                                              $target_field); 
        &do_cmd('cp',$current_sm,$output_sm);
        $doneflag=1;
      }

      print "Fit Diagnostics,Iteration: ", sprintf( "%3d, ", ${iteration} ),
            ($convergence_control==1) ? " Field Dif:${fielddif}, " : "",
            "Fitting:", sprintf( " %10.8f, ", ${fitting} ),
            "Smoothing:", sprintf( " %10.8f, ", ${smoothing} ), 
            "Movement:", sprintf( " %10.8f, ", ${movement} ), 
            "Error:", sprintf( "%10.8f, ", ${avg_rel_err} ),
            "Res:", sprintf( "%10.8f", ${sum}/${firstsum} ), "\n";
    }
    if (!$doneflag) {
      &do_cmd('cp',$output_sm,$current_sm);
    }
  }

  unlink( $control_sphere );

  if( $convergence_control != 1 ) {
    if( $convergence_control == 0 ) {
      $fielddif = &get_inter_field_distance($output_sm,$source_field,
                                            $target_field); 
    }
    print "Fit Diagnostics,iteration: ${iteration}, Field Dif:${fielddif} \n";
  }
  unlink( $source_field );
  unlink( $target_field );
  unlink( $current_sm );
}

# Check if the input surface has the same side orientation (left)
# as the default template model.

sub CheckFlipOrientation {

  my $obj = shift;

  my $npoly = `print_n_polygons $obj`;
  chomp( $npoly );

  my $ret = `tail -5 $obj`;
  my @verts = split( ' ', $ret );
  my @last3 = ( $verts[$#verts-2], $verts[$#verts-1], $verts[$#verts] );

  my $dummy_sphere = "${tmpdir}/dummy_sphere.obj";
  &do_cmd('create_tetra',$dummy_sphere,0,0,0,1,1,1,$npoly);
  $ret = `tail -5 $dummy_sphere`;
  unlink( $dummy_sphere );
  @verts = split( ' ', $ret );
  my @sphere3 = ( $verts[$#verts-2], $verts[$#verts-1], $verts[$#verts] );

  if( $last3[0] == $verts[$#verts-2] &&
      $last3[1] == $verts[$#verts-1] &&
      $last3[2] == $verts[$#verts-0] ) {
    return 0;
  } else {
    return 1;
  }
}

# Blurring at a large fwhm on a fine surface during the
# initial stages is SLOW, so refine the coarse control
# mesh by up to 2 levels and blur on it. Then reduce the
# blurred field to the dimensionality of the control mesh.

sub fast_field_blur {

  my $control_mapping_mesh_size = shift;
  my $obj = shift;
  my $alpha = shift;
  my $fwhm = shift;
  my $field = shift;

  my $npoly = max( 81920, $control_mapping_mesh_size );

  my $obj_rsl = "${tmpdir}/obj_rsl.obj";
  &do_cmd("subdivide_polygons", $obj, $obj_rsl, $npoly );

  &do_cmd( 'depth_potential', $obj_rsl, '-alpha', $alpha,
           '-depth_potential', $field );

  # remove outliers from the surface field (due to defects in the surface)

  my $ret = `vertstats_stats $field`;
  $ret =~ /Mean: (.*)/;
  my $mean = $1;
  $ret =~ /Stdev: (.*)/;
  my $stdev = $1;
  my $low_limit = $mean - 2.0 * $stdev;
  my $hi_limit = $mean + 2.0 * $stdev;

  &do_cmd( 'vertstats_math', '-old_style_file', '-seg', '-const', 1, 
           '-const2', $low_limit, $hi_limit, $field, 
           "${tmpdir}/fast_field_blur_mid.txt" );
  &do_cmd( 'vertstats_math', '-old_style_file', '-seg', '-const', $low_limit,
           '-const2', -99999999.0, $low_limit, $field, 
           "${tmpdir}/fast_field_blur_low.txt" );
  &do_cmd( 'vertstats_math', '-old_style_file', '-seg', '-const', $hi_limit,
           '-const2', $hi_limit, 99999999.0, $field, 
           "${tmpdir}/fast_field_blur_hi.txt" );
  &do_cmd( 'vertstats_math', '-old_style_file', '-mult', $field, 
           "${tmpdir}/fast_field_blur_mid.txt", $field );
  &do_cmd( 'vertstats_math', '-old_style_file', '-add', $field, 
           "${tmpdir}/fast_field_blur_low.txt", $field );
  &do_cmd( 'vertstats_math', '-old_style_file', '-add', $field, 
           "${tmpdir}/fast_field_blur_hi.txt", $field );
  unlink( "${tmpdir}/fast_field_blur_mid.txt" );
  unlink( "${tmpdir}/fast_field_blur_low.txt" );
  unlink( "${tmpdir}/fast_field_blur_hi.txt" );

  if( $fwhm > 0.0 ) {
    &do_cmd("depth_potential", "-smooth", $fwhm, $field,
            $obj_rsl, $field );
  }
  unlink( $obj_rsl );

  # Reduce blurred field to control_mapping_mesh_size.
  if( $control_mapping_mesh_size < $npoly ) {
    my $nverts = $control_mapping_mesh_size/2 + 2;
    `head -$nverts $field > ${tmpdir}/fast_field_blur_tmp.txt`;
    `mv ${tmpdir}/fast_field_blur_tmp.txt $field`;
  }

}


sub get_inter_field_distance {

  my ($sm,$source_field_blur,$target_field_blur) =  @_;

  my $temp_remap = "${tmpdir}/tmp_remap.txt";

  &surf_resample( $sm, $target_field_blur, $temp_remap );

  #okay so measure distance  
  open SOURCEFIELD,$source_field_blur; 
  open TARGETFIELD,$temp_remap;
  my $sum=0;
  while(1) {
    my $sourceval = <SOURCEFIELD>;
    if (!$sourceval){
      last;
    }
    while (($sourceval eq "")||($sourceval eq "\n")) {
      $sourceval = <SOURCEFIELD> ;
    }
    my $targetval = <TARGETFIELD>;
    if (!$targetval){
      die("One of the source or target field files is corrupted");
    }
    while (($targetval eq "")||($targetval eq "\n")) {
      $targetval = <TARGETFIELD> ;
    }
    $sum=$sum + abs($targetval-$sourceval);                    
  }
  my $targetval = <TARGETFIELD>;
  if ($targetval) {
    # target_field is longer than source_field for some reason.
    ### die("One of the source or target field files is corrupted");
  }
  close(SOURCEFIELD);
  close(TARGETFIELD); 
  unlink( $temp_remap );
  return $sum;    
}

sub surf_resample {

  my $source_to_target_mapping = shift;
  my $target_field = shift;
  my $output_source_field = shift;

  my $clobber = 1;

  # check for files
  die "Couldn't find input file: $source_to_target_mapping\n" 
      if (!-e $source_to_target_mapping);
  die "Couldn't find input file: $target_field\n" if (!-e $target_field);

  if( -e $output_source_field && !$clobber ) {
    die "$me: $output_source_field exists, -clobber to overwrite\n";
  }

  open INOBJ,$target_field;
  my @inobjarray = <INOBJ>;
  my $target_field_size = ($#inobjarray+1)*2-4;
  if( $inobjarray[0] eq "\n" ||$inobjarray[0]  eq " \n" ) {
    $target_field_size = $target_field_size-2;
  }
  close(INOBJ);

  open INOBJ,$source_to_target_mapping;
  @inobjarray = <INOBJ>;
  my $control_mapping_mesh = $inobjarray[2]*2-4;
  my $target_mapping_mesh = $inobjarray[3]*2-4;
  close(INOBJ);

  my $target_mesh_size = $target_mapping_mesh;
  my $control_mesh_size = $control_mapping_mesh;

  my $control_mesh = "${tmpdir}/rsl_control_mesh.obj";
  my $target_mesh = "${tmpdir}/rsl_target_mesh.obj";
  my $old_mapping = "${tmpdir}/rsl_old_mapping.sm";;
  my $refined_mapping = "${tmpdir}/rsl_refined_mapping.sm";
 
  &do_cmd('cp', $source_to_target_mapping, $refined_mapping);
  #Then we make the control mesh and the sphere mesh
  &do_cmd('create_tetra',$control_mesh,0,0,0,1,1,1,$control_mesh_size);
  # and the sphere mesh
  &do_cmd('create_tetra',$target_mesh,0,0,0,1,1,1,$target_mesh_size);

  while ($control_mesh_size!=$target_mesh_size){
    $control_mesh_size = $control_mesh_size*4;
    if( $control_mesh_size>$target_mesh_size ) { 
      die "control mesh is not a subsampling of target mesh\n";
    }
    &do_cmd('cp', $refined_mapping, $old_mapping); 
    &do_cmd('create_tetra',$control_mesh,0,0,0,1,1,1,$control_mesh_size);
    &do_cmd('refine-surface-map',$old_mapping, $control_mesh, $target_mesh,
            $refined_mapping);
  }

  #now we can do the resample 
  &do_cmd( 'surface-resample', $target_mesh, $target_mesh, $target_field,
           $refined_mapping, $output_source_field );

  #clean-up
  unlink( $control_mesh );
  unlink( $old_mapping );
  unlink( $target_mesh );
  unlink( $refined_mapping );

}

sub do_cmd { 

   print STDOUT "@_\n" if ${verbose};
   system(@_) == 0 or die;
}

