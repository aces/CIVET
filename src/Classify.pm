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

# Partial volume estimator on masked brain to obtain
# final discrete classification.

sub pve {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $model_vent_cereb_mask = @_[3];
    my $model_subcortical_mask = @_[4];

    my $inputType = ${$image}->{inputType};
    my $correctPVE = ${$image}->{correctPVE};
    my $maskCerebellum = ${$image}->{maskcerebellum};
    my $scGM_PVE = ${$image}->{pve_subcortical};

    my $t1_input = ${$image}->{t1}{final};
    my $t2_input = ${$image}->{t2}{final};
    my $pd_input = ${$image}->{pd}{final};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $t1_tal_nl_xfm = ${$image}->{t1_tal_nl_xfm};
    my $model_headmask = "${$image}->{nlinmodel}_headmask.mnc";
    my $subcortical_mask = ${$image}->{subcortical_mask};

    my $pve_prefix  = ${$image}->{pve_prefix};
    my $pve_gm      = ${$image}->{pve_gm};
    my $pve_wm      = ${$image}->{pve_wm};
    my $pve_csf     = ${$image}->{pve_csf};
    my $pve_sc      = ${$image}->{pve_sc};
    my $pve_disc    = ${$image}->{pve_disc};

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
         inputs => [$skull_mask, @classify_images, $t1_tal_nl_xfm],
         outputs => [$cls_clean],
         args => ["classify_clean", "-clobber", "-clean_tags", "-mask_source",
                  "-mask", $skull_mask, "-mask_classified", "-mask_tag",
                  "-tagdir", ${$image}->{tagdir},
                  "-tagfile", ${$image}->{tagfile},
                  "-bgtagfile", ${$image}->{bgtagfile},
                  "-tag_transform", $t1_tal_nl_xfm,
                  @classify_images, $cls_clean],
         prereqs => $Prereqs });

    # Transform $model_vent_cereb_mask from the model to the subject.
    # This is the model with the ventricles, brainstem, cerebellum.
    # We keep the ouptut since we'll need it elsewhere later.
    # Note: should change the name of output in MRI_Image.

    ${$pipeline_ref}->addStage( {
         name => "cereb_vent_mask",
         label => "transform cereb+vent mask to subject",
         inputs => [$cls_clean, $t1_tal_nl_xfm],
         outputs => [$subcortical_mask],
         args => ["mincresample", "-clobber", "-quiet", "-like", $cls_clean, 
                  "-transform", $t1_tal_nl_xfm, "-nearest", "-invert", 
                  $model_vent_cereb_mask, $subcortical_mask],
         prereqs => ["mask_classify"] });

    # Set up options for pve:

    my $Classify_complete = undef;

    my @extraPVE = ();
    push @extraPVE, ("-iterate") if( $correctPVE );
    push @extraPVE, ("-restrict");
    push @extraPVE, ($skull_mask);

    # For pve_outputs, make order csf, wm, gm, [sc] for discretize_pve.
    my @pve_inputs = @classify_images;
    my @pve_outputs = ( $pve_csf, $pve_wm, $pve_gm );

    # Create SC tissue class for sub-cortical gray.

    if( $scGM_PVE ) {
      push @pve_outputs, ($pve_sc);
      push @extraPVE, "-subcortical";
      push @extraPVE, $model_subcortical_mask;
    }

    if( $maskCerebellum ) {
      push @extraPVE, "-noncortical_mask";
      push @extraPVE, $subcortical_mask;  # this is model_vent_cereb_mask
    }

    ${$pipeline_ref}->addStage( {
         name => "pve",
         label => "partial volume estimation",
         inputs => [@pve_inputs, $cls_clean, $t1_tal_nl_xfm],
         outputs => [@pve_outputs],
         args => ["pve_script", "-clobber", @extraPVE,
                  "-classify", "-mask", $model_headmask,
                  '-curve', 'auto', "-nlxfm", $t1_tal_nl_xfm, 
                  '-image', $cls_clean, @classify_images, $pve_prefix],
         prereqs => ["mask_classify","cereb_vent_mask"] });

    $Classify_complete = ["pve"];

    return( $Classify_complete );
}

1;
