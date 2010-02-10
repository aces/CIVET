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


sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $t1_input = ${$image}->{t1}{final};
    my $t2_input = ${$image}->{t2}{final};
    my $pd_input = ${$image}->{pd}{final};

    my $Skull_Mask = ${$image}->{skull_mask_tal};

    # compute a brain mask in stereotaxic space based on t1, t2, pd.

    my $maskType = ${$image}->{maskType};

    my @skullInputs = ();
    push @skullInputs, ($t1_input) if ( -e ${$image}->{t1}{native} );
    push @skullInputs, ($t2_input) if ( -e ${$image}->{t2}{native} );
    push @skullInputs, ($pd_input) if ( -e ${$image}->{pd}{native} );

    ${$pipeline_ref}->addStage(
         { name => "skull_removal",
         label => "removal of skull (in stereotaxic space)",
         inputs => \@skullInputs,
         outputs => [$Skull_Mask],
         args => ["remove_skull", $maskType, $t1_input, $t2_input, 
                  $pd_input, undef, $Skull_Mask ],
         prereqs => $Prereqs });

    my $Skull_Masking_complete = [ "skull_removal" ];

    return( $Skull_Masking_complete );
}


1;
