#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
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

    my @Cortical_Thickness_complete = ( "resample_left_thickness",
                                        "resample_right_thickness" );

    ############################################################################
    ##### Combine fields for cortical thickness for left+right hemispheres #####
    ############################################################################

    if( ${$image}->{combinesurfaces} ) {

      my $native_rms_full = ${$image}->{rms}{full};
      ${$pipeline_ref}->addStage( {
           name => "thickness_${tmethod}_${tkernel}mm",
           label => "native thickness",
           inputs => [$left_mid_surface, $right_mid_surface, 
                      $native_rms_left, $native_rms_right],
           outputs => [$native_rms_full],
           args => ["objconcat", $left_mid_surface, $right_mid_surface,
                    $native_rms_left, $native_rms_right, "none", $native_rms_full],
           prereqs => ["thickness_${tmethod}_${tkernel}mm_left",
                       "thickness_${tmethod}_${tkernel}mm_right"] });

      push @Cortical_Thickness_complete, ("thickness_${tmethod}_${tkernel}mm");

      my $native_rms_rsl_full = ${$image}->{rms_rsl}{full};
      ${$pipeline_ref}->addStage( {
           name => "resample_full_thickness",
           label => "nonlinear resample full thickness",
           inputs => [$left_mid_surface, $right_mid_surface, 
                      $rsl_left_thickness, $rsl_right_thickness],
           outputs => [$native_rms_rsl_full],
           args => ["objconcat", $left_mid_surface, $right_mid_surface,
                    $rsl_left_thickness, $rsl_right_thickness, "none", 
                    $native_rms_rsl_full],
           prereqs => ["resample_left_thickness", "resample_right_thickness"] });

      push @Cortical_Thickness_complete, ("resample_full_thickness");

      ##############################################################
      ##### Mid surface, with cortical thickness asymmetry map #####
      ##### (using resampled thickness)                        #####
      ##############################################################

      my $rsl_left_thickness = ${$image}->{rms_rsl}{left};
      my $rsl_right_thickness = ${$image}->{rms_rsl}{right};

      my @outputs = ( ${$image}->{rms_rsl}{asym_hemi} );
      push @outputs, ( ${$image}->{rms_rsl}{asym_full} ) if( ${$image}->{combinesurfaces} );

      ${$pipeline_ref}->addStage( {
           name => "asymmetry_rms_${tmethod}_${tkernel}mm",
           label => "asymmetry cortical thickness map",
           inputs => [$rsl_left_thickness, $rsl_right_thickness],
           outputs => [@outputs],
           args => ["asymmetry_cortical_thickness", "-clobber", $rsl_left_thickness, 
                    $rsl_right_thickness, @outputs],
           prereqs => [ "resample_left_thickness", "resample_right_thickness" ] });

      push @Cortical_Thickness_complete, ("asymmetry_rms_${tmethod}_${tkernel}mm");

    }

    return( \@Cortical_Thickness_complete );

}

sub mean_curvature {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $tkernel = ${$image}->{tkernel};

    my $left_gray_surface = ${$image}->{gray}{left};
    my $left_white_surface = ${$image}->{white}{left};
    my $left_mid_surface = ${$image}->{mid_surface}{left};

    my $right_gray_surface = ${$image}->{gray}{right};
    my $right_white_surface = ${$image}->{white}{right};
    my $right_mid_surface = ${$image}->{mid_surface}{right};

    my $native_mc_gray_left = ${$image}->{mc_gray}{left};
    my $native_mc_white_left = ${$image}->{mc_white}{left};
    my $native_mc_mid_left = ${$image}->{mc_mid}{left};

    my $native_mc_gray_right = ${$image}->{mc_gray}{right};
    my $native_mc_white_right = ${$image}->{mc_white}{right};
    my $native_mc_mid_right = ${$image}->{mc_mid}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my $surfreg_model = ${$image}->{surfregmodel};

    ####################################################
    ##### Calculation of mean curvature on the mid #####
    ##### surface in native space                  #####
    ####################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_left_gray",
         label => "native mean curvature on gray surface",
         inputs => [$left_gray_surface, $t1_tal_xfm],
         outputs => [$native_mc_gray_left],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $left_gray_surface, 
                  $native_mc_gray_left],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_left_white",
         label => "native mean curvature on white surface",
         inputs => [$left_white_surface, $t1_tal_xfm],
         outputs => [$native_mc_white_left],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $left_white_surface, 
                  $native_mc_white_left],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_left_mid",
         label => "native mean curvature on mid surface",
         inputs => [$left_mid_surface, $t1_tal_xfm],
         outputs => [$native_mc_mid_left],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $left_mid_surface, 
                  $native_mc_mid_left],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_right_gray",
         label => "native mean curvature on gray surface",
         inputs => [$right_gray_surface, $t1_tal_xfm],
         outputs => [$native_mc_gray_right],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $right_gray_surface, 
                  $native_mc_gray_right],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_right_white",
         label => "native mean curvature on white surface",
         inputs => [$right_white_surface, $t1_tal_xfm],
         outputs => [$native_mc_white_right],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $right_white_surface, 
                  $native_mc_white_right],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "mean_curvature_${tkernel}mm_right_mid",
         label => "native mean curvature on mid surface",
         inputs => [$right_mid_surface, $t1_tal_xfm],
         outputs => [$native_mc_mid_right],
         args => ["mean_curvature", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm, $right_mid_surface, 
                  $native_mc_mid_right],
         prereqs => $Prereqs });

    ############################################
    ##### Resampling of the mean curvature #####
    ############################################

    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};
    my $rsl_left_gray_mc = ${$image}->{mc_gray_rsl}{left};
    my $rsl_left_white_mc = ${$image}->{mc_white_rsl}{left};
    my $rsl_left_mid_mc = ${$image}->{mc_mid_rsl}{left};
    my $rsl_right_gray_mc = ${$image}->{mc_gray_rsl}{right};
    my $rsl_right_white_mc = ${$image}->{mc_white_rsl}{right};
    my $rsl_right_mid_mc = ${$image}->{mc_mid_rsl}{right};

    # resampling is based on the mid surface
    ${$pipeline_ref}->addStage( {
          name => "resample_left_mean_curvature_gray",
          label => "resample left mean curvature on gray surface",
          inputs => [$native_mc_gray_left, $left_surfmap, $left_mid_surface],
          outputs => [$rsl_left_gray_mc],
          args => ["surface-resample", $surfreg_model, $left_mid_surface,
                   $native_mc_gray_left, $left_surfmap, $rsl_left_gray_mc],
          prereqs => ["mean_curvature_${tkernel}mm_left_gray"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_left_mean_curvature_white",
          label => "resample left mean curvature on white surface",
          inputs => [$native_mc_white_left, $left_surfmap, $left_mid_surface],
          outputs => [$rsl_left_white_mc],
          args => ["surface-resample", $surfreg_model, $left_mid_surface,
                   $native_mc_white_left, $left_surfmap, $rsl_left_white_mc],
          prereqs => ["mean_curvature_${tkernel}mm_left_white"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_left_mean_curvature_mid",
          label => "resample left mean curvature on mid surface",
          inputs => [$native_mc_mid_left, $left_surfmap, $left_mid_surface],
          outputs => [$rsl_left_mid_mc],
          args => ["surface-resample", $surfreg_model, $left_mid_surface,
                   $native_mc_mid_left, $left_surfmap, $rsl_left_mid_mc],
          prereqs => ["mean_curvature_${tkernel}mm_left_mid"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_right_mean_curvature_gray",
          label => "resample right mean curvature on gray surface",
          inputs => [$native_mc_gray_right, $right_surfmap, $right_mid_surface],
          outputs => [$rsl_right_gray_mc],
          args => ["surface-resample", $surfreg_model, $right_mid_surface,
                   $native_mc_gray_right, $right_surfmap, $rsl_right_gray_mc],
          prereqs => ["mean_curvature_${tkernel}mm_right_gray"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_right_mean_curvature_white",
          label => "resample right mean curvature on white surface",
          inputs => [$native_mc_white_right, $right_surfmap, $right_mid_surface],
          outputs => [$rsl_right_white_mc],
          args => ["surface-resample", $surfreg_model, $right_mid_surface,
                   $native_mc_white_right, $right_surfmap, $rsl_right_white_mc],
          prereqs => ["mean_curvature_${tkernel}mm_right_white"] });

    ${$pipeline_ref}->addStage( {
          name => "resample_right_mean_curvature_mid",
          label => "resample right mean curvature on mid surface",
          inputs => [$native_mc_mid_right, $right_surfmap, $right_mid_surface],
          outputs => [$rsl_right_mid_mc],
          args => ["surface-resample", $surfreg_model, $right_mid_surface,
                   $native_mc_mid_right, $right_surfmap, $rsl_right_mid_mc],
          prereqs => ["mean_curvature_${tkernel}mm_right_mid"] });

    my @Mean_Curvature_complete = ( "resample_left_mean_curvature_gray",
                                    "resample_left_mean_curvature_white",
                                    "resample_left_mean_curvature_mid",
                                    "resample_right_mean_curvature_gray",
                                    "resample_right_mean_curvature_white",
                                    "resample_right_mean_curvature_mid" );

    ########################################################################
    ##### Combine fields for mean curvature for left+right hemispheres #####
    ########################################################################

    if( ${$image}->{combinesurfaces} ) {

      my $native_mc_gray_full = ${$image}->{mc_gray}{full};
      my $native_mc_white_full = ${$image}->{mc_white}{full};
      my $native_mc_mid_full = ${$image}->{mc_mid}{full};

      ${$pipeline_ref}->addStage( {
           name => "mean_curvature_${tkernel}mm_gray",
           label => "native mean curvature on gray surface",
           inputs => [$left_gray_surface, $right_gray_surface,
                      $native_mc_gray_left, $native_mc_gray_right],
           outputs => [$native_mc_gray_full],
           args => ["objconcat", $left_gray_surface, $right_gray_surface,
                    $native_mc_gray_left, $native_mc_gray_right, "none", 
                    $native_mc_gray_full],
           prereqs => [ "mean_curvature_${tkernel}mm_left_gray",
                        "mean_curvature_${tkernel}mm_right_gray" ] });

      ${$pipeline_ref}->addStage( {
           name => "mean_curvature_${tkernel}mm_white",
           label => "native mean curvature on white surface",
           inputs => [$left_white_surface, $right_white_surface,
                      $native_mc_white_left, $native_mc_white_right],
           outputs => [$native_mc_white_full],
           args => ["objconcat", $left_white_surface, $right_white_surface,
                    $native_mc_white_left, $native_mc_white_right, "none", 
                    $native_mc_white_full],
           prereqs => [ "mean_curvature_${tkernel}mm_left_white",
                        "mean_curvature_${tkernel}mm_right_white" ] });

      ${$pipeline_ref}->addStage( {
           name => "mean_curvature_${tkernel}mm_mid",
           label => "native mean curvature on mid surface",
           inputs => [$left_mid_surface, $right_mid_surface,
                      $native_mc_mid_left, $native_mc_mid_right],
           outputs => [$native_mc_mid_full],
           args => ["objconcat", $left_mid_surface, $right_mid_surface,
                    $native_mc_mid_left, $native_mc_mid_right, "none", 
                    $native_mc_mid_full],
           prereqs => [ "mean_curvature_${tkernel}mm_left_mid",
                        "mean_curvature_${tkernel}mm_right_mid" ] });

      push @Mean_Curvature_complete, ("mean_curvature_${tkernel}mm_gray");
      push @Mean_Curvature_complete, ("mean_curvature_${tkernel}mm_white");
      push @Mean_Curvature_complete, ("mean_curvature_${tkernel}mm_mid");

      ##### Note: could do asym maps of rsl mc just like for rms.
    }

    return( \@Mean_Curvature_complete );

}

sub position {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $mid_rsl_left = ${$image}->{mid_surface_rsl}{left};
    my $mid_rsl_right = ${$image}->{mid_surface_rsl}{right};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my @outputs = ( ${$image}->{pos_rsl}{asym_hemi} );
    push @outputs, ( ${$image}->{pos_rsl}{asym_full} ) if( ${$image}->{combinesurfaces} );

    ####################################################
    ##### Calculation of asymmetry map in position #####
    ##### of cortical surfaces                     #####
    ####################################################

    ${$pipeline_ref}->addStage( {
         name => "asymmetry_map_position",
         label => "asymmetry map in position of cortical surfaces",
         inputs => [$mid_rsl_left, $mid_rsl_right, $t1_tal_xfm],
         outputs => [@outputs],
         args => ["asymmetry_position_map", "-clobber", $mid_rsl_left,
                  $mid_rsl_right, $t1_tal_xfm, @outputs],
         prereqs => $Prereqs });

    my @Position_complete = ( "asymmetry_map_position" );

    return( \@Position_complete );
}

sub gyrification_index {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};
    my $mid_left = ${$image}->{mid_surface}{left};
    my $mid_right = ${$image}->{mid_surface}{right};
    my $white_left = ${$image}->{cal_white}{left};
    my $white_right = ${$image}->{cal_white}{right};

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
         name => "gyrification_index_left_gray",
         label => "gyrification index on native left gray surface",
	 inputs => [$gray_left, $t1_tal_xfm],
         outputs => [$native_gi_left],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "gray", $gray_left, $native_gi_left],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_left_white",
         label => "gyrification index on native left white surface",
         inputs => [$white_left, $t1_tal_xfm],
         outputs => [$native_gi_left],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "white", "-append", $white_left, $native_gi_left],
         prereqs => ["gyrification_index_left_gray"] });

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_left_mid",
         label => "gyrification index on native left mid surface",
         inputs => [$mid_left, $t1_tal_xfm],
         outputs => [$native_gi_left],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "mid", "-append", $mid_left, $native_gi_left],
         prereqs => ["gyrification_index_left_white"] });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_right_gray",
         label => "gyrification index on native right gray surface",
	 inputs => [$gray_right, $t1_tal_xfm],
         outputs => [$native_gi_right],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "gray", $gray_right, $native_gi_right],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_right_white",
         label => "gyrification index on native right white surface",
         inputs => [$white_right, $t1_tal_xfm],
         outputs => [$native_gi_right],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "white", "-append", $white_right, $native_gi_right],
         prereqs => ["gyrification_index_right_gray"] });

    ${$pipeline_ref}->addStage( {
         name => "gyrification_index_right_mid",
         label => "gyrification index on native right mid surface",
         inputs => [$mid_right, $t1_tal_xfm],
         outputs => [$native_gi_right],
         args => ["gyrification_index", "-transform", $t1_tal_xfm,
                  "-label", "mid", "-append", $mid_right, $native_gi_right],
         prereqs => ["gyrification_index_right_white"] });

    my @Gyrification_Index_complete = ( "gyrification_index_left_mid",
                                        "gyrification_index_right_mid" );

    ###########################################
    ##### Combined left+right hemispheres #####
    ###########################################

    if( ${$image}->{combinesurfaces} ) {
      my $gray_full = ${$image}->{gray}{full};
      my $white_full = ${$image}->{cal_white}{full};
      my $mid_full = ${$image}->{mid_surface}{full};
      my $native_gi_full = ${$image}->{gyrification_index}{full};

      ${$pipeline_ref}->addStage( {
           name => "gyrification_index_full_gray",
           label => "gyrification index on native full gray surface",
	   inputs => [$gray_full, $t1_tal_xfm],
           outputs => [$native_gi_full],
           args => ["gyrification_index", "-transform", $t1_tal_xfm,
                    "-label", "gray", $gray_full, $native_gi_full],
           prereqs => $Prereqs });
  
      ${$pipeline_ref}->addStage( {
           name => "gyrification_index_full_white",
           label => "gyrification index on native full white surface",
           inputs => [$white_full, $t1_tal_xfm],
           outputs => [$native_gi_full],
           args => ["gyrification_index", "-transform", $t1_tal_xfm,
                    "-label", "white", "-append", $white_full, $native_gi_full],
           prereqs => ["gyrification_index_full_gray"] });
  
      ${$pipeline_ref}->addStage( {
           name => "gyrification_index_full_mid",
           label => "gyrification index on native full mid surface",
           inputs => [$mid_full, $t1_tal_xfm],
           outputs => [$native_gi_full],
           args => ["gyrification_index", "-transform", $t1_tal_xfm,
                    "-label", "mid", "-append", $mid_full, $native_gi_full],
           prereqs => ["gyrification_index_full_white"] });

      push @Gyrification_Index_complete, ("gyrification_index_full_mid");
    }

    return( \@Gyrification_Index_complete );

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

sub lobe_features {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $native_rms_rsl_left = ${$image}->{rms_rsl}{left};
    my $native_rms_rsl_right = ${$image}->{rms_rsl}{right};

    my $lobe_thickness_left = ${$image}->{lobe_thickness}{left};
    my $lobe_thickness_right = ${$image}->{lobe_thickness}{right};

    my $surface_labels_left = ${$image}->{surface_atlas}{left};
    my $surface_labels_right = ${$image}->{surface_atlas}{right};

    ###################################################
    ##### Lobe parcellation of cortical thickness #####
    ###################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage( {
         name => "lobe_thickness_left",
         label => "native lobe thickness left",
         inputs => [$native_rms_rsl_left],
         outputs => [$lobe_thickness_left],
         args => ["lobe_stats", "-norm", $native_rms_rsl_left,
                  $surface_labels_left, "average cortical thickness", $lobe_thickness_left],
         prereqs => $Prereqs });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage( {
         name => "lobe_thickness_right",
         label => "native lobe thickness right",
         inputs => [$native_rms_rsl_right],
         outputs => [$lobe_thickness_right],
         args => ["lobe_stats", "-norm", $native_rms_rsl_right,
                  $surface_labels_right, "average cortical thickness", $lobe_thickness_right],
         prereqs => $Prereqs });

    my @Lobe_complete = ( "lobe_thickness_left", "lobe_thickness_right" );

    ###############################################
    ##### Lobe parcellation of mean curvature #####
    ###############################################

#
# Note quite ready: need to repeat on gray, white, mid surfaces. CL.
#
#   if( ${$image}->{meancurvature} ) {

#     my $native_mc_rsl_left = ${$image}->{mc_rsl}{left};
#     my $native_mc_rsl_right = ${$image}->{mc_rsl}{right};
#     my $lobe_mc_left = ${$image}->{lobe_mc}{left};
#     my $lobe_mc_right = ${$image}->{lobe_mc}{right};

#     ###########################
#     ##### Left hemisphere #####
#     ###########################

#     ${$pipeline_ref}->addStage( {
#          name => "lobe_mean_curvature_left",
#          label => "native lobe mean curvature left",
#          inputs => [$native_rms_rsl_left],
#          outputs => [$lobe_mc_left],
#          args => ["lobe_stats", "-norm", $native_mc_rsl_left,
#                   $surface_labels_left, "average absolute mean curvature", $lobe_mc_left],
#          prereqs => $Prereqs });

#     ############################
#     ##### Right hemisphere #####
#     ############################
# 
#     ${$pipeline_ref}->addStage( {
#          name => "lobe_mean_curvature_right",
#          label => "native lobe mean curvature right",
#          inputs => [$native_rms_rsl_right],
#          outputs => [$lobe_mc_right],
#          args => ["lobe_stats", "-norm", $native_mc_rsl_right,
#                   $surface_labels_right, "average absolute mean curvature", $lobe_mc_right],
#          prereqs => $Prereqs });

#     push @Lobe_complete, ("lobe_mean_curvature_left");
#     push @Lobe_complete, ("lobe_mean_curvature_right");
#   }

    ############################################
    ##### Lobe parcellation of cortex area #####
    ############################################

    if( ${$image}->{resamplesurfaces} ) {

      my $gray_rsl_left = ${$image}->{gray_rsl}{left};
      my $gray_rsl_right = ${$image}->{gray_rsl}{right};

      my $lobe_area_left = ${$image}->{lobe_areas}{left};
      my $lobe_area_right = ${$image}->{lobe_areas}{right};

      my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

      ###########################
      ##### Left hemisphere #####
      ###########################

      ${$pipeline_ref}->addStage( {
         name => "lobe_area_left",
         label => "native lobe features left",
         inputs => [$gray_rsl_left, $t1_tal_xfm],
         outputs => [$lobe_area_left],
         args => ["lobe_area", "-transform", $t1_tal_xfm, 
                  $gray_rsl_left, $surface_labels_left, $lobe_area_left ],
         prereqs => $Prereqs });

      ############################
      ##### Right hemisphere #####
      ############################

      ${$pipeline_ref}->addStage( {
         name => "lobe_area_right",
         label => "native lobe area",
         inputs => [$gray_rsl_right, $t1_tal_xfm],
         outputs => [$lobe_area_right],
         args => ["lobe_area", "-transform", $t1_tal_xfm,
                  $gray_rsl_right, $surface_labels_right, 
                  $lobe_area_right],
         prereqs => $Prereqs });

      push @Lobe_complete, ("lobe_area_left");
      push @Lobe_complete, ("lobe_area_right");
    }

    ##############################################
    ##### Lobe parcellation of cortex volume #####
    ##############################################

    if( ${$image}->{resamplesurfaces} ) {

      my $native_volume_rsl_left = ${$image}->{surface_volume_rsl}{left};
      my $native_volume_rsl_right = ${$image}->{surface_volume_rsl}{right};

      my $lobe_volume_left = ${$image}->{lobe_volumes}{left};
      my $lobe_volume_right = ${$image}->{lobe_volumes}{right};

      my $surface_labels_left = ${$image}->{surface_atlas}{left};
      my $surface_labels_right = ${$image}->{surface_atlas}{right};

      ###########################
      ##### Left hemisphere #####
      ###########################

      ${$pipeline_ref}->addStage( {
           name => "lobe_volume_left",
           label => "native lobe vertex-volumes left",
           inputs => [$native_volume_rsl_left],
           outputs => [$lobe_volume_left],
           args => ["lobe_stats", $native_volume_rsl_left,
                    $surface_labels_left, "total cortical volume", $lobe_volume_left],
           prereqs => $Prereqs });

      ############################
      ##### Right hemisphere #####
      ############################

      ${$pipeline_ref}->addStage( {
           name => "lobe_volume_right",
           label => "native lobe vertex-volumes right",
           inputs => [$native_volume_rsl_right],
           outputs => [$lobe_volume_right],
           args => ["lobe_stats", $native_volume_rsl_right,
                    $surface_labels_right, "total cortical volume", $lobe_volume_right],
           prereqs => $Prereqs });

      push @Lobe_complete, ("lobe_volume_left");
      push @Lobe_complete, ("lobe_volume_right");
    }

    return( \@Lobe_complete );
}


1;
