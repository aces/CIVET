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

    my $white_left = ${$image}->{white}{left};
    my $white_right = ${$image}->{white}{right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};
    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};

    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    #################################################################
    ##### Calculation of the cortical thickness in native space #####
    #################################################################

    my @Cortical_Thickness_complete = ();
    my $count = 0;
    foreach my $tmethod (@{${$image}->{tmethod}}) {

      foreach my $tkernel (@{${$image}->{tkernel}}) {

        my $native_rms_left = @{${$image}->{rms}{left}}[$count];
        my $native_rms_right = @{${$image}->{rms}{right}}[$count];

        ###########################
        ##### Left hemisphere #####
        ###########################

        ${$pipeline_ref}->addStage( {
             name => "thickness_${tmethod}_${tkernel}mm_left",
             label => "native thickness ${tmethod} ${tkernel}mm",
             inputs => [$white_left, $gray_left, $t1_tal_xfm],
             outputs => [$native_rms_left],
             args => ["cortical_thickness", "-${tmethod}", "-fwhm", ${tkernel}, 
                      "-transform", $t1_tal_xfm,
                      $white_left, $gray_left, $native_rms_left],
             prereqs => $Prereqs });

        ############################
        ##### Right hemisphere #####
        ############################

        ${$pipeline_ref}->addStage( {
             name => "thickness_${tmethod}_${tkernel}mm_right",
             label => "native thickness ${tmethod} ${tkernel}mm",
             inputs => [$white_right, $gray_right, $t1_tal_xfm],
             outputs => [$native_rms_right],
             args => ["cortical_thickness", "-${tmethod}", "-fwhm", ${tkernel}, 
                      "-transform", $t1_tal_xfm,
                      $white_right, $gray_right, $native_rms_right],
             prereqs => $Prereqs });

        ################################################
        ##### Resampling of the cortical thickness #####
        ################################################

        my $rsl_left_thickness = @{${$image}->{rms_rsl}{left}}[$count];
        my $rsl_right_thickness = @{${$image}->{rms_rsl}{right}}[$count];

        ${$pipeline_ref}->addStage( {
              name => "resample_left_thickness_${tmethod}_${tkernel}mm",
              label => "surface resample left thickness ${tmethod} ${tkernel}mm",
              inputs => [$native_rms_left, $left_surfmap, $left_mid_surface],
              outputs => [$rsl_left_thickness],
              args => ["surface-resample", ${$image}->{surfregmodel}{left},
                       $left_mid_surface, $native_rms_left, $left_surfmap, 
                       $rsl_left_thickness],
              prereqs => ["thickness_${tmethod}_${tkernel}mm_left"] });

        # Important note: The surfmap file is always left-oriented, so the
        #                 mid_surface must also be left-oriented. Only the
        #                 connectivity is read, so pass the left_mid_surface,
        #                 as opposed to flipping the right_mid_surface. CL.
        ${$pipeline_ref}->addStage( {
              name => "resample_right_thickness_${tmethod}_${tkernel}mm",
              label => "surface resample right thickness ${tmethod} ${tkernel}mm",
              inputs => [$native_rms_right, $right_surfmap, $left_mid_surface],
              outputs => [$rsl_right_thickness],
              args => ["surface-resample", ${$image}->{surfregmodel}{right}, 
                       $left_mid_surface, $native_rms_right, $right_surfmap, 
                       $rsl_right_thickness],
              prereqs => [ @$Prereqs, "thickness_${tmethod}_${tkernel}mm_right"] });

        push @Cortical_Thickness_complete, "resample_left_thickness_${tmethod}_${tkernel}mm";
        push @Cortical_Thickness_complete, "resample_right_thickness_${tmethod}_${tkernel}mm";

        ############################################################################
        ##### Combine fields for cortical thickness for left+right hemispheres #####
        ############################################################################

        if( ${$image}->{combinesurfaces} ) {

          my $native_rms_full = @{${$image}->{rms}{full}}[$count];
          ${$pipeline_ref}->addStage( {
               name => "thickness_${tmethod}_${tkernel}mm",
               label => "native full thickness ${tmethod} ${tkernel}mm",
               inputs => [$left_mid_surface, $right_mid_surface, 
                          $native_rms_left, $native_rms_right],
               outputs => [$native_rms_full],
               args => ["objconcat", $left_mid_surface, $right_mid_surface,
                        $native_rms_left, $native_rms_right, "none", $native_rms_full],
               prereqs => ["thickness_${tmethod}_${tkernel}mm_left",
                           "thickness_${tmethod}_${tkernel}mm_right"] });

          push @Cortical_Thickness_complete, ("thickness_${tmethod}_${tkernel}mm");

          my $native_rms_rsl_full = @{${$image}->{rms_rsl}{full}}[$count];
          ${$pipeline_ref}->addStage( {
               name => "resample_full_thickness_${tmethod}_${tkernel}mm",
               label =>"resampled full thickness ${tmethod} ${tkernel}mm",
               inputs => [$left_mid_surface, $right_mid_surface, 
                          $rsl_left_thickness, $rsl_right_thickness],
               outputs => [$native_rms_rsl_full],
               args => ["objconcat", $left_mid_surface, $right_mid_surface,
                        $rsl_left_thickness, $rsl_right_thickness, "none", 
                        $native_rms_rsl_full],
               prereqs => ["resample_left_thickness_${tmethod}_${tkernel}mm", 
                           "resample_right_thickness_${tmethod}_${tkernel}mm"] });
   
          push @Cortical_Thickness_complete, ("resample_full_thickness_${tmethod}_${tkernel}mm");

        }

        ##############################################################
        ##### Mid surface, with cortical thickness asymmetry map #####
        ##### (using resampled thickness)                        #####
        ##############################################################

        my $rsl_left_thickness = @{${$image}->{rms_rsl}{left}}[$count];
        my $rsl_right_thickness = @{${$image}->{rms_rsl}{right}}[$count];
  
        my @outputs = ( @{${$image}->{rms_rsl}{asym_hemi}}[$count] );
        push @outputs, ( @{${$image}->{rms_rsl}{asym_full}}[$count] ) if( ${$image}->{combinesurfaces} );

        ${$pipeline_ref}->addStage( {
             name => "asymmetry_rms_${tmethod}_${tkernel}mm",
             label => "asymmetry cortical thickness map ${tmethod} ${tkernel}mm",
             inputs => [$rsl_left_thickness, $rsl_right_thickness],
             outputs => [@outputs],
             args => ["asymmetry_cortical_thickness", "-clobber", $rsl_left_thickness, 
                      $rsl_right_thickness, @outputs],
             prereqs => ["resample_left_thickness_${tmethod}_${tkernel}mm", 
                         "resample_right_thickness_${tmethod}_${tkernel}mm"] });

        push @Cortical_Thickness_complete, ("asymmetry_rms_${tmethod}_${tkernel}mm");
        $count++;
      }
    }

    return( \@Cortical_Thickness_complete );

}

sub mean_curvature {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $left_gray_surface = ${$image}->{gray}{left};
    my $left_white_surface = ${$image}->{white}{left};
    my $left_mid_surface = ${$image}->{mid_surface}{left};

    my $right_gray_surface = ${$image}->{gray}{right};
    my $right_white_surface = ${$image}->{white}{right};
    my $right_mid_surface = ${$image}->{mid_surface}{right};

    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    my @Mean_Curvature_complete = ();
    my $count = 0;
    foreach my $tkernel (@{${$image}->{tkernel}}) {

      ####################################################
      ##### Calculation of mean curvature on the mid #####
      ##### surface in native space                  #####
      ####################################################

      my $native_mc_gray_left = @{${$image}->{mc_gray}{left}}[$count];
      my $native_mc_white_left = @{${$image}->{mc_white}{left}}[$count];
      my $native_mc_mid_left = @{${$image}->{mc_mid}{left}}[$count];
  
      my $native_mc_gray_right = @{${$image}->{mc_gray}{right}}[$count];
      my $native_mc_white_right = @{${$image}->{mc_white}{right}}[$count];
      my $native_mc_mid_right = @{${$image}->{mc_mid}{right}}[$count];

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

      my $rsl_left_gray_mc = @{${$image}->{mc_gray_rsl}{left}}[$count];
      my $rsl_left_white_mc = @{${$image}->{mc_white_rsl}{left}}[$count];
      my $rsl_left_mid_mc = @{${$image}->{mc_mid_rsl}{left}}[$count];
      my $rsl_right_gray_mc = @{${$image}->{mc_gray_rsl}{right}}[$count];
      my $rsl_right_white_mc = @{${$image}->{mc_white_rsl}{right}}[$count];
      my $rsl_right_mid_mc = @{${$image}->{mc_mid_rsl}{right}}[$count];

      # resampling is based on the mid surface
      ${$pipeline_ref}->addStage( {
            name => "resample_left_mean_curvature_${tkernel}mm_gray",
            label => "resample left mean curvature on gray surface",
            inputs => [$native_mc_gray_left, $left_surfmap, $left_mid_surface],
            outputs => [$rsl_left_gray_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{left},
                     $left_mid_surface, $native_mc_gray_left, $left_surfmap, 
                     $rsl_left_gray_mc],
            prereqs => ["mean_curvature_${tkernel}mm_left_gray"] });

      ${$pipeline_ref}->addStage( {
            name => "resample_left_mean_curvature_${tkernel}mm_white",
            label => "resample left mean curvature on white surface",
            inputs => [$native_mc_white_left, $left_surfmap, $left_mid_surface],
            outputs => [$rsl_left_white_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{left},
                     $left_mid_surface, $native_mc_white_left, $left_surfmap, 
                     $rsl_left_white_mc],
            prereqs => ["mean_curvature_${tkernel}mm_left_white"] });

      ${$pipeline_ref}->addStage( {
            name => "resample_left_mean_curvature_${tkernel}mm_mid",
            label => "resample left mean curvature on mid surface",
            inputs => [$native_mc_mid_left, $left_surfmap, $left_mid_surface],
            outputs => [$rsl_left_mid_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{left}, 
                     $left_mid_surface, $native_mc_mid_left, $left_surfmap, 
                     $rsl_left_mid_mc],
            prereqs => ["mean_curvature_${tkernel}mm_left_mid"] });

      # Important note: The surfmap file is always left-oriented, so the
      #                 mid_surface must also be left-oriented. Only the
      #                 connectivity is read, so pass the left_mid_surface,
      #                 as opposed to flipping the right_mid_surface. CL.
      ${$pipeline_ref}->addStage( {
            name => "resample_right_mean_curvature_${tkernel}mm_gray",
            label => "resample right mean curvature on gray surface",
            inputs => [$native_mc_gray_right, $right_surfmap, $left_mid_surface],
            outputs => [$rsl_right_gray_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{right}, 
                     $left_mid_surface, $native_mc_gray_right, $right_surfmap, 
                     $rsl_right_gray_mc],
            prereqs => [@$Prereqs, "mean_curvature_${tkernel}mm_right_gray"] });

      ${$pipeline_ref}->addStage( {
            name => "resample_right_mean_curvature_${tkernel}mm_white",
            label => "resample right mean curvature on white surface",
            inputs => [$native_mc_white_right, $right_surfmap, $left_mid_surface],
            outputs => [$rsl_right_white_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{right}, 
                     $left_mid_surface, $native_mc_white_right, $right_surfmap, 
                     $rsl_right_white_mc],
            prereqs => [@$Prereqs, "mean_curvature_${tkernel}mm_right_white"] });

      ${$pipeline_ref}->addStage( {
            name => "resample_right_mean_curvature_${tkernel}mm_mid",
            label => "resample right mean curvature on mid surface",
            inputs => [$native_mc_mid_right, $right_surfmap, $left_mid_surface],
            outputs => [$rsl_right_mid_mc],
            args => ["surface-resample", ${$image}->{surfregmodel}{right}, 
                     $left_mid_surface, $native_mc_mid_right, $right_surfmap, 
                     $rsl_right_mid_mc],
            prereqs => [@$Prereqs, "mean_curvature_${tkernel}mm_right_mid"] });

      push @Mean_Curvature_complete, "resample_left_mean_curvature_${tkernel}mm_gray";
      push @Mean_Curvature_complete, "resample_left_mean_curvature_${tkernel}mm_white";
      push @Mean_Curvature_complete, "resample_left_mean_curvature_${tkernel}mm_mid";
      push @Mean_Curvature_complete, "resample_right_mean_curvature_${tkernel}mm_gray";
      push @Mean_Curvature_complete, "resample_right_mean_curvature_${tkernel}mm_white";
      push @Mean_Curvature_complete, "resample_right_mean_curvature_${tkernel}mm_mid";

      ########################################################################
      ##### Combine fields for mean curvature for left+right hemispheres #####
      ########################################################################

      if( ${$image}->{combinesurfaces} ) {

        my $native_mc_gray_full = @{${$image}->{mc_gray}{full}}[$count];
        my $native_mc_white_full = @{${$image}->{mc_white}{full}}[$count];
        my $native_mc_mid_full = @{${$image}->{mc_mid}{full}}[$count];

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
      $count++;
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
    my $white_left = ${$image}->{white}{left};
    my $white_right = ${$image}->{white}{right};

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
      my $white_full = ${$image}->{white}{full};
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


sub cls_volumes {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $cls_correct = ${$image}->{cls_correct};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $output = ${$image}->{cls_volumes};

    #############################################################
    ##### Calculation of classified volumes in native space #####
    #############################################################

    ${$pipeline_ref}->addStage( {
         name => "cls_volumes",
         label => "compute tissue volumes in native space",
         inputs => [$t1_tal_xfm, $cls_correct, $gray_left, $gray_right],
         outputs => [$output],
         args => ["compute_icbm_vols", "-clobber", "-transform", $t1_tal_xfm,
                  "-invert", "-surface_mask", "$gray_left:$gray_right",
                  $cls_correct, $output],
         prereqs => $Prereqs });

    my $Cls_Volume_complete = [ "cls_volumes" ];

    return( $Cls_Volume_complete );
}


sub lobe_features {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $surface_labels_left = ${$image}->{surface_atlas}{left};
    my $surface_labels_right = ${$image}->{surface_atlas}{right};

    my @Lobe_complete = ();
    my $count = 0;
    foreach my $tmethod (@{${$image}->{tmethod}}) {
      foreach my $tkernel (@{${$image}->{tkernel}}) {

        ###################################################
        ##### Lobe parcellation of cortical thickness #####
        ###################################################

        my $lobe_thickness_left = @{${$image}->{lobe_thickness}{left}}[$count];
        my $lobe_thickness_right = @{${$image}->{lobe_thickness}{right}}[$count];
        my $native_rms_rsl_left = @{${$image}->{rms_rsl}{left}}[$count];
        my $native_rms_rsl_right = @{${$image}->{rms_rsl}{right}}[$count];

        ###########################
        ##### Left hemisphere #####
        ###########################

        ${$pipeline_ref}->addStage( {
             name => "${$image}->{surfaceatlas}_lobe_thickness_left_${tmethod}_${tkernel}mm",
             label => "native lobe thickness left ${tkernel}mm",
             inputs => [$native_rms_rsl_left],
             outputs => [$lobe_thickness_left],
             args => ["lobe_stats", "-norm", $native_rms_rsl_left,
                      $surface_labels_left, "average cortical thickness", 
                      $lobe_thickness_left],
             prereqs => $Prereqs });

        ############################
        ##### Right hemisphere #####
        ############################

        ${$pipeline_ref}->addStage( {
             name => "${$image}->{surfaceatlas}_lobe_thickness_right_${tmethod}_${tkernel}mm",
             label => "native lobe thickness right ${tkernel}mm",
             inputs => [$native_rms_rsl_right],
             outputs => [$lobe_thickness_right],
             args => ["lobe_stats", "-norm", $native_rms_rsl_right,
                      $surface_labels_right, "average cortical thickness", 
                      $lobe_thickness_right],
             prereqs => $Prereqs });
  
        push @Lobe_complete, "${$image}->{surfaceatlas}_lobe_thickness_left_${tmethod}_${tkernel}mm";
        push @Lobe_complete, "${$image}->{surfaceatlas}_lobe_thickness_right_${tmethod}_${tkernel}mm";
  
        ###############################################
        ##### Lobe parcellation of mean curvature #####
        ###############################################
#
# Note quite ready: need to repeat on gray, white, mid surfaces. CL.
####### IMPORTANT: Take this out of tmethod loop. CL.
#
#       if( ${$image}->{meancurvature} ) {

#         my $native_mc_rsl_left = @{${$image}->{mc_rsl}{left}}[$count];
#         my $native_mc_rsl_right = @{${$image}->{mc_rsl}{right}}[$count];
#         my $lobe_mc_left = @{${$image}->{lobe_mc}{left}}[$count];
#         my $lobe_mc_right = @{${$image}->{lobe_mc}{right}}[$count];

#         ###########################
#         ##### Left hemisphere #####
#         ###########################

#         ${$pipeline_ref}->addStage( {
#              name => "${$image}->{surfaceatlas}_lobe_mean_curvature_left_${tkernel}mm",
#              label => "native lobe mean curvature left ${tkernel}mm",
#              inputs => [$native_rms_rsl_left],
#              outputs => [$lobe_mc_left],
#              args => ["lobe_stats", "-norm", $native_mc_rsl_left,
#                       $surface_labels_left, "average absolute mean curvature", 
#                       $lobe_mc_left],
#              prereqs => $Prereqs });

#         ############################
#         ##### Right hemisphere #####
#         ############################
# 
#         ${$pipeline_ref}->addStage( {
#              name => "${$image}->{surfaceatlas}_lobe_mean_curvature_right_${tkernel}mm",
#              label => "native lobe mean curvature right ${tkernel}mm",
#              inputs => [$native_rms_rsl_right],
#              outputs => [$lobe_mc_right],
#              args => ["lobe_stats", "-norm", $native_mc_rsl_right,
#                       $surface_labels_right, "average absolute mean curvature", $lobe_mc_right],
#              prereqs => $Prereqs });

#         push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_mean_curvature_left_${tkernel}mm");
#         push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_mean_curvature_right_${tkernel}mm");
#       }
        $count++;
      }
    }

    if( ${$image}->{resamplesurfaces} ) {

      ###################################################
      ##### Lobe parcellation of cortex native area #####
      ###################################################

      my $gray_rsl_left = ${$image}->{gray_rsl}{left};
      my $gray_rsl_right = ${$image}->{gray_rsl}{right};
      my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

      ###########################
      ##### Left hemisphere #####
      ###########################

      ${$pipeline_ref}->addStage( {
         name => "${$image}->{surfaceatlas}_lobe_native_area_left",
         label => "native lobe area left",
         inputs => [$gray_rsl_left, $t1_tal_xfm],
         outputs => [${$image}->{native_lobe_areas}{left}],
         args => ["lobe_area", "-transform", $t1_tal_xfm, 
                  $gray_rsl_left, $surface_labels_left, 
                  ${$image}->{native_lobe_areas}{left} ],
         prereqs => $Prereqs });

      ############################
      ##### Right hemisphere #####
      ############################

      ${$pipeline_ref}->addStage( {
         name => "${$image}->{surfaceatlas}_lobe_native_area_right",
         label => "native lobe area right",
         inputs => [$gray_rsl_right, $t1_tal_xfm],
         outputs => [${$image}->{native_lobe_areas}{right}],
         args => ["lobe_area", "-transform", $t1_tal_xfm, 
                  $gray_rsl_right, $surface_labels_right, 
                  ${$image}->{native_lobe_areas}{right} ],
         prereqs => $Prereqs });

      push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_native_area_left");
      push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_native_area_right");

      #################################################################
      ##### Lobe parcellation of resampled elementary cortex area #####
      #################################################################

      $count = 0;
      foreach my $akernel (@{${$image}->{rsl_area_fwhm}}) {

        my $native_areas_rsl_left = @{${$image}->{surface_area_rsl}{left}}[$count];
        my $native_areas_rsl_right = @{${$image}->{surface_area_rsl}{right}}[$count];

        my $lobe_area_left = @{${$image}->{rsl_lobe_areas}{left}}[$count];
        my $lobe_area_right = @{${$image}->{rsl_lobe_areas}{right}}[$count];

        ###########################
        ##### Left hemisphere #####
        ###########################

        ${$pipeline_ref}->addStage( {
           name => "${$image}->{surfaceatlas}_lobe_area_left_${akernel}mm",
           label => "native lobe features left ${akernel}mm",
           inputs => [$native_areas_rsl_left],
           outputs => [$lobe_area_left],
           args => ["lobe_stats", $native_areas_rsl_left,
                    $surface_labels_left, "total cortical elementary area", 
                    $lobe_area_left ],
           prereqs => $Prereqs });

        ############################
        ##### Right hemisphere #####
        ############################
  
        ${$pipeline_ref}->addStage( {
           name => "${$image}->{surfaceatlas}_lobe_area_right_${akernel}mm",
           label => "native lobe area ${akernel}mm",
           inputs => [$native_areas_rsl_right],
           outputs => [$lobe_area_right],
           args => ["lobe_stats", $native_areas_rsl_right,
                    $surface_labels_right, "total cortical elementary area", 
                    $lobe_area_right],
           prereqs => $Prereqs });

        push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_area_left_${akernel}mm");
        push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_area_right_${akernel}mm");

        $count++;
      }

      ##############################################
      ##### Lobe parcellation of cortex volume #####
      ##############################################

      $count = 0;
      foreach my $vkernel (@{${$image}->{rsl_volume_fwhm}}) {

        my $native_volume_rsl_left = @{${$image}->{surface_volume_rsl}{left}}[$count];
        my $native_volume_rsl_right = @{${$image}->{surface_volume_rsl}{right}}[$count];

        my $lobe_volume_left = @{${$image}->{rsl_lobe_volumes}{left}}[$count];
        my $lobe_volume_right = @{${$image}->{rsl_lobe_volumes}{right}}[$count];

        ###########################
        ##### Left hemisphere #####
        ###########################

        ${$pipeline_ref}->addStage( {
             name => "${$image}->{surfaceatlas}_lobe_volume_left_${vkernel}mm",
             label => "native lobe vertex-volumes left ${vkernel}mm",
             inputs => [$native_volume_rsl_left],
             outputs => [$lobe_volume_left],
             args => ["lobe_stats", $native_volume_rsl_left,
                      $surface_labels_left, "total cortical volume", $lobe_volume_left],
             prereqs => $Prereqs });

        ############################
        ##### Right hemisphere #####
        ############################

        ${$pipeline_ref}->addStage( {
             name => "${$image}->{surfaceatlas}_lobe_volume_right_${vkernel}mm",
             label => "native lobe vertex-volumes right ${vkernel}mm",
             inputs => [$native_volume_rsl_right],
             outputs => [$lobe_volume_right],
             args => ["lobe_stats", $native_volume_rsl_right,
                      $surface_labels_right, "total cortical volume", $lobe_volume_right],
             prereqs => $Prereqs });

        push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_volume_left_${vkernel}mm");
        push @Lobe_complete, ("${$image}->{surfaceatlas}_lobe_volume_right_${vkernel}mm");

        $count++;
      }
    }
    return( \@Lobe_complete );
}


1;
