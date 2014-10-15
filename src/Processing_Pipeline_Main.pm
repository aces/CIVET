#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# This is the Main package for single spectral runs (t1 only)
package CIVET_Main;
# Force all variables to be declared
use strict;

use MRI_Image;

use Link_Native;
use Clean_Scans;
use Linear_Transforms;
use Skull_Masking;
use Classify;
use Cortex_Mask;
use Non_Linear_Transforms;
use Segment;
use Surface_Fit;
use Surface_Register;
use Cortical_Measurements;
use Verify_Image;
use VBM;

# the version number

$PMP::VERSION = '0.7.1'; #Things that have to be defined Poor Man's Pipeline


sub create_pipeline{
    my $pipeline_ref = @_[0];  
    my $image = @_[1];
    my $models = @_[2];
    my $surface_models = @_[3];
    my $Global_intermediate_model = @_[4];
    my $Global_Template = @_[5];

    my $Global_LinRegModel = "${$models}->{RegLinDir}/${$models}->{RegLinModel}";
    my $Global_NLRegModel = "${$models}->{RegNLDir}/${$models}->{RegNLModel}";

    ##########################################
    ##### Preprocessing the native files #####
    ##########################################

    my @res = Link_Native::create_pipeline(
      $pipeline_ref,
      undef,
      $image
    );
    my $Link_Native_complete  = $res[0];

    ################################################
    ##### Calculation of linear transformation #####
    ################################################

    @res = Linear_Transforms::stx_register(
      $pipeline_ref,
      $Link_Native_complete,
      $image,
      $Global_LinRegModel,
      $Global_intermediate_model
    );
    my $Linear_Registration_complete = $res[0];

    ################################################
    ##### Application of linear transformation #####
    ################################################

    @res = Linear_Transforms::transform(
      $pipeline_ref,
      $Linear_Registration_complete,
      $image,
      $Global_Template
    );
    my $Linear_Transforms_complete = $res[0];

    ############################################################
    ##### Non-uniformity correction (in stereotaxic space) #####
    ############################################################

    @res = Clean_Scans::create_pipeline(
      $pipeline_ref,
      $Linear_Transforms_complete,
      $image,
      $Global_LinRegModel
    );
    my $Clean_Scans_complete = $res[0];

    ##############################################
    ##### Skull masking in stereotaxic space #####
    ##############################################

    @res = Skull_Masking::stereotaxic_mask(
      $pipeline_ref,
      $Clean_Scans_complete,
      $image
    );
    my $Skull_Masking_complete = $res[0];

    #####################################
    ##### Non-linear transformation #####
    #####################################

    @res = Non_Linear_Transforms::create_pipeline(
      $pipeline_ref,
      $Skull_Masking_complete,
      $image,
      $Global_NLRegModel
    );
    my $Non_Linear_Transforms_complete = $res[0];

    #################################
    ##### Tissue classification #####
    #################################

    @res = Classify::pve(
      $pipeline_ref,
      [@{$Non_Linear_Transforms_complete},@{$Skull_Masking_complete}],
      $image
    );
    my $Classify_complete = $res[0];

    ############################################################
    ##### Cortex masking (used only for white matter mask) #####
    ############################################################

    @res = Cortex_Mask::create_pipeline(
      $pipeline_ref,
      $Classify_complete,
      $image
    );
    my $Cortex_Mask_complete = $res[0];

    ################################################
    ##### Processing of VBM files for analysis #####
    ################################################

    my $VBM_complete = undef;
    unless (${$image}->{VBM} eq "noVBM") {
      @res = VBM::create_pipeline(
        $pipeline_ref,
        $Cortex_Mask_complete,
        $image
      );
      my $VBM_complete = $res[0];
    }

    ##############################
    ##### ANIMAL brain atlas #####
    ##############################

    my $Segment_complete = undef;
    unless (${$image}->{animal} eq "noANIMAL") {
      my $fullpath_animalregmodel = "${$models}->{AnimalNLRegDir}/${$models}->{AnimalNLRegModel}";
      @res = Segment::create_pipeline(
        $pipeline_ref,
        [@{$Non_Linear_Transforms_complete},@{$Classify_complete}],
        $image,
        $Global_Template,
        ${$models}->{AnimalModel},
        ${$models}->{AnimalRegNLModel},
      );
      $Segment_complete = $res[0];
    }

    #######################################
    ##### Cortical surface extraction #####
    #######################################

    my $Surface_Fit_complete = undef;
    my $Surface_QC_complete = undef;
    my $Combine_Surface_complete = undef;
    my $SurfReg_complete = undef;
    my $SurfResample_complete = undef;
    my $Thickness_complete = undef;
    my $SingleSurface_complete = undef;
    my $Mean_Curvature_complete = undef;
    my $LobeFeatures_complete = undef;
    my $Position_complete = undef;
    my $GyrificationIndex_complete = undef;
    my $CerebralVolume_complete = undef;
    my $ClsVolumes_complete = undef;
    my $LobeFeatures_complete = $res[0];
    my $Verify_CLASP_complete = undef;
    my $Verify_Atlas_complete = undef;
    my $Verify_Laplace_complete = undef;
    my $Verify_Surfsurf_complete = undef;
    my $Verify_image_complete = undef;
    my $Verify_QC_complete = undef;

    unless (${$image}->{surface} eq "noSURFACE") {

      ####################################################
      ##### CLASP white and gray surfaces extraction #####
      ####################################################

      @res = Surface_Fit::create_pipeline(
        $pipeline_ref,
        [@{$Cortex_Mask_complete},@{$Classify_complete}],
        $image,
        ${$models}->{SubcorticalMask},
      );
      $Surface_Fit_complete = $res[0];

      #######################################
      ##### Quality control on surfaces #####
      #######################################

      @res = Surface_Fit::surface_qc(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image,
      );
      $Surface_QC_complete = $res[0];

      @res = Verify::laplacian(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image
      );
      $Verify_Laplace_complete = $res[0];

      @res = Verify::surfsurf(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image
      );
      $Verify_Surfsurf_complete = $res[0];

      ##########################################
      ##### Combine left+right hemispheres #####
      ##########################################

      @res = Surface_Fit::combine_surfaces(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image,
      );
      $Combine_Surface_complete = $res[0];

      ##############################
      ##### Gyrification Index #####
      ##############################

      @res = Cortical_Measurements::gyrification_index(
        $pipeline_ref,
        [@{$Surface_Fit_complete},@{$Combine_Surface_complete}],
        $image
      );
      $GyrificationIndex_complete = $res[0];

      ###########################
      ##### Cerebral Volume #####
      ###########################

      @res = Cortical_Measurements::cerebral_volume(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image
      );
      $CerebralVolume_complete = $res[0];

      ##############################
      ##### Classified Volumes #####
      ##############################

      @res = Cortical_Measurements::cls_volumes(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image
      );
      $ClsVolumes_complete = $res[0];

      ################################
      ##### Surface registration #####
      ################################

      my $Global_SurfRegModelLeft = "${$surface_models}->{SurfRegModelDir}/${$surface_models}->{MidModelLeft}";
      my $Global_SurfRegModelRight = "${$surface_models}->{SurfRegModelDir}/${$surface_models}->{MidModelRight}";
      @res = Surface_Register::create_pipeline(
        $pipeline_ref,
        $Surface_Fit_complete,
        $image,
        $Global_SurfRegModelLeft,
        $Global_SurfRegModelRight,
      );
      $SurfReg_complete = $res[0];

      ###########################################
      ##### Resampling of cortical surfaces #####
      ###########################################
 
      if( ${$image}->{resamplesurfaces} ) {
        @res = Surface_Register::resample_surfaces(
          $pipeline_ref,
          $SurfReg_complete,
          $image
        );
        $SurfResample_complete = $res[0];

        @res = Verify::atlas(
          $pipeline_ref,
          $SurfResample_complete,
          $image
        );
        $Verify_Atlas_complete = $res[0];

        ######################################
        ##### Asymmetry map for position #####
        ######################################

        @res = Cortical_Measurements::position(
          $pipeline_ref,
          [@{$SurfResample_complete},@{$Combine_Surface_complete}],
          $image
        );
        $Position_complete = $res[0];

        my @resArea = Surface_Register::resampled_surface_areas(
          $pipeline_ref,
          $SurfResample_complete,
          $image,
          $Global_SurfRegModelLeft,
          $Global_SurfRegModelRight
        );

        @res = Surface_Register::resampled_surface_volumes(
          $pipeline_ref,
          $SurfResample_complete,
          $image,
          $Global_SurfRegModelLeft,
          $Global_SurfRegModelRight
        );
        $SurfResample_complete = [@{$resArea[0]},@{$res[0]}];
      }

      ##############################################
      ##### Cortical Thickness, Mean Curvature #####
      ##############################################

      @res = Cortical_Measurements::thickness(
        $pipeline_ref,
        [@{$SurfReg_complete},@{$Combine_Surface_complete}],
        $image
      );
      $Thickness_complete = $res[0];

      if( ${$image}->{meancurvature} ) {
        @res = Cortical_Measurements::mean_curvature(
          $pipeline_ref,
          [@{$SurfReg_complete},@{$Combine_Surface_complete}],
          $image
        );
        $Mean_Curvature_complete = $res[0];
      }

      #################################################
      ##### Lobe parcellation for cortex features #####
      #################################################

      ## Note: Should split lobe_features into thickness, curvature, area, volume,
      ##       because change in thickness fwhm doesn't affect other 3 metrics.
      ##       Anyway, it's running nonetheless, but it's not optimal. CL.

      my $lobePrereqs = [@{$SurfReg_complete},@{$Thickness_complete}];
      push @{$lobePrereqs}, @{$Mean_Curvature_complete} if( ${$image}->{meancurvature} );
      push @{$lobePrereqs}, @{$SurfResample_complete} if( ${$image}->{resamplesurfaces} );

      @res = Cortical_Measurements::lobe_features(
        $pipeline_ref,
        $lobePrereqs,
        $image,
      );
      $LobeFeatures_complete = $res[0];
    }

    ##############################
    ##### Quality assessment #####
    ##############################

    my $imagePrereqs = [ @{$Classify_complete} ];

    unless (${$image}->{surface} eq "noSURFACE") {
      push @{$imagePrereqs}, @{$Surface_Fit_complete};
      push @{$imagePrereqs}, @{$Surface_QC_complete};
    }
    unless (${$image}->{animal} eq "noANIMAL") {
      push @{$imagePrereqs}, @{$Segment_complete};
    }

    @res = Verify::image(
      $pipeline_ref,
      $imagePrereqs,
      $image
    );

    $Verify_image_complete = $res[0];

    unless (${$image}->{surface} eq "noSURFACE") {
      my $CLASPPrereqs = [ @{$Surface_Fit_complete} ];
      push @{$CLASPPrereqs}, @{$GyrificationIndex_complete};
      push @{$CLASPPrereqs}, @{$Thickness_complete};
      @res = Verify::clasp(
        $pipeline_ref,
        $CLASPPrereqs,
        $image
      );
      $Verify_CLASP_complete = $res[0];

    }

    my $QCPrereqs = [ @{$Classify_complete} ];
    unless (${$image}->{surface} eq "noSURFACE") {
      push @{$QCPrereqs}, @{$Surface_QC_complete};
      push @{$QCPrereqs}, @{$GyrificationIndex_complete};
      push @{$QCPrereqs}, @{$CerebralVolume_complete};
      push @{$QCPrereqs}, @{$ClsVolumes_complete};
      push @{$QCPrereqs}, @{$LobeFeatures_complete};
      push @{$QCPrereqs}, @{$SurfResample_complete} if( ${$image}->{resamplesurfaces} );
    }
    if (${$image}->{animal} eq "ANIMAL") {
      push @{$QCPrereqs}, @{$Segment_complete};
    }

    @res = Verify::QC( 
        $pipeline_ref,
        $QCPrereqs,
        $image
      );
    $Verify_QC_complete = $res[0];

}
