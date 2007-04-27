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

    my $lin_model = ${$image}->{linmodel};
    my $nl_model = ${$image}->{nlinmodel};
    my $surf_mask = ${$image}->{surfmask};

    my $t1_tal_final = ( -e ${$image}->{t1}{native} ) ? ${$image}->{t1}{final} : undef;
    my $t2_tal_final = ( -e ${$image}->{t2}{native} ) ? ${$image}->{t2}{final} : undef;
    my $pd_tal_final = ( -e ${$image}->{pd}{native} ) ? ${$image}->{pd}{final} : undef;

    my $skull_mask_native = ${$image}->{skull_mask_native};
    my $cls_correct = ${$image}->{cls_correct};
    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $t1_nl_xfm = ${$image}->{t1_tal_nl_xfm};
    my $surface_info_file = ${$image}->{surface_qc};
    my $brainmask_info_file = ${$image}->{brainmask_qc};
    my $classify_info_file = ${$image}->{classify_qc};

    my $t1_nl_final = ${$image}->{t1_nl_final};
    my $skull_mask_nat_stx = ${$image}->{skull_mask_nat_stx};

    my @verifyRows;
    my @verifyInputs;

    # Row 1: Brain mask in native space, used for linear registration.
    #        For convenience, transform this mask to stx space for ease
    #        of comparison with the registered subject.

    ${$pipeline_ref}->addStage(
      { name => "verify_brain_mask",
      label => "verification of native brain mask",
      inputs => [ $skull_mask_native, $t1_tal_xfm ],
      outputs => [$skull_mask_nat_stx],
      args => [ "mincresample", "-clobber", "-like", $t1_tal_final, 
                "-nearest_neighbour", "-transform", $t1_tal_xfm, 
                $skull_mask_native, $skull_mask_nat_stx ],
      prereqs => $Prereqs });

    ${$pipeline_ref}->addStage(
      { name => "brain_mask_qc",
      label => "native brain mask quality check",
      inputs => [ $skull_mask_native, $t1_tal_xfm ],
      outputs => [$brainmask_info_file],
      args => [ "brain_mask_qc", $skull_mask_native, "${lin_model}_mask.mnc",
                "-transform", $t1_tal_xfm, $brainmask_info_file ],
      prereqs => $Prereqs });

    push @verifyRows, ( "-row", "color:gray", 
                        "title:\@${brainmask_info_file}",
                        "overlay:${surf_mask}:red:1.0",
                        $skull_mask_nat_stx );
    push @verifyInputs, ( $skull_mask_nat_stx, $brainmask_info_file );

    # Row 2a (b,c): registered t1 (t2,pd) images, nu-corrected, inormalized
    if( $t1_tal_final ) {
      my $t1_base = &basename( $t1_tal_final );
      push @verifyRows, ( "-row", "color:gray", 
                          "title:t1 final image ${t1_base}",
                          "overlay:${surf_mask}:red:1.0",
                          $t1_tal_final );
      push @verifyInputs, ( $t1_tal_final );
    }

    if( $t2_tal_final ) {
      my $t2_base = &basename( $t2_tal_final );
      push @verifyRows, ( "-row", "color:gray", 
                          "title:t2 final image ${t2_base}", 
                          "overlay:${surf_mask}:red:1.0",
                          $t2_tal_final );
      push @verifyInputs, ( $t2_tal_final );
    }

    if( $pd_tal_final ) {
      my $pd_base = &basename( $pd_tal_final );
      push @verifyRows, ( "-row", "color:gray",
                          "title:pd final image ${pd_base}", 
                          "overlay:${surf_mask}:red:1.0",
                          $pd_tal_final );
      push @verifyInputs, ( $pd_tal_final );
    }

    # Row 3: non-linear registration for t1 image.

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
                        "overlay:${surf_mask}:red:1.0",
                        $t1_nl_final );
    push @verifyInputs, ( $t1_nl_final );

    # Row 4: Classified image.

    ${$pipeline_ref}->addStage(
      { name => "classify_qc",
      label => "classification quality check",
      inputs => [ $cls_correct ],
      outputs => [$classify_info_file],
      args => [ "classify_qc", $cls_correct, $classify_info_file ],
      prereqs => $Prereqs });

    push @verifyRows, ("-row", "color:gray", 
                       "title:\@${classify_info_file}", $cls_correct );
    push @verifyInputs, ( $cls_correct, $classify_info_file );

    # Row 5: Segmentation labels.
    unless (${$image}->{animal} eq "noANIMAL") {
        my $stx_labels = ${$image}->{stx_labels};
        push @verifyRows, ("-row", "color:label", 
                           "title:ANIMAL segmentation", $stx_labels );
        push @verifyInputs, ( $stx_labels );
    }

    # Row 6: Cortical white and gray surfaces.

    unless (${$image}->{surface} eq "noSURFACE") {
      push @verifyRows, ( "-row", "color:gray",
                          "title:\@${surface_info_file}",
                          "overlay:${white_surface_left}:blue:0.5",
                          "overlay:${gray_surface_left}:red:0.5",
                          "overlay:${white_surface_right}:blue:0.5",
                          "overlay:${gray_surface_right}:red:0.5",
                          $cls_correct );
      push @verifyInputs, ( $white_surface_left, $gray_surface_left, 
                            $white_surface_right, $gray_surface_right,
                            $surface_info_file );
    }
    my @verifyCmd = ( "create_verify_image", ${$image}->{verify}, "-clobber", 
                      "-width", 1200 );

    ${$pipeline_ref}->addStage(
      { name => "verify_image",
      label => "create overall verification image",
      inputs => \@verifyInputs,
      outputs => [${$image}->{verify}],
      args => [ @verifyCmd, @verifyRows ],
      prereqs => ["verify_image_nlfit", "verify_brain_mask", "brain_mask_qc",
                  "classify_qc"] });

    my $Verify_Image_complete = [ "verify_image" ];
    return( $Verify_Image_complete );
}

sub clasp {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $title = "CLASP surfaces";
    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $thickness_left = ${$image}->{rms}{left};
    my $thickness_right = ${$image}->{rms}{right};
    my $native_gi_left = ${$image}->{gyrification_index}{left};
    my $native_gi_right = ${$image}->{gyrification_index}{right};

    my @claspInputs;
    push @claspInputs, ( $gray_surface_left );
    push @claspInputs, ( $gray_surface_right );
    push @claspInputs, ( $white_surface_left );
    push @claspInputs, ( $white_surface_right );
    push @claspInputs, ( $thickness_left );
    push @claspInputs, ( $thickness_right );
  
    my $verify_file = ${$image}->{verify_clasp};

    my @Verify_CLASP_complete = ( );

    # Plot 3D views of surfaces.
    unless (${$image}->{surface} eq "noSURFACE") {
      ${$pipeline_ref}->addStage(
        { name => "verify_clasp",
        label => "create verification image for surfaces",
        inputs => \@claspInputs,
        outputs => [$verify_file],
        args => [ "verify_clasp", $gray_surface_left, $gray_surface_right, 
                  $white_surface_left, $white_surface_right, $thickness_left,
                  $thickness_right, $verify_file, "\@${native_gi_left}",
                  "\@${native_gi_right}", "${$image}->{tmethod}\_${$image}->{tkernel}mm" ],
        prereqs => $Prereqs });
        push @Verify_CLASP_complete, ("verify_clasp");
    }


    return( \@Verify_CLASP_complete );
}


1;
