#!/usr/bin/env perl

# Surface registration using surftracc and Maxime's data term.

#olly has a go....

use strict;
use FindBin;
use lib "$FindBin::Bin";

# Full path to surface-register-smartest in this current directory
my $surf_reg_smart = "$FindBin::Bin/surface-register-smartest";

use MNI::Startup;
use Getopt::Tabular;
use MNI::Spawn;
use MNI::DataDir;
use MNI::FileUtilities qw(test_file check_output_dirs);
use File::Temp qw/ tempdir /;
 use File::Basename;
 my($Help, $Usage, $me);
 my(@opt_table, %opt, $source, $target, $outxfm, @args, $tmpdir);
  $me = &basename($0);
 # make tmpdir
my $tmpdir = &tempdir( "$me-XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );

 print "MyCmd ${me} @{ARGV}\n";

my $verbose   = 0;
my $clobber   = 0;
my $control_mesh_min =20;
my $control_mesh_max =10000000;
my $mesh_smooth =1;
my $blur_coef =1.5;
my $neighbourhood_radius =2.3;
my $search_radius =0.5;
my $convergence_control=0;
my $convergence_threshold=20;
my $target_spacing = undef;
my $max_blur = undef;
my $keep_blur = 0;  

$Help = <<HELP;
|    $me fully configurable hierachical surface fitting...
| 
| Problems or comments should be sent to: oliver\@bic.mni.mcgill.ca
HELP

$Usage = "Usage: $me [options]  source.obj source.txt target.obj target.txt output.sm\n".
         "       $me -help to list options\n\n";

@opt_table = (
   ["-verbose", "const", "1", \$verbose,
      "be verbose" ],
   ["-clobber", "const", "1", \$clobber,
      "clobber existing files" ],
   ["-mesh_smooth", "string", 1, \$mesh_smooth,
      "neighbour weight in smoothing step (default 1)" ],      
   ["-neighbourhood_radius", "string",1,\$neighbourhood_radius, 
      "neighbourhood radius (default 2.3)" ],
   ["-search_radius", "string",1,\$search_radius, 
      "search radius (default 0.5)" ],
   ["-min_control_mesh", "string",1,\$control_mesh_min,
       "control mesh must no less than X nodes..." ],
   ["-max_control_mesh", "string",1,\$control_mesh_max,
       "control mesh must no greater than X nodes..." ],
  ["-convergence_control", "string",1,\$convergence_control, 
      "0 static, 1 inter-field distance, 2 node movement" ],
   ["-convergence_threshold", "string",1,\$convergence_threshold, 
      "for static control = num iterations, for non-static convergence control % change (0.01 =1%)" ], 
   ["-blur_coef", "string",1,\$blur_coef,
       "factor to increase/decrease blurring (default 1.5)" ],     
   ["-keep_blur", "const","1",\$keep_blur, 
   "keep blurred files" ], 
    ["-target_spacing", "string","1",\$target_spacing, 
   "specify target spacing" ],  
   ["-maximum_blur", "string","1",\$max_blur, 
   "specify target spacing" ],  
       
   );    

# Check arguments
&Getopt::Tabular::SetHelp($Help, $Usage);
&GetOptions (\@opt_table, \@ARGV) || exit 1;
 die "usage: $0 source_obj source_txt target_obj target_txt smap_out" unless @ARGV==5;
 my( $source_obj,$source_field, $target_obj, $target_field, $map_final ) = @ARGV;


 # The programs used.  
# Must load quarantine in path first.
#
RegisterPrograms( [qw(create_tetra
		      initial-surface-map
		      surftracc
		      refine-surface-map
		      cp)] );

my $old_surface_mapping = "${tmpdir}/old_map.sm";
my $surface_mapping = "${tmpdir}/map.sm";
my $control_mesh = "${tmpdir}/control_mesh.obj";
my $target_mesh = "${tmpdir}/target_mesh.obj";
my $keep_blur_cmd = "-keep_blur";
if (!$keep_blur) {$keep_blur_cmd="-no_keep_blur";} 
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

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,20);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd("initial-surface-map", $control_mesh,$target_mesh, $surface_mapping);


$source_spacing =$target_spacing;

my $source_blur=undef;
my $target_blur =undef;

if ($control_mesh_min<=20 && $control_mesh_max>=20){
  $source_blur = int(64.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(64.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  if ($neighbourhood_radius>1.1){
    print("Fixing neighbour radius down to 1.1 to avoid a crash! ${max_blur}::${source_spacing}::${blur_coef}\n");
    $temp_nr =1.1;
  }
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur",
          $source_blur,"-target_blur" ,$target_blur  ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold, $old_surface_mapping, $source_obj, $source_field, 
          $target_obj, $target_field, $surface_mapping );
}

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,80);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd("refine-surface-map",$surface_mapping, $control_mesh,$target_mesh, $old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping);

if ($control_mesh_min<=80 && $control_mesh_max>=80){
  $source_blur = int(32.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(32.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  if ($neighbourhood_radius>1.9){
    print("Fixing neighbour radius down to 1.9 to avoid a crash!\n");
    $temp_nr =1.9;
  }
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd, "-source_blur",
          $source_blur,"-target_blur" ,$target_blur ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
}

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,320);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd( "refine-surface-map", $surface_mapping,$control_mesh,$target_mesh,$old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping);


if ($control_mesh_min<=320 &&$control_mesh_max>=320){
  $source_blur = int(16.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(16.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur" ,
          $source_blur,"-target_blur" ,$target_blur ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
}

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,1280);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd( "refine-surface-map", $surface_mapping,$control_mesh,$target_mesh,$old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping); 

if ($control_mesh_min<=1280 && $control_mesh_max>=1280){
  $source_blur = int(8.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(8.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur" ,
          $source_blur,"-target_blur" ,$target_blur  ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
}

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,5120);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd( "refine-surface-map", $surface_mapping,$control_mesh,$target_mesh,$old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping);

if ($control_mesh_min<=5120 && $control_mesh_max>=5120){
  $source_blur = int(4.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(4.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur" ,
          $source_blur,"-target_blur" ,$target_blur  ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
}
 
&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,20480);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd( "refine-surface-map", $surface_mapping,$control_mesh,$target_mesh,$old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping);

if ($control_mesh_min<=20480 &&$control_mesh_max>=20480){
  $source_blur = int(2.0*$blur_coef*$source_spacing*+0.5);
  $target_blur = int(2.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur" ,
          $source_blur,"-target_blur" ,$target_blur  ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
} 

&do_cmd("create_tetra",$control_mesh,0,0,0,1,1,1,81920);
&do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,81920);
&do_cmd( "refine-surface-map", $surface_mapping,$control_mesh,$target_mesh,$old_surface_mapping);
&do_cmd("cp",$old_surface_mapping,$surface_mapping); 
 
if ($control_mesh_min<=81920&&$control_mesh_max>=81920){
  $source_blur = int(1.0*$blur_coef*$source_spacing+0.5);
  $target_blur = int(1.0*$blur_coef*$target_spacing+0.5);
  if ($max_blur){
    if ($source_blur>$max_blur){$source_blur = $max_blur};
    if ($target_blur>$max_blur){$target_blur = $max_blur};
  }
  &do_cmd("mv",$surface_mapping,$old_surface_mapping);
  my $temp_nr =   $neighbourhood_radius;
  &do_cmd($surf_reg_smart, "-verbose" ,"-clobber",$keep_blur_cmd,"-source_blur" ,
          $source_blur,"-target_blur" ,$target_blur ,"-mesh_smooth" ,$mesh_smooth,
          "-neighbourhood_radius",$temp_nr,"-search_radius",$search_radius,
          "-convergence_control",$convergence_control,"-convergence_threshold",
          $convergence_threshold ,$old_surface_mapping, $source_obj ,$source_field ,
          $target_obj,$target_field,$surface_mapping);
}
 
&do_cmd("cp", $surface_mapping,$map_final);


sub do_cmd { 
   print STDOUT "@_\n";
   system(@_) == 0 or die;
}


sub measure_final_fit {

  ($source_field,$target_field, $surface_mapping) = @_;
  my $remapped_target =  "${tmpdir}/remapped_target.txt";          
  &do_cmd('surface-resample2', '-clobber',$surface_mapping,$target_field,$remapped_target);       
  #okay so measure distance  
  open SOURCEFIELD,$source_field; 
  open TARGETFIELD,$remapped_target;                
  my $sum=0;
  while(1){               
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
    #print "$sourceval\t $targetval\n";
    $sum=$sum + abs($targetval-$sourceval);    
    
  }
  my $targetval = <TARGETFIELD>;
  if ($targetval){
    die("One of the source or target field files is corrupted");
  }
  print "***************Final Convergence is ${sum} **************************\n";

}
