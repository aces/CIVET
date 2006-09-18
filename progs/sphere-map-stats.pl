#! /usr/bin/env perl
#
# Configurable surface register 
#
# Oliver Lyttelton oliver@bic.mni.mcgill.ca

#

use strict;
use warnings "all";
use Getopt::Tabular;
use File::Basename;
use File::Temp qw/ tempdir /;


my($Help, $Usage, $me);
my(@opt_table, %opt, @args, $tmpdir);

$me = &basename($0);
%opt = (
   'verbose'   => 0,
   'clobber'   => 0,
   );

$Help = <<HELP;
|    $me fully configurable surface fitting...
| 
| Problems or comments should be sent to: oliver\@bic.mni.mcgill.ca
HELP

$Usage = "Usage: $me [options] source_to_target_sm ratio_output.txt area_output.txt\n".
         "       $me -help to list options\n\n";

@opt_table = (
   ["-verbose", "boolean", 0, \$opt{verbose},
      "be verbose" ],
   ["-clobber", "boolean", 0, \$opt{clobber},
      "clobber existing files" ]
         );

# Check arguments
&Getopt::Tabular::SetHelp($Help, $Usage);
&GetOptions (\@opt_table, \@ARGV) || exit 1;
die $Usage if($#ARGV != 2);
my $source_to_target_mapping= shift(@ARGV);
my $ratio_output_file= shift(@ARGV);
my $area_output_file= shift(@ARGV);

# check for files
die "$me: Couldn't find input file: $source_to_target_mapping\n" if (!-e $source_to_target_mapping);

if(-e $ratio_output_file && !$opt{clobber}){
   die "$me: $ratio_output_file exists, -clobber to overwrite\n";
   }
if(-e $area_output_file && !$opt{clobber}){
   die "$me: $area_output_file exists, -clobber to overwrite\n";
   }
# make tmpdir
$tmpdir = &tempdir( "$me-XXXXXXXX", TMPDIR => 1, CLEANUP => 1 );
 $tmpdir = "./";
open INOBJ,$source_to_target_mapping;
my @inobjarray = <INOBJ>;
my $control_mesh_size = $inobjarray[2]*2-4;
my $target_mesh_size =  $inobjarray[3]*2-4;
 
close(INOBJ);

print("target mesh size:${target_mesh_size} control mesh size:${control_mesh_size}\n");

my $control_mesh = "${tmpdir}/control_mesh.obj";
my $target_mesh = "${tmpdir}/target_mesh.obj";
 
#Then we make the control mesh and the sphere mesh
&do_cmd('create_tetra',$control_mesh,0,0,0,1,1,1,$control_mesh_size);
# and the sphere mesh
&do_cmd('create_tetra',$target_mesh,0,0,0,1,1,1,$target_mesh_size);


#now we can do the stats
&do_cmd('surface-map-stats','-proc_ratios','-proc_flipped','-ratio_file',$ratio_output_file,'-area_file',$area_output_file,$target_mesh,$target_mesh,$control_mesh,$source_to_target_mapping);



sub do_cmd { 
   print STDOUT "@_\n" if $opt{verbose};
   system(@_) == 0 or die;
}












