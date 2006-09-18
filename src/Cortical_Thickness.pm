# Compute the cortical thickness.

package Cortical_Thickness;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $tkernel = ${$image}->{tkernel};
    my $tmethod = ${$image}->{tmethod};

    my $white_left = ${$image}->{white}{cal_left};
    my $white_right = ${$image}->{white}{cal_right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $mid_left = ${$image}->{mid}{left};
    my $mid_right = ${$image}->{mid}{right};
    my $native_rms_left = ${$image}->{rms}{left};
    my $native_rms_right = ${$image}->{rms}{right};
    my $native_rms_blur_left = ${$image}->{rms_blur}{left};
    my $native_rms_blur_right = ${$image}->{rms_blur}{right};

    #################################################
    ##### Calculation of the cortical thickness #####
    #################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage(
         { name => "thickness_left",
         label => "native thickness",
         inputs => [$white_left, $gray_left],
         outputs => [$native_rms_left],
         args => ["cortical_thickness", "-clobber", "-${tmethod}", $white_left,
                  $gray_left, $native_rms_left],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "mid_surface_left",
         label => "create intermediate left surface",
         inputs => [$white_left, $gray_left],
         outputs => [$mid_left],
         args => ["average_surfaces", $mid_left, "none", "none", 1,
                  $gray_left, $white_left],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "thickness_blur_left",
         label => "blurred thickness",
         inputs => [$mid_left, $native_rms_left],
         outputs => [$native_rms_blur_left],
         args => ["diffuse", "-kernel", $tkernel, "-iterations", 1000,
                  "-parametric", 1, $mid_left, $native_rms_left,
                  $native_rms_blur_left],
         prereqs => ["thickness_left","mid_surface_left"] });

    ############################
    ##### Right hemisphere #####
    ############################

    ${$pipeline_ref}->addStage(
         { name => "thickness_right",
         label => "native thickness",
         inputs => [$white_right, $gray_right],
         outputs => [$native_rms_right],
         args => ["cortical_thickness", "-clobber", "-${tmethod}", $white_right,
                  $gray_right, $native_rms_right],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "mid_surface_right",
         label => "create intermediate right surface",
         inputs => [$white_right, $gray_right],
         outputs => [$mid_right],
         args => ["average_surfaces", $mid_right, "none", "none", 1,
                  $gray_right, $white_right],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "thickness_blur_right",
         label => "blurred thickness",
         inputs => [$mid_right, $native_rms_right],
         outputs => [$native_rms_blur_right],
         args => ["diffuse", "-kernel", $tkernel, "-iterations", 1000,
                  "-parametric", 1, $mid_right, $native_rms_right,
                  $native_rms_blur_right],
         prereqs => ["thickness_right","mid_surface_right"] });


    my $Cortical_Thickness_complete = ["thickness_blur_left", 
                                       "thickness_blur_right"];

    return( $Cortical_Thickness_complete );

}


1;
