#!/usr/bin/env perl

#
# Hybrid geometric and data-driven surface registration using surftracc
# and Maxime's depth potential as the data term.
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
use MNI::FileUtilities qw(test_file check_output_dirs);
use File::Temp qw/ tempdir /;
use File::Basename;
my($Help, $Usage, $me);
my(@opt_table, $source, $target, $outxfm, $tmpdir);
$me = &basename($0);

# make tmpdir
my $tmpdir = &tempdir( "$me-XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );

my $verbose   = 0;
my $clobber   = 0;
my $control_mesh_min = 320;
my $control_mesh_max = 81920;
my $mesh_smooth = 1;
my $blur_coef = 1.25;
my $neighbourhood_radius = 1.8;
my $target_spacing = 1.9;
my $max_fwhm = undef;

my @conf = (
   { control_size     => 20,     # This step should never be used.
     target_size      => 5120,
     geom_factor      => 150,
     blur_factor      => 64.0,
     alpha            => 0.05,
     search_radius    => 1.5,
     penalty_ratio    => 0.05,
     max_ngh_rad      => 1.1,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 80,     # This step not very reliable. Kind of unstable.
     target_size      => 5120,
     geom_factor      => 200,
     blur_factor      => 24.0,
     alpha            => 0.001,
     search_radius    => 0.25,
     penalty_ratio    => 0.05,
     max_ngh_rad      => 2.3,
     conv_control     => 0,
     conv_thresh      => 20},

   { control_size     => 320,
     target_size      => 5120,
     geom_factor      => 150,
     blur_factor      => 16.0,
     alpha            => 0.00625,
     search_radius    => 0.375,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 1280,
     target_size      => 20480,
     geom_factor      => 150,
     blur_factor      => 8.0,
     alpha            => 0.0125,
     search_radius    => 0.325,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 5120,
     target_size      => 20480,
     geom_factor      => 120,
     blur_factor      => 4.0,
     alpha            => 0.025,
     search_radius    => 0.25,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 20480,
     target_size      => 20480,
     geom_factor      => 100,
     blur_factor      => 2.0,
     alpha            => 0.05,
     search_radius    => 0.225,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 81920,
     target_size      => 81920,
     geom_factor      => 40,
     blur_factor      => 1.0,
     alpha            => 0.10,
     search_radius    => 0.20,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 81920,
     target_size      => 81920,
     geom_factor      => 0,
     blur_factor      => 1.0,
     alpha            => 0.10,
     search_radius    => 0.20,    ### 0.15,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 327680,
     target_size      => 327680,
     geom_factor      => 0,
     blur_factor      => 1.0,
     alpha            => 0.10,
     search_radius    => 0.15,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 0,
     conv_thresh      => 5 }
);

$Help = <<HELP;
| $me Hybrid geometric and data-driven hierachical surface registration...
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
   ["-target_spacing", "string","1",\$target_spacing, 
     "specify target spacing" ],  
   ["-maximum_blur", "string","1",\$max_fwhm, 
    "specify target spacing" ],  
       
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
                      adapt_object_mesh
                      depth_potential
                      mv
                      cp)] );

my $old_surface_mapping = "${tmpdir}/old_map.sm";
my $surface_mapping = "${tmpdir}/map.sm";

# do the registration
 
if (!$target_spacing){
  $target_spacing = `surface-stats -edge_length ${target_obj} | awk '{sum=sum+\$1; count=count+1} END{print sum/count}'`;
}

my $source_spacing =  `surface-stats -edge_length ${source_obj} | awk '{sum=sum+\$1; count=count+1} END{print sum/count}' `;


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

print "source_area $source_area\n";
print "target_area $target_area\n";

$source_spacing = $target_spacing; ### * sqrt( $source_area / $target_area );

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

  # Fancy printout of options.

  print STDOUT "\n-+-------------------------[$i]-------------------------\n".
                 " | control mesh size:              $conf[$i]{control_size}\n".
                 " | target mesh size:               $conf[$i]{target_size}\n";

  if( $control_mesh_min<=$conf[$i]{control_size} && 
      $control_mesh_max>=$conf[$i]{control_size} ) {
    $source_fwhm = int($conf[$i]{blur_factor}*$blur_coef*$source_spacing+0.5);
    $target_fwhm = int($conf[$i]{blur_factor}*$blur_coef*$target_spacing+0.5);
    if ($max_fwhm){
      if ($source_fwhm>$max_fwhm){$source_fwhm = $max_fwhm};
      if ($target_fwhm>$max_fwhm){$target_fwhm = $max_fwhm};
    }
    $temp_nr = $neighbourhood_radius;
    if( defined $conf[$i]{max_ngh_rad} ) {
      if( $neighbourhood_radius > $conf[$i]{max_ngh_rad} ) {
        $temp_nr = $conf[$i]{max_ngh_rad};
      }
    }
    print STDOUT " | geometric blur factor:          $conf[$i]{geom_factor}\n".
                 " | dataterm blur factor:           $conf[$i]{blur_factor}\n".
                 " | depth potential alpha:          $conf[$i]{alpha}\n".
                 " | search radius:                  $conf[$i]{search_radius}\n".
                 " | penalty ratio:                  $conf[$i]{penalty_ratio}\n".
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

    my $source_obj_blur = "${tmpdir}/source_obj_blur.obj";
    my $target_obj_blur = "${tmpdir}/target_obj_blur.obj";
    my $source_field_blur = "${tmpdir}/source_field_blur.txt";
    my $target_field_blur = "${tmpdir}/target_field_blur.txt";

    &do_cmd( 'adapt_object_mesh', $source_obj, $source_obj_blur, 99999999, 
             $conf[$i]{geom_factor} );
    &do_cmd( 'adapt_object_mesh', $target_obj, $target_obj_blur, 99999999, 
             $conf[$i]{geom_factor} );

    &surface_register_smartest( "-alpha", $conf[$i]{alpha},
            "-source_fwhm", $source_fwhm, "-target_fwhm", $target_fwhm,
            "-mesh_smooth", $mesh_smooth,
            "-penalty_ratio", $conf[$i]{penalty_ratio},
            "-neighbourhood_radius", $temp_nr,
            "-search_radius", $conf[$i]{search_radius},
            "-convergence_control", $conf[$i]{conv_control},
            "-convergence_threshold", $conf[$i]{conv_thresh},
            $old_surface_mapping, $source_obj_blur, $target_obj_blur, 
            $surface_mapping );

    unlink( $source_obj_blur );
    unlink( $target_obj_blur );
  }
}

&do_cmd("cp", $surface_mapping, $map_final);

#  the end of main script

#
# Configurable surface register: perform one stage
#

sub surface_register_smartest {

  my $mesh_smooth = 1;
  my $penalty_ratio = 0.05;
  my $source_fwhm = 0;
  my $target_fwhm = 0;
  my $neighbourhood_radius = 2.7;
  my $search_radius = 0.5;
  my $alpha = 0.05;
  my $convergence_control = 0;
  my $convergence_threshold = 20;

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

  # register surfaces at this control mapping size
  my $doneflag = 0;
  my $iteration=0;
  my $oldsum = 10000000000000;
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
                '-smoothing_weight', $mesh_smooth,
                '-penalty_ratio', $penalty_ratio,
                '-neighbourhood_radius', $neighbourhood_radius,
                '-search_radius', $search_radius, $control_sphere, 
                $source_field, $target_sphere, $target_field,
                $control_sphere, $current_sm, $output_sm, '2>&1' );
    my $out_text = `@cmd`;

    $out_text =~ /TOTAL.*mean\s=(.*)\(.*\n/;   ## given by -debug 2
    my $movement = ${1};
    my $rel_error = 0;
    my $rel_error2 = 0;

    if( $convergence_control==0 ) {
      # static number of iterations
      if($iteration>=$convergence_threshold) {
        $doneflag =1;
      }
      print "Fit Diagnostics,Iteration: ${iteration}, Movement:${movement}\n";
    } else {
      if ($convergence_control==1) {
        $fielddif = &get_inter_field_distance($output_sm,$source_field,
                                              $target_field);
        $sum =$fielddif;
      }
      if ($convergence_control==2) {
        $sum=$movement;
      }
  
      if( $iteration==1 ) {
        $firstsum = $sum;
      }

      $rel_error = ($oldsum-$sum)/$oldsum;
      $oldsum=$sum;
      $conv_hist[(${iteration}%3)] = $rel_error;
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
            "Movement:", sprintf( " %10.8f, ", ${movement} ), 
            "Error:", sprintf( "%10.8f, ", ${rel_error} ),
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

# if( $target_mapping_mesh != $target_field_size ) {
#   die "target mapping mesh ($target_mapping_mesh) and target field ($target_field_size) have different sizes";
# }

  my $target_mesh_size = $target_mapping_mesh;
  my $control_mesh_size = $control_mapping_mesh;

  # my $target_mesh_size = $control_mesh_size;

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

