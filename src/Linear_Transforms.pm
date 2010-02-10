#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# Generate the linear transforms to stereotaxic space.
# For best results:
#   1 - apply some preliminary nu_correct in native space
#       (this is technically incorrect as nu_correct assumes
#       that the image is in stereotaxic space, but in general
#       this really helps enough to remove non-uniformities 
#       for mincbet to produce a good mask and bestlinreg to
#       compute a good linear transformation).
#   2 - compute a brain mask in native space, using mincbet,
#       for use by bestlinreg for registration.
#   3 - finally compute the linear transformation
#   4 - apply linear transformation to native files
# Note: We will rerun nu_correct in stereotaxic space for use
#       by the classifier so everything will be fine. A new
#       brain mask will also be computed.
#
package Linear_Transforms;
use strict;
use PMP::PMP;
use MRI_Image;
use File::Basename;

# Compute the transformations necessary to bring source images into MNI-Talairach
# space.

sub stx_register {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $regModel = @_[3];
    my $intermediateModel = @_[4];

    my $skull_mask = ${$image}->{skull_mask_native};

    my $t1_tal_xfm    = ${$image}->{t1_tal_xfm};
    my $t2pd_t1_xfm  = ${$image}->{t2pd_t1_xfm};
    my $t2pd_tal_xfm  = ${$image}->{t2pd_tal_xfm};
    my $tal_to_6_xfm  = ${$image}->{tal_to_6_xfm};
    my $tal_to_7_xfm  = ${$image}->{tal_to_7_xfm};

    my $regModelDir  = dirname( $regModel );
    my $regModelName = basename( $regModel );

    # Preliminary nu_correct on the native images to improve the 
    # results of mincbet and bestlinreg. Run only 100 iterations.
    # No need to be too fancy at this stage.

    my $native_files = ${$image}->get_hash( "native" );
    my $nuc_files = ${$image}->get_hash( "nuc" );
    my $nuc_dist = ${$image}->{nuc_dist};
    my $nuc_damping = ${$image}->{nuc_damping};
    my $nuc_cycles = 1;
    my $nuc_iters = 100;

    my @nuc_complete = ();

    foreach my $type ( keys %{ $native_files } ) {
      my $input = $native_files->{$type};
      my $output = $nuc_files->{$type};
      if( -e $input ) {
        my $mask_option = "none";
        ${$pipeline_ref}->addStage(
             { name => "nuc_${type}_native",
             label => "non-uniformity correction on native ${type}",
             inputs => [ $input ],
             outputs => [ $output ],
             args => ["nuc_inorm_stage", $input, $output, $mask_option, $nuc_dist, 
                      $nuc_damping, $nuc_cycles, $nuc_iters],
             prereqs => $Prereqs } );
        push @nuc_complete, ("nuc_${type}_native");
      }
    }

    # Compute the transformation necessary to align t2/pd to t1. Use
    # the images after correction of non-uniformities. In case both t2 
    # and pd exist, use t2. Assume that t2 and pd have been acquired 
    # together and that they are aligned with one another.

    my $t1_input = ${$image}->{t1}{nuc};
    my $t2_input = ${$image}->{t2}{nuc};
    my $pd_input = ${$image}->{pd}{nuc};

    my @skullInputs = ($t1_input);
    push @skullInputs, ($t2_input) if (-e ${$image}->{t2}{native});
    push @skullInputs, ($pd_input) if (-e ${$image}->{pd}{native});
    my $Coregister_complete = \@nuc_complete;

    if( -e ${$image}->{t2}{native} ) {
      ${$pipeline_ref}->addStage(
           { name => "t2_pd_coregister",
           label => "co-register t2/pd to t1",
           inputs => [$t1_input, $t2_input],
           outputs => [$t2pd_t1_xfm],
           args => ["mritoself", "-clobber", "-nothreshold", "-mi", "-lsq6", 
                    $t2_input, $t1_input, $t2pd_t1_xfm ],
           prereqs => \@nuc_complete } );
      push @skullInputs, ($t2pd_t1_xfm);
      $Coregister_complete = ["t2_pd_coregister"];
    } else {
      if( -e ${$image}->{pd}{native} ) {
        ${$pipeline_ref}->addStage(
             { name => "t2_pd_coregister",
             label => "co-register t2/pd to t1",
             inputs => [$t1_input, $pd_input],
             outputs => [$t2pd_t1_xfm],
             args => ["mritoself", "-clobber", "-nothreshold", "-mi", "-lsq6", 
                      $pd_input, $t1_input, $t2pd_t1_xfm ],
             prereqs => \@nuc_complete } );
        push @skullInputs, ($t2pd_t1_xfm);
        $Coregister_complete = ["t2_pd_coregister"];
      }
    }

    ##### Compute a preliminary skull mask using t1 native only, 
    ##### to apply during linear registration. Use the user mask
    ##### if one is given.

    my $user_mask = ${$image}->{user_mask};
    if( -e $user_mask ) {
      ${$pipeline_ref}->addStage(
           { name => "skull_masking_native",
           label => "masking of skull in native space",
           inputs => [],
           outputs => [$skull_mask],
           args => ["ln", "-sf", $user_mask, $skull_mask ],
           prereqs => $Prereqs } );

    } else {
      ${$pipeline_ref}->addStage(
           { name => "skull_masking_native",
           label => "masking of skull in native space",
           inputs => \@skullInputs,
           outputs => [$skull_mask],
           args => ["remove_skull", "t1Only", $t1_input, $t2_input,
                    $pd_input, $t2pd_t1_xfm, $skull_mask ],
           prereqs => $Coregister_complete });
    }

    ##### Compute transforms to STX space directly or indirectly #####

    my @extraTransform;
    if ( $intermediateModel ) {

      my $IntermediateModelDir = dirname( $intermediateModel );
      my $IntermediateModelName = basename( $intermediateModel );
      my $t1_suppressed = ${$image}->{t1_suppressed};

      push @extraTransform, "-two-stage";
      push @extraTransform, "-premodeldir";
      push @extraTransform, $IntermediateModelDir;
      push @extraTransform, "-premodel";
      push @extraTransform, $IntermediateModelName;
      push @extraTransform, "-t1suppressed";
      push @extraTransform, $t1_suppressed;

    } else {
      push @extraTransform, "-single-stage";
    }

    # TEMPORARY: This will actually recompute t2pd_t1_xfm a second time,
    #            but no big deal, it's cheap. This can be cleaned-up later.

    my @registerInputs = ($t1_input);
    push @registerInputs, ($t2_input) if (-e ${$image}->{t2}{native});
    push @registerInputs, ($pd_input) if (-e ${$image}->{pd}{native});

    my @registerOutputs = ($t1_tal_xfm);
    if ( (-e ${$image}->{t2}{native}) or (-e ${$image}->{pd}{native}) ) {
      push @registerOutputs, ($t2pd_tal_xfm);
    }

    ${$pipeline_ref}->addStage(
       { name => "stx_register",
         label => "compute transforms to stx space",
         inputs => \@registerInputs,
         outputs => \@registerOutputs,
         args => ["multispectral_stx_registration", "-nothreshold",
                  "-clobber", @extraTransform, ${$image}->{lsqtype},
                  "-modeldir", $regModelDir, "-model", $regModelName,
                  "-source_mask", $skull_mask,
                  $t1_input, $t2_input, $pd_input,
                  $t1_tal_xfm, $t2pd_tal_xfm ],
         prereqs => ["skull_masking_native"] } );

   ############## Generate the tal to 6 and 7 space transforms (only on t1)

    ${$pipeline_ref}->addStage(
         { name => "stx_tal_to_6",
         label => "compute transforms to 6 param space from Tal.",
         inputs => [$t1_tal_xfm ],
         outputs => [$tal_to_6_xfm],
         args => ["talto6", $t1_tal_xfm, $tal_to_6_xfm],
         prereqs => ["stx_register"] });

    ${$pipeline_ref}->addStage(
         { name => "stx_tal_to_7",
         label => "compute transforms to 7 param space from Tal",
         inputs => [$t1_tal_xfm],
         outputs => [$tal_to_7_xfm],
         args => ["talto7", $t1_tal_xfm, $tal_to_7_xfm],
         prereqs => ["stx_register"] });

    #Must now set the completion condition.

    my $Linear_Transforms_complete = ["stx_tal_to_6", "stx_tal_to_7"];

    return( $Linear_Transforms_complete );    
}   



# Since the transformations necessary to bring source images into MNI-Talairach
# space had been computed in the previous stages, now we need to 'resample' the
# images, essentially applying the computed transformation on the actual images.


sub transform {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $Template = @_[3];

    my $t1_native = (-e ${$image}->{t1}{native}) ? ${$image}->{t1}{native} : undef;
    my $t2_native = (-e ${$image}->{t2}{native}) ? ${$image}->{t2}{native} : undef;
    my $pd_native = (-e ${$image}->{pd}{native}) ? ${$image}->{pd}{native} : undef;
    my $t1_tal  = (-e ${$image}->{t1}{native}) ? ${$image}->{t1}{tal} : undef;
    my $t2_tal  = (-e ${$image}->{t2}{native}) ? ${$image}->{t2}{tal} : undef;
    my $pd_tal  = (-e ${$image}->{pd}{native}) ? ${$image}->{pd}{tal} : undef;

    my $t1_tal_xfm   = ${$image}->{t1_tal_xfm};
    my $t2pd_tal_xfm = ${$image}->{t2pd_tal_xfm};
    my $interpMethod = "-${$image}->{interpMethod}";
    my @Transform_complete = ();

    # Note: Do not use -keep_real_range as it doesn't really do what we
    #       want. It doesn't clip out of bound values; instead, it only
    #       resets the min/max range without changing values. Values that
    #       are out of bounds will be clipped in nuc_inorm_stage (next
    #       step). It also fails for images in float: it sets the real
    #       range to (0,1).

    if( $t1_native ) {
      ${$pipeline_ref}->addStage(
           { name => "tal_t1",
           label => "resample t1 into stereotaxic space",
           inputs => [$t1_native, $t1_tal_xfm],
           outputs => [$t1_tal],
           args => ["mincresample", "-clobber", "-transform",
                   $t1_tal_xfm, "-like", $Template, $interpMethod,
                   $t1_native, $t1_tal],
           prereqs => $Prereqs});
      push @Transform_complete, ("tal_t1");
    }
 
    if( $t2_native ) {
      ${$pipeline_ref}->addStage(
           { name => "tal_t2",
           label => "resample t2 into stereotaxic space",
           inputs => [$t2_native, $t2pd_tal_xfm],
           outputs => [$t2_tal],
           args => ["mincresample", "-clobber", "-transform",
                   $t2pd_tal_xfm, "-like", $Template, $interpMethod,
                   $t2_native, $t2_tal],
           prereqs => $Prereqs});
      push @Transform_complete, ("tal_t2");
    }

    if( $pd_native ) {
      ${$pipeline_ref}->addStage(
           { name => "tal_pd",
           label => "resample pd into stereotaxic space",
           inputs => [$pd_native, $t2pd_tal_xfm],
           outputs => [$pd_tal],
           args => ["mincresample", "-clobber", "-transform",
                   $t2pd_tal_xfm, "-like", $Template, $interpMethod,
                   $pd_native, $pd_tal],
           prereqs => $Prereqs});
      push @Transform_complete, ("tal_pd");
    }

    return( \@Transform_complete );
}


1;

