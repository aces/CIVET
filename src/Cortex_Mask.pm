# Removes the skull and meninges (in Talairach space)

package Cortex_Mask;
use strict;
use PMP::PMP;
use MRI_Image;


sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $cls_clean = ${$image}->{cls_clean};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $cortex = ${$image}->{cortex};
    my $brain_mask = ${$image}->{brain_mask};

    ##############################################
    ##### Second mask using cortical_surface #####
    ##############################################

    ${$pipeline_ref}->addStage(
         { name => "cortical_masking",
         label => "masking cortical tissues based on classified image using cortical_surface",
         inputs => [$skull_mask, $cls_clean],
         outputs => [$cortex, $brain_mask],
         args => ["cortical_mask", $cls_clean, $cortex, 
                  $skull_mask, $brain_mask],
         prereqs => $Prereqs });

    my $Cortex_Mask_complete = ["cortical_masking"];

    return( $Cortex_Mask_complete );
}


1;
