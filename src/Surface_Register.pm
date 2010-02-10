#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
##############################
#### Surface registration ####
##############################

# Once the cortical surfaces are produced, they need to be aligned with the
# surfaces of other brains in the data set so cortical thickness data could be
# compared across subjects. To achieve this, SURFREG performs a non-linear
# registration of the surfaces to a pre-defined template surface. This transform
# is then applied (by resampling) in native space.

package Surface_Register;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $surfreg_model = @_[3];
    my $surfreg_dataterm = @_[4];

    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};
    my $left_dataterm = ${$image}->{dataterm}{left};
    my $right_dataterm = ${$image}->{dataterm}{right};
    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};

# ---------------------------------------------------------------------------
#  Step 1: Compute data term on mid surfaces using Maxime's depth potential.
#          We must use alpha=0.05 to be consistent with Oliver's average
#          surface model.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "dataterm_left_surface",
          label => "WM left surface depth potential",
          inputs => [$left_mid_surface],
          outputs => [$left_dataterm],
          args => ["depth_potential", "-alpha", "0.05", "-depth_potential", 
                   $left_mid_surface, $left_dataterm ],
          prereqs => $Prereqs } );

    ${$pipeline_ref}->addStage( {
          name => "dataterm_right_surface",
          label => "WM right surface depth potential",
          inputs => [$right_mid_surface],
          outputs => [$right_dataterm],
          args => ["depth_potential", "-alpha", "0.05", "-depth_potential", 
                   $right_mid_surface, $right_dataterm ],
          prereqs => $Prereqs } );

# ---------------------------------------------------------------------------
#  Step 2: Surface registration to left+right hemispheric averaged model.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "surface_registration_left",
          label => "register left mid-surface nonlinearly",
          inputs => [$left_mid_surface,$left_dataterm],
          outputs => [$left_surfmap],
          args => ["bestsurfreg.pl", "-clobber", "-min_control_mesh", "80",
                   "-max_control_mesh", "81920", "-blur_coef", "1.25", 
                   "-neighbourhood_radius", "2.8", "-target_spacing", "1.9", 
                   $surfreg_model, $surfreg_dataterm,
                   $left_mid_surface, $left_dataterm, $left_surfmap ],
          prereqs => ["dataterm_left_surface"] });

    ${$pipeline_ref}->addStage( {
          name => "surface_registration_right",
          label => "register right mid-surface nonlinearly",
          inputs => [$right_mid_surface,$right_dataterm],
          outputs => [$right_surfmap],
          args => ["bestsurfreg.pl", "-clobber", "-min_control_mesh", "80",
                   "-max_control_mesh", "81920", "-blur_coef", "1.25",
                   "-neighbourhood_radius", "2.8", "-target_spacing", "1.9",
                   $surfreg_model, $surfreg_dataterm,
                   $right_mid_surface, $right_dataterm, $right_surfmap ],
          prereqs => ["dataterm_right_surface"] });

    my $SurfReg_complete = [ "surface_registration_left",
                             "surface_registration_right" ];

    return( $SurfReg_complete );
}

##################################################
#### Resample the surfaces after registration ####
##################################################

sub resample_surfaces {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $left_white_surface = ${$image}->{cal_white}{left};
    my $right_white_surface = ${$image}->{cal_white}{right};
    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};
    my $left_gray_surface = ${$image}->{gray}{left};
    my $right_gray_surface = ${$image}->{gray}{right};

    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};

    my $left_white_surface_rsl = ${$image}->{cal_white_rsl}{left};
    my $right_white_surface_rsl = ${$image}->{cal_white_rsl}{right};
    my $left_mid_surface_rsl = ${$image}->{mid_surface_rsl}{left};
    my $right_mid_surface_rsl = ${$image}->{mid_surface_rsl}{right};
    my $left_gray_surface_rsl = ${$image}->{gray_rsl}{left};
    my $right_gray_surface_rsl = ${$image}->{gray_rsl}{right};

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_left_white",
          label => "resample left white surface",
          inputs => [$left_white_surface, $left_surfmap],
          outputs => [$left_white_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $left_white_surface,
                    $left_surfmap, $left_white_surface_rsl ],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_right_white",
          label => "resample right white surface",
          inputs => [$right_white_surface, $right_surfmap],
          outputs => [$right_white_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $right_white_surface,
                    $right_surfmap, $right_white_surface_rsl ],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_left_gray",
          label => "resample left gray surface",
          inputs => [$left_gray_surface, $left_surfmap],
          outputs => [$left_gray_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $left_gray_surface,
                    $left_surfmap, $left_gray_surface_rsl ],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_right_gray",
          label => "resample right gray surface",
          inputs => [$right_gray_surface, $right_surfmap],
          outputs => [$right_gray_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $right_gray_surface,
                    $right_surfmap, $right_gray_surface_rsl ],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_left_mid",
          label => "resample left mid surface",
          inputs => [$left_mid_surface, $left_surfmap],
          outputs => [$left_mid_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $left_mid_surface,
                    $left_surfmap, $left_mid_surface_rsl ],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_resample_right_mid",
          label => "resample right mid surface",
          inputs => [$right_mid_surface, $right_surfmap],
          outputs => [$right_mid_surface_rsl],
          args => [ "sphere_resample_obj", "-clobber", $right_mid_surface,
                    $right_surfmap, $right_mid_surface_rsl ],
          prereqs => $Prereqs });

    my $SurfResample_complete = [ "surface_resample_left_white",
                                  "surface_resample_right_white",
                                  "surface_resample_left_gray",
                                  "surface_resample_right_gray",
                                  "surface_resample_left_mid",
                                  "surface_resample_right_mid" ];

    return( $SurfResample_complete );
}

#####################################################
#### Compute surface areas on resampled surfaces ####
#####################################################

sub resampled_surface_areas {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $surfreg_model = @_[3];

    my $fwhm = ${$image}->{rsl_fwhm};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $left_mid_surface_rsl = ${$image}->{mid_surface_rsl}{left};
    my $right_mid_surface_rsl = ${$image}->{mid_surface_rsl}{right};
    my $left_surface_area_rsl = ${$image}->{surface_area_rsl}{left};
    my $right_surface_area_rsl = ${$image}->{surface_area_rsl}{right};

    ${$pipeline_ref}->addStage( {
          name => "surface_area_rsl_left_mid",
          label => "surface area on resampled left mid surface",
          inputs => [$left_mid_surface_rsl,$t1_tal_xfm],
          outputs => [$left_surface_area_rsl],
          args => [ "cortical_area_stats", $left_mid_surface_rsl,
                    $surfreg_model, $t1_tal_xfm, $fwhm, 
                    $left_surface_area_rsl],
          prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
          name => "surface_area_rsl_right_mid",
          label => "surface area on resampled right mid surface",
          inputs => [$right_mid_surface_rsl,$t1_tal_xfm],
          outputs => [$right_surface_area_rsl],
          args => [ "cortical_area_stats", $right_mid_surface_rsl,
                    $surfreg_model, $t1_tal_xfm, $fwhm, 
                    $right_surface_area_rsl],
          prereqs => $Prereqs });

    my $SurfaceAreas_complete = [ "surface_area_rsl_left_mid",
                                  "surface_area_rsl_right_mid" ];

    return( $SurfaceAreas_complete );
}


1;
