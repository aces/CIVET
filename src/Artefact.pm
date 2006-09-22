#Compute susceptability artefacts.

package Artefact;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $t1_input = ${$image}->{t1}{final};
    my $brain_mask = ${$image}->{brain_mask};

    my $cls_artefact = ${$image}->{artefact};

    # The output of this stage is used in quality control (see Oliver).
    # I guess this stage could use $skull_mask.

    ${$pipeline_ref}->addStage(
         { name => "artefact",
         label => "susceptability artefacts",
         inputs => [$brain_mask, $t1_input],
         outputs => [$cls_artefact],
         args => ["class_art", "0.15", "4", $brain_mask,
                  $t1_input, $cls_artefact],
         prereqs => $Prereqs});

    #Must now set the completion condition.

    my $Artefact_complete = ["artefact"];

    return( $Artefact_complete );
}

1;
