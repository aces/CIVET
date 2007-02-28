# The Linking stage for simple t1, t2, pd pipeline.
# We demand that image type be better that byte, otherwise the 
# resolution will be too poor.

package Link_Native;
use strict;

use MRI_Image;

sub create_pipeline {
    
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];

    my $inputType = ${$image}->{maskType};
    my $maskType = ${$image}->{inputType};
    my $source_files = ${$image}->get_hash( "source" );
    my $native_files = ${$image}->get_hash( "native" );

    # do the symbolic links on files of known types (t1, t2, pd right now).

    # t1 image file must always exist.
    if( -e $source_files->{t1} ) {
      system( "ln -fs $source_files->{t1} $native_files->{t1}" );
      check_input_image( $source_files->{t1} );
    } else {
      die "Error: t1 image file $source_files->{t1} must exist for pipeline to continue.\n";
    }

    # look for t2 and pd images if we need them later.
    if( ( $maskType eq "multispectral" ) or ($inputType eq "multispectral") ) {
      if( -e $source_files->{t2} ) {
        system( "ln -fs $source_files->{t2} $native_files->{t2}" );
        check_input_image( $source_files->{t2} );
      }
      if( -e $source_files->{pd} ) {
        system( "ln -fs $source_files->{pd} $native_files->{pd}" );
        check_input_image( $source_files->{pd} );
      }
    }

    my $Link_Native_complete = [];

    return( $Link_Native_complete );
}

sub check_input_image {

  my $input = shift;

  my $image_type = `mincinfo -vartype image $input`;
  if( $image_type eq "byte" ) {
    print "WARNING: Data type for image $input is byte.\n";
    print "         This may result in loss of resolution.\n";
  }

  my $xspacing = `mincinfo -attvalue xspace:spacing $input`;
  my $yspacing = `mincinfo -attvalue yspace:spacing $input`;
  my $zspacing = `mincinfo -attvalue zspace:spacing $input`;
  if( $xspacing eq "irregular__" || $yspacing eq "irregular__" ||
      $zspacing eq "irregular__" ) {
    die "ERROR: image file $input has irregular slice spacing.\n";
  }

}

1;
