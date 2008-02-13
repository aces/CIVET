#!/usr/bin/env perl

# Surface registration using surftracc and Maxime's data term.

#olly has a go....

use strict;
use FindBin;
use lib "$FindBin::Bin";

# Full path to surface-register-smartest in this current directory
my $surf_reg_smart = "$FindBin::Bin/surface-register-smartest";
my $surf_resample = "$FindBin::Bin/surface-resample2";

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

print "${me} @{ARGV}\n";

my $verbose   = 0;
my $clobber   = 0;
my $control_mesh_min =20;
my $control_mesh_max =10000000;
my $mesh_smooth =1;
my $blur_coef =1.25;
my $neighbourhood_radius =2.3;
my $target_spacing = undef;
my $max_blur = undef;
my $keep_blur = 0;  

my @conf = (
   { control_size     => 20,
     target_size      => 81920,
     blur_factor      => 64.0,
     search_radius    => 1.5,
     penalty_ratio    => 0.05,
     max_ngh_rad      => 1.1,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 80,
     target_size      => 81920,
     blur_factor      => 32.0,
     search_radius    => 0.75,
     penalty_ratio    => 0.05,
     max_ngh_rad      => 1.9,
     conv_control     => 0,
     conv_thresh      => 50},

   { control_size     => 320,
     target_size      => 81920,
     blur_factor      => 20.0,
     search_radius    => 0.375,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 1280,
     target_size      => 81920,
     blur_factor      => 8.0,
     search_radius    => 0.325,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 0,
     conv_thresh      => 50 },

   { control_size     => 5120,
     target_size      => 81920,
     blur_factor      => 4.0,
     search_radius    => 0.25,
     penalty_ratio    => 0.05,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 20480,
     target_size      => 81920,
     blur_factor      => 2.0,
     search_radius    => 0.225,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 },

   { control_size     => 81920,
     target_size      => 81920,
     blur_factor      => 1.0,
     search_radius    => 0.20,
     penalty_ratio    => 0.10,
     max_ngh_rad      => undef,
     conv_control     => 2,
     conv_thresh      => 0.01 }
);


$Help = <<HELP;
|    $me fully configurable hierachical surface fitting...
| 
| Problems or comments should be sent to: oliver\@bic.mni.mcgill.ca
|                                     or: claude\@bic.mni.mcgill.ca
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
                      surface-stats
                      mv
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

$source_spacing =$target_spacing;

my $source_blur = undef;
my $target_blur = undef;
my $temp_nr = undef;

my $i;
for ($i=0; $i<=$#conf; $i++) {

  # Fancy printout of options.

  print STDOUT "\n-+-------------------------[$i]-------------------------\n".
                 " | control mesh size:              $conf[$i]{control_size}\n".
                 " | target mesh size:               $conf[$i]{target_size}\n";

  if ($control_mesh_min<=$conf[$i]{control_size} && $control_mesh_max>=$conf[$i]{control_size}){
    $source_blur = int($conf[$i]{blur_factor}*$blur_coef*$source_spacing+0.5);
    $target_blur = int($conf[$i]{blur_factor}*$blur_coef*$target_spacing+0.5);
    if ($max_blur){
      if ($source_blur>$max_blur){$source_blur = $max_blur};
      if ($target_blur>$max_blur){$target_blur = $max_blur};
    }
    $temp_nr = $neighbourhood_radius;
    if( defined $conf[$i]{max_ngh_rad} ) {
      if( $neighbourhood_radius > $conf[$i]{max_ngh_rad} ) {
        $temp_nr = $conf[$i]{max_ngh_rad};
      }
    }
    print STDOUT " | blur factor:                    $conf[$i]{blur_factor}\n".
                 " | search radius:                  $conf[$i]{search_radius}\n".
                 " | penalty ratio:                  $conf[$i]{penalty_ratio}\n".
                 " | source blur:                    $source_blur mm\n".
                 " | target blur:                    $target_blur mm\n".
                 " | max neighbourhood radius:       $temp_nr\n".
                 " | convergence params:             $conf[$i]{conv_control}:$conf[$i]{conv_thresh}\n".
                 "-+-----------------------------------------------------\n".
                  "\n";
  } else {
    print STDOUT "-+-----------------------------------------------------\n".
                "\n";
  }

  &do_cmd( "create_tetra",$control_mesh,0,0,0,1,1,1,$conf[$i]{control_size});
  &do_cmd( "create_tetra",$target_mesh,0,0,0,1,1,1,$conf[$i]{target_size});
  if( $i == 0 ) {
    &do_cmd("initial-surface-map", $control_mesh, $target_mesh, $surface_mapping);
  } else {
    &do_cmd("refine-surface-map", $surface_mapping, $control_mesh, $target_mesh, $old_surface_mapping);
    &do_cmd("cp", $old_surface_mapping, $surface_mapping);
  }

  if ($control_mesh_min<=$conf[$i]{control_size} && $control_mesh_max>=$conf[$i]{control_size}){
    &do_cmd("mv", $surface_mapping, $old_surface_mapping);
    &do_cmd($surf_reg_smart, "-verbose", "-clobber", $keep_blur_cmd, "-source_blur",
            $source_blur,"-target_blur" ,$target_blur ,
            "-mesh_smooth", $mesh_smooth,
            "-penalty_ratio", $conf[$i]{penalty_ratio},
            "-neighbourhood_radius", $temp_nr,
            "-search_radius", $conf[$i]{search_radius},
            "-convergence_control", $conf[$i]{conv_control},
            "-convergence_threshold", $conf[$i]{conv_thresh},
            $old_surface_mapping, $source_obj, $source_field ,
            $target_obj, $target_field, $surface_mapping);
  }
}

&do_cmd("cp", $surface_mapping, $map_final);


sub do_cmd { 
   print STDOUT "@_\n" if ${verbose};
   system(@_) == 0 or die;
}

