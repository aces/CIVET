# The Segmentation stages

# ANIMAL essentially maps the images to a probabilistic atlas developed
# from the ICBM database. Bain lobes and major brain organelles are identified
# in the atlas, and each voxel is then given a probability value of being in
# that lobe or organelle. These stages will also calculate the volume of the
# identified lobes.

package Segment;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $Second_Model_Dir = @_[3];

    # global files for segmentation

    my $stx_labels        = ${$image}->{stx_labels};
    my $label_volumes     = ${$image}->{label_volumes};
    my $lobe_volumes      = ${$image}->{lobe_volumes};
    my $stx_labels_masked = ${$image}->{stx_labels_masked}; 
    my $t1_tal_xfm        = ${$image}->{t1_tal_xfm};
    my $t1_tal_nl_xfm     = ${$image}->{t1_tal_nl_xfm};
    my $cls_correct       = ${$image}->{cls_correct};
    my $skull_mask        = ${$image}->{skull_mask_tal};

    # extra files

    my $identity = "${Second_Model_Dir}/identity.xfm";

### Note: In below, $cls_correct in based on $skull_mask, so it
###       contains the cerebellum and brain stem.

    ${$pipeline_ref}->addStage(
         { name => "segment",
         label => "automatic labelling",
         inputs => [$t1_tal_nl_xfm, $cls_correct],
         outputs => [$stx_labels],
         args => ["stx_segment", "-clobber", "-symmetric_atlas",
                  $t1_tal_nl_xfm, $identity, $cls_correct, $stx_labels],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
         { name => "segment_volumes",
         label => "label and compute lobe volumes in native space",
         inputs => [$t1_tal_xfm, $stx_labels],
         outputs => [$label_volumes, $lobe_volumes],
         args => ["compute_icbm_vols", "-clobber", "-transform", 
                  $t1_tal_xfm, "-invert", "-lobe_volumes", 
                  $lobe_volumes, $stx_labels, $label_volumes],
         prereqs => ["segment"] });

    my $seg_mask_expr = 'if(A[1]<0.5){out=0;}else{out=A[0];}';

    ${$pipeline_ref}->addStage(
         { name => "segment_mask",
         label => "mask the segmentation",
         inputs => [$stx_labels, $skull_mask],
         outputs => [$stx_labels_masked],
         args => ["minccalc", "-clobber", "-expr", $seg_mask_expr,
                  $stx_labels, $skull_mask, $stx_labels_masked],
         prereqs => ["segment_volumes"] });

    my $Segment_complete = ["segment_mask"];

    return( $Segment_complete );
}

1;
