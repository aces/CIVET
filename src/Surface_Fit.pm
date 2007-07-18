################################
#### Cortical fitting steps ####
################################

# Explanation:
# The surfaces produced here by CLASP are a result of a deforming ellipsoid
# model that shrinks inward in an iterative fashion until it finds the inner
# surface of the cortex that is produced by the interface between gray matter
# and white matter. This surface is frequently referred to as the
# 'white-surface'. The surface is a polygonal (triangulated) mesh, each point 
# on which is referred to as a 'vertex'. Once this surface is produced, a
# process of expansion outwards towards the CSF skeleton follows. This process
# is governed by laplacian fluid dynamics and attempts to find the best fit for
# the pial surface (or gray-surface) taking into account the partial volume
# information. Since this surface is an expansion from the white-surface, each
# vertex on the new surface is 'linked' to an original vertex on the
# white-surface. CLASP now produces two seperate hemispheres, each with an 82k
# polygonal mesh.

package Surface_Fit;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $claspOption = @_[3];          # not yet used
    my $Second_model_Dir = @_[4];

    my $pve_wm  = ${$image}->{pve_wm};
    my $pve_csf = ${$image}->{pve_csf};

    my $cls_correct    = ${$image}->{cls_correct};
    my $t1_tal_mnc     = ${$image}->{t1}{final};
    my $nl_transform   = ${$image}->{t1_tal_nl_xfm};
    my $final_callosum = ${$image}->{final_callosum};
    my $final_classify = ${$image}->{final_classify};
    my $skel_csf       = ${$image}->{csf_skel};
    my $brain_mask     = ${$image}->{brain_mask};
    my $laplace_field  = ${$image}->{laplace};

    my $model_mask      = "${Second_model_Dir}/Cerebellum_Ventricles_SubCortical_Mask.mnc";
    my $slide_left_xfm  = "${Second_model_Dir}/slide_left.xfm";
    my $slide_right_xfm = "${Second_model_Dir}/slide_right.xfm";
    my $flip_right_xfm  = "${Second_model_Dir}/flip_right.xfm";

    # Final surfaces in stereotaxic space
    my $left_hemi_white = ${$image}->{white}{left};
    my $right_hemi_white = ${$image}->{white}{right};
    my $left_hemi_white_calibrated = ${$image}->{white}{cal_left};
    my $right_hemi_white_calibrated = ${$image}->{white}{cal_right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $mid_surface_left = ${$image}->{mid_surface}{left};
    my $mid_surface_right = ${$image}->{mid_surface}{right};

    my $surface_qc = ${$image}->{surface_qc};

    # a bunch of temporary files that should be cleaned up.

    my $wm_left_centered  = ${$image}->{wm_left_centered};
    my $wm_right_centered = ${$image}->{wm_right_centered};
    my $white_surf_left_prelim = ${$image}->{white}{left_prelim};
    my $white_surf_right_prelim = ${$image}->{white}{right_prelim};
    my $white_surf_right_prelim_flipped = ${$image}->{white}{right_prelim_flipped};

# ---------------------------------------------------------------------------
#  Step 1: Application of the custom mask (ventricules, cerebellum,
#          sub-cortical gray) and final classification for surface
#          extraction.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "surface_classify",
          label => "fix the classification for surface extraction",
          inputs => [$cls_correct, $pve_wm, $pve_csf, $nl_transform ],
          outputs => [$final_callosum, $final_classify, $skel_csf],
          args => ["surface_fit_classify", $cls_correct, $pve_wm, $pve_csf, 
                   $final_callosum, $final_classify, $skel_csf,
                   $nl_transform, $Second_model_Dir ],
          prereqs => $Prereqs }
          );

# ---------------------------------------------------------------------------
#  Step 2: Extraction of the white matter mask for the hemispheres.
# ---------------------------------------------------------------------------

    my $user_mask = ${$image}->{user_mask};  # not a PMP input
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    ${$pipeline_ref}->addStage(
          { name => "create_wm_hemispheres",
          label => "create white matter hemispheric masks",
          inputs => [$final_classify, $t1_tal_mnc, $brain_mask, $t1_tal_xfm],
          outputs => [$wm_left_centered, $wm_right_centered],
          args=>["extract_wm_hemispheres", $final_classify, $t1_tal_mnc,
                 $brain_mask, $user_mask, $t1_tal_xfm,
                 $Second_model_Dir, $wm_left_centered, 
                 $wm_right_centered],
          prereqs =>["surface_classify"] }
          );

# ---------------------------------------------------------------------------
#  Step 3: Extraction of the white surfaces
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "extract_white_surface_left",
          label => "extract white left surface in Talairach",
          inputs => [$wm_left_centered], 
          outputs => [$white_surf_left_prelim],
          args => ["extract_white_surface", $wm_left_centered,
                  $white_surf_left_prelim, 0.5],
          prereqs => ["create_wm_hemispheres"] }
          );

    ${$pipeline_ref}->addStage(
          { name => "extract_white_surface_right",
          label => "extract white right surface in Talairach",
          inputs => [$wm_right_centered],
          outputs => [$white_surf_right_prelim],
          args => ["extract_white_surface", $wm_right_centered,
                  $white_surf_right_prelim, 0.5],
          prereqs => ["create_wm_hemispheres"] }
          );

    ${$pipeline_ref}->addStage(
          { name => "slide_left_hemi_obj_back",
          label => "move left hemi obj to left",
          inputs => [$white_surf_left_prelim],
          outputs => [$left_hemi_white],
          args => ["transform_objects", $white_surf_left_prelim, $slide_left_xfm,
                  $left_hemi_white] ,
          prereqs =>["extract_white_surface_left"] }
          );
 
    ${$pipeline_ref}->addStage(
          { name => "flip_right_hemi_obj_back",
          label => "flip right hemi obj back to resemble right side",
          inputs => [$white_surf_right_prelim],
          outputs => [$white_surf_right_prelim_flipped],
          args => ["transform_objects", $white_surf_right_prelim, 
                   $flip_right_xfm,
                  $white_surf_right_prelim_flipped] ,
          prereqs =>["extract_white_surface_right"] }
          );

    ${$pipeline_ref}->addStage(
          { name => "slide_right_hemi_obj_back",
          label => "move right hemi obj to right",
          inputs => [$white_surf_right_prelim_flipped],
          outputs => [$right_hemi_white],
          args => ["transform_objects", $white_surf_right_prelim_flipped, $slide_right_xfm,
                  $right_hemi_white] ,
          prereqs =>["flip_right_hemi_obj_back"] }
          );


# ---------------------------------------------------------------------------
#  Step 3: Calibrate white_surface wite a gradient field
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "calibrate_left_white",
          label => "calibrate left WM-surface with gradient field",
          inputs => [$left_hemi_white, $final_classify, $skel_csf,
                    $t1_tal_mnc],
          outputs => [$left_hemi_white_calibrated],
          args => ["calibrate_white", $t1_tal_mnc, $final_classify,
                  $skel_csf, $left_hemi_white, $left_hemi_white_calibrated],
          prereqs => ["slide_left_hemi_obj_back"] }
          );

    ${$pipeline_ref}->addStage(
          { name => "calibrate_right_white",
          label => "calibrate right WM-surface with gradient field",
          inputs => [$right_hemi_white, $final_classify, $skel_csf,
                    $t1_tal_mnc],
          outputs => [$right_hemi_white_calibrated],
          args => ["calibrate_white", $t1_tal_mnc, $final_classify, 
                  $skel_csf, $right_hemi_white, $right_hemi_white_calibrated],
          prereqs => ["slide_right_hemi_obj_back"] }
          );


# ---------------------------------------------------------------------------
#  Step 4: Create a Laplacian field from the WM surface to the
#          outer boundary of gray matter
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "laplace_field",
          label => "create laplacian field in the cortex",
          inputs => [$skel_csf, $left_hemi_white,$right_hemi_white,
                    $final_classify,$final_callosum],
          outputs => [$laplace_field],
          args => ["make_asp_grid", $skel_csf, $left_hemi_white_calibrated,
                  $right_hemi_white_calibrated, $final_classify,
                  $final_callosum, $laplace_field],
          prereqs => ["calibrate_left_white","calibrate_right_white"] }
          );

# ---------------------------------------------------------------------------
#  Step 5: Expand a copy of the white surface out to the gray
#          boundary.  Note that now we can delete the temporary
#          masked white matter ($masked_input), and use the
#          original classified volume for this step.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "gray_surface_left",
          label => "expand to left pial surface in Talairach",
          inputs => [$final_classify, $left_hemi_white, $laplace_field],
          outputs => [$gray_surface_left],
          args => ["expand_from_white", $final_classify, 
                   $left_hemi_white, $gray_surface_left, $laplace_field],
          prereqs => ["laplace_field"] }
          );

    ${$pipeline_ref}->addStage(
          { name => "gray_surface_right",
          label => "expand to right pial surface in Talairach",
          inputs => [$final_classify, $right_hemi_white, $laplace_field],
          outputs => [$gray_surface_right],
          args => ["expand_from_white", $final_classify, 
                   $right_hemi_white, $gray_surface_right, $laplace_field],
          prereqs => ["laplace_field"] }
          );

# ---------------------------------------------------------------------------
#  Step 6: Find the mid-surfaces from calibrated white and gray.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "mid_surface_left",
          label => "left mid-surface",
          inputs => [$left_hemi_white_calibrated, $gray_surface_left],
          outputs => [$mid_surface_left],
          args => ["average_surfaces", $mid_surface_left, "none", "none",
                   1, $left_hemi_white_calibrated, $gray_surface_left ],
          prereqs => ["gray_surface_left"] }
          );

    ${$pipeline_ref}->addStage( {
          name => "mid_surface_right",
          label => "right mid-surface",
          inputs => [$right_hemi_white_calibrated, $gray_surface_right],
          outputs => [$mid_surface_right],
          args => ["average_surfaces", $mid_surface_right, "none", "none",
                   1, $right_hemi_white_calibrated, $gray_surface_right ],
          prereqs => ["gray_surface_right"] }
          );

# ---------------------------------------------------------------------------
#  Step 7: Find the fitting error for the white and gray surfaces.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage(
          { name => "surface_fit_error",
          label => "surface fit error measurement",
          inputs => [$final_classify, $wm_left_centered, 
                     $wm_right_centered,
                     $white_surf_left_prelim, 
                     $white_surf_right_prelim, 
                     $gray_surface_left, $gray_surface_right],
          outputs => [$surface_qc],
          args => ["surface_qc", $final_classify, $wm_left_centered, 
                   $wm_right_centered, 
                   $white_surf_left_prelim, 
                   $white_surf_right_prelim, $gray_surface_left, 
                   $gray_surface_right, $surface_qc ],
          prereqs => ["gray_surface_left", "gray_surface_right"] }
          );

    my $Surface_Fit_complete = [ "mid_surface_left",
                                 "mid_surface_right",
                                 "surface_fit_error" ];

    return( $Surface_Fit_complete );
}

1;
