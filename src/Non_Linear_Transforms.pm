#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# The non-linear fitting stages for t1. 
# Other images t2 and pd will be transformed relative to t1 with the
# same non-linear transformation.

package Non_Linear_Transforms;
use strict;
use PMP::PMP;
use MRI_Image;
use File::Basename;
use MNI::PathUtilities qw(replace_ext);

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Non_Linear_Transforms_Prereqs = @_[1];
    my $image = @_[2];
    my $nl_model = @_[3];

    my $t1_tal_mnc = ${$image}->{t1}{final};
    my $skull_mask = ${$image}->{skull_mask_tal};
    my $t1_tal_nl_xfm = ${$image}->{t1_tal_nl_xfm};

# Not pretty, but must add extension .mnc to model name (because 
# stx_register uses the same model, but without the .mnc extension).
    my $Non_Linear_Target = "${nl_model}.mnc";
    my $model_mask = "${nl_model}_mask.mnc";

    ${$pipeline_ref}->addStage( {
         name => "nlfit",
         label => "creation of nonlinear transform",
         inputs => [$t1_tal_mnc, $skull_mask],
         outputs => [$t1_tal_nl_xfm],
         args => ["best1stepnlreg.pl", "-clobber", "-source_mask", 
                  $skull_mask, "-target_mask", $model_mask, 
                  $t1_tal_mnc, $Non_Linear_Target, $t1_tal_nl_xfm],
         prereqs => $Non_Linear_Transforms_Prereqs });

    my $Non_Linear_Transforms_complete = ["nlfit"]; 

    return( $Non_Linear_Transforms_complete );
}

1;
