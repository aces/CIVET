# Compute the cortical thickness.

package Cortical_Measurements;
use strict;
use PMP::PMP;
use MRI_Image;

sub thickness {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $tkernel = ${$image}->{tkernel};
    my $tmethod = ${$image}->{tmethod};

    my $white_left = ${$image}->{cal_white}{left};
    my $white_right = ${$image}->{cal_white}{right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $native_rms_left = ${$image}->{rms}{left};
    my $native_rms_right = ${$image}->{rms}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my $surfreg_model = ${$image}->{surfregmodel};

    #################################################################
    ##### Calculation of the cortical thickness in native space #####
    #################################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage(
         { name => "thickness_${tmethod}_${tkernel}mm_left",
         label => "native thickness",
         inputs => [$white_left, $gray_left, $t1_tal_xfm],
         outputs => [$native_rms_left],
         args => ["cortical_thickness", "-${tmethod}", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm,
                  $white_left, $gray_left, $native_rms_left],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage(
         { name => "thickness_${tmethod}_${tkernel}mm_right",
         label => "native thickness",
         inputs => [$white_right, $gray_right, $t1_tal_xfm],
         outputs => [$native_rms_right],
         args => ["cortical_thickness", "-${tmethod}", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm,
                  $white_right, $gray_right, $native_rms_right],
         prereqs => $Prereqs });

    ################################################
    ##### Resampling of the cortical thickness #####
    ################################################

    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};
    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};
    my $rsl_left_thickness = ${$image}->{rms_rsl}{left};
    my $rsl_right_thickness = ${$image}->{rms_rsl}{right};

    ${$pipeline_ref}->addStage( {
          name => "resample_left_thickness",
          label => "nonlinear resample left thickness",
          inputs => [$native_rms_left, $left_surfmap, $left_mid_surface],
          outputs => [$rsl_left_thickness],
          args => ["surface-resample", $surfreg_model, $left_mid_surface,
                   $native_rms_left, $left_surfmap, $rsl_left_thickness],
          prereqs => ["thickness_${tmethod}_${tkernel}mm_left"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_right_thickness",
          label => "nonlinear resample right thickness",
          inputs => [$native_rms_right, $right_surfmap, $right_mid_surface],
          outputs => [$rsl_right_thickness],
          args => ["surface-resample", $surfreg_model, $right_mid_surface,
                   $native_rms_right, $right_surfmap, $rsl_right_thickness],
          prereqs => ["thickness_${tmethod}_${tkernel}mm_right"] });

    my $Cortical_Thickness_complete = [ "resample_left_thickness",
                                        "resample_right_thickness" ];

    return( $Cortical_Thickness_complete );

}

sub lobe_area {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $white_left = ${$image}->{cal_white}{left};
    my $white_right = ${$image}->{cal_white}{right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $animal_labels_left = ${$image}->{animal_labels}{left};
    my $animal_labels_right = ${$image}->{animal_labels}{right};
    my $lobe_area_left = ${$image}->{lobe_areas}{left};
    my $lobe_area_right = ${$image}->{lobe_areas}{right};

    my $native_rms_left = ${$image}->{rms}{left};
    my $native_rms_right = ${$image}->{rms}{right};
    my $lobe_thickness_left = ${$image}->{lobe_thickness}{left};
    my $lobe_thickness_right = ${$image}->{lobe_thickness}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $stx_labels_masked = ${$image}->{stx_labels_masked};

    #################################################################################
    ##### Calculation of the cortical thickness and cortex area in native space #####
    #################################################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage(
         { name => "lobe_area_left",
         label => "native lobe area",
         inputs => [$white_left, $gray_left, $t1_tal_xfm, $native_rms_left ],
         outputs => [$animal_labels_left, $lobe_area_left, $lobe_thickness_left],
         args => ["lobe_area", "-transform", $t1_tal_xfm,
                  $white_left, $gray_left, $native_rms_left, $stx_labels_masked, 
                  $animal_labels_left, $lobe_area_left, $lobe_thickness_left ],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "lobe_area_right",
         label => "native lobe area",
         inputs => [$white_right, $gray_right, $t1_tal_xfm, $native_rms_right ],
         outputs => [$animal_labels_right, $lobe_area_right, $lobe_thickness_right],
         args => ["lobe_area", "-transform", $t1_tal_xfm,
                  $white_right, $gray_right, $native_rms_right, $stx_labels_masked, 
                  $animal_labels_right, $lobe_area_right, $lobe_thickness_right ],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    my $Lobe_Area_complete = ["lobe_area_left", "lobe_area_right"];

    return( $Lobe_Area_complete );

}

sub mean_curvature {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $tkernel = ${$image}->{tkernel};

    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};

    my $native_mc_left = ${$image}->{mc}{left};
    my $native_mc_right = ${$image}->{mc}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my $surfreg_model = ${$image}->{surfregmodel};

    ####################################################
    ##### Calculation of mean curvature on the mid #####
    ##### surface in native space                  #####
    ####################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage(
         { name => "mean_curvature_${tkernel}mm_left",
         label => "native mean curvature",
         inputs => [$left_mid_surface, $t1_tal_xfm],
         outputs => [$native_mc_left],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $left_mid_surface,
                  $native_mc_left],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage(
         { name => "mean_curvature_${tkernel}mm_right",
         label => "native mean curvature",
         inputs => [$right_mid_surface, $t1_tal_xfm],
         outputs => [$native_mc_right],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $right_mid_surface,
                  $native_mc_right],
         prereqs => $Prereqs });

    ############################################
    ##### Resampling of the mean curvature #####
    ############################################

    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};
    my $rsl_left_mc = ${$image}->{mc_rsl}{left};
    my $rsl_right_mc = ${$image}->{mc_rsl}{right};

    ${$pipeline_ref}->addStage( {
          name => "resample_left_mean_curvature",
          label => "nonlinear resample left mean curvature",
          inputs => [$native_mc_left, $left_surfmap, $left_mid_surface],
          outputs => [$rsl_left_mc],
          args => ["surface-resample", $surfreg_model, $left_mid_surface,
                   $native_mc_left, $left_surfmap, $rsl_left_mc],
          prereqs => ["mean_curvature_${tkernel}mm_left"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_right_mean_curvature",
          label => "nonlinear resample right mean curvature",
          inputs => [$native_mc_right, $right_surfmap, $right_mid_surface],
          outputs => [$rsl_right_mc],
          args => ["surface-resample", $surfreg_model, $right_mid_surface,
                   $native_mc_right, $right_surfmap, $rsl_right_mc],
          prereqs => ["mean_curvature_${tkernel}mm_right"] });

    my $Mean_Curvature_complete = [ "resample_left_mean_curvature",
                                    "resample_right_mean_curvature" ];

    return( $Mean_Curvature_complete );

}

sub gyrification_index {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my $native_gi_left = ${$image}->{gyrification_index}{left};
    my $native_gi_right = ${$image}->{gyrification_index}{right};

    ################################################
    ##### Calculation of gyrification index on #####
    ##### gray surfaces in native space        #####
    ################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_left",
         label => "gyrification index on native gray left surface",
         inputs => [$gray_left, $t1_tal_xfm],
         outputs => [$native_gi_left],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  $gray_left, $native_gi_left],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage( { 
         name => "gyrification_index_right",
         label => "gyrification index on native gray right surface",
         inputs => [$gray_right, $t1_tal_xfm],
         outputs => [$native_gi_right],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  $gray_right, $native_gi_right],
         prereqs => $Prereqs });

    my $Gyrification_Index_complete = [ "gyrification_index_left",
                                        "gyrification_index_right" ];

    return( $Gyrification_Index_complete );

}

sub cerebral_volume {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};
    my $final_callosum = ${$image}->{final_callosum};
    my $final_classify = ${$image}->{final_classify};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my $output = ${$image}->{cerebral_volume};

    ##########################################################
    ##### Calculation of cerebral volume in native space #####
    ##########################################################

    ${$pipeline_ref}->addStage( {
         name => "cerebral_volume",
         label => "cerebral volume in native space",
         inputs => [$final_classify, $final_callosum, $gray_left, 
                    $gray_right, $t1_tal_xfm],
         outputs => [$output],
         args => ["cerebral_volume", $final_classify, $final_callosum,
                  $gray_left, $gray_right, $t1_tal_xfm, $output],
         prereqs => $Prereqs });

    my $Cerebral_Volume_complete = [ "cerebral_volume" ];

    return( $Cerebral_Volume_complete );
}

sub single_surface {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $tkernel = ${$image}->{tkernel};
    my $tmethod = ${$image}->{tmethod};

    my $white_left = ${$image}->{cal_white}{left};
    my $white_right = ${$image}->{cal_white}{right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};
    my $mid_left = ${$image}->{mid_surface}{left};
    my $mid_right = ${$image}->{mid_surface}{right};

    my $native_rms_left = ${$image}->{rms}{left};
    my $native_rms_right = ${$image}->{rms}{right};

    my $white_full = ${$image}->{cal_white}{full};
    my $gray_full = ${$image}->{gray}{full};
    my $mid_full = ${$image}->{mid_surface}{full};
    my $native_rms_full = ${$image}->{rms}{full};

    #####################################################################
    ##### Combine left/right surfaces (mostly for viewing purposes) #####
    #####################################################################

    #########################
    ##### White surface #####
    #########################

    ${$pipeline_ref}->addStage( {
         name => "white_surface_full",
         label => "white surface full",
         inputs => [$white_left, $white_right],
         outputs => [$white_full],
         args => ["objconcat", $white_left, $white_right, "none", "none",
                  $white_full, "none"],
         prereqs => $Prereqs });

    ########################
    ##### Gray surface #####
    ########################

    ${$pipeline_ref}->addStage( {
         name => "gray_surface_full",
         label => "gray surface full",
         inputs => [$gray_left, $gray_right],
         outputs => [$gray_full],
         args => ["objconcat", $gray_left, $gray_right, "none", "none",
                  $gray_full, "none"],
         prereqs => $Prereqs });

    ####################################################
    ##### Mid surface, with cortical thickness map #####
    ####################################################

    ${$pipeline_ref}->addStage( {
         name => "mid_surface_full_${tmethod}_${tkernel}mm",
         label => "mid surface full",
         inputs => [$mid_left, $mid_right, $native_rms_left, $native_rms_right],
         outputs => [$mid_full, $native_rms_full],
         args => ["objconcat", $white_left, $white_right, $native_rms_left, $native_rms_right,
                  $mid_full, $native_rms_full],
         prereqs => $Prereqs });

    ##############################################################
    ##### Mid surface, with cortical thickness asymmetry map #####
    ##### (using resampled thickness)                        #####
    ##############################################################

    my $rsl_left_thickness = ${$image}->{rms_rsl}{left};
    my $rsl_right_thickness = ${$image}->{rms_rsl}{right};

    my $rsl_asym_hemi = ${$image}->{rms_rsl}{asym_hemi};
    my $rsl_asym_full = ${$image}->{rms_rsl}{asym_full};

    ${$pipeline_ref}->addStage( {
         name => "asymmetry_rms_${tmethod}_${tkernel}mm",
         label => "asymmetry cortical thickness map",
         inputs => [$rsl_left_thickness, $rsl_right_thickness],
         outputs => [$rsl_asym_hemi, $rsl_asym_full],
         args => ["asymmetry_cortical_thickness", "-clobber", $rsl_left_thickness, 
                  $rsl_right_thickness, $rsl_asym_hemi, $rsl_asym_full],
         prereqs => $Prereqs });

    my $Single_Surface_complete = [ "white_surface_full",
                                    "gray_surface_full",
                                    "mid_surface_full_${tmethod}_${tkernel}mm",
                                    "asymmetry_rms_${tmethod}_${tkernel}mm" ];

    return( $Single_Surface_complete );

}




1;
