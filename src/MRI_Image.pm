
package MRI_Image;

use strict;

my @ImageTypes = ( "t1", "t2", "pd" );

my $Integer = '[+-]?\d+';
my $PositiveInteger = '[+]?\d+';
my $Float = '[+-]? ( \d+(\.\d*)? | \.\d+ ) ([Ee][+-]?\d+)?';
my $PositiveFloat = '[+]? ( \d+(\.\d*)? | \.\d+ ) ([Ee][+-]?\d+)?';


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
    my $correctPVE = shift;
    my $maskType = shift;
    my $cropNeck = shift;
    my $interpMethod = shift;
    my $nuc_dist = shift;
    my $lsqtype = shift;
    my $surface = shift;
    my $animal = shift;
    my $thickness = shift;
    my $linmodel = shift;
    my $nlinmodel = shift;
    my $surfregmodel = shift;
    my $surfregdataterm = shift;
    my $surfmask = shift;
    my $template = shift;

    #####   $image->{dsid} = $dsid;
    $image->{inputType} = $inputType;
    $image->{correctPVE} = $correctPVE;
    $image->{maskType} = $maskType;
    $image->{cropNeck} = $cropNeck;
    $image->{interpMethod} = $interpMethod;
    $image->{nuc_dist} = $nuc_dist;
    $image->{lsqtype} = $lsqtype;
    $image->{animal} = $animal;
    $image->{surface} = $surface;
    $image->{tmethod} = $$thickness[0];
    $image->{tkernel} = $$thickness[1];
    $image->{linmodel} = $linmodel;
    $image->{nlinmodel} = $nlinmodel;
    $image->{surfregmodel} = $surfregmodel;
    $image->{surfregdataterm} = $surfregdataterm;
    $image->{surfmask} = $surfmask;
    $image->{template} = $template;

    $image->validate_options();

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
    $image->{directories}{SR} = "transforms/surfreg" unless( $surface eq "noSURFACE" );
    $image->{directories}{THICK} = "thickness" if( defined $$thickness[0] && defined $$thickness[1] );

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

    $image->print_options( $Base_Dir, $dsid );

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
      unless( $surface eq "noSURFACE" ) {
        $image->{animal_labels}{left} = "${seg_dir}/${prefix}_${dsid}_animal_surface_labels_left.txt";
        $image->{animal_labels}{right} = "${seg_dir}/${prefix}_${dsid}_animal_surface_labels_right.txt";
        $image->{lobe_areas}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_left.dat";
        $image->{lobe_areas}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_right.dat";
        if( defined $$thickness[0] && defined $$thickness[1] ) {
          $image->{lobe_thickness}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_$image->{tmethod}_$image->{tkernel}mm_left.dat";
          $image->{lobe_thickness}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_$image->{tmethod}_$image->{tkernel}mm_right.dat";
        } else {
          $image->{lobe_thickness}{left} = undef;
          $image->{lobe_thickness}{right} = undef;
        }
      } else {
        $image->{animal_labels}{left} = undef;
        $image->{animal_labels}{right} = undef;
        $image->{lobe_areas}{left} = undef;
        $image->{lobe_areas}{right} = undef;
        $image->{lobe_thickness}{left} = undef;
        $image->{lobe_thickness}{right} = undef;
      }
    } else {
      $image->{stx_labels} = undef;
      $image->{label_volumes} = undef;
      $image->{lobe_volumes} = undef;
      $image->{stx_labels_masked} = undef;
      $image->{cls_volumes} = undef;
      $image->{animal_labels}{left} = undef;
      $image->{animal_labels}{right} = undef;
      $image->{lobe_areas}{left} = undef;
      $image->{lobe_areas}{right} = undef;
      $image->{lobe_thickness}{left} = undef;
      $image->{lobe_thickness}{right} = undef;
    }

    # Define surface files.
    my $surf_dir = "${Base_Dir}/$image->{directories}{SURF}";
    $image->{white}{left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_81920.obj";
    $image->{white}{right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_81920.obj";

    $image->{white}{cal_left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_calibrated_81920.obj";
    $image->{white}{cal_right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_calibrated_81920.obj";

    $image->{gray}{left} = "${surf_dir}/${prefix}_${dsid}_gray_surface_left_81920.obj";
    $image->{gray}{right} = "${surf_dir}/${prefix}_${dsid}_gray_surface_right_81920.obj";

    $image->{mid_surface}{left} = "${surf_dir}/${prefix}_${dsid}_mid_surface_left_81920.obj";
    $image->{mid_surface}{right} = "${surf_dir}/${prefix}_${dsid}_mid_surface_right_81920.obj";

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

    # Define surface registration files.
    my $sr_dir = "${Base_Dir}/$image->{directories}{SR}";
    $image->{dataterm}{left} = "${surf_dir}/${prefix}_${dsid}_left_dataterm.vv";
    $image->{dataterm}{right} = "${surf_dir}/${prefix}_${dsid}_right_dataterm.vv";
    $image->{surface_map}{left} = "${sr_dir}/${prefix}_${dsid}_left_surfmap.sm";
    $image->{surface_map}{right} = "${sr_dir}/${prefix}_${dsid}_right_surfmap.sm";

    # Define cortical thickness files.
    my $thick_dir = "${Base_Dir}/$image->{directories}{THICK}";
    if( defined $$thickness[0] && defined $$thickness[1] ) {
      $image->{rms}{left} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_left.txt";
      $image->{rms}{right} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_right.txt";
      $image->{rms_rsl}{left} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_left.txt";
      $image->{rms_rsl}{right} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_right.txt";
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
      $image->{rms_rsl}{left} = undef;
      $image->{rms_rsl}{right} = undef;
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
    $image->{brainmask_qc} = "${verify_dir}/${prefix}_${dsid}_brainmask_qc.txt";

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

sub validate_options {

  my $image = shift;

  # The following errors should never occur unless there is a bug in the code
  # (not direct inputs from user).

  if( !( $image->{inputType} eq "t1only" ||
         $image->{inputType} eq "multispectral" ) ) {
    die "ERROR: Image type must be t1only or multispectral.\n";
  }
  if( !( $image->{maskType} eq "t1only" ||
         $image->{maskType} eq "multispectral" ) ) {
    die "ERROR: Mask type must be t1only or multispectral.\n";
  }

  if( !( $image->{lsqtype} eq "-lsq6" ||
         $image->{lsqtype} eq "-lsq9" ||
         $image->{lsqtype} eq "-lsq12" ) ) {
    die "ERROR: Type or linear registration must be -lsq6, -lsq9 or -lsq12.\n";
  }

  if( !( $image->{animal} eq "ANIMAL" || $image->{animal} eq "noANIMAL" ) ) {
    die "ERROR: Invalid option for ANIMAL segmentation.\n";
  }

  if( !( $image->{surface} eq "SURFACE" || $image->{surface} eq "noSURFACE" ) ) {
    die "ERROR: Invalid option for surface extraction.\n";
  }

  # The following parameters are direct inputs from user so check them.

  # value of cropNeck must be a positive number, if a number is given
  if( defined $image->{cropNeck} ) {
    if( !check_value( $image->{cropNeck}, $PositiveFloat ) ) {
      die "ERROR: Value of -crop-neck ($image->{cropNeck}) must be a positive integer number.\n";
    }
  }

  # must be one of trilinear, tricubic, sinc.
  if( !( $image->{interpMethod} eq "tricubic" ||
         $image->{interpMethod} eq "trilinear" ||
         $image->{interpMethod} eq "sinc" ) ) {
    die "ERROR: Interpolation method must be trilinear, tricubic, or sinc.\n";
  }

  # value of N3-distance must be a positive number
  if( !check_value( $image->{nuc_dist}, $PositiveFloat ) ) {
    die "ERROR: Value of -N3-distance ($image->{nuc_dist}) must be a positive integer number.\n";
  }

  # value of tmethod must be tlink, tlaplace, tnear or tnormal
  if( defined $image->{tmethod} ) {
    if( !( $image->{tmethod} eq "tlink" ||
         $image->{tmethod} eq "tlaplace" ||
         $image->{tmethod} eq "tnear" ||
         $image->{tmethod} eq "tnormal" ) ) {
      die "ERROR: Cortical thickness method ($image->{tmethod}) must be tlink, tlaplace, tnear, or tnormal.\n";
    }
  }

  # value of tkernel must be a positive integer number or zero
  if( defined $image->{tkernel} ) {
    if( !check_value( $image->{tkernel}, $PositiveFloat ) ) {
      die "ERROR: Value of blurring kernel ($image->{tkernel}) must be a positive integer number.\n";
    }
  }

  # The following models must exist.

  if( ! -e "$image->{linmodel}.mnc" ) {
    die "ERROR: Linear registration model $image->{linmodel} must exist.\n";
  }

  if( ! -e "$image->{nlinmodel}.mnc" ) {
    die "ERROR: Non-linear registration model $image->{nlinmodel} must exist.\n";
  }

  if( $image->{surface} eq "SURFACE" ) {
    if( ! -e $image->{surfregmodel} ) {
      die "ERROR: Surface registration model $image->{surfregmodel} must exist.\n";
    }
    if( ! -e $image->{surfregdataterm} ) {
      die "ERROR: Surface registration model $image->{surfregdataterm} must exist.\n";
    }
  }

  if( ! -e $image->{template} ) {
    die "ERROR: Template model $image->{template} must exist.\n";
  }

}

sub check_value {
   my ($val, $type) = @_;

   unless (defined $val && $val =~ /^$type$/x) {
      return 0;
   }
   return 1;
}

# Save a summary of the options in the subject's log directory.

sub print_options {

  my $image = shift;
  my $Base_Dir = shift;
  my $dsid = shift;

  open PIPE, "> ${Base_Dir}/$image->{directories}{LOG}/${dsid}.options";
  print PIPE "Classification is $image->{inputType}\n";
  print PIPE "PVE iterative correction to mean and variance is ON\n"
    if( $image->{correctPVE} );
  print PIPE "Brain masking is $image->{maskType}\n";
  print PIPE "Crop neck at $image->{cropNeck}\%\n" if( $image->{cropNeck} > 0 );
  print PIPE "Interpolation method from native to stereotaxic is $image->{interpMethod}\n";
  print PIPE "N3 distance is $image->{nuc_dist}mm\n";
  print PIPE "Linear registration type is $image->{lsqtype}\n";
  if( $image->{surface} eq "SURFACE" ) {
    if( defined $image->{tmethod} && defined $image->{tkernel} ) {
      print PIPE "Cortical thickness using $image->{tmethod}, blurred at $image->{tkernel}mm\n";
    }
  }
  print PIPE "Model for linear registration is\n  $image->{linmodel}\n";
  print PIPE "Model for non-linear registration is\n  $image->{nlinmodel}\n";
  print PIPE "Model for surface registration is\n  $image->{surfregmodel}\n";
  print PIPE "Dataterm for surface registration is\n  $image->{surfregdataterm}\n";
  print PIPE "Surface mask for linear registration is\n  $image->{surfmask}\n";
  print PIPE "Template for image-processing is\n  $image->{template}\n";
  close PIPE;
}

1;
