#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
#Non-uniformity correction and normalization in stereotaxic space.

package Clean_Scans;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {

    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $regModel = @_[3];

    my $input_files  = ${$image}->get_hash( "tal" );
    my $output_files = ${$image}->get_hash( "final" );
    my $nuc_dist = ${$image}->{nuc_dist};
    my $nuc_damping = ${$image}->{nuc_damping};
    my $nuc_cycles = 3;
    my $nuc_iters = 100;

    my $multi = ( ${$image}->{inputType} eq "multispectral" ) ||
                ( ${$image}->{maskType} eq "multispectral" );

    my @Clean_Scans_complete = ();

    foreach my $type ( keys %{ $input_files } ) {
      my $input = $input_files->{$type};
      my $output = $output_files->{$type};
      next if( $type ne "t1" && !$multi );
      if( -e ${$image}->{$type}{source} ) {
        ${$pipeline_ref}->addStage(
             { name => "nuc_inorm_${type}",
             label => "non-uniformity correction and normalization on stx ${type}",
             inputs => [ $input ],
             outputs => [ $output ],
             args => ["nuc_inorm_stage", $input, $output, "stx", ${regModel},
                      "none", 0, $nuc_dist, $nuc_damping, $nuc_cycles, 
                      $nuc_iters],
             prereqs => $Prereqs } );
        push @Clean_Scans_complete, ("nuc_inorm_${type}");
      }
    }

    return( \@Clean_Scans_complete );
}


1;
