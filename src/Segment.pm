#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# The Segmentation stages

# ANIMAL essentially maps the images to a probabilistic atlas developed
# from the ICBM database. Bain lobes and major brain organelles are identified
# in the atlas, and each voxel is then given a probability value of being in
# that lobe or organelle. These stages will also calculate the volume of the
# identified lobes.

package Segment;
use strict;
use FindBin;
use lib "$FindBin::Bin";

use PMP::PMP;
use MRI_Image;

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $Template = @_[3];
    my $animal_model = @_[4];
    my $animal_nl_model = @_[5];

    # global files for segmentation

    my $animal_labels        = ${$image}->{animal_labels};
    my $lobe_volumes         = ${$image}->{lobe_volumes};
    my $animal_labels_masked = ${$image}->{animal_labels_masked}; 
    my $t1_tal_mnc           = ${$image}->{t1}{final};
    my $t1_tal_nl_animal_xfm = ${$image}->{t1_tal_nl_xfm};
    my $t1_tal_xfm           = ${$image}->{t1_tal_xfm};
    my $cls_correct          = ${$image}->{cls_correct};
    my $skull_mask           = ${$image}->{skull_mask_tal};

    # extra files

    my $identity = "$FindBin::Bin/models/identity.xfm";

    # Compute the non-linear transformation to the model of the atlas,
    # if not the same as the target for registration.

    if( ${animal_nl_model} ne ${$image}->{nlinmodel} ) {
      # Not pretty, but must add extension .mnc to model name (because stx_register uses
      # the same model, but without the .mnc extension).
      my $Non_Linear_Target = "${animal_nl_model}.mnc";
      my $model_head_mask = "${animal_nl_model}_mask.mnc";
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

    ${$pipeline_ref}->addStage( {
         name => "segment",
         label => "automatic labelling",
         inputs => [$t1_tal_nl_animal_xfm, $cls_correct],
         outputs => [$animal_labels],
         args => ["lobe_segment", "-clobber", "-modeldir", $animal_model,
                  $t1_tal_nl_animal_xfm, $identity, "-template", $Template,
                  $cls_correct, $animal_labels],
         prereqs => $Prereqs } );

    ${$pipeline_ref}->addStage( {
         name => "segment_volumes",
         label => "label and compute lobe volumes in native space",
         inputs => [$t1_tal_xfm, $animal_labels],
         outputs => [$lobe_volumes],
         args => ["compute_icbm_vols", "-clobber", "-transform", 
                  $t1_tal_xfm, "-invert", $animal_labels, $lobe_volumes],
         prereqs => ["segment"] });

    my $seg_mask_expr = 'if(A[1]<0.5){out=0;}else{out=A[0];}';
    ${$pipeline_ref}->addStage( {
         name => "segment_mask",
         label => "mask the segmentation",
         inputs => [$animal_labels, $skull_mask],
         outputs => [$animal_labels_masked],
         args => ["minccalc", "-clobber", "-expr", $seg_mask_expr,
                  $animal_labels, $skull_mask, $animal_labels_masked],
         prereqs => ["segment"] });

    my $Segment_complete = ["segment_mask", "segment_volumes" ];

    return( $Segment_complete );
}

1;
