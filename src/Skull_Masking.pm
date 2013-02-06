#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# Creation of a mask for skull masking, using mincbet on t1, t2, pd
# in stereotaxic space.

package Skull_Masking;
use strict;
use PMP::PMP;
use MRI_Image;

# Generate a brain mask in stereotaxic space using mincbet
# on (t1,t2,pd) or using the provided user-defined mask in
# native space.

sub stereotaxic_mask {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $Skull_Masking_complete = undef;
    my $Skull_Mask = ${$image}->{skull_mask_tal};
    my $t1_input = ${$image}->{t1}{final};

    if( -e ${$image}->{user_mask}) {

      my $user_mask = ${$image}->{skull_mask_native};
      my $t1_tal_xfm = ${$image}->{t1_tal_xfm};

      ${$pipeline_ref}->addStage( {
           name => "user_mask_stx",
           label => "transformation of user mask to stereotaxic space",
           inputs => [$t1_input,$user_mask,$t1_tal_xfm],
           outputs => [$Skull_Mask],
           args => ["mincresample", '-clobber', '-unsigned', '-byte',
                    '-transform', $t1_tal_xfm, '-nearest', '-like',
                    $t1_input, $user_mask, $Skull_Mask ],
           prereqs => $Prereqs });
      $Skull_Masking_complete = [ "user_mask_stx" ];

    } else {

      my $t2_input = ${$image}->{t2}{final};
      my $pd_input = ${$image}->{pd}{final};
      my $t2pd_t1_xfm = ${$image}->{t2pd_t1_xfm};
      my $model_headmask = "${$image}->{nlinmodel}_headmask.mnc";

      my $multi = ( ${$image}->{maskType} eq "multispectral" );
      my @skullInputs = ($t1_input);
      push @skullInputs, ($t2_input) if (-e ${$image}->{t2}{source} && $multi);
      push @skullInputs, ($pd_input) if (-e ${$image}->{pd}{source} && $multi);

      ${$pipeline_ref}->addStage( {
           name => "mincbet_mask_stx",
           label => "removal of skull using mincbet (in stereotaxic space)",
           inputs => [@skullInputs],
           outputs => [$Skull_Mask],
           args => ["remove_skull", ${$image}->{maskType}, $t1_input, $t2_input,
                    $pd_input, $model_headmask, $Skull_Mask ],
           prereqs => $Prereqs });

      $Skull_Masking_complete = [ "mincbet_mask_stx" ];
    }

    return( $Skull_Masking_complete );

}

1;
