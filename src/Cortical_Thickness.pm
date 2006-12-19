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

    my $native_rms_left = ${$image}->{rms}{left};
    my $native_rms_right = ${$image}->{rms}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $stx_labels_masked = ${$image}->{stx_labels_masked};

    #################################################################################
    ##### Calculation of the cortical thickness and cortex area in native space #####
    #################################################################################

    ###########################
    ##### Left hemisphere #####
    ###########################

    ${$pipeline_ref}->addStage(
         { name => "thickness_left",
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
         { name => "thickness_right",
         label => "native thickness",
         inputs => [$white_right, $gray_right, $t1_tal_xfm],
         outputs => [$native_rms_right],
         args => ["cortical_thickness", "-${tmethod}", "-fwhm", ${tkernel}, 
                  "-transform", $t1_tal_xfm,
                  $white_right, $gray_right, $native_rms_right],
         prereqs => $Prereqs });

    my $Cortical_Thickness_complete = ["thickness_left", "thickness_right"];

    return( $Cortical_Thickness_complete );

}


1;
