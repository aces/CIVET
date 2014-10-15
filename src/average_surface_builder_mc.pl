#! /usr/bin/env perl
#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
##############################
#### Average Surface Builder ####
##############################

# PIPELINE 1 (iteration 0 only): Create average norsl surface
# for each hemi {
#       1A: script: average_surfaces (norsl)
#           output: avg0_${hemi}.obj
# } end hemi loop
#       1B: Collapse hemis (symmetrical only):
#           scripts: transform_objects, average surfaces
#           output: avg0_sym.obj
#        1C: Flip left sym avg to right sym avg (symmetrical only):
#           scripts: transform_objects
#           output: avg0_sym_right.obj
# PIPELINE 2 (iterations 0 thru $iterations_n-1):
# for n = 0 through $iterations_n {
#   for each subj {
#       for each hemi {
#       2A: Surface Registration
#           script: bestsurfreg.pl 
#           output: ${subj}_output${n}_${hemi}.sm
#       2B: Surface Resampling
#           script: sphere_resample_obj 
#           output: ${subj}_mid_surface_rsl${n}_${hemi}_$numvertices.obj
#        2C: Diff_surfaces (individual surfs)
#             script: diff_surfaces
#           output: diff_surfs_${prefix}_${subj}_${hemi}_it$n.txt
#       } end hemi loop
#   } end subj loop
# PIPELINE 3 (iterations 0 thru $iterations_n-1): 
#        3A: Create average rsl surface
#           script: average_surfaces (rsl)
#           output: avg${n+1}_${hemi}.obj
#        3B: Collapse hemis (symmetrical only):
#           scripts: transform_objects, average surfaces
#           output: avg${n+1}_sym.obj
#        3C: Flip left sym avg to right sym avg (symmetrical only):
#           scripts: transform_objects
#           output: avg${n+1}_sym_right.obj
# PIPELINE 4 (iterations 0 thru $iterations_n-1): Diff surfaces (average surfs) 
#   for each hemi {
#           script: diff_surfaces
#           output: diff_surfs_${prefix}_${hemi}_avg${n}_vs_avg{$n+1}.txt
#   } end hemi loop
#   ITERATE PIPELINES (2) - (6)
# } end iteration loop

package Average_Surface_Builder;
use strict;
use FindBin;
use Cwd qw( abs_path );
use Env qw( PATH );
use Getopt::Tabular;
use PMP::PMP;
use PMP::spawn;
use PMP::pbs;
use PMP::sge;
use PMP::Array;
use MNI::Startup;
use MNI::PathUtilities qw(split_path);
use MNI::FileUtilities qw(check_output_dirs check_output_path);
use MNI::DataDir;

############# Some directories that the user will need to specify
my $dir = undef;
my $study = undef;
my $prefix = undef;
my $subjectlistfile = undef;
my $outdir;
my $iterations_n = undef;
my $sym = 1;                  # 1 is "sym", 0 is "asym"
my $geom = 1;                 # 1 is geomsurfreg, 0 is bestsurfreg
my @hemi = ("left","right");
my $numvertices = 81920;
my $surfType = "mid";
my $marchingCubes = 0;
my $left_mask = undef;
my $right_mask = undef;
my $usage = "\nUSAGE:\n$ProgramName -dir <dir> -study <study> -prefix <prefix> -id-file <subjectlistfile> -outdir <outdir> -it <num> -sym|-no-sym -numvertices <num> -mid|-white|-gray";

############# Options table
my @leftOverArgs;
my @argTbl = (

["Options", "section"],
["-dir", "string", 1,  \$dir,
           "Directory path?", "<dir path>"],
["-study", "string", 1,  \$study,
           "Study name?", "<study name>"],
["-prefix", "string", 1,  \$prefix,
           "Prefix?", "<prefix>"],
["-id-file", "string", 1,  \$subjectlistfile,
           "Subject list file?", "<subjectlistfile>"],
["-outdir", "string", 1,  \$outdir,
           "Output directory?", "<outdir>"],
["-it", "string", 1,  \$iterations_n,
           "Number of iterations?", "<num>"],
["-sym|-no-sym", "boolean", 1, \$sym, "Symmetrical or asymmetrical?" ],
["-geom|-no-geom", "boolean", 1, \$geom, "geom_surfreg or bestsurfreg?" ],
["-numvertices", "string", 1,  \$numvertices,
           "Number of vertices (e.g., 81920).", "<num>"],
["-marching-cubes|-no-marching-cubes", "boolean", 1, \$marchingCubes, 
           "Indicate that the white surface is for marching-cubes [default ASP]"],
["-left-mask", "string", 1,  \$left_mask,
           "Left surface mask for marching-cubes", "<left_mask>"],
["-right-mask", "string", 1,  \$right_mask,
           "Right surface mask for marching-cubes", "<right_mask>"],
["-white", "const", "white",  \$surfType, "white surface average [default mid]"],
["-mid", "const", "mid",  \$surfType, "mid surface average"],
["-gray", "const", "gray",  \$surfType, "gray surface average [default mid]"],
          );

GetOptions(\@argTbl, \@ARGV, \@leftOverArgs) or die "\n";

#SETUP PIPELINES

my %PMPconf = ( 'DEFAULT' => { 'type' => "spawn",
                               'maxqueued' => 10000,
                               'granularity' => 1,
                               'queue' => undef,
                               'hosts' => undef,
                               'opts' => undef },
                'MNIBIC'  => { 'type' => "sge",
                               'maxqueued' => 1000,
                               'granularity' => 1,
                               'queue' => "all.q",
                               'hosts' => undef,
                               'opts' => undef },
                'CLUMEQ'  => { 'type' => "pbs",
                               'maxqueued' => 100,
                               'granularity' => 1,
                               'queue' => "brain",
                               'hosts' => undef,
                               'opts' => "-l ncpus=1" },
                'COLOSSE'  => { 'type' => "pbs",
                               'maxqueued' => 1000,
                               'granularity' => 1,
                               'queue' => "default",
                               'hosts' => undef,
                               'opts' => "-P eim-670-aa -l h_rt=6:00:00" },
                'RQCHP'   => { 'type' => "pbs",
                               'maxqueued' => 800,
                               'granularity' => 1,
                               'queue' => "qwork\@ms",
                               'hosts' => undef,
                               'opts' => "-l walltime=7:00:00" },
                'NIH'     => { 'type' => "pbs",
                               'maxqueued' => 1000,
                               'granularity' => 1,
                               'queue' => "norm",
                               'hosts' => undef,
                               'opts' => "-l nodes=1:p2800" } );

my $PMPtype = ( $ENV{'CIVET_JOB_SCHEDULER'} || "DEFAULT" );
my $PMPmaxQueued = $PMPconf{$PMPtype}{maxqueued};
my $PMPgranularity = $PMPconf{$PMPtype}{granularity};
my $PMPqueue = $PMPconf{$PMPtype}{queue};
my $PMPhosts = $PMPconf{$PMPtype}{hosts};
my $PMPopts = $PMPconf{$PMPtype}{opts};

############# Override default PMP options based on command line options
$PMPconf{$PMPtype}{maxqueued} = $PMPmaxQueued;
$PMPconf{$PMPtype}{granularity} = $PMPgranularity;
$PMPconf{$PMPtype}{queue} = $PMPqueue;
$PMPconf{$PMPtype}{hosts} = $PMPhosts;
$PMPconf{$PMPtype}{opts} = $PMPopts;

# BUILD SUBJECT ID LIST

open (MYFILE, $subjectlistfile);
my @subjectlist = <MYFILE>;
close (MYFILE);
chomp (@subjectlist);

# @subjectlist = @subjectlist[0..1];

# CREATE LOG AND TMP DIRECTORIES

$dir =~ s#/+$##;      # remove trailing / at end of directory name, if any
$dir = abs_path( $dir );
$outdir =~ s#/+$##;      # remove trailing / at end of directory name, if any
$outdir = abs_path( $outdir );
`mkdir -p $outdir`;

my $tmpdir = "${outdir}/tmp";
`mkdir -p $tmpdir`;

# Specific mask for calibration of white surface. This mask must be supplied
# from the outside after a few iterations to establish a starting white surface.
# We need to paint the mask as we iterate.

my %surfreg_model_mask;
if( defined( $left_mask ) && -e $left_mask ) {
  $surfreg_model_mask{left} = $left_mask;
} else {
  $surfreg_model_mask{left} = "none";
}
if( defined( $right_mask && -e $right_mask ) ) {
  $surfreg_model_mask{right} = $right_mask;
} else {
  $surfreg_model_mask{right} = "none";
}

# Create flip_right.xfm on the fly for the symmetric case.
my $flip_right = "${tmpdir}/flip_right.xfm";
if( $sym ) {
  `param2xfm -scales -1 1 1 $flip_right`;
}

####### CREATE PIPELINE 2 ##########

my %surfreg_model;

for(my $n = 0; $n < $iterations_n; $n++){

  my $nminus1 = sprintf( "%02d", $n-1 );
  $surfreg_model{left} = ($n == 0) ? "none" : "$outdir/$nminus1/avg_left.obj";
  $surfreg_model{right} = ($n == 0) ? "none" : "$outdir/$nminus1/avg_right.obj";

  $n = sprintf( "%02d", $n );
  my $nplus1 = sprintf( "%02d", $n+1 );
  print "Iteration: $n\n";

  my $logdir = "$outdir/$n/logs";
  `mkdir -p $logdir`;

  next if( ( -e "$outdir/$n/avg_left.obj" ) && -e ( "$outdir/$n/avg_right.obj" ) );

  my $pipes = PMP::Array->new();
  foreach my $subj (@subjectlist){
    print "Processing subject $subj...\n";
    `mkdir -p "$outdir/${n}/${subj}"`;
    foreach my $hemi (@hemi) {
      my $pipeline = init_pipeline( "ASB2-$subj-it$n-$hemi", $logdir, 0 );
      my $surf = undef;
      my $prereqs = [];
      if( $surfType eq "white" && $marchingCubes ) {
        $surf = "${outdir}/${n}/${subj}/${surfType}_${hemi}.obj";
        if( ! (-e $surf ) ) {

          my $t1 = "$dir/$study/$subj/final/${prefix}_${subj}_t1_final.mnc";
          my $cls = "$dir/$study/$subj/temp/${prefix}_${subj}_final_classify.mnc";
          my $wm_mask = "$dir/$study/$subj/temp/${prefix}_${subj}_wm_${hemi}.mnc";
          if( -e $wm_mask ) {

            my @calibrate = ();
            push @calibrate, "-calibrate" if( $surfreg_model_mask{$hemi} ne "none" );
            # Extract the marching-cubes white surface, which is already surface 
            # registered and resampled, without self-intersections if the stage 
            # is successful.
            $pipeline->addStage( {
                name => "extract_white_surface_${subj}_${hemi}",
                label => "extract marching-cubes white $hemi surface in Talairach",
                inputs => [],
                outputs => [$surf],
                args => ["marching_cubes.pl", "\-${hemi}", '-subsample', @calibrate,
                         $t1, $cls, $wm_mask, $surf, $surfreg_model{$hemi},
                         $surfreg_model_mask{$hemi} ],
                prereqs => [] });
 
            $prereqs = [ "extract_white_surface_${subj}_${hemi}" ];
          } else {
            $surf = undef;
          }
        }
      } else {
        $surf = "$dir/$study/$subj/surfaces/${prefix}_${subj}_${surfType}_surface_${hemi}_${numvertices}.obj";
        $surf = undef if( !( -e $surf ) );
      }

      if( defined( $surf ) ) {

        my $surf_rsl = "${outdir}/${n}/${subj}/${surfType}_rsl_${hemi}.obj";

        if( !( -e $surf_rsl ) ) {
          if( $surfreg_model{$hemi} ne "none" ) {

            my $surfmap = "${outdir}/${n}/${subj}/surfmap_${hemi}.sm";

            if( $geom ) {
              $pipeline->addStage( {
                  name => "surface_registration_${subj}_${hemi}",
                  label => "register $hemi $surf surface nonlinearly",
                  inputs => [$surf],
                  outputs => [$surfmap],
                  args => ["geom_surfreg.pl", "-clobber", "-min_control_mesh", "320",
                           "-max_control_mesh", 81920, "-blur_coef", "1.25",
                           "-neighbourhood_radius", "1.8", "-target_spacing", "1.9",
                           $surfreg_model{$hemi}, $surf, $surfmap],
                  prereqs => $prereqs });
            } else {
              $pipeline->addStage( {
                  name => "surface_registration_${subj}_${hemi}",
                  label => "register $hemi $surf surface nonlinearly",
                  inputs => [$surf],
                  outputs => [$surfmap],
                  args => ["bestsurfreg.pl", "-clobber", "-min_control_mesh", "320",
                           "-max_control_mesh", 81920, "-blur_coef", "1.25",
                           "-neighbourhood_radius", "2.8", "-target_spacing", "1.9",
                           $surfreg_model{$hemi}, $surf, $surfmap],
                  prereqs => $prereqs });
            }

            $pipeline->addStage( {
                name => "surface_resample_${subj}_${hemi}",
                label => "resample $hemi $surf surface",
                inputs => [$surf, $surfmap],
                outputs => [$surf_rsl],
                args => [ "sphere_resample_obj", "-clobber", $surf,
                          $surfmap, $surf_rsl ],
                prereqs => ["surface_registration_${subj}_${hemi}"] });

            my $output = "${outdir}/${n}/${subj}/diff_${surfType}_${hemi}.txt";
            $pipeline->addStage( {
                name => "diff_surfs_${subj}_${hemi}",
                label => "diff_surfaces between each subjects' $surfType surf and this iteration's avg surf",
                inputs => [$surf_rsl],
                outputs => [$output],
                args => ["diff_surfaces", $surfreg_model{$hemi}, $surf_rsl, 
                         "link", $output],
                prereqs => ["surface_resample_${subj}_${hemi}"] });

          } else {
            # This needs to be a stage, sadly. Need to wait for creation of $surf (white mc).
            if( $surfType eq "white" && $marchingCubes ) {
              $pipeline->addStage( {
                  name => "surface_resample_${subj}_${hemi}",
                  label => "copy $surf to $surf_rsl",
                  inputs => [$surf],
                  outputs => [$surf_rsl],
                  args => [ "ln", "-sf", $surf, $surf_rsl ],
                  prereqs => $prereqs });
             } else {
               `ln -sf $surf $surf_rsl`;
             }
          }
        }
      }

      # Add this pipeline to the main PMP pipe.
      $pipeline->updateStatus();
      $pipeline->resetFailures();
      $pipes->addPipe($pipeline);
      
    }       #end hemi loop
  }       # end subj loop 

  ######## RUN PIPELINE 2 ############
  ## loop until all pipes are done
  #$pipes->createDotGraph("pipeline-2-it${n}-graph.dot");
  $pipes->registerPrograms();
  $pipes->maxQueued($PMPmaxQueued);
  $pipes->setGranularity($PMPgranularity);
  $pipes->run();
  ####################################

  ####### CREATE PIPELINE 3 ##########

  my %new_model;
  $new_model{left} = "$outdir/$n/avg_left.obj";
  $new_model{right} = "$outdir/$n/avg_right.obj";

  if( !(-e $new_model{left}) || !(-e $new_model{right}) ) {

    my $pipes = PMP::Array->new();
    my $pipeline = init_pipeline( "ASB3-it$n", $logdir, 0 );

    foreach my $hemi (@hemi) {

      # Create a list of extracted surfaces.
      my @surfList;

      foreach my $subj (@subjectlist){
        my $failed_file = "${logdir}/ASB2-$subj-it$n-$hemi.extract_white_surface_${subj}_${hemi}.failed";
        my $surf = "${outdir}/${n}/${subj}/${surfType}_rsl_${hemi}.obj";
        if( -e $surf && !( -e $failed_file ) ) {
          push @surfList, $surf; 
          my @ret = `check_self_intersect $surf`;
          $ret[0] =~ /distance = (.*)/;
          my $dist = $1;
          $ret[1] =~ /triangles = (\d+)/;
          my $num = $1;
          print "resampled ${subj} ${surfType} ${hemi}: self-inter = $num ($dist)\n";
        }
      }

      $pipeline->addStage( {
          name => "average_surfaces_rsl_${hemi}",
          label => "Average $hemi $surfType surfaces on rsl",
          inputs => [],
          outputs => [$new_model{$hemi}],
          args => ["average_surfaces", $new_model{$hemi}, 
                   "$outdir/$n/avg_rms_$hemi.txt", "none", 1, @surfList],
          prereqs => [] });
    }

    # Collapse hemis (symmetrical only) 
    if( $sym ) {

      my $avg_sym_right_flipped_left = "$tmpdir/avg_sym_right_flipped_left.obj";
      
      $pipeline->addStage( {
              name => "transform_objects_rsl_sym_right",
              label => "Flip right hemi to left hemi for symmetrical",
              inputs => [$new_model{right}],
              outputs => [$avg_sym_right_flipped_left],
              args => ["transform_objects", $new_model{right}, 
                       $flip_right, $avg_sym_right_flipped_left ],
              prereqs => ["average_surfaces_rsl_right"] });

      $pipeline->addStage( {
              name => "average_surfaces_rsl_sym",
              label => "Average left and right-flipped-to-left hemis",
              inputs => [$new_model{left}, $avg_sym_right_flipped_left],
              outputs => [$new_model{left}],
              args => ["average_surfaces", $new_model{left}, "none", "none", 1,
                       $new_model{left}, $avg_sym_right_flipped_left],
              prereqs => [ "transform_objects_rsl_sym_right",
                           "average_surfaces_rsl_left"] });

      # Equidistribution of the nodes on the average surface to
      # obtain equal-area triangles.

      $pipeline->addStage( {
          name => "average_surfaces_rsl_iso_sym",
          label => "equidistribute triangles on sym average surface",
          inputs => [$new_model{left}],
          outputs => [$new_model{left}],
          args => ["equidistribute_object.pl", $new_model{left}, $new_model{left}],
          prereqs => ["average_surfaces_rsl_sym"] });

      $pipeline->addStage( {
              name => "flip_average_surfaces_rsl_sym",
              label => "Flip sym average to look like right hemi",
              inputs => [$new_model{left}],
              outputs => [$new_model{right}],
              args => ["transform_objects", $new_model{left}, 
                       $flip_right, $new_model{right} ],
              prereqs => ["average_surfaces_rsl_iso_sym"] });
    } else {
      # Equidistribution of the nodes on the average surface to
      # obtain equal-area triangles (left and right sides separately).

      foreach my $hemi (@hemi) {
        $pipeline->addStage( {
            name => "average_surfaces_rsl_iso_${hemi}",
            label => "equidistribute triangles on $hemi average surface",
            inputs => [$new_model{$hemi}],
            outputs => [$new_model{$hemi}],
            args => ["equidistribute_object.pl", $new_model{$hemi}, $new_model{$hemi}],
            prereqs => ["average_surfaces_rsl_${hemi}"] });
      }
    }

    ####### ADD PIPE PIPELINE 3 ########
    # update the status of all stages based on previous pipeline runs
    $pipeline->updateStatus();
    # restart all stages that failed in a previous run
    $pipeline->resetFailures();
    $pipes->addPipe($pipeline);

    ######## RUN PIPELINE 3 ############
    # loop until all pipes are done
    #$pipes->createDotGraph("pipeline-3-it${n}-graph.dot");
    $pipes->registerPrograms();
    $pipes->maxQueued($PMPmaxQueued);
    $pipes->setGranularity($PMPgranularity);
    $pipes->run();
    ####################################
    unlink( "$tmpdir/avg_sym_right_flipped_left.obj" ) 
      if( -e "$tmpdir/avg_sym_right_flipped_left.obj" );

    if( !(-e $new_model{left}) || !(-e $new_model{right}) ) {
      die "Somehow, the average models on this iteration were not created.\n";
    }
  }

  ####### FINAL CLEANUP ########
  $surfreg_model{left} = $new_model{left};
  $surfreg_model{right} = $new_model{right};
  my $gi_left = `gyrification_index $surfreg_model{left}`; chomp( $gi_left );
  my $gi_right = `gyrification_index $surfreg_model{right}`; chomp( $gi_right );
  print "Iter $n: GI-left $gi_left GI-right $gi_right\n";

  `depth_potential -area_simple $surfreg_model{left} $tmpdir/area_tmp.txt`;
  my $max_area_left = `vertstats_stats $tmpdir/area_tmp.txt |grep Maximum`;
  my $stdev_area_left = `vertstats_stats $tmpdir/area_tmp.txt |grep Stdev`;
  my $mean_area_left = `vertstats_stats $tmpdir/area_tmp.txt |grep Mean`;
  chomp( $max_area_left );
  chomp( $stdev_area_left );
  chomp( $mean_area_left );

  `depth_potential -area_simple $surfreg_model{right} $tmpdir/area_tmp.txt`;
  my $max_area_right = `vertstats_stats $tmpdir/area_tmp.txt |grep Maximum`;
  my $stdev_area_right = `vertstats_stats $tmpdir/area_tmp.txt |grep Stdev`;
  my $mean_area_right = `vertstats_stats $tmpdir/area_tmp.txt |grep Mean`;
  chomp( $max_area_right );
  chomp( $stdev_area_right );
  chomp( $mean_area_right );

  print "Iter $n: Area left $mean_area_left $stdev_area_left $max_area_left\n";
  print "Iter $n: Area right $mean_area_right $stdev_area_right $max_area_right\n";
  unlink( "$tmpdir/area_tmp.txt" );

}

unlink( $flip_right ) if( -e $flip_right );
unlink( $tmpdir );

# the end
sub init_pipeline {
    my $name = shift;
    my $logdir = shift;
    my $debug = shift;
    my $pipeline = undef;

    if ($PMPconf{$PMPtype}{type} eq "spawn") {
        $pipeline = PMP::spawn->new();
        $PMPgranularity = 0;
    } elsif ($PMPconf{$PMPtype}{type} eq "sge") {
        $pipeline = PMP::sge->new();
        $pipeline->setQueue($PMPconf{$PMPtype}{queue});
        $pipeline->setHosts($PMPconf{$PMPtype}{hosts}) if( defined $PMPconf{$PMPtype}{hosts} );
        $pipeline->setQueueOptions($PMPconf{$PMPtype}{opts}) if( defined $PMPconf{$PMPtype}{opts} );
        $pipeline->setPriorityScheme("later-stages");
    } elsif ($PMPconf{$PMPtype}{type} eq "pbs") {
        $pipeline = PMP::pbs->new();
        $pipeline->setQueue($PMPconf{$PMPtype}{queue});
        $pipeline->setHosts($PMPconf{$PMPtype}{hosts}) if( defined $PMPconf{$PMPtype}{hosts} );
        $pipeline->setQueueOptions($PMPconf{$PMPtype}{opts}) if( defined $PMPconf{$PMPtype}{opts} );
        $pipeline->setPriorityScheme("later-stages");
    }

    $pipeline->name($name);
    $pipeline->statusDir($logdir);

    # turn off debug messaging for now
    $pipeline->debug($debug);

    return $pipeline;
}

