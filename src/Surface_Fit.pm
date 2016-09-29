#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
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
# use FindBin;
# use lib "$FindBin::Bin";

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $pve_gm  = ${$image}->{pve_gm};
    my $pve_wm  = ${$image}->{pve_wm};
    my $pve_csf = ${$image}->{pve_csf};
    my $pve_disc = ${$image}->{pve_disc};

    my $cls_correct    = ${$image}->{cls_correct};
    my $t1_tal_mnc     = ${$image}->{t1}{final};
    my $skull_mask     = ${$image}->{skull_mask_tal};
    my $final_callosum = ${$image}->{final_callosum};
    my $subcortical_mask = ${$image}->{subcortical_mask};
    my $blood_vessels  = ${$image}->{removebloodvessels} ? ${$image}->{blood_vessels} : "none";
    my $final_classify = ${$image}->{final_classify};
    my $skel_csf       = ${$image}->{csf_skel};
    my $brain_mask     = ${$image}->{brain_mask};
    my $laplace_field  = ${$image}->{laplace};

    # Final surfaces in stereotaxic space
    my $left_hemi_white80K = ${$image}->{white}{left80K};
    my $right_hemi_white80K = ${$image}->{white}{right80K};
    my $left_hemi_white = ${$image}->{white}{left};
    my $right_hemi_white = ${$image}->{white}{right};
    my $gray_surface_left80K = ${$image}->{gray}{left80K};
    my $gray_surface_right80K = ${$image}->{gray}{right80K};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $mid_surface_left = ${$image}->{mid_surface}{left};
    my $mid_surface_right = ${$image}->{mid_surface}{right};
    my $wm_left = ${$image}->{wm_left};
    my $wm_right = ${$image}->{wm_right};

# ---------------------------------------------------------------------------
#  Step 1: Application of the custom mask (ventricules, cerebellum,
#          sub-cortical gray) and final classification for surface
#          extraction.
# ---------------------------------------------------------------------------

    my @bloodOutput = ();
    push @bloodOutput, ($blood_vessels) if (-e ${$image}->{removebloodvessels});

    ${$pipeline_ref}->addStage( {
          name => "surface_classify",
          label => "fix the classification for surface extraction",
          inputs => [$t1_tal_mnc, $cls_correct, $pve_wm, $pve_csf, 
                     $pve_disc, $brain_mask ],
          outputs => [$final_callosum, $subcortical_mask, @bloodOutput,
                      $final_classify, $skel_csf],
          args => ["surface_fit_classify", $t1_tal_mnc, $cls_correct, 
                   $pve_wm, $pve_csf, $pve_disc, $brain_mask, 
                   $final_callosum, $subcortical_mask, $blood_vessels,
                   ${$image}->{maskhippocampus}, $final_classify, 
                   $skel_csf ],
          prereqs => $Prereqs }
          );

# ---------------------------------------------------------------------------
#  Step 2: Extraction of the white matter mask for the hemispheres.
# ---------------------------------------------------------------------------

    my @maskInput = ();
    push @maskInput, (${$image}->{skull_mask_native}) if (-e ${$image}->{user_mask});
    my $user_mask = (-e ${$image}->{user_mask}) ?
                    ${$image}->{skull_mask_native} : "none";
    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

    ${$pipeline_ref}->addStage( {
          name => "create_wm_hemispheres",
          label => "create white matter hemispheric masks",
          inputs => [$final_classify, $t1_tal_mnc, @maskInput,
                     $brain_mask, $t1_tal_xfm],
          outputs => [$wm_left, $wm_right],
          args=>["extract_wm_hemispheres", $final_classify, $t1_tal_mnc,
                 $brain_mask, $user_mask, $t1_tal_xfm, $wm_left, $wm_right],
          prereqs =>["surface_classify"] });

# ---------------------------------------------------------------------------
#  Step 3: Extraction of the white surfaces (with gradient calibration)
# ---------------------------------------------------------------------------

    my @mc_opts = ();
    push @mc_opts, '-subsample';
    push @mc_opts, '-calibrate' if( ${$image}->{calibrateWhite} );;
    push @mc_opts, '-refine' if( ${$image}->{surface} eq "hiResSURFACE" );

    ${$pipeline_ref}->addStage( {
          name => "extract_white_surface_left",
          label => "extract marching-cubes white left surface in Talairach",
          inputs => [$t1_tal_mnc, $cls_correct, $skull_mask, $wm_left], 
          outputs => [$left_hemi_white80K, $left_hemi_white],
          args => ["marching_cubes.pl", '-left', @mc_opts,
                   $t1_tal_mnc, $cls_correct, $skull_mask, $wm_left,
                   $left_hemi_white80K, ${$image}->{mc_model}{left},
                   ${$image}->{mc_mask}{left} ],
          prereqs => ["create_wm_hemispheres"] }
          );

    ${$pipeline_ref}->addStage( {
          name => "extract_white_surface_right",
          label => "extract marching-cubes white right surface in Talairach",
          inputs => [$t1_tal_mnc, $cls_correct, $skull_mask, $wm_right], 
          outputs => [$right_hemi_white80K, $right_hemi_white],
          args => ["marching_cubes.pl", '-right', @mc_opts,
                   $t1_tal_mnc, $cls_correct, $skull_mask, $wm_right,
                   $right_hemi_white80K, ${$image}->{mc_model}{right},
                   ${$image}->{mc_mask}{right} ],
          prereqs => ["create_wm_hemispheres"] }
          );

# ---------------------------------------------------------------------------
#  Step 4: Create a Laplacian field from the WM surface to the
#          outer boundary of gray matter
# ---------------------------------------------------------------------------

    ## NOTE: this should use ${$image}->{user_mask} if one exists.
    ##       This way, the user could paint the offending pieces of
    ##       classified WM in the skull, if any. CL.

    ${$pipeline_ref}->addStage( {
          name => "laplace_field",
          label => "create laplacian field in the cortex",
          inputs => [$t1_tal_mnc, $brain_mask, $skel_csf, $left_hemi_white,
                     $right_hemi_white, $final_classify,
                     $pve_gm, $pve_disc, $final_callosum],
          outputs => [$laplace_field],
          args => ["make_asp_grid", $t1_tal_mnc, $brain_mask, 
                   $skel_csf, $left_hemi_white,
                   $right_hemi_white, $final_classify, $pve_gm,
                   $pve_disc, $final_callosum, $laplace_field],
          prereqs => ["extract_white_surface_left","extract_white_surface_right"] }
          );

# ---------------------------------------------------------------------------
#  Step 5: Expand a copy of the white surface out to the gray
#          boundary.  Note that now we can delete the temporary
#          masked white matter ($masked_input), and use the
#          original classified volume for this step.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "gray_surface_left",
          label => "expand to left pial surface in Talairach",
          inputs => [$left_hemi_white80K, $laplace_field],
          outputs => [$gray_surface_left80K],
          args => ["expand_from_white", '-left', $left_hemi_white80K, 
                   $gray_surface_left80K, $laplace_field ],
          prereqs => ["laplace_field"] }
          );
    ${$pipeline_ref}->addStage( {
          name => "gray_surface_right",
          label => "expand to right pial surface in Talairach",
          inputs => [$right_hemi_white80K, $laplace_field],
          outputs => [$gray_surface_right80K],
          args => ["expand_from_white", '-right', $right_hemi_white80K, 
                   $gray_surface_right80K, $laplace_field],
          prereqs => ["laplace_field"] }
          );

    if( ${$image}->{surface} eq "hiResSURFACE" ) {
      ${$pipeline_ref}->addStage( {
            name => "gray_surface_left_hires",
            label => "expand to left pial surface in Talairach",
            inputs => [$left_hemi_white, $gray_surface_left80K, $laplace_field],
            outputs => [$gray_surface_left],
            args => ["expand_from_white", '-left', '-hiresonly',
                     $left_hemi_white, $gray_surface_left80K, 
                     $laplace_field ],
            prereqs => ["gray_surface_left"] } );

      ${$pipeline_ref}->addStage( {
            name => "gray_surface_right_hires",
            label => "expand to right pial surface in Talairach",
            inputs => [$right_hemi_white, $gray_surface_right80K,
                       $laplace_field],
            outputs => [$gray_surface_right],
            args => ["expand_from_white", '-right', '-hiresonly',
                     $right_hemi_white, $gray_surface_right80K, 
                     $laplace_field],
            prereqs => ["gray_surface_right"] } );
    }

# ---------------------------------------------------------------------------
#  Step 6: Find the mid-surfaces from white and gray.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "mid_surface_left",
          label => "left mid-surface",
          inputs => [$left_hemi_white, $gray_surface_left],
          outputs => [$mid_surface_left],
          args => ["average_surfaces", $mid_surface_left, "none", "none",
                   1, $left_hemi_white, $gray_surface_left ],
          prereqs => [${$image}->{surface} eq "hiResSURFACE" ? 
                       "gray_surface_left_hires" :
                       "gray_surface_left"] } );

    ${$pipeline_ref}->addStage( {
          name => "mid_surface_right",
          label => "right mid-surface",
          inputs => [$right_hemi_white, $gray_surface_right],
          outputs => [$mid_surface_right],
          args => ["average_surfaces", $mid_surface_right, "none", "none",
                   1, $right_hemi_white, $gray_surface_right ],
          prereqs => [${$image}->{surface} eq "hiResSURFACE" ? 
                       "gray_surface_right_hires" :
                       "gray_surface_right"] } );

    my @Surface_Fit_complete = ( "mid_surface_left",
                                 "mid_surface_right" );
    return( \@Surface_Fit_complete );
}

# ---------------------------------------------------------------------------
#  Step 7: Find the fitting error for the white and gray surfaces.
# ---------------------------------------------------------------------------
sub surface_qc {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $final_classify = ${$image}->{final_classify};
    my $wm_left = ${$image}->{wm_left};
    my $wm_right = ${$image}->{wm_right};
    my $white_surf_left = ${$image}->{white}{left};
    my $white_surf_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $skull_mask = ${$image}->{skull_mask_tal};

    my $surface_qc = ${$image}->{surface_qc};

    ${$pipeline_ref}->addStage( {
          name => "surface_fit_error",
          label => "surface fit error measurement",
          inputs => [$final_classify, $wm_left, $wm_right,
                     $white_surf_left, $white_surf_right, 
                     $gray_surface_left, $gray_surface_right, $skull_mask],
          outputs => [$surface_qc],
          args => ["surface_qc", $final_classify, $wm_left, 
                   $wm_right, $white_surf_left, 
                   $white_surf_right, $gray_surface_left, 
                   $gray_surface_right, $skull_mask, $surface_qc ],
          prereqs => $Prereqs } );

    my @Surface_QC_complete = ( "surface_fit_error" );
    return( \@Surface_QC_complete );
}

# ---------------------------------------------------------------------------
#  Step 8: Combine left+right hemispheres into a single surface.
# ---------------------------------------------------------------------------
sub combine_surfaces {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    # Final surfaces in stereotaxic space
    my $left_hemi_white = ${$image}->{white}{left};
    my $right_hemi_white  = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $mid_surface_left = ${$image}->{mid_surface}{left};
    my $mid_surface_right = ${$image}->{mid_surface}{right};

    my @Combine_Surface_complete = ();

    if( ${$image}->{combinesurfaces} ) {
      my $white_full = ${$image}->{white}{full};
      my $gray_full = ${$image}->{gray}{full};
      my $mid_full = ${$image}->{mid_surface}{full};

      ${$pipeline_ref}->addStage( {
           name => "white_surface_full",
           label => "white surface full",
           inputs => [$left_hemi_white, $right_hemi_white],
           outputs => [$white_full],
           args => ["objconcat", $left_hemi_white, $right_hemi_white,
                    "none", "none", $white_full, "none"],
           prereqs => $Prereqs } );

      ${$pipeline_ref}->addStage( {
           name => "gray_surface_full",
           label => "gray surface full",
           inputs => [$gray_surface_left, $gray_surface_right],
           outputs => [$gray_full],
           args => ["objconcat", $gray_surface_left, $gray_surface_right,
                    "none", "none", $gray_full, "none"],
           prereqs => $Prereqs } );

      ${$pipeline_ref}->addStage( {
           name => "mid_surface_full",
           label => "mid surface full",
           inputs => [$mid_surface_left, $mid_surface_right],
           outputs => [$mid_full],
           args => ["objconcat", $mid_surface_left, $mid_surface_right,
                    "none", "none", $mid_full, "none"],
           prereqs => $Prereqs } );

      @Combine_Surface_complete = ( "white_surface_full",
                                    "gray_surface_full",
                                    "mid_surface_full" );
    }

    return( \@Combine_Surface_complete );
}

1;
