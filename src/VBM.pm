#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# The VBM stages

# Blurring of the classified image for VBM (Voxel-based Morphometry)

package VBM;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $cls = ${$image}->{cls_correct};
    my $cls_masked = ${$image}->{VBM_cls_masked};
    my $mask = ${$image}->{skull_mask_tal};
    my $smooth_wm = ${$image}->{VBM_smooth_wm};
    my $smooth_gm = ${$image}->{VBM_smooth_gm};
    my $smooth_csf = ${$image}->{VBM_smooth_csf};
    my $smooth_sc = ${$image}->{VBM_smooth_sc};

    my $volumeFWHM = ${$image}->{VBM_fwhm};
    my $cerebellum = ${$image}->{VBM_cerebellum};

    ##########################################################################
    #####  Run a smoothing kernel on the different tissue classes of     #####
    #####  the brain for VBM purposes. These steps are prerequisites     #####
    #####  for the purposes of examining symmetry in subsequent stages.  #####
    ##########################################################################

    # Mask the classified image with the brain mask to remove
    # cerebellum and brain steam.

    if( $cerebellum eq "noCerebellum" ) {
      $mask = ${$image}->{brain_mask};
      ${$pipeline_ref}->addStage( {
           name => "VBM_cls_masked",
           label => "VBM masking of classified image",
           inputs => [$cls, $mask],
           outputs => [$cls_masked],
           args => ["mincmath", "-clobber", "-mult", $cls, $mask,
                    $cls_masked],
           prereqs => $Prereqs });
       $Prereqs = ["VBM_cls_masked"];
    } else {
       $cls_masked = $cls;
    }

    ${$pipeline_ref}->addStage( {
         name => "VBM_smooth_${volumeFWHM}_csf",
         label => "CSF map for VBM",
         inputs => [$cls_masked, $mask],
         outputs => [$smooth_csf],
         args => ["smooth_mask", "-clobber", "-binvalue", 1, "-fwhm",
                  $volumeFWHM, "-mask", $mask, $cls_masked, $smooth_csf],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "VBM_smooth_${volumeFWHM}_wm",
         label => "WM map for VBM",
         inputs => [$cls_masked, $mask],
         outputs => [$smooth_wm],
         args => ["smooth_mask", "-clobber", "-binvalue", 3, "-fwhm",
                  $volumeFWHM, "-mask", $mask, $cls_masked, $smooth_wm],
         prereqs => $Prereqs });

    ${$pipeline_ref}->addStage( {
         name => "VBM_smooth_${volumeFWHM}_gm",
         label => "GM map for VBM",
         inputs => [$cls_masked, $mask],
         outputs => [$smooth_gm],
         args => ["smooth_mask", "-clobber", "-binvalue", 2, "-fwhm",
                  $volumeFWHM, "-mask", $mask, $cls_masked, $smooth_gm],
         prereqs => $Prereqs });

    if( ${$image}->{pve_subcortical} ) {
      ${$pipeline_ref}->addStage( {
           name => "VBM_smooth_${volumeFWHM}_sc",
           label => "SC map for VBM",
           inputs => [$cls_masked, $mask],
           outputs => [$smooth_sc],
           args => ["smooth_mask", "-clobber", "-binvalue", 4, "-fwhm",
                    $volumeFWHM, "-mask", $mask, $cls_masked, $smooth_sc],
           prereqs => $Prereqs });
    }

    # Construct symmetric maps.
    my @VBM_complete = ( "VBM_smooth_${volumeFWHM}_wm", 
                         "VBM_smooth_${volumeFWHM}_gm", 
                         "VBM_smooth_${volumeFWHM}_csf" );
    push @VBM_complete, "VBM_smooth_${volumeFWHM}_sc" if( ${$image}->{pve_subcortical} );

    my $symmetry = ${$image}->{VBM_symmetry};

    if( $symmetry eq "Symmetry" ) {
      my $smooth_sc_sym = ${$image}->{VBM_smooth_sc_sym};
      my $smooth_wm_sym = ${$image}->{VBM_smooth_wm_sym};
      my $smooth_gm_sym = ${$image}->{VBM_smooth_gm_sym};
      my $smooth_csf_sym = ${$image}->{VBM_smooth_csf_sym};

      if( ${$image}->{pve_subcortical} ) {
        ${$pipeline_ref}->addStage( {
             name => "VBM_smooth_${volumeFWHM}_sc_sym",
             label => "CSF symmetry map for VBM",
             inputs => [$smooth_sc],
             outputs => [$smooth_sc_sym],
             args => ["asymmetry_vbm_map", "-clobber", $smooth_sc, $smooth_sc_sym],
             prereqs => ["VBM_smooth_${volumeFWHM}_sc"] });
      }

      ${$pipeline_ref}->addStage( {
           name => "VBM_smooth_${volumeFWHM}_wm_sym",
           label => "CSF symmetry map for VBM",
           inputs => [$smooth_wm],
           outputs => [$smooth_wm_sym],
           args => ["asymmetry_vbm_map", "-clobber", $smooth_wm, $smooth_wm_sym],
           prereqs => ["VBM_smooth_${volumeFWHM}_wm"] });

      ${$pipeline_ref}->addStage( {
           name => "VBM_smooth_${volumeFWHM}_gm_sym",
           label => "CSF symmetry map for VBM",
           inputs => [$smooth_gm],
           outputs => [$smooth_gm_sym],
           args => ["asymmetry_vbm_map", "-clobber", $smooth_gm, $smooth_gm_sym],
           prereqs => ["VBM_smooth_${volumeFWHM}_gm"] });

      ${$pipeline_ref}->addStage( {
           name => "VBM_smooth_${volumeFWHM}_csf_sym",
           label => "CSF symmetry map for VBM",
           inputs => [$smooth_csf],
           outputs => [$smooth_csf_sym],
           args => ["asymmetry_vbm_map", "-clobber", $smooth_csf, $smooth_csf_sym],
           prereqs => ["VBM_smooth_${volumeFWHM}_csf"] });

      @VBM_complete = ( "VBM_smooth_${volumeFWHM}_wm_sym", 
                        "VBM_smooth_${volumeFWHM}_gm_sym", 
                        "VBM_smooth_${volumeFWHM}_csf_sym" );
      push @VBM_complete, "VBM_smooth_${volumeFWHM}_sc_sym" if( ${$image}->{pve_subcortical} );

    }

    return( \@VBM_complete );
}


1;
