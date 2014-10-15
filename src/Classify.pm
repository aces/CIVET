#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
#Discrete classification and partial volume estimation

package Classify;
use strict;
use PMP::PMP;
use MRI_Image;

# Version of pve to use:
my $OLD_PVE = 0;

# Partial volume estimator on masked brain to obtain
# final discrete classification.

sub pve {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $inputType = ${$image}->{inputType};
    my $correctPVE = ${$image}->{correctPVE};

    my $t1_input = ${$image}->{t1}{final};
    my $t2_input = ${$image}->{t2}{final};
    my $pd_input = ${$image}->{pd}{final};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $t1_tal_nl_xfm = ${$image}->{t1_tal_nl_xfm};
    my $model_headmask = "${$image}->{nlinmodel}_headmask.mnc";

    my $pve_prefix  = ${$image}->{pve_prefix};
    my $pve_gm      = ${$image}->{pve_gm};
    my $pve_wm      = ${$image}->{pve_wm};
    my $pve_csf     = ${$image}->{pve_csf};

    my $cls_clean    = ${$image}->{cls_clean};
    my $cls_correct  = ${$image}->{cls_correct};

    #####################################
    ##### The classification stages #####
    #####################################

    # Explanation:
    # These are the steps that produce 'discretely' classified (segmented)
    # images from the final images. Basically, using classify_clean
    # (the main component of INSECT), the intensity of each voxel puts it
    # into one of 4 categories: Gray matter, white matter, CSF, or background.

    my @classify_images = ($t1_input);
    if ($inputType eq "multispectral") {
      if( -e ${$image}->{t2}{source} and -e ${$image}->{pd}{source} ) {
        push @classify_images, ($t2_input);
        push @classify_images, ($pd_input);
      } else {
        print "Warning: need both t2 and pd images for multispectral classification.\n";
      }
    }

    # Discrete classification on masked brain.

    # Note: We run with tags without background since skull
    #       and unwanted tissues have been removed in the mask.
    #       We use $skull_mask instead of $brain_mask since 
    #       $skull_mask (from mincbet) keeps the cerebellum
    #       which contains a lot of the tag points, for a better
    #       sampling of the voxels of gray intensity.

    ${$pipeline_ref}->addStage( {
         name => "mask_classify",
         label => "tissue classification",
         inputs => [$skull_mask, @classify_images],
         outputs => [$cls_clean],
         args => ["classify_clean", "-clobber", "-clean_tags", "-mask_source",
                  "-mask", $skull_mask, "-mask_classified", "-mask_tag",
                  "-tagdir", ${$image}->{tagdir},
                  "-tagfile", ${$image}->{tagfile},
                  "-bgtagfile", ${$image}->{bgtagfile},
                  "-tag_transform", $t1_tal_nl_xfm,
                  @classify_images, $cls_clean],
         prereqs => $Prereqs });

    my @extraPVE = ();
    push @extraPVE, ("-iterate") if( $correctPVE );

    # Use the head mask to extend pve classification 
    # outside brain mask. Note that cls_clean is masked,
    # but pve_classify will not be (to avoid losing bits
    # of classified tissue due to masking). Linear mask
    # is ok, no need for non-linear here.

    if( $OLD_PVE ) {
      ${$pipeline_ref}->addStage( {
           name => "pve",
           label => "partial volume estimation",
           inputs => [@classify_images, $cls_clean],
           outputs => [$pve_gm, $pve_wm, $pve_csf],
           args => ["pve_script", "-clobber", "-nosubcortical", @extraPVE,
                    "-curve", "auto", "-mask", $model_headmask,
                    "-image", $cls_clean, @classify_images,
                    $pve_prefix],
           prereqs => ["mask_classify"] });

      # Rebinarize the final masked pve maps.

      ${$pipeline_ref}->addStage(
           { name => "reclassify",
           label => "rebinarize PVE maps",
           inputs => [$pve_csf, $pve_wm, $pve_gm],
           outputs => [$cls_correct],
           args => ["discretize_pve", "-clobber", $pve_csf,
                    $pve_wm, $pve_gm, $cls_correct],
           prereqs => [ "pve" ] });

    } else {

      ${$pipeline_ref}->addStage( {
           name => "pve",
           label => "partial volume estimation",
           inputs => [@classify_images, $cls_clean],
           outputs => [$pve_gm, $pve_wm, $pve_csf, $cls_correct],
           args => ["pve_script", "-clobber", "-nosubcortical", @extraPVE,
                    "-curve", "auto", "-mask", $model_headmask,
                    "-image", $cls_clean, "-classify", @classify_images,
                    $pve_prefix],
           prereqs => ["mask_classify"] });
    }

    # Must now set the completion condition.

    my $Classify_complete = ["pve"];

    return( $Classify_complete );
}

1;
