#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# Removes the skull and meninges (in Talairach space)

package Cortex_Mask;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $xfm = ${$image}->{t1_tal_nl_xfm};
    my $cls = ${$image}->{cls_correct};
    my $pve_csf = ${$image}->{pve_csf};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $brain_mask = ${$image}->{brain_mask};

    ##############################################
    ##### Second mask using cortical_surface #####
    ##############################################

    ${$pipeline_ref}->addStage(
         { name => "cortical_masking",
         label => "masking cortical tissues using cortical_surface",
         inputs => [$xfm, $skull_mask, $cls, $pve_csf],
         outputs => [$brain_mask],
         args => ["cortical_mask", $cls, $pve_csf, $skull_mask, 
                  $brain_mask, $xfm ],
         prereqs => $Prereqs });

    my $Cortex_Mask_complete = ["cortical_masking"];

    return( $Cortex_Mask_complete );
}


1;
