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
    my $Template = @_[3];
    my $Second_Model_Dir = @_[4];
    my $atlas = @_[5];
    my $atlasdir = @_[6];
    my $nl_model = @_[7];

    # global files for segmentation

    my $stx_labels        = ${$image}->{stx_labels};
    my $label_volumes     = ${$image}->{label_volumes};
    my $lobe_volumes      = ${$image}->{lobe_volumes};
    my $stx_labels_masked = ${$image}->{stx_labels_masked}; 
    my $cls_volumes       = ${$image}->{cls_volumes};
    my $t1_tal_mnc        = ${$image}->{t1}{final};
    my $t1_tal_nl_animal_xfm = ${$image}->{t1_tal_nl_xfm};
    my $t1_tal_xfm        = ${$image}->{t1_tal_xfm};
    my $cls_correct       = ${$image}->{cls_correct};
    my $skull_mask        = ${$image}->{skull_mask_tal};

    # extra files

    my $identity = "${Second_Model_Dir}/identity.xfm";

    # Compute the non-linear transformation to the model of the atlas,
    # if not the same as the target for registration.

    if( ${nl_model} ne ${$image}->{nlinmodel} ) {
      # Not pretty, but must add extension .mnc to model name (because stx_register uses
      # the same model, but without the .mnc extension).
      my $Non_Linear_Target = "${nl_model}.mnc";
      my $model_head_mask = "${nl_model}_mask.mnc";
      $t1_tal_nl_animal_xfm = ${$image}->{t1_tal_nl_animal_xfm};

      ${$pipeline_ref}->addStage( {
           name => "nlfit_animal",
           label => "creation of nonlinear transform for ANIMAL segmentation",
           inputs => [$t1_tal_mnc, $skull_mask ],
           outputs => [$t1_tal_nl_animal_xfm],
           args => ["best1stepnlreg.pl", "-clobber", "-source_mask", $skull_mask,
                    "-normalize", "-target_mask", $model_head_mask, $t1_tal_mnc,
                    $Non_Linear_Target, $t1_tal_nl_animal_xfm],
           prereqs => $Prereqs } );
      $Prereqs = [ "nlfit_animal" ];
    }

    ### Note: In below, $cls_correct in based on $skull_mask, so it
    ###       contains the cerebellum and brain stem.

    # Use the old stx_segment or the new lobe_segment.

    if( $atlas eq "-symmetric_atlas" ) {
      ${$pipeline_ref}->addStage( {
           name => "segment",
           label => "automatic labelling",
           inputs => [$t1_tal_nl_animal_xfm, $cls_correct],
           outputs => [$stx_labels],
           args => ["stx_segment", "-clobber", $atlas, "-modeldir", $atlasdir,
                    $t1_tal_nl_animal_xfm, $identity, "-template", $Template,
                    $cls_correct, $stx_labels],
           prereqs => $Prereqs } );

      # to do: use -lobe_mapping to specify mapping file to lobes:
      # $LobeMap = "$FindBin::Bin/../share/jacob/" . 
      #            'seg/jacob_atlas_brain_fine_remap_to_lobes.dat';
      ${$pipeline_ref}->addStage( {
           name => "segment_volumes",
           label => "label and compute lobe volumes in native space",
           inputs => [$t1_tal_xfm, $stx_labels],
           outputs => [$label_volumes, $lobe_volumes],
           args => ["compute_icbm_vols", "-clobber", "-transform", 
                    $t1_tal_xfm, "-invert", "-lobe_volumes", 
                    $lobe_volumes, $stx_labels, $label_volumes],
           prereqs => ["segment"] });
    } else {
      ${$pipeline_ref}->addStage( {
           name => "segment",
           label => "automatic labelling",
           inputs => [$t1_tal_nl_animal_xfm, $cls_correct],
           outputs => [$stx_labels],
           args => ["lobe_segment", "-clobber", "-modeldir", $atlasdir,
                    $t1_tal_nl_animal_xfm, $identity, "-template", $Template,
                    $cls_correct, $stx_labels],
           prereqs => $Prereqs } );

      # check this: label_volumes and lobe_volumes should be the same here.
      ${$pipeline_ref}->addStage( {
           name => "segment_volumes",
           label => "label and compute lobe volumes in native space",
           inputs => [$t1_tal_xfm, $stx_labels],
           outputs => [$label_volumes],
           args => ["compute_icbm_vols", "-clobber", "-transform", 
                    $t1_tal_xfm, "-invert", $stx_labels, $label_volumes],
           prereqs => ["segment"] });
    }

    my $seg_mask_expr = 'if(A[1]<0.5){out=0;}else{out=A[0];}';

    ${$pipeline_ref}->addStage( {
         name => "segment_mask",
         label => "mask the segmentation",
         inputs => [$stx_labels, $skull_mask],
         outputs => [$stx_labels_masked],
         args => ["minccalc", "-clobber", "-expr", $seg_mask_expr,
                  $stx_labels, $skull_mask, $stx_labels_masked],
         prereqs => ["segment"] });

    ${$pipeline_ref}->addStage( {
         name => "cls_volumes",
         label => "compute tissue volumes in native space",
         inputs => [$t1_tal_xfm, $cls_correct],
         outputs => [$cls_volumes],
         args => ["compute_icbm_vols", "-clobber", "-transform", $t1_tal_xfm,
                  "-invert", $cls_correct, $cls_volumes],
         prereqs => $Prereqs });

    my $Segment_complete = ["segment_mask", "segment_volumes", "cls_volumes"];

    return( $Segment_complete );
}

1;
