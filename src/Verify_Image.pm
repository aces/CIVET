#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
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

    my $t1_native = ${$image}->{t1}{source};
    my $t2_native = ${$image}->{t2}{source};
    my $pd_native = ${$image}->{pd}{source};
    my $t1_tal_final = ${$image}->{t1}{final};
    my $t2_tal_final = ${$image}->{t2}{final};
    my $pd_tal_final = ${$image}->{pd}{final};

    my $skull_mask_stx = ${$image}->{skull_mask_tal};
    my $animal_labels = ( defined ${$image}->{animal_labels_masked} ) ? ${$image}->{animal_labels_masked} : "none";
    my $cls_correct = ${$image}->{cls_correct};
    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};

    my $t1_tal_xfm = ${$image}->{t1_tal_xfm};
    my $t1_nl_xfm = ${$image}->{t1_tal_nl_xfm};

    my $surface_info_file = ${$image}->{surface_qc};
    my $classify_info_file = ${$image}->{classify_qc};

    my $lin_model = ${$image}->{linmodel};
    my $nl_model = ${$image}->{nlinmodel};
    my $surf_mask = ${$image}->{surfmask};

    my $lsqtype = ${$image}->{lsqtype};
    my $multi = ( ${$image}->{inputType} eq "multispectral" );

    my @imageInputs;
    push @imageInputs, ( $t1_native, $t1_tal_final ) if(-e $t1_native );
    push @imageInputs, ( $t2_native, $t2_tal_final ) if(-e $t2_native && $multi );
    push @imageInputs, ( $pd_native, $pd_tal_final ) if(-e $pd_native && $multi );
    push @imageInputs, ( $animal_labels ) if( defined ${$image}->{animal_labels_masked} );
    push @imageInputs, ( $white_surface_left, $white_surface_right,
                         $gray_surface_left, $gray_surface_right,
                         $surface_info_file ) if( ${$image}->{surface} ne "noSURFACE" );

    ${$pipeline_ref}->addStage( {
      name => "verify_image",
      label => "create overall verification image",
      inputs => [ @imageInputs, $skull_mask_stx,
                  $cls_correct, $t1_tal_xfm, $t1_nl_xfm ],
      outputs => [${$image}->{verify}, $classify_info_file ],
      args => [ 'verify_image', $t1_native, $t2_native, $pd_native,
                $t1_tal_final, $t2_tal_final, $pd_tal_final,
                $skull_mask_stx, $animal_labels, 
                $cls_correct, $white_surface_left, $white_surface_right,
                $gray_surface_left, $gray_surface_right,
                $t1_tal_xfm, $t1_nl_xfm, $lin_model, $nl_model, $surf_mask, 
                $surface_info_file, $classify_info_file,
                $lsqtype, ${$image}->{verify} ],
      prereqs => $Prereqs } );

    my $Verify_Image_complete = [ "verify_image" ];
    return( $Verify_Image_complete );
}

sub clasp {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $title = "CLASP surfaces";
    my $tkernel = @{${$image}->{tkernel}}[0];  # fix: use first one in list
    my $white_surface_left = ${$image}->{white}{left};
    my $white_surface_right = ${$image}->{white}{right};
    my $gray_surface_left = ${$image}->{gray}{left};
    my $gray_surface_right = ${$image}->{gray}{right};
    my $thickness_left = @{${$image}->{rms}{left}}[0];  # fix: use first one in list
    my $thickness_right = @{${$image}->{rms}{right}}[0];
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

      ${$pipeline_ref}->addStage( {
        name => "verify_clasp",
        label => "create verification image for surfaces",
        inputs => \@claspInputs,
        outputs => [$verify_file],
        args => [ "verify_clasp", $gray_surface_left, $gray_surface_right, 
                  $white_surface_left, $white_surface_right, $thickness_left,
                  $thickness_right, $verify_file, "\@${native_gi_left}",
                  "\@${native_gi_right}", "${$image}->{tmethod}\_${tkernel}mm" ],
        prereqs => $Prereqs });
        push @Verify_CLASP_complete, ("verify_clasp");
    }

    return( \@Verify_CLASP_complete );

}


sub atlas {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $mid_rsl_left = ${$image}->{mid_surface_rsl}{left};
    my $mid_rsl_right = ${$image}->{mid_surface_rsl}{right};
    my $labels_left = ${$image}->{surface_atlas}{left};
    my $labels_right = ${$image}->{surface_atlas}{right};
    my $gyri_left = ${$image}->{surface_gyri}{left};
    my $gyri_right = ${$image}->{surface_gyri}{right};

    my $verify_file = ${$image}->{verify_atlas};

    my @Verify_Atlas_complete = ( );

    # Plot 3D views of parcellated surfaces.

    unless (${$image}->{surface} eq "noSURFACE") {
      if( ${$image}->{resamplesurfaces} ) {
        ${$pipeline_ref}->addStage( {
          name => "verify_atlas",
          label => "create verification image for surface parcellation",
          inputs => [ $mid_rsl_left, $mid_rsl_right ],
          outputs => [$verify_file],
          args => [ "verify_atlas", $mid_rsl_left, $mid_rsl_right, 
                    $labels_left, $labels_right, $gyri_left,
                    $gyri_right, $verify_file, ${$image}->{surfaceatlas} ],
          prereqs => $Prereqs });
          push @Verify_Atlas_complete, ("verify_atlas");
      }
    }

    return( \@Verify_Atlas_complete );

}


sub surfsurf {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $white_left = ${$image}->{white}{left};
    my $white_right = ${$image}->{white}{right};
    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};

    my $verify_file = ${$image}->{verify_surfsurf};

    my @Verify_Surfsurf_complete = ( );

    # Plot 3D views of surface-surface intersections.

    unless (${$image}->{surface} eq "noSURFACE") {
      if( ${$image}->{resamplesurfaces} ) {
        ${$pipeline_ref}->addStage( {
          name => "verify_surfsurf",
          label => "create verification image for surf-surf intersections ",
          inputs => [ $white_left, $white_right, $gray_left, $gray_right ],
          outputs => [$verify_file],
          args => [ "verify_surfsurf", $white_left, $white_right, 
                    $gray_left, $gray_right, $verify_file ],
          prereqs => $Prereqs });
          push @Verify_Surfsurf_complete, ("verify_surfsurf");
      }
    }

    return( \@Verify_Surfsurf_complete );

}


sub laplacian {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $gray_left = ${$image}->{gray}{left};
    my $gray_right = ${$image}->{gray}{right};
    my $clasp_field = ${$image}->{laplace};

    my $verify_file = ${$image}->{verify_laplace};

    my @Verify_Laplace_complete = ( );

    # Plot 3D views of Laplacian on gray surfaces.

    unless (${$image}->{surface} eq "noSURFACE") {
      if( ${$image}->{resamplesurfaces} ) {
        ${$pipeline_ref}->addStage( {
          name => "verify_laplace",
          label => "create verification image for Laplacian field",
          inputs => [ $gray_left, $gray_right, $clasp_field ],
          outputs => [$verify_file],
          args => [ "verify_laplacian", $gray_left, $gray_right, 
                    $clasp_field, $verify_file ],
          prereqs => $Prereqs });
          push @Verify_Laplace_complete, ("verify_laplace");
      }
    }

    return( \@Verify_Laplace_complete );

}


sub QC {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my @QCInputs;
    push @QCInputs, ( ${$image}->{t1}{source} );
    push @QCInputs, ( ${$image}->{t1}{final} );
    push @QCInputs, ( ${$image}->{t1_tal_xfm} );
    push @QCInputs, ( ${$image}->{skull_mask_tal} );
    push @QCInputs, ( ${$image}->{cls_correct} );
    push @QCInputs, ( ${$image}->{classify_qc} );
    unless (${$image}->{surface} eq "noSURFACE") {
      push @QCInputs, ( ${$image}->{surface_qc} );
      if( ${$image}->{resamplesurfaces} ) {
        push @QCInputs, ( ${$image}->{mid_surface_rsl}{left} );
        push @QCInputs, ( ${$image}->{mid_surface_rsl}{right} );
      }
      push @QCInputs, ( ${$image}->{gray}{left} );
      push @QCInputs, ( ${$image}->{white}{left} );
      push @QCInputs, ( ${$image}->{gray}{right} );
      push @QCInputs, ( ${$image}->{white}{right} );
      push @QCInputs, ( @{${$image}->{lobe_thickness}{left}}[0] );
      push @QCInputs, ( @{${$image}->{lobe_thickness}{right}}[0] );
      push @QCInputs, ( ${$image}->{gyrification_index}{left} );
      push @QCInputs, ( ${$image}->{gyrification_index}{right} );
      if( ${$image}->{combinesurfaces} ) {
        push @QCInputs, ( ${$image}->{gyrification_index}{full} );
      }
    }
    if( ${$image}->{animal} eq "ANIMAL" ) {
      push @QCInputs, ( ${$image}->{lobe_volumes} );
    }
  
    my $qc_file = ${$image}->{civet_qc};

    my @Verify_QC_complete = ( );

    # Extract information for QC.

    ${$pipeline_ref}->addStage( {
      name => "verify_civet",
      label => "extract QC information",
      inputs => \@QCInputs,
      outputs => [$qc_file],
      args => [ "civet_qc", ${$image}->{t1}{source}, ${$image}->{t1}{final},
                ${$image}->{t1_tal_xfm}, ${$image}->{skull_mask_tal}, 
                "${$image}->{linmodel}\_mask.mnc", ${$image}->{cls_correct}, 
                ${$image}->{laplace}, ${$image}->{classify_qc}, ${$image}->{surface_qc}, 
                ${$image}->{mid_surface_rsl}{left}, ${$image}->{mid_surface_rsl}{right},
                ${$image}->{gray}{left}, ${$image}->{white}{left}, 
                ${$image}->{gray}{right}, ${$image}->{white}{right},
                @{${$image}->{lobe_thickness}{left}}[0], 
                @{${$image}->{lobe_thickness}{right}}[0],
                ${$image}->{gyrification_index}{left}, ${$image}->{gyrification_index}{right},
                ${$image}->{combinesurfaces} ?  ${$image}->{gyrification_index}{full} : "none",
                ${$image}->{animal} eq "ANIMAL" ? ${$image}->{lobe_volumes} : "none",
                $qc_file ],
      prereqs => $Prereqs });

    push @Verify_QC_complete, ("verify_civet");

    return( \@Verify_QC_complete );

}


1;
