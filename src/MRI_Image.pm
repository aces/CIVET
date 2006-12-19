
package MRI_Image;

use strict;

my @ImageTypes = ( "t1", "t2", "pd" );


# Public functions:


# The constructor for processing an MRI Image

sub new {

    # allow for inheritance
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $image = {};
    # bring the class into existence
    bless( $image, $class);

    my $Source_Dir = shift;
    my $Target_Dir = shift;
    my $prefix = shift;
    my $dsid = shift;
    my $inputType = shift;
    my $maskType = shift;
    my $cropNeck = shift;
    my $nuc_dist = shift;
    my $lsqtype = shift;
    my $surface = shift;
    my $animal = shift;
    my $thickness = shift;

    #####   $image->{dsid} = $dsid;
    $image->{inputType} = $inputType;
    $image->{maskType} = $maskType;
    $image->{cropNeck} = $cropNeck;
    $image->{nuc_dist} = $nuc_dist;
    $image->{lsqtype} = $lsqtype;
    $image->{animal} = $animal;
    $image->{surface} = $surface;
    $image->{tmethod} = $$thickness[0];
    $image->{tkernel} = $$thickness[1];

    # Create working directories for processing this image.

    $image->{directories} = { 'LOG'    => "logs", 
                              'TMP'    => "temp", 
                              'NATIVE' => "native", 
                              'FINAL'  => "final", 
                              'MASK'   => "mask", 
                              'CLS'    => "classify", 
                              'VER'    => "verify",
                              'LIN'    => "transforms/linear", 
                              'NL'     => "transforms/nonlinear" };

    $image->{directories}{SEG} = "segment" unless( $animal eq "noANIMAL" );
    $image->{directories}{SURF} = "surfaces" unless( $surface eq "noSURFACE" );
    $image->{directories}{THICK} = "thickness" if( $$thickness[0] && $$thickness[1] );

    my $Base_Dir = "${Target_Dir}/${dsid}";
    system( "mkdir -p ${Base_Dir}" ) if( ! -d ${Base_Dir} );

    foreach my $keydir ( keys %{ $image->{directories} } ) {
      my $subdir = $image->{directories}{$keydir};
      system( "mkdir -p ${Base_Dir}/${subdir}" )
        if( ! -d "${Base_Dir}/${subdir}" );
    }

    # Define volume files on each image type.
    foreach my $type (@ImageTypes) {
      $image->{$type} = $image->image( $type, $Source_Dir, $Base_Dir, 
                                       $prefix, $dsid );
    }

    my $tmp_dir = "${Base_Dir}/$image->{directories}{TMP}";

    # Define linear transformation files.
    my $lin_dir = "${Base_Dir}/$image->{directories}{LIN}";
    $image->{t1_tal_xfm} = "${lin_dir}/${prefix}_${dsid}_t1_tal.xfm";
    $image->{t2pd_t1_xfm} = "${lin_dir}/${prefix}_${dsid}_t2pd_t1.xfm";
    $image->{t2pd_tal_xfm} = "${lin_dir}/${prefix}_${dsid}_t2pd_tal.xfm";
    $image->{tal_to_6_xfm} = "${lin_dir}/${prefix}_${dsid}_t1_tal_to_6.xfm";
    $image->{tal_to_7_xfm} = "${lin_dir}/${prefix}_${dsid}_t1_tal_to_7.xfm";
    $image->{t1_suppressed} = "${lin_dir}/${prefix}_${dsid}_t1_suppressed.mnc";

    # Define non-linear transformation files.
    my $nl_dir = "${Base_Dir}/$image->{directories}{NL}";
    $image->{t1_tal_nl_xfm} = "${nl_dir}/${prefix}_${dsid}_nlfit_It.xfm";

    # Define classification files.
    my $cls_dir = "${Base_Dir}/$image->{directories}{CLS}";
    $image->{cls_clean} = "${cls_dir}/${prefix}_${dsid}_cls_clean.mnc";
    $image->{cls_correct} = "${cls_dir}/${prefix}_${dsid}_classify.mnc";
    $image->{artefact} = "${cls_dir}/${prefix}_${dsid}_artefact.mnc";
    $image->{pve_prefix} = "${cls_dir}/${prefix}_${dsid}_pve";
    $image->{pve_wm} = "$image->{pve_prefix}_wm.mnc";
    $image->{pve_gm} = "$image->{pve_prefix}_gm.mnc";
    $image->{pve_csf} = "$image->{pve_prefix}_csf.mnc";
    $image->{curve_prefix} = "${tmp_dir}/${prefix}_${dsid}_curve";
    $image->{curve_cg} = "$image->{curve_prefix}_cg.mnc";


    # Define brain-masking files.
    my $mask_dir = "${Base_Dir}/$image->{directories}{MASK}";
    $image->{brain_mask} = "${mask_dir}/${prefix}_${dsid}_brain_mask.mnc";
    $image->{skull_mask_native} = "${mask_dir}/${prefix}_${dsid}_skull_mask_native.mnc";
    $image->{skull_mask_tal} = "${mask_dir}/${prefix}_${dsid}_skull_mask.mnc";
    $image->{cortex}     = "${mask_dir}/${prefix}_${dsid}_cortex.obj";

    # Define ANIMAL segmentation files.
    my $seg_dir = "${Base_Dir}/$image->{directories}{SEG}";
    unless ($image->{animal} eq "noANIMAL") {
      $image->{stx_labels} = "${seg_dir}/${prefix}_${dsid}_stx_labels.mnc";
      $image->{label_volumes} = "${seg_dir}/${prefix}_${dsid}_masked.dat";
      $image->{lobe_volumes} = "${seg_dir}/${prefix}_${dsid}_lobes.dat";
      $image->{stx_labels_masked} = "${seg_dir}/${prefix}_${dsid}_stx_labels_masked.mnc";
      $image->{cls_volumes} = "${seg_dir}/${prefix}_${dsid}_cls_volumes.dat";
      $image->{lobe_areas}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_left.dat";
      $image->{lobe_areas}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_right.dat";
    } else {
      $image->{stx_labels} = undef;
      $image->{label_volumes} = undef;
      $image->{lobe_volumes} = undef;
      $image->{stx_labels_masked} = undef;
      $image->{cls_volumes} = undef;
      $image->{lobe_areas}{left} = undef;
      $image->{lobe_areas}{right} = undef;
    }

    # Define surface files.
    my $surf_dir = "${Base_Dir}/$image->{directories}{SURF}";
    $image->{white}{left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_81920.obj";
    $image->{white}{right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_81920.obj";

    $image->{white}{cal_left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_calibrated_81920.obj";
    $image->{white}{cal_right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_calibrated_81920.obj";

    $image->{gray}{left} = "${surf_dir}/${prefix}_${dsid}_gray_surface_left_81920.obj";
    $image->{gray}{right} = "${surf_dir}/${prefix}_${dsid}_gray_surface_right_81920.obj";

    # a bunch of associated temporary files for surface extraction (should clean this up!)
    $image->{final_callosum} = "${tmp_dir}/${prefix}_${dsid}_final_callosum.mnc";
    $image->{final_classify} = "${tmp_dir}/${prefix}_${dsid}_final_classify.mnc";
    $image->{csf_skel} = "${tmp_dir}/${prefix}_${dsid}_csf_skel.mnc";
    $image->{laplace} = "${tmp_dir}/${prefix}_${dsid}_clasp_field.mnc";
    $image->{wm_left_centered} = "${tmp_dir}/${prefix}_${dsid}_wm_left_centered.mnc";
    $image->{wm_right_centered} = "${tmp_dir}/${prefix}_${dsid}_wm_right_centered.mnc";
    $image->{white}{left_prelim} = "${tmp_dir}/${prefix}_${dsid}_white_surface_left_81920.obj";
    $image->{white}{right_prelim} = "${tmp_dir}/${prefix}_${dsid}_white_surface_right_81920.obj";
    $image->{white}{right_prelim_flipped} = "${tmp_dir}/${prefix}_${dsid}_white_surface_right_flipped_81920.obj";

    # Define cortical thickness files.
    my $thick_dir = "${Base_Dir}/$image->{directories}{THICK}";
    if( $$thickness[0] && $$thickness[1] ) {
      $image->{rms}{left} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_left.txt";
      $image->{rms}{right} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_right.txt";
      unless ($image->{animal} eq "noANIMAL") {
        $image->{lobe_thickness}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_left.dat";
        $image->{lobe_thickness}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_right.dat";
      } else {
        $image->{lobe_thickness}{left} = undef;
        $image->{lobe_thickness}{right} = undef;
      }
    } else {
      $image->{rms}{left} = undef;
      $image->{rms}{right} = undef;
      $image->{lobe_thickness}{left} = undef;
      $image->{lobe_thickness}{right} = undef;
    }

    # Define verification files.
    my $verify_dir = "${Base_Dir}/$image->{directories}{VER}";
    $image->{verify} = "${verify_dir}/${prefix}_${dsid}_verify.png";
    $image->{verify_clasp} = "${verify_dir}/${prefix}_${dsid}_clasp.png";
    $image->{skull_mask_nat_stx} = "${tmp_dir}/${prefix}_${dsid}_skull_mask_native_stx.mnc";
    $image->{t1_nl_final} = "${Base_Dir}/$image->{directories}{FINAL}/${prefix}_${dsid}_t1_nl.mnc";
    $image->{surface_qc} = "${verify_dir}/${prefix}_${dsid}_surface_qc.txt";

    return( $image );
}



sub get {

  my $image = shift;
  my $key = shift;

  my @files = ();
  foreach my $type (@ImageTypes) {
    push @files, $image->{$type}{$key};
  }
  return( @files );

}

sub get_hash {

  my $image = shift;
  my $key = shift;

  my $files = {};
  foreach my $type (@ImageTypes) {
    $files->{$type} = $image->{$type}{$key};
  }
  return( $files );

}

sub get_dir {

  my $image = shift;
  my $key = shift;

  return $image->{directories}{$key};
}


# Local functions:

sub image {

  my $image = shift;
  my $type = shift;
  my $sourceDir = shift;
  my $targetDir = shift;
  my $prefix = shift;
  my $dsid = shift;

  # The source file may be zipped or not.
  my $suffix = "";
  if( -e "${sourceDir}/${prefix}_${dsid}_${type}.mnc.gz" ) {
    $suffix = ".gz";
  }

  my $h = { source   => "${sourceDir}/${prefix}_${dsid}_${type}.mnc${suffix}",
            native   => "${targetDir}/$image->{directories}{NATIVE}/${prefix}_${dsid}_${type}.mnc${suffix}",
            nuc      => "${targetDir}/$image->{directories}{NATIVE}/${prefix}_${dsid}_${type}_nuc.mnc",
            tal      => "${targetDir}/$image->{directories}{FINAL}/${prefix}_${dsid}_${type}_tal.mnc",
            final    => "${targetDir}/$image->{directories}{FINAL}/${prefix}_${dsid}_${type}_final.mnc"
          };

  return( $h );

}


1;
