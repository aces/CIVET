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
use Artefact;
use Cortex_Mask;
use Non_Linear_Transforms;
use Segment;
use Surface_Fit;
use Cortical_Thickness;
use Verify_Image;
# use NL_Surface_Register;
# use Surface_Segment;

# the version number

$PMP::VERSION = '0.6.9'; #Things that have to be defined Poor Man's Pipeline


sub create_pipeline{
    my $pipeline_ref = @_[0];  
    my $image = @_[1];
    my $Global_LinRegModel = @_[2];
    my $Global_NLRegModel = @_[3];
    my $Global_surfModel = @_[4];
    my $Global_intermediate_model = @_[5];
    my $Global_surf_reg_model = @_[6]; 
    my $Global_Template = @_[7]; 
    my $Global_second_model_dir = @_[8];

    ##########################################
    ##### Preprocessing the native files #####
    ##########################################

    my @res = Link_Native::create_pipeline(
      $pipeline_ref,
      undef,
      $image
    );
    my $Link_Native_complete  = $res[0];

    #######################################################
    ##### Non-uniformity correction (in native space) #####
    #######################################################

    @res = Clean_Scans::create_pipeline(
      $pipeline_ref,
      $Link_Native_complete,
      $image
    );
    my $Clean_Scans_complete = $res[0];

    ################################################
    ##### Calculation of linear transformation #####
    ################################################

    @res = Linear_Transforms::stx_register(
      $pipeline_ref,
      $Clean_Scans_complete,
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

    ##############################################
    ##### Skull masking in stereotaxic space #####
    ##############################################

    @res = Skull_Masking::create_pipeline(
      $pipeline_ref,
      $Linear_Transforms_complete,
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

    ######################################################
    ##### Tissue classification in stereotaxic space #####
    ######################################################

    @res = Classify::pve(
      $pipeline_ref,
      $Non_Linear_Transforms_complete,
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

    ##############################################################
    ##### Susceptibility artefacts (could use skull mask???) #####
    ##############################################################

    @res = Artefact::create_pipeline(
      $pipeline_ref,
      $Cortex_Mask_complete,
      $image
    );
    my $Artefact_complete = $res[0];

    ##############################
    ##### ANIMAL brain atlas #####
    ##############################

    my $Segment_complete = undef;
    unless (${$image}->{animal} eq "noANIMAL") {
      @res = Segment::create_pipeline(
        $pipeline_ref,
        [@{$Non_Linear_Transforms_complete},@{$Classify_complete}],
        $image,
        $Global_second_model_dir
      );
      $Segment_complete = $res[0];
    }

    ####################################################
    ##### CLASP white and gray surfaces extraction #####
    ####################################################

    my $Surface_Fit_complete = undef;
    unless (${$image}->{surface} eq "noSURFACE") {
      @res = Surface_Fit::create_pipeline(
        $pipeline_ref,
        [@{$Cortex_Mask_complete},@{$Classify_complete}],
        $image,
        "smallOnly",
        $Global_second_model_dir
      );
      $Surface_Fit_complete = $res[0];
    }

    ##############################
    ##### Cortical Thickness #####
    ##############################

    my $Thickness_complete = undef;
    unless (${$image}->{surface} eq "noSURFACE") {
      if ( ${$image}->{tmethod} and ${$image}->{tkernel} ) {
        @res = Cortical_Thickness::create_pipeline(
          $pipeline_ref,
          $Surface_Fit_complete,
          $image
        );
        $Thickness_complete = $res[0];
      }
    }

    ##############################
    ##### Quality assessment #####
    ##############################

    my $imagePrereqs = [ @{$Classify_complete}, @{$Non_Linear_Transforms_complete} ];

    unless (${$image}->{surface} eq "noSURFACE") {
      push @{$imagePrereqs}, @{$Surface_Fit_complete};
    }
    unless (${$image}->{animal} eq "noANIMAL") {
      push @{$imagePrereqs}, @{$Segment_complete};
    }

    @res = Verify::image(
      $pipeline_ref,
      $imagePrereqs,
      $image,
      $Global_NLRegModel,
      $Global_surfModel
    );

    my $Verify_image_complete = $res[0];


    my $Verify_CLASP_complete = undef;
    unless (${$image}->{surface} eq "noSURFACE") {
      my $CLASPPrereqs = [ @{$Surface_Fit_complete} ];
      @res = Verify::clasp(
        $pipeline_ref,
        $CLASPPrereqs,
        $image
      );
      $Verify_CLASP_complete = $res[0];
    }

#
#     my $Global_Surface_Segment_Dir = "${Global_Base_Dir}/surface_segment";
#     system("mkdir -p ${Global_Surface_Segment_Dir}") if (! -d $Global_Surface_Segment_Dir);
#
#
#     $ref = PMP::Surface_Segment::create_pipeline(
#     $pipeline_ref,
#     $Surface_Fit_complete,
#     $Global_Surface_Segment_Dir,
#     $Global_Temp_Dir,
#     $Prefix,
#     $DSID,
#     "smallOnly",
#     $Segment_stx_labels_masked,
#     $Surface_Fit_gray_surface_82k,
#     $Surface_Fit_gray_surface_328k, 
#     $Linear_Transforms_tal_to_6_xfm
#     );
#     @res = @{$ref};
#     my $Surface_Segment_complete = $res[0];
#     my $Surface_Segment_stx_surface_labels_82k = $res[1];
#     my $Surface_Segment_stx_surface_lobes_82k = $res[2];
#
#
#
#     my $Global_Surface_Register_Dir = "${Global_Base_Dir}/surface_transforms";
#     system("mkdir -p ${Global_Surface_Register_Dir}") if (! -d $Global_Surface_Register_Dir);
#
#     $ref = PMP::NL_Surface_Register::create_pipeline(
#     $pipeline_ref,
#     $Surface_Fit_complete,
#     $Global_Surface_Register_Dir,
#     $Global_Temp_Dir,
#     $Prefix,
#     $DSID,
#     "smallOnly",
#     $Surface_Fit_white_surface_82k,
#     undef,   
#     $Global_surf_reg_model,
#     undef
#     );
#     @res = @{$ref};
#     my  $NL_Surface_Register_complete = $res[0];
#     my  $NL_Surface_Register_surface_mapping_82k = $res[1];
#
#
#        ${$pipeline_ref}->addStage(
#         { name => "signoff",
#         label => "mark pipeline completed",
#         inputs => [],
#         outputs => [],
#         args => ["touch","${Global_Log_Dir}/${Prefix}_${DSID}.complete"],
#         prereqs => [@{$NL_Surface_Register_complete},@{$Surface_Segment_complete}]
#          });
#
#


#     my $Global_Surface_Measurements_Dir = "${Global_Base_Dir}/surface_measurements";
#     system("mkdir -p ${Global_Surface_Measurements_Dir}") if (! -d $Global_Surface_Measurements_Dir);
#
#     @res = PMP::Surface_Measurements::create_pipeline(
#     $pipeline_ref,
#     $Surface_Fit_complete,
#     $Global_Surface_Measurements_Dir,
#     $Global_Temp_Dir,
#     $Prefix,
#     $DSID,
#     "smallOnly",
#     $Surface_Fit_gray_surface_82k,
#     $Surface_Fit_white_surface_82k,
#     $Linear_Transforms_t1_tal_xfm
#     );
}
