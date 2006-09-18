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
      my $image_type = `mincinfo -vartype image $source_files->{t1}`;
      if( $image_type eq "byte" ) {
        print "WARNING: Data type for image $source_files->{t1} is byte.\n";
        print "         This may result in loss of resolution.\n";
      }
    } else {
      die "Error: t1 image file $source_files->{t1} must exist for pipeline to continue.\n";
    }

    # look for t2 and pd images if we need them later.
    if( ( $maskType eq "multispectral" ) or ($inputType eq "multispectral") ) {
      if( -e $source_files->{t2} ) {
        system( "ln -fs $source_files->{t2} $native_files->{t2}" );
        my $image_type = `mincinfo -vartype image $source_files->{t2}`;
        if( $image_type eq "byte" ) {
          print "WARNING: Data type for image $source_files->{t2} is byte.\n";
          print "         This may result in loss of resolution.\n";
        }
      }
      if( -e $source_files->{pd} ) {
        system( "ln -fs $source_files->{pd} $native_files->{pd}" );
        my $image_type = `mincinfo -vartype image $source_files->{pd}`;
        if( $image_type eq "byte" ) {
          print "WARNING: Data type for image $source_files->{pd} is byte.\n";
          print "         This may result in loss of resolution.\n";
        }
      }
    }

    my $Link_Native_complete = [];

    return( $Link_Native_complete );
}


1;
