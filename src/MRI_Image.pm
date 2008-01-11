
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
    my $interpMethod = shift;
    my $nuc_dist = shift;
    my $lsqtype = shift;
    my $surface = shift;
    my $thickness = shift;
    my $ResampleSurfaces = shift;
    my $CombineSurfaces = shift;
    my $vbm = shift;
    my $VBM_fwhm = shift;
    my $VBM_symmetry = shift;
    my $VBM_cerebellum = shift;
    my $animal = shift;
    my $template = shift;
    my $models = shift;

    #####   $image->{dsid} = $dsid;
    $image->{inputType} = $inputType;
    $image->{correctPVE} = $correctPVE;
    $image->{maskType} = $maskType;
    $image->{interpMethod} = $interpMethod;
    $image->{nuc_dist} = $nuc_dist;
    $image->{lsqtype} = $lsqtype;
    $image->{VBM} = $vbm;
    $image->{VBM_fwhm} = $VBM_fwhm;
    $image->{VBM_symmetry} = $VBM_symmetry;
    $image->{VBM_cerebellum} = $VBM_cerebellum;
    $image->{animal} = $animal;
    $image->{surface} = $surface;
    $image->{tmethod} = $$thickness[0];
    $image->{tkernel} = $$thickness[1];
    $image->{resamplesurfaces} = $ResampleSurfaces;
    $image->{combinesurfaces} = $CombineSurfaces;
    $image->{linmodel} = "${$models}->{RegLinDir}/${$models}->{RegLinModel}";
    $image->{nlinmodel} = "${$models}->{RegNLDir}/${$models}->{RegNLModel}";
    $image->{surfregmodel} = "${$models}->{SurfRegModelDir}/${$models}->{SurfRegModel}";
    $image->{surfregdataterm} = "${$models}->{SurfRegModelDir}/${$models}->{SurfRegDataTerm}";
    $image->{surfmask} = "${$models}->{SurfaceMaskDir}/${$models}->{SurfaceMask}";
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

    $image->{directories}{VBM} = "VBM" unless( $vbm eq "noVBM" );
    $image->{directories}{SEG} = "segment" unless( $animal eq "noANIMAL" );
    $image->{directories}{SURF} = "surfaces" unless( $surface eq "noSURFACE" );
    $image->{directories}{SR} = "transforms/surfreg" unless( $surface eq "noSURFACE" );
    $image->{directories}{THICK} = "thickness";

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
    $image->{cls_volumes} = "${cls_dir}/${prefix}_${dsid}_cls_volumes.dat";
    $image->{artefact} = "${cls_dir}/${prefix}_${dsid}_artefact.mnc";
    $image->{pve_prefix} = "${cls_dir}/${prefix}_${dsid}_pve";
    $image->{pve_wm} = "$image->{pve_prefix}_wm.mnc";
    $image->{pve_gm} = "$image->{pve_prefix}_gm.mnc";
    $image->{pve_csf} = "$image->{pve_prefix}_csf.mnc";
    $image->{curve_prefix} = "${tmp_dir}/${prefix}_${dsid}_curve";
    $image->{curve_cg} = "$image->{curve_prefix}_cg.mnc";

    # Define the VBM files.
    my $VBM_Dir = "${Base_Dir}/$image->{directories}{VBM}";
    unless ($image->{VBM} eq "noVBM") {
      $image->{VBM_cls_masked} = "${VBM_Dir}/${prefix}_${dsid}_cls_masked.mnc";
      $image->{VBM_smooth_wm} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_wm.mnc";
      $image->{VBM_smooth_gm} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_gm.mnc";
      $image->{VBM_smooth_csf} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_csf.mnc";
      unless ($image->{VBM_symmetry} eq "noSymmetry") {
        $image->{VBM_smooth_wm_sym} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_wm_sym.mnc";
        $image->{VBM_smooth_gm_sym} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_gm_sym.mnc";
        $image->{VBM_smooth_csf_sym} = "${VBM_Dir}/${prefix}_${dsid}_smooth_${VBM_fwhm}mm_csf_sym.mnc";
      }
    }

    # Define brain-masking files.
    my $mask_dir = "${Base_Dir}/$image->{directories}{MASK}";
    if( -e "${Source_Dir}/${prefix}_${dsid}_mask.mnc.gz" ) {
      $image->{user_mask} = "${Source_Dir}/${prefix}_${dsid}_mask.mnc.gz",
    } else {
      $image->{user_mask} = "${Source_Dir}/${prefix}_${dsid}_mask.mnc",
    }
    $image->{brain_mask} = "${mask_dir}/${prefix}_${dsid}_brain_mask.mnc";
    $image->{skull_mask_native} = "${mask_dir}/${prefix}_${dsid}_skull_mask_native.mnc";
    $image->{skull_mask_tal} = "${mask_dir}/${prefix}_${dsid}_skull_mask.mnc";
    $image->{cortex} = "${mask_dir}/${prefix}_${dsid}_cortex.obj";

    # Define ANIMAL segmentation files.
    my $seg_dir = "${Base_Dir}/$image->{directories}{SEG}";
    unless ($image->{animal} eq "noANIMAL") {
      $image->{t1_tal_nl_animal_xfm} = "${seg_dir}/${prefix}_${dsid}_nlfit_It.xfm";
      $image->{stx_labels} = "${seg_dir}/${prefix}_${dsid}_stx_labels.mnc";
      $image->{label_volumes} = "${seg_dir}/${prefix}_${dsid}_masked.dat";
      $image->{lobe_volumes} = "${seg_dir}/${prefix}_${dsid}_lobes.dat";
      $image->{stx_labels_masked} = "${seg_dir}/${prefix}_${dsid}_stx_labels_masked.mnc";
      unless( $surface eq "noSURFACE" ) {
        $image->{animal_labels}{left} = "${seg_dir}/${prefix}_${dsid}_animal_surface_labels_left.txt";
        $image->{animal_labels}{right} = "${seg_dir}/${prefix}_${dsid}_animal_surface_labels_right.txt";
        $image->{lobe_areas}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_left.dat";
        $image->{lobe_areas}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_areas_right.dat";
        $image->{lobe_thickness}{left} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_$image->{tmethod}_$image->{tkernel}mm_left.dat";
        $image->{lobe_thickness}{right} = "${seg_dir}/${prefix}_${dsid}_lobe_thickness_$image->{tmethod}_$image->{tkernel}mm_right.dat";
      } else {
        $image->{animal_labels}{left} = undef;
        $image->{animal_labels}{right} = undef;
        $image->{lobe_areas}{left} = undef;
        $image->{lobe_areas}{right} = undef;
        $image->{lobe_thickness}{left} = undef;
        $image->{lobe_thickness}{right} = undef;
      }
    } else {
      $image->{t1_tal_nl_animal_xfm} = undef;
      $image->{stx_labels} = undef;
      $image->{label_volumes} = undef;
      $image->{lobe_volumes} = undef;
      $image->{stx_labels_masked} = undef;
      $image->{animal_labels}{left} = undef;
      $image->{animal_labels}{right} = undef;
      $image->{lobe_areas}{left} = undef;
      $image->{lobe_areas}{right} = undef;
      $image->{lobe_thickness}{left} = undef;
      $image->{lobe_thickness}{right} = undef;
    }

    # Define surface files.
    my $surf_dir = "${Base_Dir}/$image->{directories}{SURF}";
    unless ($image->{surface} eq "noSURFACE") {
      $image->{white}{left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_81920.obj";
      $image->{white}{right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_81920.obj";

      $image->{cal_white}{left} = "${surf_dir}/${prefix}_${dsid}_white_surface_left_calibrated_81920.obj";
      $image->{cal_white}{right} = "${surf_dir}/${prefix}_${dsid}_white_surface_right_calibrated_81920.obj";

      $image->{gray}{left} = "${surf_dir}/${prefix}_${dsid}_gray_surface_left_81920.obj";
      $image->{gray}{right} = "${surf_dir}/${prefix}_${dsid}_gray_surface_right_81920.obj";

      $image->{mid_surface}{left} = "${surf_dir}/${prefix}_${dsid}_mid_surface_left_81920.obj";
      $image->{mid_surface}{right} = "${surf_dir}/${prefix}_${dsid}_mid_surface_right_81920.obj";

      unless( $image->{combinesurfaces} ) {
        $image->{cal_white}{full} = "${surf_dir}/${prefix}_${dsid}_white_surface_calibrated_81920.obj";
        $image->{gray}{full} = "${surf_dir}/${prefix}_${dsid}_gray_surface_81920.obj";
        $image->{mid_surface}{full} = "${surf_dir}/${prefix}_${dsid}_mid_surface_81920.obj";
      }

      unless( $image->{resamplesurfaces} ) {
        $image->{cal_white_rsl}{left} = "${surf_dir}/${prefix}_${dsid}_white_surface_rsl_left_calibrated_81920.obj";
        $image->{cal_white_rsl}{right} = "${surf_dir}/${prefix}_${dsid}_white_surface_rsl_right_calibrated_81920.obj";
        $image->{gray}{left_rsl} = "${surf_dir}/${prefix}_${dsid}_gray_surface_rsl_left_81920.obj";
        $image->{gray}{right_rsl} = "${surf_dir}/${prefix}_${dsid}_gray_surface_rsl_right_81920.obj";
        $image->{mid_surface_rsl}{left} = "${surf_dir}/${prefix}_${dsid}_mid_surface_rsl_left_81920.obj";
        $image->{mid_surface_rsl}{right} = "${surf_dir}/${prefix}_${dsid}_mid_surface_rsl_right_81920.obj";
      }

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
      $image->{rms}{left} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_left.txt";
      $image->{rms}{right} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm_right.txt";
      $image->{rms}{full} = "${thick_dir}/${prefix}_${dsid}_native_rms_$image->{tmethod}_$image->{tkernel}mm.txt";
      $image->{rms_rsl}{left} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_left.txt";
      $image->{rms_rsl}{right} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_right.txt";
      $image->{rms_rsl}{full} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm.txt";
      $image->{rms_rsl}{asym_hemi} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_asym_hemi.txt";
      $image->{rms_rsl}{asym_full} = "${thick_dir}/${prefix}_${dsid}_native_rms_rsl_$image->{tmethod}_$image->{tkernel}mm_asym.txt";
      $image->{cerebral_volume} = "${thick_dir}/${prefix}_${dsid}_cerebral_volume.dat";

      # Define cortical mean curvature files.
      my $thick_dir = "${Base_Dir}/$image->{directories}{THICK}";
      $image->{mc}{left} = "${thick_dir}/${prefix}_${dsid}_native_mc_$image->{tkernel}mm_left.txt";
      $image->{mc}{right} = "${thick_dir}/${prefix}_${dsid}_native_mc_$image->{tkernel}mm_right.txt";
      $image->{mc_rsl}{left} = "${thick_dir}/${prefix}_${dsid}_native_mc_rsl_$image->{tkernel}mm_left.txt";
      $image->{mc_rsl}{right} = "${thick_dir}/${prefix}_${dsid}_native_mc_rsl_$image->{tkernel}mm_right.txt";

      # Define cortical mean curvature files.
      $image->{gyrification_index}{left} = "${surf_dir}/${prefix}_${dsid}_gi_left.dat";
      $image->{gyrification_index}{right} = "${surf_dir}/${prefix}_${dsid}_gi_right.dat";
    }

    # Define verification files.
    my $verify_dir = "${Base_Dir}/$image->{directories}{VER}";
    $image->{verify} = "${verify_dir}/${prefix}_${dsid}_verify.png";
    $image->{verify_clasp} = "${verify_dir}/${prefix}_${dsid}_clasp.png";
    $image->{skull_mask_nat_stx} = "${tmp_dir}/${prefix}_${dsid}_skull_mask_native_stx.mnc";
    $image->{t1_nl_final} = "${Base_Dir}/$image->{directories}{FINAL}/${prefix}_${dsid}_t1_nl.mnc";
    $image->{surface_qc} = "${verify_dir}/${prefix}_${dsid}_surface_qc.txt";
    $image->{brainmask_qc} = "${verify_dir}/${prefix}_${dsid}_brainmask_qc.txt";
    $image->{classify_qc} = "${verify_dir}/${prefix}_${dsid}_classify_qc.txt";

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
  } else {
    if( -e "${sourceDir}/${prefix}_${dsid}_${type}.mnc.Z" ) {
      $suffix = ".Z";
    }
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

  if( !( $image->{VBM} eq "VBM" || $image->{VBM} eq "noVBM" ) ) {
    die "ERROR: Invalid option for VBM.\n";
  }

  if( !( $image->{animal} eq "ANIMAL" || $image->{animal} eq "noANIMAL" ) ) {
    die "ERROR: Invalid option for ANIMAL segmentation.\n";
  }

  if( !( $image->{surface} eq "SURFACE" || $image->{surface} eq "noSURFACE" ) ) {
    die "ERROR: Invalid option for surface extraction.\n";
  }

  # The following parameters are direct inputs from user so check them.

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
  if( !( $image->{tmethod} eq "tlink" ||
       $image->{tmethod} eq "tlaplace" ||
       $image->{tmethod} eq "tnear" ||
       $image->{tmethod} eq "tnormal" ) ) {
    die "ERROR: Cortical thickness method ($image->{tmethod}) must be tlink, tlaplace, tnear, or tnormal.\n";
  }

  # value of tkernel must be a positive integer number or zero
  if( !check_value( $image->{tkernel}, $PositiveFloat ) ) {
    die "ERROR: Value of blurring kernel ($image->{tkernel}) must be a positive integer number.\n";
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
  print PIPE "Interpolation method from native to stereotaxic is $image->{interpMethod}\n";
  print PIPE "N3 distance is $image->{nuc_dist}mm\n";
  print PIPE "Linear registration type is $image->{lsqtype}\n";
  if( $image->{surface} eq "SURFACE" ) {
    print PIPE "Cortical thickness using $image->{tmethod}, blurred at $image->{tkernel}mm\n";
  }
  print PIPE "Model for linear registration is\n  $image->{linmodel}\n";
  print PIPE "Model for non-linear registration is\n  $image->{nlinmodel}\n";
  print PIPE "Model for surface registration is\n  $image->{surfregmodel}\n";
  print PIPE "Dataterm for surface registration is\n  $image->{surfregdataterm}\n";
  print PIPE "Surface mask for linear registration is\n  $image->{surfmask}\n";
  print PIPE "Template for image-processing is\n  $image->{template}\n";
  if( $image->{VBM} eq "VBM" ) {
    print PIPE "VBM analysis with volumetric blurring $image->{VBM_fwhm}mm,\n";
    if( $image->{VBM_symmetry} eq "Symmetry" ) {
      print PIPE "  with symmetry maps, ";
    } else {
      print PIPE "  without symmetry maps, ";
    }
    if( $image->{VBM_cerebellum} eq "Cerebellum" ) {
      print PIPE "with cerebellum\n";
    } else {
      print PIPE "without cerebellum\n";
    }
  }
  close PIPE;
}

# Create a list of references to cite for the algorithms used in CIVET.

sub make_references {

  my $image = shift;
  my $Target_Dir = shift;

  print "\nCreating references ${Target_Dir}/References.txt...\n\n";

  open PIPE, "> ${Target_Dir}/References.txt";
  print PIPE "The following references must be included in any publication\n";
  print PIPE "using CIVET.\n\n";

  print PIPE "Non-uniformity corrections\n";
  print PIPE "==========================\n";
  print PIPE "  J.G. Sled, A.P. Zijdenbos and A.C. Evans, \"A non-parametric method\n";
  print PIPE "     for automatic correction of intensity non-uniformity in MRI data\",\n";
  print PIPE "     in \"IEEE Transactions on Medical Imaging\", vol. 17, n. 1,\n";
  print PIPE "     pp. 87-97, 1998\n\n";

  print PIPE "Stereotaxic registration\n";
  print PIPE "========================\n";
  print PIPE "  [1] D. L. Collins, P. Neelin, T. M. Peters and A. C. Evans,\n";
  print PIPE "  \"Automatic 3D Inter-Subject Registration of MR Volumetric Data in\n";
  print PIPE "  Standardized Talairach Space,\" Journal of Computer Assisted\n";
  print PIPE "  Tomography, 18(2) pp. 192-205, 1994\n\n";
  print PIPE "  If avg305 model is used, cite:\n";
  print PIPE "  ------------------------------\n";
  print PIPE "    Stereotaxic registration of the MRI volumes was achieved using the\n";
  print PIPI "    mni\_autoreg package (www.bic.mni.mcgill.ca/packages) [1] with the\n";
  print PIPE "    MNI305 target [2].\n";
  print PIPE "    [2] A. C. Evans, D. L. Collins, S. R. Mills, E. D. Brown, R. L.\n";
  print PIPE "    Kelly, and T. M. Peters, \"3D statistical neuroanatomical models from\n";
  print PIPE "    305 MRI volumes,\" San Francisco, CA, USA, 1994.\n\n";
  print PIPE "  If icbm152 linear model is used, cite:\n";
  print PIPE "  --------------------------------------\n";
  print PIPE "    Stereotaxic registration of the MRI volumes was achieved using the\n";
  print PIPI "    mni\_autoreg package (www.bic.mni.mcgill.ca/packages) [1] with the\n";
  print PIPE "    ICBM152 linear target [3].\n";
  print PIPE "    [3] J. Mazziotta, A. Toga, A. Evans, P. Fox, J. Lancaster, K. Zilles,\n";
  print PIPE "    R. Woods, T. Paus, G. Simpson, B. Pike, C. Holmes, L. Collins,\n";
  print PIPE "    P. Thompson, D. MacDonald, M. Iacoboni, T. Schormann, K. Amunts,\n";
  print PIPE "    N. Palomero-Gallagher, S. Geyer, L. Parsons, K. Narr, N. Kabani,\n";
  print PIPE "    G. Le Goualher, D. Boomsma, T. Cannon, R. Kawashima, and B. Mazoyer,\n";
  print PIPE "    \"A probabilistic atlas and reference system for the human\n";
  print PIPE "    brain: International Consortium for Brain Mapping (ICBM),\"\n";
  print PIPE "    Philos Trans R Soc Lond B Biol Sci, vol. 356, pp. 1293-322, 2001.\n\n";
  print PIPE "  If icbm152 non-linear 6th generation symmetric model is used, cite:\n";
  print PIPE "  -------------------------------------------------------------------\n";
  print PIPE "    Stereotaxic registration of the MRI volumes was achieved using the\n";
  print PIPI "    mni\_autoreg package (www.bic.mni.mcgill.ca/packages) [1] with the\n";
  print PIPE "    ICBM152 non-linear 6th generation target [4].\n";
  print PIPE "    [4] G. Grabner, A. L. Janke, M. M. Budge, D. Smith, J. Pruessner,\n";
  print PIPE "    and D. L. Collins, \"Symmetric atlasing and model based segmentation:\n";
  print PIPE "    an application to the hippocampus in older adults,\" Med Image Comput\n";
  print PIPE "    Comput Assist Interv Int Conf Med Image Comput Comput Assist Interv,\n";
  print PIPE "    vol. 9, pp. 58-66, 2006.\n\n";

  print PIPE "Brain-masking\n";
  print PIPE "=============\n";
  print PIPE "  S.M. Smith, \"Fast robust automated brain extraction,\" Human Brain\n";
  print PIPE "  Mapping, 17(3):143-155, November 2002.\n\n";

  print PIPE "Classification\n";
  print PIPE "==============\n";
  print PIPE "  Zijdenbos, A., Forghani, R., and Evans, A., \"Automatic Quantification\n";
  print PIPE "  of MS Lesions in 3D MRI Brain Data Sets: Validation of INSECT,\". In\n";
  print PIPE "  Medical Image Computing and Computer-Assisted Interventation (MICCAI98),\n";
  print PIPE "  W.M. Wells, A. Colchester, and S. Delp, eds. (Cambridge, MA, Springer-\n";
  print PIPE "  Verlag Berlin Heidelberg), pp. 439-448, 1998.\n\n";

  print PIPE "  Tohka, J., Zijdenbos, A., and Evans, A., \"Fast and robust parameter estimation\n";
  print PIPE "  for statistical partial volume models in brain MRI,\" NeuroImage 23:1, pp. 84-97\n";
  print PIPE "  2004.\n\n";

  if( $image->{surface} eq "SURFACE" ) {
    print PIPE "Surface extraction\n";
    print PIPE "==================\n";
    print PIPE " ... paper by Oliver Lyttelton (extraction by hemispheres)\n";

    print PIPE "  Kim, J.S., Singh, V., Lee, J.K., Lerch, J., Ad-Dab'bagh, Y., MacDonald, D.,\n";
    print PIPE "  Lee, J.M., Kim, S.I., and Evans, A.C., \"Automated 3-D extraction and \n";
    print PIPE "  evaluation of the inner and outer cortical surfaces using a Laplacian \n";
    print PIPE "  map and partial volume effect classification,\" NeuroImage 27, pp. 210-221,\n";
    print PIPE "  2005.\n\n";

    print PIPE "  MacDonald, D., Kabani, N., Avis, D., and Evans, A.C., \"Automated 3-D\n";
    print PIPE "  Extraction of Inner and Outer Surfaces of Cerebral Cortex from MRI.\n";
    print PIPE "  NeuroImage 12, pp. 340-356, 2000.\n\n";

    print PIPE "Cortical thickness\n";
    print PIPE "==================\n";
    print PIPE "  Lerch, J.P. and Evans, A.C., \"Cortical thickness analysis examined through\n";
    print PIPE "  power analysis and a population simulation,\" NeuroImage 24, pp. 163-173,\n";
    print PIPE "  2005.\n\n";

    print PIPE "Surface diffusion smoothing\n";
    print PIPE "===========================\n";
    print PIPE "  M. K. Chung and J. Taylor, \"Diffusion Smoothing on Brain Surface\n";
    print PIPE "  via Finite Element Method,\" Biomedical Imaging: Macro to Nano, 2004,\n";
    print PIPE "  IEEE International Symposium on, vol 1, pp. 432-435, 2004.\n\n";

    print PIPE "Surface registration\n";
    print PIPE "====================\n";
    print PIPE "  S.M. Robbins, \"Anatomical Standardization of the Human Brain in Euclidean\n";
    print PIPE "  3-Space and on the Cortical 2-Manifold,\" Ph.D. Thesis, School of Computer\n";
    print PIPE "  Science (Montreal, McGill University), 2004.\n\n";
    print PIPE "  O. Lyttelton, M. Boucher, S. Robbins, and A. Evans, \"An unbiased iterative\n";
    print PIPE "  group registration template for cortical surface analysis,\" NeuroImage 34,\n";
    print PIPE "  pp. 1535-1544, 2007\n\n";
  }

  if( $image->{animal} eq "ANIMAL" ) {
    # print PIPE "ANIMAL segmentation\n";
    # print PIPE "===================\n";
    # print PIPE " ... paper by Louis Collins\n\n";
  }

  close PIPE;
}

1;
