#
# Copyright Alan C. Evans
# Professor of Neurology
# McGill University
#
# Stage for regularization of t1, t2, pd, mask. We remove
# direction cosines and impose regular spacing and z,y,x
# internal voxel ordering.

package Link_Native;
use strict;

use MRI_Image;

sub create_pipeline {
    
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $multi = ( ${$image}->{inputType} eq "multispectral" ) ||
                ( ${$image}->{maskType} eq "multispectral" );
    my $source_files = ${$image}->get_hash( "source" );
    my $native_files = ${$image}->get_hash( "native" );

    my $input_t1 = $source_files->{t1};
    my $output_t1 = $native_files->{t1};

    my $input_t2 = ($multi && -e $source_files->{t2}) ? $source_files->{t2} : "none";
    my $output_t2 = ($multi && -e $source_files->{t2}) ? $native_files->{t2} : "none";
    my $input_pd = ($multi && -e $source_files->{pd}) ? $source_files->{pd} : "none";
    my $output_pd = ($multi && -e $source_files->{pd}) ? $native_files->{pd} : "none";
    my $input_mask = (-e ${$image}->{user_mask}) ? ${$image}->{user_mask} : "none";
    my $output_mask = (-e ${$image}->{user_mask}) ? ${$image}->{skull_mask_native} : "none";
    my $input_mp2 = (-e ${$image}->{mp2}) ? ${$image}->{mp2} : "none";
    my $stx_model = ${$image}->{nlinmodel};

    my @outputs = ( $output_t1 );
    push @outputs, $output_t2 if( $input_t2 ne "none" );
    push @outputs, $output_pd if( $input_pd ne "none" );
    push @outputs, $output_mask if( $input_mask ne "none" );

    if( -e $input_t1 ) {
      ${$pipeline_ref}->addStage( {
           name => "clean_native_scan",
           label => "regularization of native scans",
           inputs => [],
           outputs => \@outputs,
           args => ["clean_native_scan", $input_t1, $input_t2, $input_pd,
                    $input_mp2, $input_mask, $output_t1, $output_t2, $output_pd, 
                    $output_mask, $stx_model],
           prereqs => $Prereqs } );
    } else {
      die "Error: t1 image file $input_t1 must exist for pipeline to continue.\n";
    }

    my $Link_Native_complete = ["clean_native_scan"];

    return( $Link_Native_complete );
}

1;
