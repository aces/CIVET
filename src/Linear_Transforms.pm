# Generate the linear tal transforms for simple t1 pipeline

package Linear_Transforms;
use strict;
use PMP::PMP;
use MRI_Image;
use File::Basename;

sub stx_register {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $regModel = @_[3];
    my $intermediateModel = @_[4];

    my $t1_input   = ${$image}->{t1}{nuc};
    my $t2_input   = ${$image}->{t2}{nuc};
    my $pd_input   = ${$image}->{pd}{nuc};

    my $maskType = "t1Only";
    my $cropNeck = ${$image}->{cropNeck};
    my $skull_mask = ${$image}->{skull_mask_native};

    my $t1_tal_xfm    = ${$image}->{t1_tal_xfm};
    my $t2pd_tal_xfm  = ${$image}->{t2pd_tal_xfm};
    my $tal_to_6_xfm  = ${$image}->{tal_to_6_xfm};
    my $tal_to_7_xfm  = ${$image}->{tal_to_7_xfm};

    my $regModelDir  = dirname( $regModel);
    my $regModelName = basename( $regModel);

    ##### Compute a preliminary skull mask for t1 native, to apply
    ##### during linear registration. Use t1 only since t2/pd have
    ##### not been registered to t1 yet. Use 1.0mm sampling.

    ${$pipeline_ref}->addStage(
         { name => "skull_masking_native",
         label => "masking of skull in native space",
         inputs => [$t1_input],
         outputs => [$skull_mask],
         args => ["remove_skull", $maskType, $cropNeck, $t1_input, undef,
                  undef, $skull_mask ],
         prereqs => $Prereqs });

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
                  "-clobber", @extraTransform, 
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

    my $t1_native = (-e ${$image}->{t1}{native}) ? ${$image}->{t1}{nuc} : undef;
    my $t2_native = (-e ${$image}->{t2}{native}) ? ${$image}->{t2}{nuc} : undef;
    my $pd_native = (-e ${$image}->{pd}{native}) ? ${$image}->{pd}{nuc} : undef;
    my $t1_final  = (-e ${$image}->{t1}{native}) ? ${$image}->{t1}{final} : undef;
    my $t2_final  = (-e ${$image}->{t2}{native}) ? ${$image}->{t2}{final} : undef;
    my $pd_final  = (-e ${$image}->{pd}{native}) ? ${$image}->{pd}{final} : undef;

    my $t1_tal_xfm    = ${$image}->{t1_tal_xfm};
    my $t2pd_tal_xfm  = ${$image}->{t2pd_tal_xfm};
    my @Transform_complete = ();

    if( $t1_native ) {
      ${$pipeline_ref}->addStage(
           { name => "final_t1",
           label => "resample t1 into stereotaxic space",
           inputs => [$t1_native, $t1_tal_xfm],
           outputs => [$t1_final],
           args => ["mincresample", "-clobber", "-transform",
                   $t1_tal_xfm, "-like", $Template,
                   $t1_native, $t1_final],
           prereqs => $Prereqs});
      push @Transform_complete, ("final_t1");
    }
 
    if( $t2_native ) {
      ${$pipeline_ref}->addStage(
           { name => "final_t2",
           label => "resample t2 into stereotaxic space",
           inputs => [$t2_native, $t2pd_tal_xfm],
           outputs => [$t2_final],
           args => ["mincresample", "-clobber", "-transform",
                   $t2pd_tal_xfm, "-like", $Template,
                   $t2_native, $t2_final],
           prereqs => $Prereqs});
      push @Transform_complete, ("final_t2");
    }

    if( $pd_native ) {
      ${$pipeline_ref}->addStage(
           { name => "final_pd",
           label => "resample pd into stereotaxic space",
           inputs => [$pd_native, $t2pd_tal_xfm],
           outputs => [$pd_final],
           args => ["mincresample", "-clobber", "-transform",
                   $t2pd_tal_xfm, "-like", $Template,
                   $pd_native, $pd_final],
           prereqs => $Prereqs});
      push @Transform_complete, ("final_pd");
    }

    return( \@Transform_complete );
}


1;

