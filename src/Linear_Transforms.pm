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

# Compute the transformations necessary to bring source images 
# into MNI-Talairach space.

sub stx_register {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $regModel = @_[3];
    my $intermediateModel = @_[4];

    my $t1_tal_xfm    = ${$image}->{t1_tal_xfm};
    my $t2pd_t1_xfm  = ${$image}->{t2pd_t1_xfm};
    my $t2pd_tal_xfm  = ${$image}->{t2pd_tal_xfm};
    my $tal_to_6_xfm  = ${$image}->{tal_to_6_xfm};
    my $tal_to_7_xfm  = ${$image}->{tal_to_7_xfm};

    my $multi = ( ${$image}->{inputType} eq "multispectral" ) ||
                ( ${$image}->{maskType} eq "multispectral" );

    my $regModelDir  = dirname( $regModel );
    my $regModelName = basename( $regModel );

    # Preliminary nu_correct on the native images to improve the 
    # results of bestlinreg. Run only 100 iterations. No need to be 
    # too fancy at this stage.

    my $source_files = ${$image}->get_hash( "source" );
    my $native_files = ${$image}->get_hash( "native" );
    my $nuc_files = ${$image}->get_hash( "nuc" );
    my $headheight = ${$image}->{headheight};
    my $nuc_dist = ${$image}->{nuc_dist};
    my $nuc_damping = ${$image}->{nuc_damping};
    my $nuc_cycles = 1;
    my $nuc_iters = 100;

    my @nuc_complete = ();

    foreach my $type ( keys %{ $native_files } ) {
      my $source = $source_files->{$type};
      my $input = $native_files->{$type};
      my $output = $nuc_files->{$type};

      next if( $type ne "t1" && !$multi );

      if( -e $source ) {
        ${$pipeline_ref}->addStage( {
             name => "nuc_${type}_native",
             label => "non-uniformity correction on native ${type}",
             inputs => [ $input ],
             outputs => [ $output ],
             args => ["nuc_inorm_stage", $input, $output, "native", ${regModel},
                      "none", $headheight, $nuc_dist, $nuc_damping, 
                      $nuc_cycles, $nuc_iters],
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
    push @skullInputs, ($t2_input) if (-e ${$image}->{t2}{source} && $multi);
    push @skullInputs, ($pd_input) if (-e ${$image}->{pd}{source} && $multi);
    my $Coregister_complete = \@nuc_complete;

    if( $multi ) {
      if( -e ${$image}->{t2}{source} ) {
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
        if( -e ${$image}->{pd}{source} ) {
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
    #            Note that multispectral_stx_registration does not save
    #            t2pd_t1_xfm but saves only t2pd_tal_xfm.

    if( ${$image}->{inputIsStx} ) {

      ${$pipeline_ref}->addStage( {
           name => "stx_register",
           label => "compute identity transform to stx space",
           inputs => [],
           outputs => [$t1_tal_xfm],
           args => ["param2xfm", "-clobber", $t1_tal_xfm],
           prereqs => [] } );

      if ( $multi && ( (-e ${$image}->{t2}{source}) or (-e ${$image}->{pd}{source}) ) ) {
        ${$pipeline_ref}->addStage( {
             name => "stx_register_t2pd",
             label => "compute identity transform to stx space for t2/pd",
             inputs => [$t2pd_t1_xfm],
             outputs => [$t2pd_tal_xfm],
             args => ["cp", "-f", $t2pd_t1_xfm, $t2pd_tal_xfm],
             prereqs => $Coregister_complete } );
      }

    } else {

      my @registerInputs = ($t1_input);
      push @registerInputs, ($t2_input) if (-e ${$image}->{t2}{source} && $multi );
      push @registerInputs, ($pd_input) if (-e ${$image}->{pd}{source} && $multi );

      my @registerOutputs = ($t1_tal_xfm);
      if ( $multi && ( (-e ${$image}->{t2}{source}) or (-e ${$image}->{pd}{source}) ) ) {
        push @registerOutputs, ($t2pd_tal_xfm);
      }

      # Note: no more need for a mask with new bestlinreg.pl using -nmi.
      ${$pipeline_ref}->addStage( {
           name => "stx_register",
           label => "compute transforms to stx space",
           inputs => \@registerInputs,
           outputs => \@registerOutputs,
           args => ["multispectral_stx_registration", "-nothreshold",
                    "-clobber", @extraTransform, ${$image}->{lsqtype},
                    "-modeldir", $regModelDir, "-model", $regModelName,
                    "-source_mask", "targetOnly", $t1_input, $t2_input, 
                    $pd_input, $t1_tal_xfm, $t2pd_tal_xfm ],
           prereqs => $Coregister_complete } );
    }

    ############## Generate the tal to 6 and 7 space transforms (only on t1)

    ${$pipeline_ref}->addStage( {
         name => "stx_tal_to_6",
         label => "compute transforms to 6 param space from Tal.",
         inputs => [$t1_tal_xfm ],
         outputs => [$tal_to_6_xfm],
         args => ["talto6", $t1_tal_xfm, $tal_to_6_xfm],
         prereqs => ["stx_register"] });

    ${$pipeline_ref}->addStage( {
         name => "stx_tal_to_7",
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

    my $multi = ( ${$image}->{inputType} eq "multispectral" ) ||
                ( ${$image}->{maskType} eq "multispectral" );

    my $t1_native = (-e ${$image}->{t1}{source}) ? ${$image}->{t1}{native} : undef;
    my $t2_native = (-e ${$image}->{t2}{source} && $multi ) ? ${$image}->{t2}{native} : undef;
    my $pd_native = (-e ${$image}->{pd}{source} && $multi ) ? ${$image}->{pd}{native} : undef;
    my $t1_tal  = (-e ${$image}->{t1}{source}) ? ${$image}->{t1}{tal} : undef;
    my $t2_tal  = (-e ${$image}->{t2}{source} && $multi ) ? ${$image}->{t2}{tal} : undef;
    my $pd_tal  = (-e ${$image}->{pd}{source} && $multi ) ? ${$image}->{pd}{tal} : undef;

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

