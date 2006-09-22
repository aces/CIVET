# For purposes of rapid quality assessments of the output of this pipeline,
# the following stages produce an image file in '.png' format that show-cases
# the output of the main stages of the pipeline.

package Verify;

use strict;
use File::Basename;
use PMP::PMP;
use MRI_Image;

sub image {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $nl_model = @_[3];

    my $t1_tal_final = ( -e ${$image}->{t1}{native} ) ? ${$image}->{t1}{final} : undef;
    my $t2_tal_final = ( -e ${$image}->{t2}{native} ) ? ${$image}->{t2}{final} : undef;
    my $pd_tal_final = ( -e ${$image}->{pd}{native} ) ? ${$image}->{pd}{final} : undef;
    my $cls_correct = ${$image}->{cls_correct};
    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};

    my $t1_nl_xfm = ${$image}->{t1_tal_nl_xfm};
    my $surface_info_file = ${$image}->{surface_qc};

    my $verify1 = ${$image}->{verify};
    my $t1_nl_final = ${$image}->{t1_nl_final};

    my @verifyRows;
    my @verifyInputs;

    # Row 1a (b,c): registered t1 (t2,pd) images, nu-corrected, inormalized
    if( $t1_tal_final ) {
      my $t1_base = &basename( $t1_tal_final );
      push @verifyRows, ( "-row", "color:gray", 
                          "title:t1 final image ${t1_base}",
                          $t1_tal_final );
      push @verifyInputs, ( $t1_tal_final );
    }

    if( $t2_tal_final ) {
      my $t2_base = &basename( $t2_tal_final );
      push @verifyRows, ( "-row", "color:gray", 
                          "title:t2 final image ${t2_base}", 
                          $t2_tal_final );
      push @verifyInputs, ( $t2_tal_final );
    }

    if( $pd_tal_final ) {
      my $pd_base = &basename( $pd_tal_final );
      push @verifyRows, ( "-row", "color:gray",
                          "title:pd final image ${pd_base}", 
                          $pd_tal_final );
      push @verifyInputs, ( $pd_tal_final );
    }

    # Row 2: non-linear registration for t1 image.

    ${$pipeline_ref}->addStage(
      { name => "verify_image_nlfit",
      label => "verification of non-linear registration",
      inputs => [ $t1_tal_final, $t1_nl_xfm ],
      outputs => [$t1_nl_final],
      args => [ "mincresample", "-clobber", "-like", $t1_tal_final, 
                "-tricubic", "-transform", $t1_nl_xfm, 
                $t1_tal_final, $t1_nl_final ],
      prereqs => $Prereqs });

    my $nl_model_base = &basename( $nl_model );
    push @verifyRows, ( "-row", "color:gray",
                        "title:t1 non-linear registration to ${nl_model_base}", 
                        $t1_nl_final );
    push @verifyInputs, ( $t1_nl_final );

    # Row 3: Classified image.

    push @verifyRows, ("-row", "color:gray", 
                       "title:classified image", $cls_correct );
    push @verifyInputs, ( $cls_correct );

    # Row 4: Segmentation labels.
    unless (${$image}->{animal} eq "noANIMAL") {
        my $stx_labels = ${$image}->{stx_labels};
        push @verifyRows, ("-row", "color:label", 
                           "title:ANIMAL segmentation", $stx_labels );
        push @verifyInputs, ( $stx_labels );
    }

    # Row 5: Cortical white and gray surfaces.

    unless (${$image}->{surface} eq "noSURFACE") {
      push @verifyRows, ( "-row", "color:gray",
                          "title:\@${surface_info_file}",
                          "overlay:${white_surface_left}:blue:0.5",
                          "overlay:${gray_surface_left}:red:0.5",
                          "overlay:${white_surface_right}:blue:0.5",
                          "overlay:${gray_surface_right}:red:0.5",
                          $cls_correct );
      push @verifyInputs, ( $white_surface_left, $gray_surface_left, 
                            $white_surface_right, $gray_surface_right );
    }
    my @verifyCmd = ( "create_verify_image", $verify1, "-clobber", 
                      "-width", 1200 );

    ${$pipeline_ref}->addStage(
      { name => "verify_image",
      label => "create overall verification image",
      inputs => \@verifyInputs,
      outputs => [$verify1],
      args => [ @verifyCmd, @verifyRows ],
      prereqs => ["verify_image_nlfit"] });

    my $Verify_Image_complete = [ "verify_image" ];
    return( $Verify_Image_complete );
}

sub clasp {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $verify_file = ${$image}->{verify_clasp};

    my @Verify_CLASP_complete = ( );

    # Plot 3D views of surfaces.
    unless (${$image}->{surface} eq "noSURFACE") {
      ${$pipeline_ref}->addStage(
        { name => "verify_clasp",
        label => "create verification image for surfaces",
        inputs => [$gray_surface_left, $gray_surface_right, $white_surface_left,
                   $white_surface_right],
        outputs => [$verify_file],
        args => [ "verify_clasp", $gray_surface_left, $gray_surface_right, 
                  $white_surface_left, $white_surface_right, $verify_file, 
                  "CLASP surfaces" ],
        prereqs => $Prereqs });
        push @Verify_CLASP_complete, ("verify_clasp");
    }

    return( \@Verify_CLASP_complete );
}


1;
