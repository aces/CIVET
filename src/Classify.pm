#Discrete classification and partial volume estimation

package Classify;
use strict;
use PMP::PMP;
use MRI_Image;

# Partial volume estimator on masked brain to obtain
# final discrete classification.

sub pve {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $inputType = ${$image}->{inputType};

    my $t1_input = ${$image}->{t1}{final};
    my $t2_input = ${$image}->{t2}{final};
    my $pd_input = ${$image}->{pd}{final};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $t1_tal_nl_xfm = ${$image}->{t1_tal_nl_xfm};

    # these are in temp/ dir
    my $pve_curve_prefix = ${$image}->{curve_prefix};
    my $pve_curvature = ${$image}->{curve_cg};

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
      if( -e ${$image}->{t2}{native} and -e ${$image}->{pd}{native} ) {
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

    ${$pipeline_ref}->addStage(
         { name => "mask_classify",
         label => "tissue classification",
         inputs => [$skull_mask, @classify_images],
         outputs => [$cls_clean],
         args => ["classify_clean", "-clobber", "-clean_tags",
                  "-mask", $skull_mask, "-mask_classified", "-mask_tag",
                  "-tagfile", "ntags_1000_prob_90_nobg.tag",
                  "-tag_transform", $t1_tal_nl_xfm,
                  @classify_images, $cls_clean],
         prereqs => $Prereqs });

    # Compute pve maps based on masked brain.
    # Note: This needs to be extended to multispectral somehow. The
    #       effect of curve_cg is to enhance the pve_csf, so it is
    #       very useful. However, pd image may yield a better definition
    #       of the csf than t1.

    ${$pipeline_ref}->addStage(
         { name => "pve_curvature",
         label => "curvature map from MRI",
         inputs => [$t1_input, $cls_clean, $skull_mask],
         outputs => [$pve_curvature],
         args => ["pve_curvature", "-clobber", $t1_input,
                  $cls_clean, $skull_mask, $pve_curve_prefix],
         prereqs => ["mask_classify"] });

    ${$pipeline_ref}->addStage(
         { name => "pve",
         label => "partial volume estimation",
         inputs => [$pve_curvature, @classify_images,
                   $skull_mask, $cls_clean],
         outputs => [$pve_gm, $pve_wm, $pve_csf],
         args => ["pve_script", "-clobber", "-nosubcortical", "-curve",
                  $pve_curvature, "-mask", $skull_mask,
                  "-image", $cls_clean, @classify_images,
                  $pve_prefix],
         prereqs => ["pve_curvature"] });

    # Rebinarize the final masked pve maps.

    ${$pipeline_ref}->addStage(
         { name => "reclassify",
         label => "rebinarize PVE maps",
         inputs => [$pve_csf, $pve_wm, $pve_gm],
         outputs => [$cls_correct],
         args => ["discretize_pve", "-clobber", $pve_csf,
                  $pve_wm, $pve_gm, $cls_correct],
         prereqs => [ "pve" ] });

    #Must now set the completion condition.

    my $Classify_complete = ["reclassify"];

    return( $Classify_complete );
}



1;
