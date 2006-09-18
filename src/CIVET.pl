#! /usr/bin/env perl

##########################################################################################################
##########################################################################################################
### Run CIVET pipeline within the PMP framework. 
###         
###         Includes N3, INSECT, ANIMAL, CLASP2, and Surfreg among others.
###
###         By default, CIVET will run on multispectral data. Symmetry tools can 
###            be invoked optionally. Running on t1 images only, running without 
###            ANIMAL, and adding kiddie registration models for pediatric data
###            are other main options. 
###            CIVET will calculate cortical thickness at each vertex using the 
###            t-link metric (in both registered and native spaces) on surfaces 
###            that have been non-linearly registered. 
###            The default surfaces are made of 81,920 polygons and 40,962 vertices 
###            each. Optionally, CIVET can produce surfaces with 327,680 polygons 
###            and 163,842 vertices.
###            CIVET will also produce regional thickness maps as well as surface 
###            areas based on the intersection of ANIMAL with the surfaces of the 
###            cortex.
###
###         In the current version, CIVET requires a quarantine of the software
###            invoked and an environment file.
###            
###                                       
###   Authors:                                  
###         Based on original pipeline scripts by: Jason Lerch                   
###         Current modifications: Yasser Ad-Dab'bagh
###         Date: May 3, 2005       
###                                    
###   Glossary:                           
###         CIVET: Corticometric Iterative Vertex-based Estimations of  
###            Thickness                  
###         CLASP: Constrained Laplacian ASP       
###         ASP: Anatomic Segmentation using Proximity         
###         PMP: Poor Man's Pipeline
###         N3: Non-parametric Non-uniform intensity Normalization
###         INSECT: Intensity-Normalized Stereotaxic Environment for Classification 
###            of Tissues
###         ANIMAL: Automatic Non-linear Image Matching and Automatic Labeling
###         t-link: As each vertex of the pial surface is linked to a vertex in the
###            White-matter/Gray-matter interface surface because the former surface 
###            is produced by expansion from the latter, the distance between these 
###            linked surfaces can be used to measure cortical thickness at that vertex. 
###         VBC: Vertex-based Corticometry
###         VBM: Voxel-based Morphometry              
###                                 
##########################################################################################################
##########################################################################################################

use strict;
use PMP::PMP;
use PMP::Array;
use MNI::Startup;
use MNI::PathUtilities qw(split_path);
use MNI::FileUtilities qw(check_output_dirs check_output_path);
use MNI::DataDir;
use Getopt::Tabular;

# $Header$
# $Revision$

my $version = "0.9.6.1";
my $versionDate= "November 15, 2005";
my $author= "Yasser Ad-Dab'bagh (based on earlier work by Jason Lerch)";
my $usage = "\nUSAGE:\n\n$ProgramName -sourcedir <dir> -basedir <dir> -prefix <prefix> [options] id1 id2 ... idn > <logfile> &\n
ALTERNATIVE USAGE:\n
$ProgramName -sourcedir <dir> -basedir <dir> -prefix <prefix> -id-file <idfile> [options]  > <logfile> &\n\n";

# Although technically optional, you should add the following at the end of the command line: 
# "> logfile.txt &", as is shown in the "my $usage" line above...
# this writes the pipeline output to a log file in the working directory, and allows the pipeline to
# run in the background.
# Also note that CIVET.pl will optionally run with a text file listing the id's as input, instead of
# typing a series of 'idn' in the command line. This is especially useful when processing a large 
# number of id's at once, which when typed individually could lead the command line to exceed the
# character number limts.

my $help = <<HELP;

$ProgramName, version $version, released $versionDate.
Released by $author.

Takes any number of multi or single spectral input MINC volumes and
extracts the cortical surfaces from them utilizing the PMP pipeline
system. It then calculates cortical thickness at each vertex of the 
produced cortical surfaces (non-linearly registered) using the t-link 
metric (in both Talairach and native spaces). It can also produce ANIMAL 
segmentations, symmetry analyses, regional thickness, surface areas 
and volumes for brain lobes.

HELP
Getopt::Tabular::SetHelp($help, $usage);

####################
# Argument handling:
####################

my $reset = undef;
my $command = "printStatus";
my $PMPtype = "sge";
my $pbsQueue = "long";
my $pbsHosts = "yorick:bullcalf";
my $sgeQueue = "aces.q";
my $resetRunning = 1;

############# User defined registration target models 
############# (defaults defined below in the 'registration targets' section)
my $regModelDir = undef;
my $regModel = undef;
my $kiddieModel = undef;
my $kiddieModelDir = undef;
my $smallSurfRegModelDir = undef;
my $smallSurfRegModel = undef;
my $smallSurfModelDataTerm = undef;
my $largeSurfRegModelDir = undef;
my $largeSurfRegModel = undef;
my $largeSurfModelDataTerm = undef;

############# Use kiddie registration (for pediatric data)
my $kiddieReg = 0;

############# The status report filename:
my $statusReportFile = "CIVET_status_report.csv";

############# Options for how CIVET is to be run: the default will be to run
############# multispectral data, cleaning tags, ANIMAL, the production of 82k 
############# polygon surfaces, no symmetry stages, and surface registration. 
############# Default volumetric blurring is at 10mmFWHM. 
my $inputType = "multispectral";
my $classifyType = "cleanTags";
my $nucOrder = "pre&post";
my $VBC = "VBC";
my $maskOption = "BET";
my $claspOption = "smallOnly";
my $cortexArea = "cortexArea";
my $VBM = "VBM";
my $animal = "ANIMAL";
my $volumeFWHM = undef;
my $surfaceFWHM = undef;
my $symmetry = "noSymmetry";
my $surfReg = "surfReg";

############# Some directories that the user will need to specify
my $sourceDir = undef;
my $base = undef;
my $prefix = undef;
my $sourceSubDir = "noIdSubDir";
my $idTextFile = undef;

############# Options table
my @leftOverArgs;
my @argTbl = (
   ["Execution control", "section"],
   ["-spawn", "const", "spawn", \$PMPtype, "Use the perl system interface to spawn jobs"],
   ["-sge", "const", "sge", \$PMPtype, "Use SGE to spawn jobs"],
   ["-pbs", "const", "pbs", \$PMPtype, "Use PBS to spawn jobs"],

   ["PBS options", "section"],
   ["-pbs-queue", "string", 1, \$pbsQueue, "Which PBS queue to use [short|medium|long]"],
   ["-pbs-hosts", "string", 1, \$pbsHosts, "Colon separated list of pbs hosts [ex: yorick:bullcalf]"],

   ["SGE options", "section"],
   ["-sge-queue", "string", 1, \$sgeQueue, "Which SGE queue to use"],

   ["File options", "section"],
   ["-sourcedir", "string", 1, \$sourceDir, "Directory containing the source files."],
   ["-basedir", "string", 1, \$base, "Directory where processed data will be placed."],
   ["-prefix", "string", 1, \$prefix, "File prefix to be used in naming output files."],
   ["-id-subdir", "const", "IdSubDir", \$sourceSubDir,
    "Indicate that the source directory contains sub-directories for each id [default= noIdSubDir]"],
   ["-id-file", "string", 1, \$idTextFile,
    "A text file that contains all the subject id's (separated by space, tab, return or comma) that 
    CIVET will run on. [default is to list the ids in the command line]"],

   ["Pipeline options", "section"],
   ["-registration-model", "string", 1, \$regModel,
    "Define the target model for registration. [default= 'icbm_avg_152_t1_tal_lin_symmetric']"],
   ["-registration-modeldir", "string", 1, \$regModelDir,
    "Define the directory of the target model for registration. 
    [default= MNI::DataDir::dir(\"mni_autoreg\")]"],
   ["-82k-surface-model", "string", 1, \$smallSurfRegModel,
    "Define the surface registration model. [default= 
    'mni_icbm_00244_white_surface_81920.obj']"],
   ["-82k-surface-modeldir", "string", 1, \$smallSurfRegModelDir,
    "Define the directory for the surface registration model. [default= 
    MNI::DataDir::dir(\"surfreg\")]"],
   ["-82k-surface-data-term", "string", 1, \$smallSurfModelDataTerm,
    "Define the data-term file for surface registration. [default= 
    'mni_icbm_00244_white_surface_81920_data_term1.vv']"],
   ["-328k-surface-model", "string", 1, \$largeSurfRegModel,
    "Define the surface registration model. [default= 
    'mni_icbm_00244_white_surface_327680.obj']"],
   ["-328k-surface-modeldir", "string", 1, \$largeSurfRegModelDir,
    "Define the directory for the surface registration model. [default= 
    MNI::DataDir::dir(\"surfreg\")]"],
   ["-328k-surface-data-term", "string", 1, \$largeSurfModelDataTerm,
    "Define the data-term file for surface registration. [default= 
    'mni_icbm_00244_white_surface_327680_data_term1.vv']"],
   ["-kiddie-registration|-normal-registration", "boolean", undef, \$kiddieReg,
    "Add a pediatric model registration. [default= -normal-registration]"],
   ["-kiddie-model", "string", 1, \$kiddieModel,
    "Define the intermediate registration target for pediatric data. [default= 'nih_chp_avg']"],
   ["-kiddie-modeldir", "string", 1, \$kiddieModelDir,
    "Define the directory of the intermediate registration target for pediatric data. 
    [default= MNI::DataDir::dir(\"mni_autoreg\")]"],

   ["CIVET options", "section"],
   ["-t1only", "const", "t1only", \$inputType,
    "Use only T1 native files. [default= multispectral]"],
   ["-no-cleaning-tags", "const", "noCleanTags", \$classifyType,
    "run INSECT without the tag-cleaning feature. [default= cleanTags]"],
   ["-nuc", "string", 1, \$nucOrder,
    "run non-uniformity correction once or twice, at a defind order in relation to registration
    [pre|post|pre&post]. [default is to run nuc pre&post registration]"],
   ["-no-vbc", "const", "noVBC", \$VBC,
    "Do not perform vertex-based corticometry. [default= VBC]"],
   ["-no-bet", "const", "noBET", \$maskOption,
    "Do not perform skull stripping with FSL bet. [default=BET]"],
   ["-large-only", "const", "largeOnly", \$claspOption,
    "Build surfaces with 327,680 polygons. [default= smallOnly]"],
   ["-large-addition", "const", "largeAddition", \$claspOption,
    "Build 327,680 polygon surface as well as 81,920 version. [default= smallOnly]"],
   ["-no-surface-area", "const", "noCortexArea", \$cortexArea,
    "don't calculate surface areas for parcellated cortical surface regions. 
    [default= cortexArea]"],
   ["-no-vbm", "const", "noVBM", \$VBM,
    "don't run voxel-based morphometry. [default= VBM]"],
   ["-no-animal", "const", "noANIMAL", \$animal,
    "don't run volumetric ANIMAL segmentation. [default= ANIMAL]"],
   ["-volume-kernel", "string", 1, \$volumeFWHM,
    "Define the full-width half-maximum kernel of the volumetric smoothing kernel. [default= 10 mm]"],
   ["-surface-kernel", "string", 1, \$surfaceFWHM,
    "Define an additional full-width half-maximum kernel of the surface diffusion-smoothing kernel. [default= 0, 20, 30 & 40 mm]"],
   ["-symmetry", "const", "Symmetry", \$symmetry,
    "run symmetry tools. [default= noSymmetry]"],
   ["-no-surface-registration", "const", "noSurfReg", \$surfReg,
    "don't run non-linear surface registration to a model surface. [default= surfReg]"],
     
   ["Pipeline control", "section"],
   ["-run", "const", "run", \$command,
    "Run the pipeline."],
   ["-status-from-files", "const", "statusFromFiles", \$command,
    "Compute pipeline status from files"],
   ["-print-stages", "const", "printStages", \$command,
    "Print the pipeline stages."],
   ["-print-status", "const", "printStatus", \$command,
    "Print the status of each pipeline."],
   ["-make-graph", "const", "makeGraph", \$command,
    "Create dot graph file."],
   ["-make-filename-graph", "const", "makeFilenameGraph", \$command,
    "Create dot graph of filenames."],
   ["-print-status-report", "const", "printStatusReport", \$command,
    "Writes a CSV status report to file in cwd."],

   ["Stage Control", "section"],
   ["-reset-all", "const", "resetAll", \$reset,
    "Start the pipeline from the beginning."],
   ["-reset-from", "string", 1, \$reset,
    "Restart from the specified stage."],
   ["-reset-running|-no-reset-running", "boolean", 1, \$resetRunning,
    "Restart currently running jobs. [default=-reset-running]"],
);
GetOptions(\@argTbl, \@ARGV, \@leftOverArgs) or die "\n";


############# Basic usage
my @dsids;

# The following allows the input of a text file that lists the subject IDs in either line, tab, space or comma seperated fashion.

if ($idTextFile) {
   open (IDTEXTFILE, "$idTextFile") or die ("Cannot open '$idTextFile': $!");
   # read the whole text file into one string
   my $idstext = "";
   while (my $idline = <IDTEXTFILE>) {
      $idstext .= $idline;
   }
   close (IDTEXTFILE) or die ("Cannot close '$idTextFile': $!");
   # split the string on whitespace (\s) or comma
   @dsids = split(/[\s,]+/, $idstext);
   
} 
else {
    @dsids = @leftOverArgs or die $usage;
}

unless ($prefix && $base && $sourceDir) {
    die "\n\n*******ERROR********: \n     You must specify -prefix, -basedir, and -sourcedir \n********************\n\n\n";
}


############# Set no file buffering for stdout (buffer is printed every 1 line)

$| = 1;

############# Print the CIVET options list and related error messages

my $DATE = `date`;
chomp( $DATE );
my $UNAME = `uname -s -n -r`;
chomp( $UNAME );
print "\nPipeline started at $DATE on $UNAME\n";
print "\n$0 @ARGV\n";
print "\n* The source directory is: '$sourceDir' \n";
print "* The base directory is: '$base' \n";
print "* The prefix is: '$prefix' \n";
print "* The PMP class is: '$PMPtype' \n";
if ($PMPtype eq "pbs") {
   print "* The pbs queue type is: '$pbsQueue' \n";
   print "* The pbs batch host(s) is/are: '$pbsHosts' \n";
}
print "* My CIVET options are:\n     MRI-image type= '$inputType'\n";
print "     NUC Order= '$nucOrder'-registration\n";
print "     Classification Type= '$classifyType'\n";
print "     ANIMAL= '$animal'\n";
print "     VBC= '$VBC'\n";
print "     Skull masking = '$maskOption'\n";
if ($VBC ne "noVBC") {
   print "     CLASP= '$claspOption'\n";
}
if ($VBC eq "noVBC" and $claspOption ne "smallOnly") {
   die "\n\n*******ERROR********: \n      'CLASP' cannot be done when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($VBC ne "noVBC" and $animal ne "noANIMAL") {
   print "     Surface Area= '$cortexArea' \n";
}
if ($VBC eq "noVBC" and $cortexArea eq "noCortexArea") {
   die "\n\n*******ERROR********: \n      Surface Area options cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($animal eq "noANIMAL" and $cortexArea eq "noCortexArea") {
   die "\n\n*******ERROR********: \n      Surface Area options cannot be specified when ANIMAL option= '$animal' !!! \n********************\n\n\n";
}
print "     VBM= '$VBM' \n";
if ($VBM ne "noVBM") {
   print "     Symmetry Analysis= '$symmetry' \n";
}
if ($VBM eq "noVBM" and $symmetry ne "noSymmetry") {
   die "\n\n*******ERROR********: \n      Symmetry Analysis cannot be done when VBM option= '$VBM' !!! \n********************\n\n\n";
}
if ($VBC ne "noVBC") {
   print "     Surface Registration= '$surfReg' \n";
}
if ($VBC eq "noVBC" and $surfReg eq "noSurfReg") {
   die "\n\n*******ERROR********: \n      Surface registration options cannot be specified when VBC option = '$VBC' !!! \n********************\n\n\n";
}

############# Queue-related error messages
if ($pbsQueue ne "long" and $claspOption ne "noClasp"){
      die "\n\n*******ERROR********: \n      You cannot use '$pbsQueue' queue to run CLASP. 
CLASP and Surfreg, which depends on CLASP, are likely crash with this queue option!!
If you wish to keep the queue option as '$pbsQueue', you will need to change the CLASP 
option from '$claspOption' to 'noClasp'. Better yet, change the queue option to 'long'. \n********************\n\n\n";
}

if ($pbsQueue ne "long" and $animal ne "noANIMAL"){
      die "\n\n*******ERROR********: \n      You cannot use '$pbsQueue' queue to run ANIMAL. 
ANIMAL is likely crash with this queue option!!
If you wish to keep the queue option as '$pbsQueue', you will need to change the ANIMAL 
option from $animal to 'noANIMAL'. Better yet, change the queue option to 'long'. \n********************\n\n\n";
}

############# Some essential directories 
my $ICBM_dir = MNI::DataDir::dir("ICBM");
my $classify_dir = MNI::DataDir::dir("classify");


############# The -like template
my $Template = "${ICBM_dir}/icbm_template_1.00mm.mnc";


############# Define registration targets and directories and print them
unless ($regModelDir) {
   $regModelDir = MNI::DataDir::dir("mni_autoreg");
}
print "* Registration model directory is:\n  $regModelDir \n";

unless ($regModel) {
   $regModel = "icbm_avg_152_t1_tal_lin_symmetric";
}
print "* Registration model is:\n   $regModel \n";


############# Define kiddie-registration targets and directories and print them
unless ($kiddieModelDir) {
   $kiddieModelDir = MNI::DataDir::dir("mni_autoreg");
}
if ($kiddieReg){
   print "* Kiddie registration model directory is:\n $kiddieModelDir \n";
}

unless ($kiddieModel) {
   $kiddieModel = "nih_chp_avg";
}
if ($kiddieReg){
   print "* Kiddie registration model is:\n  $kiddieModel \n";
}

############# Define Surface registration targets and directories and print them, or die with error message
unless ($smallSurfRegModelDir) {
   $smallSurfRegModelDir = MNI::DataDir::dir("surfreg");
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "largeOnly"){
   print "* 82k Surface registration model directory is:\n  $smallSurfRegModelDir \n";
}
if ($VBC eq "noVBC" and $smallSurfRegModelDir ne MNI::DataDir::dir("surfreg")) {
   die "\n\n*******ERROR********: \n      82k Surface registration model directory cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "largeOnly" and $smallSurfRegModelDir ne MNI::DataDir::dir("surfreg")){
   die "\n\n*******ERROR********: \n      82k Surface registration model directory cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

unless ($smallSurfRegModel) {
   $smallSurfRegModel = "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920.obj";
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "largeOnly"){
   print "* 82k Surface registration model is:\n   $smallSurfRegModel \n";
}
if ($VBC eq "noVBC" and $smallSurfRegModel ne "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920.obj") {
   die "\n\n*******ERROR********: \n      82k Surface registration model cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "largeOnly" and $smallSurfRegModel ne "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920.obj") {
   die "\n\n*******ERROR********: \n      82k Surface registration model cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

unless ($smallSurfModelDataTerm) {
   $smallSurfModelDataTerm = "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920_data_term1.vv";
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "largeOnly"){
   print "* 82k Surface model depth-map file is:\n $smallSurfModelDataTerm \n";
}
if ($VBC eq "noVBC" and $smallSurfModelDataTerm ne "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920_data_term1.vv") {
   die "\n\n*******ERROR********: \n      82k Surface model depth-map file cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "largeOnly" and $smallSurfModelDataTerm ne "${smallSurfRegModelDir}/mni_icbm_00244_white_surface_81920_data_term1.vv") {
   die "\n\n*******ERROR********: \n      82k Surface model depth-map file cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

unless ($largeSurfRegModelDir) {
   $largeSurfRegModelDir = MNI::DataDir::dir("surfreg");
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "smallOnly"){
   print "* 328k Surface registration model directory is:\n $largeSurfRegModelDir \n";
}
if ($VBC eq "noVBC" and $largeSurfRegModelDir ne MNI::DataDir::dir("surfreg")) {
   die "\n\n*******ERROR********: \n      328k Surface registration model directory cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "smallOnly" and $largeSurfRegModelDir ne MNI::DataDir::dir("surfreg")){
   die "\n\n*******ERROR********: \n      328k Surface registration model directory cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

unless ($largeSurfRegModel) {
   $largeSurfRegModel = "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680.obj";
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "smallOnly"){
   print "* 328k Surface registration model is:\n  $largeSurfRegModel \n";
}
if ($VBC eq "noVBC" and $largeSurfRegModel ne "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680.obj") {
   die "\n\n*******ERROR********: \n      328k Surface registration model cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "smallOnly" and $largeSurfRegModel ne "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680.obj"){
   die "\n\n*******ERROR********: \n      328k Surface registration model cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

unless ($largeSurfModelDataTerm) {
   $largeSurfModelDataTerm = "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680_data_term1.vv";
}
if ($VBC ne "noVBC" and $surfReg ne "noSurfReg" and $claspOption ne "smallOnly"){
   print "* 328k Surface model depth-map file is:\n   $largeSurfModelDataTerm \n";
}
if ($VBC eq "noVBC" and $largeSurfModelDataTerm ne "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680_data_term1.vv") {
   die "\n\n*******ERROR********: \n      328k Surface model depth-map file cannot be specified when VBC option= '$VBC' !!! \n********************\n\n\n";
}
if ($claspOption eq "smallOnly" and $largeSurfModelDataTerm ne "${largeSurfRegModelDir}/mni_icbm_00244_white_surface_327680_data_term1.vv") {
   die "\n\n*******ERROR********: \n      328k Surface model depth-map file cannot be specified when CLASP option= '$claspOption' !!! \n********************\n\n\n";
}

############# Full-width half-maximums (FWHM) of blurring kernels to use. Note that CIVET will always run
############# surface diffusion smoothing at 0, 20, 30 and 40 mm FWHM kernels. If a different kernel is
############# speified, it will be in addition to these 4 kernels.
unless ($volumeFWHM) {
   $volumeFWHM = 10;
}
if ($VBM ne "noVBM"){
   print "* Volumetric smoothing kernel for VBM is: $volumeFWHM mm.\n";
}
if ($VBM eq "noVBM" and $volumeFWHM ne 10) {
   die "\n\n*******ERROR********: \n      Volumetric smoothing kernel for VBM cannot be set when VBM option= '$VBM' !!! \n********************\n\n\n";
}

unless ($surfaceFWHM) {
   $surfaceFWHM = 20;
}
if ($VBC ne "noVBC" and $surfaceFWHM eq 20){
   print "* Surface diffusion-smoothing kernels for VBC are: 0, $surfaceFWHM, 30 and 40 mm.\n\n\n";
}
if ($VBC ne "noVBC" and $surfaceFWHM ne 20){
   print "* Surface diffusion-smoothing kernels for VBC are: 0, 20, 30, 40 mm, as well as the additionally specified $surfaceFWHM mm.\n";
}
if ($VBC eq "noVBC" and $surfaceFWHM ne 20) {
   die "\n\n*******ERROR********: \n      Surface diffusion-smoothing kernel for VBC cannot be set when VBC option= '$VBC' !!! \n********************\n\n\n";
}


############# Print the Pipeline and Stage Control commands

if( !($command eq "run") ) {
  $resetRunning = 0;
}
print "\n\n* Pipeline Control command is: '$command'";
if ($reset and $resetRunning ne 0){
   print "\n* Stage control commands are: '$reset' and 'reset-running'";
}
elsif ($reset and $resetRunning eq 0){
   print "\n* Stage control commands are: '$reset' and 'no-reset-running'";
}


############# An array to store the pipeline definitions for each subject
my $pipes = PMP::Array->new();
print "\n\n\n* Data-set Subject ID(s) is/are: '@dsids'\n\n\n";


#########################################################
# Set up the pipeline output directories for each subject
#########################################################

foreach my $dsid (@dsids) {

    my $baseDir = "${base}/${dsid}";
    
    my $tempDir = "${baseDir}/temp";
    my $nativeDir = "${baseDir}/native";
    my $normalizeDir = "${baseDir}/normalize";
    my $linTransformsDir = "${baseDir}/transforms/linear";
    my $nlTransformsDir = "${baseDir}/transforms/non_linear";
    my $finalDir = "${baseDir}/final";
    my $classifyDir = "${baseDir}/classify";
    my $segDir = "${baseDir}/seg";
    my $logDir = "${baseDir}/logs";
    my $verifyDir = "${baseDir}/verify";
    my $surfaceDir = "${baseDir}/surfaces";
    my $surfaceStatsDir = "${baseDir}/surface_stats";
    my $symmetricDir = "${baseDir}/symmetric";
    my $pveDir = "${baseDir}/pve";
    my $surfaceNlinDir = "${baseDir}/surface_registration";


#############################################
# Make sure that all of the directories exist
#############################################

    system("mkdir -p $baseDir") if (! -d $baseDir);
    system("mkdir -p $tempDir") if (! -d $tempDir);
    system("mkdir -p $nativeDir") if (! -d $nativeDir);
    system("mkdir -p $normalizeDir") if (! -d $normalizeDir);
    system("mkdir -p $linTransformsDir") if (! -d $linTransformsDir);
    system("mkdir -p $finalDir") if (! -d $finalDir);
    system("mkdir -p $classifyDir") if (! -d $classifyDir);
    system("mkdir -p $logDir") if (! -d $logDir);
    system("mkdir -p $verifyDir") if (! -d $verifyDir);
    system("mkdir -p $surfaceDir") if (! -d $surfaceDir);
    system("mkdir -p $surfaceStatsDir") if (! -d $surfaceStatsDir);
    system("mkdir -p $segDir") if (! -d $segDir);
    system("mkdir -p $nlTransformsDir") if (! -d $nlTransformsDir);
    system("mkdir -p $symmetricDir") if (! -d $symmetricDir);
    system("mkdir -p $pveDir") if (! -d $pveDir);
    system("mkdir -p $surfaceNlinDir") if (! -d $surfaceNlinDir);

#####################
# Define the pipeline
#####################

    my $pipeline;
    if ($PMPtype eq "spawn") {
      use PMP::spawn;
      $pipeline = PMP::spawn->new();
    }
    elsif ($PMPtype eq "sge") {
      use PMP::sge;
      $pipeline = PMP::sge->new();
      $pipeline->setQueue($sgeQueue);
      $pipeline->setPriorityScheme("later-stages");
    }
    elsif ($PMPtype eq "pbs") {
      use PMP::pbs;
      $pipeline = PMP::pbs->new();
      $pipeline->setQueue($pbsQueue);
      $pipeline->setHosts($pbsHosts);
      $pipeline->setPriorityScheme("later-stages");
    }

    # set some generic pipeline options
    $pipeline->name("$dsid");
    $pipeline->debug(0);
    $pipeline->statusDir($logDir);

##################
# The source files
##################

    my $source_t1;
    my $source_t2;
    my $source_pd;

if ($sourceSubDir eq "noIdSubDir") {
    $source_t1 = "${sourceDir}/${prefix}_${dsid}_t1.mnc.gz";
    $source_t2 = "${sourceDir}/${prefix}_${dsid}_t2.mnc.gz";
    $source_pd = "${sourceDir}/${prefix}_${dsid}_pd.mnc.gz";
}
else {
    $source_t1 = "${sourceDir}/${dsid}/${prefix}_${dsid}_t1.mnc.gz";
    $source_t2 = "${sourceDir}/${dsid}/${prefix}_${dsid}_t2.mnc.gz";
    $source_pd = "${sourceDir}/${dsid}/${prefix}_${dsid}_pd.mnc.gz";
}
    
############################################################################ 
# Definition of the files that will be created in the course of the pipeline
############################################################################

############# Native files
    my $t1_native = "${nativeDir}/${prefix}_${dsid}_t1.mnc.gz";
    my $t2_native = "${nativeDir}/${prefix}_${dsid}_t2.mnc.gz";
    my $pd_native = "${nativeDir}/${prefix}_${dsid}_pd.mnc.gz";
    
############# Linear registration files
    my $t1_nuc = "${normalizeDir}/${prefix}_${dsid}_t1_nuc.imp";
    my $t2_nuc = "${normalizeDir}/${prefix}_${dsid}_t2_nuc.imp";
    my $pd_nuc = "${normalizeDir}/${prefix}_${dsid}_pd_nuc.imp";
    
    my $t1_nt_nuc = "${tempDir}/${prefix}_${dsid}_t1_nt_nuc.mnc";
    my $t2_nt_nuc = "${tempDir}/${prefix}_${dsid}_t2_nt_nuc.mnc";
    my $pd_nt_nuc = "${tempDir}/${prefix}_${dsid}_pd_nt_nuc.mnc";
    
    my $t1_tal_xfm = "${linTransformsDir}/${prefix}_${dsid}_t1_tal.xfm";
    my $t2_t1_xfm = "${linTransformsDir}/${prefix}_${dsid}_t2_to_t1.xfm";
    my $t2_tal_xfm = "${linTransformsDir}/${prefix}_${dsid}_t2_tal.xfm";
    my $t2pd_tal_xfm = "${linTransformsDir}/${prefix}_${dsid}_t2pd_tal.xfm";
   
    my $t1_tal_tmp_mnc = "${tempDir}/${prefix}_${dsid}_t1_final_tmp.mnc";
    my $t2_tal_tmp_mnc = "${tempDir}/${prefix}_${dsid}_t2_final_tmp.mnc";
    my $pd_tal_tmp_mnc = "${tempDir}/${prefix}_${dsid}_pd_final_tmp.mnc";

    my $t1_suppressed = "${tempDir}/${prefix}_${dsid}_t1_suppressed.mnc";
    
    my $t1_tal_manual = "${linTransformsDir}/${prefix}_${dsid}_t1_tal_manual.xfm";
    
    my $t1_tal_mnc = "${finalDir}/${prefix}_${dsid}_t1_final.mnc";
    my $t2_tal_mnc = "${finalDir}/${prefix}_${dsid}_t2_final.mnc";
    my $pd_tal_mnc = "${finalDir}/${prefix}_${dsid}_pd_final.mnc";

    my $tal_to_native_xfm = "${linTransformsDir}/${prefix}_${dsid}_tal_to_native.xfm";
    
############# Classification files   
    my $cls_tmp = "${tempDir}/${prefix}_${dsid}_cls_tmp.mnc";
    my $cls_correct = "${classifyDir}/${prefix}_${dsid}_cls_correct.mnc";
    my $cls_four = "${classifyDir}/${prefix}_${dsid}_cls_4classes.mnc";
    
############# ANIMAL files
    my $identity = "${tempDir}/identity.xfm";
    system("param2xfm -clobber $identity");
    my $t1_tal_nl_xfm = "${nlTransformsDir}/${prefix}_${dsid}_nlfit.xfm";
    my $stx_labels = "${segDir}/${prefix}_${dsid}_stx_labels.mnc";
    my $stx_surface_labels_82k = "${segDir}/${prefix}_${dsid}_animal_midsurf_81920.txt";
    my $stx_surface_labels_328k = "${segDir}/${prefix}_${dsid}_animal_midsurf_327680.txt";
    my $stx_labels_masked = "${segDir}/${prefix}_${dsid}_stx_labels_masked.mnc"; 
    my $label_volumes = "${segDir}/${prefix}_${dsid}_masked.dat";
    my $lobe_volumes = "${segDir}/${prefix}_${dsid}_lobes.dat";
    my $cls_volumes = "${classifyDir}/${prefix}_${dsid}_cls_volumes.dat";
    
############# Masking files    
    my $cortex = "${surfaceDir}/${prefix}_${dsid}_cortex.obj";
    my $cls_masked = "${classifyDir}/${prefix}_${dsid}_cls_masked.mnc";
    my $mask = "${tempDir}/${prefix}_${dsid}_cortex_mask.mnc";
    my $maskD = "${tempDir}/${prefix}_${dsid}_cortex_mask_dil.mnc";
    
############# Partial volume files
    my $pve_curve_prefix = "${pveDir}/${prefix}_${dsid}_curve";
    my $pve_curvature = "${pveDir}/${prefix}_${dsid}_curve_cg.mnc";
    my $pve_prefix = "${pveDir}/${prefix}_${dsid}_pve";
    my $pve_gm = "${pve_prefix}_gm.mnc";
    my $pve_csf = "${pve_prefix}_csf.mnc";
    my $pve_wm = "${pve_prefix}_wm.mnc";
    my $pve_sc = "${pve_prefix}_sc.mnc";

############# The smooth matter files  
    my $smooth_wm = "${classifyDir}/${prefix}_${dsid}_smooth_wm.mnc";
    my $smooth_gm = "${classifyDir}/${prefix}_${dsid}_smooth_gm.mnc";
    my $smooth_csf = "${classifyDir}/${prefix}_${dsid}_smooth_csf.mnc";
    
############# Symmetry part of the pipeline
    my $flip_wm = "${symmetricDir}/${prefix}_${dsid}_flip_wm.mnc";
    my $flip_gm = "${symmetricDir}/${prefix}_${dsid}_flip_gm.mnc";
    my $flip_csf = "${symmetricDir}/${prefix}_${dsid}_flip_csf.mnc";
    my $diff_wm = "${symmetricDir}/${prefix}_${dsid}_diff_wm.mnc";
    my $diff_gm = "${symmetricDir}/${prefix}_${dsid}_diff_gm.mnc";
    my $diff_csf = "${symmetricDir}/${prefix}_${dsid}_diff_csf.mnc";
    my $reshape_wm = "${symmetricDir}/${prefix}_${dsid}_reshape_wm.mnc";
    my $reshape_gm = "${symmetricDir}/${prefix}_${dsid}_reshape_gm.mnc";
    my $reshape_csf = "${symmetricDir}/${prefix}_${dsid}_reshape_csf.mnc";
    
############# Surface deformation output files
    my $white_masked_mnc = "${tempDir}/${prefix}_${dsid}_white_masked.mnc";
    my $white_surf_prefix = "${tempDir}/${prefix}_${dsid}_white_surface";
    my $white_tmp = "${tempDir}/${prefix}_${dsid}_white_surface_81920.obj";
    my $white_surface_82k = "${surfaceDir}/${prefix}_${dsid}_white_surface_81920.obj";
    my $white_surface_328k = "${surfaceDir}/${prefix}_${dsid}_white_surface_327680.obj";
    my $gray_surface_82k = "${surfaceDir}/${prefix}_${dsid}_gray_surface_81920.obj";
    my $gray_surface_328k = "${surfaceDir}/${prefix}_${dsid}_gray_surface_327680.obj";
    my $mid_surface_82k = "${surfaceDir}/${prefix}_${dsid}_mid_surface_81920.obj";
    my $mid_surface_328k = "${surfaceDir}/${prefix}_${dsid}_mid_surface_327680.obj";
    my $native_gray_surface_82k = "${surfaceDir}/${prefix}_${dsid}_native_gray_surface_81920.obj";
    my $native_gray_surface_328k = "${surfaceDir}/${prefix}_${dsid}_native_gray_surface_327680.obj";
    
############# Extra files needed for CLASP surface deformation
    my $skel_csf = "${tempDir}/${prefix}_${dsid}_csf_skel.mnc";
    my $laplace_field = "${tempDir}/${prefix}_${dsid}_clasp_field.mnc";
    
############# Surface area and segmentation files
    my $stx_surface_lobes_82k = "${segDir}/${prefix}_${dsid}_animal_midsurface_lobes_81920.txt";
    my $native_lobe_areas_82k = "${segDir}/${prefix}_${dsid}_native_lobe_areas_81920.txt";
    my $native_lobe_thickness_82k_20mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_81920_20mmFWHM.txt";
    my $native_lobe_thickness_82k_30mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_81920_30mmFWHM.txt";
    my $native_lobe_thickness_82k_40mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_81920_40mmFWHM.txt";
    my $native_lobe_thickness_82k_additional_blur = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_81920_additional_blur.txt";
    my $stx_surface_lobes_328k = "${segDir}/${prefix}_${dsid}_animal_midsurface_lobes_327680.txt";
    my $native_lobe_areas_328k = "${segDir}/${prefix}_${dsid}_native_lobe_areas_327680.txt";
    my $native_lobe_thickness_328k_20mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_327680_20mmFWHM.txt";
    my $native_lobe_thickness_328k_30mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_327680_30mmFWHM.txt";
    my $native_lobe_thickness_328k_40mmFWHM = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_327680_40mmFWHM.txt";
    my $native_lobe_thickness_328k_additional_blur = "${segDir}/${prefix}_${dsid}_native_lobe_thickness_327680_additional_blur.txt";

############# Cortical thickness files
    my $rms_thickness_82k = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_81920.txt";
    my $rms_thickness_328k = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_327680.txt";
    my $rms_thickness_82k_20mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_81920_20mmFWHM.txt";
    my $rms_thickness_328k_20mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_327680_20mmFWHM.txt";
    my $rms_thickness_82k_30mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_81920_30mmFWHM.txt";
    my $rms_thickness_328k_30mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_327680_30mmFWHM.txt";
    my $rms_thickness_82k_40mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_81920_40mmFWHM.txt";
    my $rms_thickness_328k_40mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_327680_40mmFWHM.txt";
    my $rms_thickness_82k_additional_blur = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_81920_additional_blur.txt";
    my $rms_thickness_328k_additional_blur = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_327680_additional_blur.txt";
   
    my $native_rms_82k = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_81920.txt";
    my $native_rms_328k = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_327680.txt";
    my $native_rms_82k_20mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_81920_20mmFWHM.txt";
    my $native_rms_328k_20mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_327680_20mmFWHM.txt";
    my $native_rms_82k_30mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_81920_30mmFWHM.txt";
    my $native_rms_328k_30mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_327680_30mmFWHM.txt";
    my $native_rms_82k_40mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_81920_40mmFWHM.txt";
    my $native_rms_328k_40mmFWHM = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_327680_40mmFWHM.txt";
    my $native_rms_82k_additional_blur = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_81920_additional_blur.txt";
    my $native_rms_328k_additional_blur = "${surfaceStatsDir}/${prefix}_${dsid}_rms_thickness_native_327680_additional_blur.txt";

############ Non-linear surface registration files    
    my $dataterm_82k = "${surfaceNlinDir}/${prefix}_${dsid}_white_dataterm_81920.vv";
    my $dataterm_328k = "${surfaceNlinDir}/${prefix}_${dsid}_white_dataterm_327680.vv";
    my $surface_mapping_82k = "${surfaceNlinDir}/${prefix}_${dsid}_surface_mapping_81920.sm";
    my $surface_mapping_328k = "${surfaceNlinDir}/${prefix}_${dsid}_surface_mapping_327680.sm";
    my $rsl_82k = "${surfaceNlinDir}/${prefix}_${dsid}_rms_81920_nlin.txt";
    my $rsl_328k = "${surfaceNlinDir}/${prefix}_${dsid}_rms_327680_nlin.txt";
    my $rsl_82k_20mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_81920_20mmFWHM_nlin.txt";
    my $rsl_328k_20mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_327680_20mmFWHM_nlin.txt";
    my $rsl_82k_30mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_81920_30mmFWHM_nlin.txt";
    my $rsl_328k_30mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_327680_30mmFWHM_nlin.txt";
    my $rsl_82k_40mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_81920_40mmFWHM_nlin.txt";
    my $rsl_328k_40mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_rms_327680_40mmFWHM_nlin.txt";
    my $rsl_82k_additional_blur = "${surfaceNlinDir}/${prefix}_${dsid}_rms_81920_additional_blur_nlin.txt";
    my $rsl_328k_additional_blur = "${surfaceNlinDir}/${prefix}_${dsid}_rms_327680_additional_blur_nlin.txt";
    my $rsl_native_82k = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_81920_nlin.txt";
    my $rsl_native_328k = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_327680_nlin.txt";
    my $rsl_native_82k_20mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_81920_20mmFWHM_nlin.txt";
    my $rsl_native_328k_20mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_327680_20mmFWHM_nlin.txt";
    my $rsl_native_82k_30mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_81920_30mmFWHM_nlin.txt";
    my $rsl_native_328k_30mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_327680_30mmFWHM_nlin.txt";
    my $rsl_native_82k_40mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_81920_40mmFWHM_nlin.txt";
    my $rsl_native_328k_40mmFWHM = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_327680_40mmFWHM_nlin.txt";
    my $rsl_native_82k_additional_blur = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_81920_additional_blur_nlin.txt";
    my $rsl_native_328k_additional_blur = "${surfaceNlinDir}/${prefix}_${dsid}_native_rms_327680_additional_blur_nlin.txt";

############# Verification files
    my $verify = "${verifyDir}/${prefix}_${dsid}_verify.png";




##################################### 
#####################################
# Begin definition of stages        #
#####################################
#####################################

    
    
   ##########################################
   ##### Preprocessing the native files #####
   ##########################################
 
   # Explanation:
   # creates links to the source image files within the 'native' subdirectory
   # of the output directory. Later stages will operate on these links.
   
   $pipeline->addStage(
      { name => "link_t1",
      label => "link the t1 image",
      inputs => [$source_t1],
      outputs => [$t1_native],
      args => ["ln", "-fs", $source_t1, $t1_native] });

   if ($inputType eq "multispectral") {
      $pipeline->addStage(
         { name => "link_t2",
         label => "link the native T2 file",
         inputs => [$source_t2],
         outputs => [$t2_native],
         args => ["ln", "-fs", $source_t2, $t2_native] });
   
      $pipeline->addStage(
         { name => "link_pd",
         label => "link the native PD file",
         inputs => [$source_pd],
         outputs => [$pd_native],
         args => ["ln", "-fs", $source_pd, $pd_native] });
   }
    
    
   ###################################################################
   ##### The non-uniformity correction stages (pre-registration) #####
   ###################################################################
   
   # Explanation:
   # Using N3, these stages will run an initial correction of intensity
   # non-uniformity in the native images. Will run on t1Only as well as
   # multispectral source images. These steps run prior to registration
   # by default. They are also run a second time post-registration.
   # Optionally, they may be performed only before or only after 
   # registration.
   
   if ($nucOrder eq "pre&post" or $nucOrder eq "pre"){  
      $pipeline->addStage(
         { name => "nuest_t1",
         label => "non-unfiformity estimation",
         inputs => [$t1_native],
         outputs => [$t1_nuc],
         args => ["nu_estimate", "-clobber", $t1_native, $t1_nuc],
         prereqs => ["link_t1"] });
   
      $pipeline->addStage(
         { name => "nueval_t1",
         label => "remove non-uniformity",
         inputs => [$t1_native, $t1_nuc],
         outputs => [$t1_nt_nuc],
         args => ["nu_evaluate", "-clobber", "-mapping", $t1_nuc, $t1_native, $t1_nt_nuc],
         prereqs => ["nuest_t1"] });
   
      if ($inputType eq "multispectral") {
         $pipeline->addStage(
            { name => "nuest_t2",
            label => "non-unfiformity estimation",
            inputs => [$t2_native],
            outputs => [$t2_nuc],
            args => ["nu_estimate", "-clobber", $t2_native, $t2_nuc],
            prereqs => ["link_t2"] });

         $pipeline->addStage(
            { name => "nuest_pd",
            label => "non-unfiformity estimation",
            inputs => [$pd_native],
            outputs => [$pd_nuc],
            args => ["nu_estimate", "-clobber", $pd_native, $pd_nuc],
            prereqs => ["link_pd"] });

         $pipeline->addStage(
            { name => "nueval_t2",
            label => "remove non-uniformity",
            inputs => [$t2_native, $t2_nuc],
            outputs => [$t2_nt_nuc],
            args => ["nu_evaluate", "-clobber", "-mapping", $t2_nuc, $t2_native, $t2_nt_nuc],
            prereqs => ["nuest_t2"] });

         $pipeline->addStage(
            { name => "nueval_pd",
            label => "remove non-uniformity",
            inputs => [$pd_native, $pd_nuc],
            outputs => [$pd_nt_nuc],
            args => ["nu_evaluate", "-clobber", "-mapping", $pd_nuc, 
              $pd_native, $pd_nt_nuc],
            prereqs => ["nuest_pd"] });
      }
   }

   ###################################
   ##### The registration stages #####
   ###################################
    
   # Explanation:
   # Will perform a 9-parameter, linear registration to the registration target
   # model in order to later bring native images into MNI-Talairach space. 
   # These stages compute the transformation necessary for this. When working with 
   # pediatric data, an intermediate step can be added: Registration first to a
   # pediatric model, then the output will be regestered to the usual target model.
   # This tends to improve the quality of pediatric linear registration. These
   # stages will also handle multispectral data: Once T1 images have been
   # registered, T2 and PD weighted images will then be registered linearly to the
   # T1 image.
   
   if ($inputType eq "t1only") {
   #check if a manual transform exists
      my @manTransform;
            if (-f $t1_tal_manual) {
               push @manTransform, "-transform";
               push @manTransform, $t1_tal_manual;
            }
      if ($kiddieReg) {
         $pipeline->addStage(
            { name => "register",
            label => "compute transform to stereotaxic space",
            inputs => [$t1_native],
            outputs => [$t1_tal_xfm, $t1_suppressed],
            args => ["mritotal_suppress", "-clobber", "-premodeldir", $kiddieModelDir, 
               "-premodel", $kiddieModel, "-modeldir", $regModelDir, "-model", $regModel, 
               "-keep_suppressed", $t1_suppressed, $t1_native, $t1_tal_xfm],
            prereqs => ["link_t1"] });
      }
      else {
         $pipeline->addStage(
            { name => "register",
            label => "compute transform to stereotaxic space",
            inputs => [$t1_native],
            outputs => [$t1_tal_xfm],
            args => ["mritotal", "-model", $regModel, "-modeldir", $regModelDir, 
               "-clobber", @manTransform, $t1_native, $t1_tal_xfm],
            prereqs => ["link_t1"] });
      }
   }

   elsif ($inputType eq "multispectral") {
      if ($kiddieReg) {
         $pipeline->addStage(
            { name => "register",
            label => "compute transforms to stx space",
            inputs => [$t1_native, $t2_native, $pd_native],
            outputs => [$t1_tal_xfm, $t2pd_tal_xfm],
            args => ["multispectral_stx_registration", "-nothreshold", "-clobber", 
               "-two-stage", "-premodeldir", $kiddieModelDir, "-premodel", $kiddieModel, 
               "-modeldir", $regModelDir, "-model", $regModel, $t1_native, $t2_native, 
               $pd_native, $t1_tal_xfm, $t2pd_tal_xfm],
            prereqs => ["link_t1", "link_t2", "link_pd"] });
      }
      else {
         $pipeline->addStage(
            { name => "register",
            label => "compute transforms to stx space",
            inputs => [$t1_native, $t2_native, $pd_native],
            outputs => [$t1_tal_xfm, $t2pd_tal_xfm],
            args => ["multispectral_stx_registration", "-nothreshold", "-clobber", 
               "-single-stage", "-modeldir", $regModelDir, "-model", $regModel, 
               $t1_native, $t2_native, $pd_native, $t1_tal_xfm, $t2pd_tal_xfm], 
            prereqs => ["link_t1", "link_t2", "link_pd"] });
      }
   }
   
   
   ############################
   ##### The final stages #####
   ############################
   
   # Explanation:
   # Since the transformations necessary to bring source images into MNI-Talairach
   # space had been computed in the previous stages, now we need to 'resample' the
   # images, essentially applying the computed transformation on the actual images.
   # When only pre-registration N3 is requested, the output of these stages is the 
   # 'final' image, or the image in stereotaxic space. When a second run of N3 or
   # only post-registration N3 is requested, the output is a 'temporary' version
   # of the final image, which awaits a later run of N3 to give the real final 
   # image.
 
   if ($nucOrder eq "pre&post"){
      $pipeline->addStage(
         { name => "final_t1",
         label => "resample t1 into stereotaxic space",
         inputs => [$t1_nt_nuc, $t1_tal_xfm],
         outputs => [$t1_tal_tmp_mnc],
         args => ["mincresample", "-clobber", "-transform",
           $t1_tal_xfm, "-like", $Template,
           $t1_nt_nuc, $t1_tal_tmp_mnc],
         prereqs => ["register", "nueval_t1"] });

      if ($inputType eq "multispectral") {
         $pipeline->addStage(
            { name => "final_t2",
            label => "resample t2 into stereotaxic space",
            inputs => [$t2_nt_nuc, $t2pd_tal_xfm],
            outputs => [$t2_tal_tmp_mnc],
            args => ["mincresample", "-clobber", "-transform",
              $t2pd_tal_xfm, "-like", $Template,
              $t2_nt_nuc, $t2_tal_tmp_mnc],
            prereqs => ["register", "nueval_t2"] });
        
         $pipeline->addStage(
            { name => "final_pd",
            label => "resample pd into stereotaxic space",
            inputs => [$pd_nt_nuc, $t2pd_tal_xfm],
            outputs => [$pd_tal_tmp_mnc],
            args => ["mincresample", "-clobber", "-transform",
              $t2pd_tal_xfm, "-like", $Template,
              $pd_nt_nuc, $pd_tal_tmp_mnc],
            prereqs => ["register", "nueval_pd"] });
      }
      
      if ($nucOrder eq "pre") {
         $pipeline->addStage(
            { name => "final_t1",
            label => "resample t1 into stereotaxic space",
            inputs => [$t1_nt_nuc, $t1_tal_xfm],
            outputs => [$t1_tal_mnc],
            args => ["mincresample", "-clobber", "-transform",
              $t1_tal_xfm, "-like", $Template,
              $t1_nt_nuc, $t1_tal_mnc],
            prereqs => ["register", "nueval_t1"] });

         if ($inputType eq "multispectral") {
            $pipeline->addStage(
               { name => "final_t2",
               label => "resample t2 into stereotaxic space",
               inputs => [$t2_nt_nuc, $t2pd_tal_xfm],
               outputs => [$t2_tal_mnc],
               args => ["mincresample", "-clobber", "-transform",
                 $t2pd_tal_xfm, "-like", $Template,
                 $t2_nt_nuc, $t2_tal_mnc],
               prereqs => ["register", "nueval_t2"] });
       
            $pipeline->addStage(
               { name => "final_pd",
               label => "resample pd into stereotaxic space",
               inputs => [$pd_nt_nuc, $t2pd_tal_xfm],
               outputs => [$pd_tal_mnc],
               args => ["mincresample", "-clobber", "-transform",
                 $t2pd_tal_xfm, "-like", $Template,
                 $pd_nt_nuc, $pd_tal_mnc],
               prereqs => ["register", "nueval_pd"] });
         }
      }

   }
   if ($nucOrder eq "post"){
      $pipeline->addStage(
         { name => "final_t1",
         label => "resample t1 into stereotaxic space",
         inputs => [$t1_native, $t1_tal_xfm],
         outputs => [$t1_tal_tmp_mnc],
         args => ["mincresample", "-clobber", "-transform",
           $t1_tal_xfm, "-like", $Template, $t1_native, 
           $t1_tal_tmp_mnc],
         prereqs => ["register"] });

      if ($inputType eq "multispectral") {
         $pipeline->addStage(
            { name => "final_t2",
            label => "resample t2 into stereotaxic space",
            inputs => [$t2_native, $t2pd_tal_xfm],
            outputs => [$t2_tal_tmp_mnc],
            args => ["mincresample", "-clobber", "-transform",
              $t2pd_tal_xfm, "-like", $Template, $t2_native, 
              $t2_tal_tmp_mnc],
            prereqs => ["register"] });
     
         $pipeline->addStage(
            { name => "final_pd",
            label => "resample pd into stereotaxic space",
            inputs => [$pd_native, $t2pd_tal_xfm],
            outputs => [$pd_tal_tmp_mnc],
            args => ["mincresample", "-clobber", "-transform",
              $t2pd_tal_xfm, "-like", $Template, $pd_native, 
              $pd_tal_tmp_mnc],
            prereqs => ["register"] });
      }
      
   } 
    
   ########################################################
   ##### Post-registration non-uniformity corrections #####
   ########################################################
   
   # Explanation:
   # Since we have noticed qualitative improvements in subsequent steps when an
   # additional run of N3 (correction of intensity non-uniformity) is performed
   # in stereotaxic space, the following stages do just that. These stages are 
   # performed by default, but may optionally be excluded.

   if ($nucOrder eq "pre&post"){ 
      $pipeline->addStage(
         { name => "post-nuc_t1",
         label => "second non-uniformity correction",
         inputs => [$t1_tal_tmp_mnc],
         outputs => [$t1_tal_mnc],
         args => ["nu_correct", "-clobber", $t1_tal_tmp_mnc, $t1_tal_mnc],
         prereqs => ["final_t1"] });

      if ($inputType eq "multispectral") {
         $pipeline->addStage(
            { name => "post-nuc_t2",
            label => "second non-uniformity correction",
            inputs => [$t2_tal_tmp_mnc],
            outputs => [$t2_tal_mnc],
            args => ["nu_correct", "-clobber", $t2_tal_tmp_mnc, $t2_tal_mnc],
            prereqs => ["final_t2"] });
    
         $pipeline->addStage(
            { name => "post-nuc_pd",
            label => "second non-uniformity correction",
            inputs => [$pd_tal_tmp_mnc],
            outputs => [$pd_tal_mnc],
            args => ["nu_correct", "-clobber", $pd_tal_tmp_mnc, $pd_tal_mnc],
            prereqs => ["final_pd"] });
      }
   }

   if ($nucOrder eq "post") {
      $pipeline->addStage(
         { name => "nuest_t1",
         label => "non-unfiformity estimation",
         inputs => [$t1_tal_tmp_mnc],
         outputs => [$t1_nuc],
         args => ["nu_estimate", "-clobber", $t1_tal_tmp_mnc, $t1_nuc],
         prereqs => ["link_t1"] });
   
      $pipeline->addStage(
         { name => "nueval_t1",
         label => "remove non-uniformity",
         inputs => [$t1_tal_tmp_mnc, $t1_nuc],
         outputs => [$t1_tal_mnc],
         args => ["nu_evaluate", "-clobber", "-mapping", $t1_nuc, $t1_tal_tmp_mnc, $t1_tal_mnc],
         prereqs => ["nuest_t1"] });
   
      if ($inputType eq "multispectral") {
         $pipeline->addStage(
            { name => "nuest_t2",
            label => "non-unfiformity estimation",
            inputs => [$t2_tal_tmp_mnc],
            outputs => [$t2_nuc],
            args => ["nu_estimate", "-clobber", $t2_tal_tmp_mnc, $t2_nuc],
            prereqs => ["link_t2"] });

         $pipeline->addStage(
            { name => "nuest_pd",
            label => "non-unfiformity estimation",
            inputs => [$pd_tal_tmp_mnc],
            outputs => [$pd_nuc],
            args => ["nu_estimate", "-clobber", $pd_tal_tmp_mnc, $pd_nuc],
            prereqs => ["link_pd"] });

         $pipeline->addStage(
            { name => "nueval_t2",
            label => "remove non-uniformity",
            inputs => [$t2_tal_tmp_mnc, $t2_nuc],
            outputs => [$t2_tal_mnc],
            args => ["nu_evaluate", "-clobber", "-mapping", $t2_nuc, $t2_tal_tmp_mnc, $t2_tal_mnc],
            prereqs => ["nuest_t2"] });

         $pipeline->addStage(
            { name => "nueval_pd",
            label => "remove non-uniformity",
            inputs => [$pd_tal_tmp_mnc, $pd_nuc],
            outputs => [$pd_tal_mnc],
            args => ["nu_evaluate", "-clobber", "-mapping", $pd_nuc, 
              $pd_tal_tmp_mnc, $pd_tal_mnc],
            prereqs => ["nuest_pd"] });
      }
   }

   #####################################
   ##### The classification stages #####
   #####################################
   
   # Explanation:
   # These are the steps that produce 'discretely' classified (segmented) images
   # from the final images. Basically, using classify_clean (the main component of
   # INSECT), the intensity of each voxel puts it into one of 4 categories:
   # Gray matter, white matter, CSF, or background.
   
   if ($nucOrder eq "pre&post") { 
      unless ($classifyType ne "cleanTags") {
         if ($inputType eq "t1only") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", "-clean_tags",
                 $t1_tal_mnc, $cls_tmp],
               prereqs => ["post-nuc_t1"] });
         }
   
         elsif ($inputType eq "multispectral") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", "-clean_tags",
                 $t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc, $cls_tmp],
               prereqs => ["post-nuc_t1", "post-nuc_t2", "post-nuc_pd"] });
         }
      }
      else {
         if ($inputType eq "t1only") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", $t1_tal_mnc, $cls_tmp],
               prereqs => ["post-nuc_t1"] });
         }
   
         elsif ($inputType eq "multispectral") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", $t1_tal_mnc, 
                 $t2_tal_mnc, $pd_tal_mnc, $cls_tmp],
               prereqs => ["post-nuc_t1", "post-nuc_t2", "post-nuc_pd"] });
         }
      }
   }

   elsif ($nucOrder ne "pre&post") {
      unless ($classifyType ne "cleanTags") {
         if ($inputType eq "t1only") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", "-clean_tags",
                 $t1_tal_mnc, $cls_tmp],
               prereqs => ["nueval_t1"] });
         }
   
         elsif ($inputType eq "multispectral") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", "-clean_tags",
                 $t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc, $cls_tmp],
               prereqs => ["nueval_t1", "nueval_t2", "nueval_pd"] });
         }
      }
      else {
         if ($inputType eq "t1only") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", $t1_tal_mnc, $cls_tmp],
               prereqs => ["nueval_t1"] });
         }
   
         elsif ($inputType eq "multispectral") {
            $pipeline->addStage(
               { name => "classify",
               label => "tissue classification",
               inputs => [$t1_tal_mnc, $t2_tal_mnc, $pd_tal_mnc],
               outputs => [$cls_tmp],
               args => ["classify_clean", "-clobber", $t1_tal_mnc, 
                 $t2_tal_mnc, $pd_tal_mnc, $cls_tmp],
               prereqs => ["nueval_t1", "nueval_t2", "nueval_pd"] });
         }
      }  
   }  

   ###################################################
   ##### The non-cortical tissues masking stages #####
   ###################################################
# CLAUDE 

   $pipeline->addStage(
      { name => "skull_masking",
      label => "masking skull based on classified image",
      inputs => [$t1_tal_mnc, $cls_tmp],
      outputs => [$cortex, $cls_masked, $mask, $maskD],
      args => ["brain_mask", $maskOption, $prefix, $dsid, $tempDir, 
               $cls_tmp, $t1_tal_mnc, $cortex, $cls_masked, $mask, $maskD ],
      prereqs => ["classify"] });

   #########################################
   ##### The partial volume estimation #####
   #########################################

   my @pve_stage_inputs = ($t1_tal_mnc, $t1_tal_xfm, $cls_masked, $mask, $maskD);
   if ($inputType eq "multispectral") {
      push @pve_stage_inputs, ($t2_tal_mnc);
      push @pve_stage_inputs, ($pd_tal_mnc);
   } 
   
   $pipeline->addStage(
      { name => "pve_stage",
      label => "partial volume estimation",
      inputs => \@pve_stage_inputs,
      outputs => [$pve_curvature, $pve_sc, $pve_wm, $pve_gm, $pve_csf, $cls_correct,
                  $skel_csf, $cls_four, $cls_volumes ],
      args => ["pve_stage", $inputType, $t1_tal_mnc, $t2_tal_mnc,
               $pd_tal_mnc, $t1_tal_xfm, $cls_masked, $mask, $maskD, $pve_curve_prefix, 
               $pve_prefix, $pve_curvature, $pve_sc, $pve_wm, $pve_gm, $pve_csf,
               $cls_correct, $skel_csf, $cls_four, $cls_volumes ],
      prereqs => ["skull_masking"] } );

   #################################################
   #### The volumetric nonlinear-fitting stage  ####
   #################################################
   
   # Explanation:
   # Non-linear registration to the registration target will allow us to use
   # ANIMAL. So this stage calculates the transform necessary for this kind of
   # registration.
   
   if ($nucOrder eq "pre&post") {
      $pipeline->addStage(
         { name => "nlfit",
         label => "creation of nonlinear transform",
         inputs => [$t1_tal_mnc],
         outputs => [$t1_tal_nl_xfm],
         args => ["nlfit_smr", "-clobber", "-modeldir", $regModelDir,
           "-model", $regModel, $t1_tal_mnc, $t1_tal_nl_xfm],
         prereqs => ["post-nuc_t1"] });
   }
   elsif ($nucOrder ne "pre&post") {
      $pipeline->addStage(
         { name => "nlfit",
         label => "creation of nonlinear transform",
         inputs => [$t1_tal_mnc],
         outputs => [$t1_tal_nl_xfm],
         args => ["nlfit_smr", "-clobber", "-modeldir", $regModelDir,
           "-model", $regModel, $t1_tal_mnc, $t1_tal_nl_xfm],
         prereqs => ["nueval_t1"] });
   }
    
   #########################
   ##### ANIMAL stages #####
   #########################
   
   # Explanation:
   # ANIMAL essentially maps the images to a probabilistic atlas developed
   # from the ICBM database. Bain lobes and major brain organelles are identified
   # in the atlas, and each voxel is then given a probability value of being in
   # that lobe or organelle. These stages will also calculate the volume of the
   # identified lobes.
 
   unless ($animal eq "noANIMAL") {
      $pipeline->addStage(
         { name => "segment",
         label => "automatic labelling",
         inputs => [$t1_tal_nl_xfm, $cls_correct],
         outputs => [$stx_labels],
         args => ["stx_segment", "-clobber", "-symmetric_atlas",
           $t1_tal_nl_xfm, $identity, $cls_correct, $stx_labels],
         prereqs => ["nlfit", "pve_stage"] });
            
      $pipeline->addStage(
         { name => "segment_volumes",
         label => "label and compute lobe volumes in native space",
         inputs => [$t1_tal_xfm, $stx_labels],
         outputs => [$label_volumes, $lobe_volumes],
         args => ["compute_icbm_vols", "-clobber", "-transform", $t1_tal_xfm,
           "-invert", "-lobe_volumes", $lobe_volumes, $stx_labels, $label_volumes],
         prereqs => ["segment"] });
      
      $pipeline->addStage(
         { name => "segment_mask",
         label => "mask the segmentation",
         inputs => [$stx_labels, $cortex],
         outputs => [$stx_labels_masked],
         args => ["surface_mask2", $stx_labels, $cortex, $stx_labels_masked],
         prereqs => ["skull_masking", "segment"] });

   }
  
   ################################
   ##### Smooth-matter stages #####
   ################################
   
   # Explanation:
   # The smooth-matter stages basically run a smoothing kernel on the different
   # tissue classes of the brain, and are important for VBM purposes. These steps 
   # are prerequisites for the purposes of examining symmetry in subsequent stages.
   
   unless ($VBM eq "noVBM") {
      $pipeline->addStage(
         { name => "smooth_wm",
         label => "WM map for VBM",
         inputs => [$cls_masked],
         outputs => [$smooth_wm],
         args => ["smooth_mask", "-clobber", "-binvalue", 3, "-fwhm",
           $volumeFWHM, $cls_masked, $smooth_wm],
         prereqs => ["skull_masking"] });
   
      $pipeline->addStage(
         { name => "smooth_gm",
         label => "GM map for VBM",
         inputs => [$cls_masked],
         outputs => [$smooth_gm],
         args => ["smooth_mask", "-clobber", "-binvalue", 2, "-fwhm",
           $volumeFWHM, $cls_masked, $smooth_gm],
         prereqs => ["skull_masking"] });
   
      $pipeline->addStage(
         { name => "smooth_csf",
         label => "CSF map for VBM",
         inputs => [$cls_masked],
         outputs => [$smooth_csf],
         args => ["smooth_mask", "-clobber", "-binvalue", 1, "-fwhm",
           $volumeFWHM, $cls_masked, $smooth_csf],
         prereqs => ["skull_masking"] });
   }

   #############################
   ##### The symmetry toys #####
   #############################
   
   # Explanation:
   # The following steps produce output that allows for the analysis of
   # symmetry/asymmetry of brain tissues.
    
   unless ($VBM eq "noVBM" or $symmetry eq "noSymmetry") {
      $pipeline->addStage(
         { name => "flip_wm",
         label => "flip WM map",
         inputs => [$smooth_wm],
         outputs => [$flip_wm],
         args => ["flip_volume", $smooth_wm, $flip_wm],
         prereqs => ["smooth_wm"] });
   
      $pipeline->addStage(
         { name => "flip_gm",
         label => "flip GM map",
         inputs => [$smooth_gm],
         outputs => [$flip_gm],
         args => ["flip_volume", $smooth_gm, $flip_gm],
         prereqs => ["smooth_gm"] });
   
      $pipeline->addStage(
         { name => "flip_csf",
         label => "flip CSF map",
         inputs => [$smooth_csf],
         outputs => [$flip_csf],
         args => ["flip_volume", $smooth_csf, $flip_csf],
         prereqs => ["smooth_csf"] });

      $pipeline->addStage(
         { name => "diff_wm",
         label => "WM asymmetry map",
         inputs => [$smooth_wm, $flip_wm],
         outputs => [$diff_wm],
         args => ["mincmath", "-clobber", "-sub", $smooth_wm,
           $flip_wm, $diff_wm],
         prereqs => ["flip_wm"] });

      $pipeline->addStage(
         { name => "diff_gm",
         label => "GM asymmetry map",
         inputs => [$smooth_gm, $flip_gm],
         outputs => [$diff_gm],
         args => ["mincmath", "-clobber", "-sub", $smooth_gm,
           $flip_gm, $diff_gm],
         prereqs => ["flip_gm"] });

      $pipeline->addStage(
         { name => "diff_csf",
         label => "CSF asymmetry map",
         inputs => [$smooth_csf, $flip_csf],
         outputs => [$diff_csf],
         args => ["mincmath", "-clobber", "-sub", $smooth_csf,
           $flip_csf, $diff_csf],
         prereqs => ["flip_csf"] });

      $pipeline->addStage(
         { name => "reshape_wm",
         label => "final WM asymmetry map",
         inputs => [$diff_wm],
         outputs => [$reshape_wm],
         args => ["mincreshape", "-clobber", "-short", "-signed",
           "-valid_range", -32000, 32000, "-image_range", -1, 1,
           $diff_wm, $reshape_wm],
         prereqs => ["diff_wm"] });
   
      $pipeline->addStage(
         { name => "reshape_gm",
         label => "final GM asymmetry map",
         inputs => [$diff_gm],
         outputs => [$reshape_gm],
         args => ["mincreshape", "-clobber", "-short", "-signed",
           "-valid_range", -32000, 32000, "-image_range", -1, 1,
           $diff_gm, $reshape_gm],
         prereqs => ["diff_gm"] });
   
      $pipeline->addStage(
         { name => "reshape_csf",
         label => "final CSF asymmetry map",
         inputs => [$diff_csf],
         outputs => [$reshape_csf],
         args => ["mincreshape", "-clobber", "-short", "-signed",
           "-valid_range", -32000, 32000, "-image_range", -1, 1,
           $diff_csf, $reshape_csf],
         prereqs => ["diff_csf"] });
   }


   ################################
   #### Cortical fitting steps ####
   ################################
   
   # Explanation:
   # The surfaces produced here by CLASP are a result of a deforming ellipsoid
   # model that shrinks inward in an iterative fashion until it finds the inner
   # surface of the cortex that is produced by the interface between gray matter
   # and white matter. This surface is frequently referred to as the
   # 'white-surface'. The surface is a polygonal (triangulated) mesh, each point 
   # on which is referred to as a 'vertex'. Once this surface is produced, a
   # process of expansion outwards towards the CSF skeleton follows. This process
   # is governed by laplacian fluid dynamics and attempts to find the best fit for
   # the pial surface (or gray-surface) taking into account the partial volume
   # information. Since this surface is an expansion from the white-surface, each
   # vertex on the new surface is 'linked' to an original vertex on the
   # white-surface. Optionally, a polygonal mesh with 328k triangles (instead of
   # the default 82k mesh) could be produced, thereby quadrupling the number of
   # vertices. 

#CLAUDE    
   unless ($VBC eq "noVBC") {
      $pipeline->addStage(
         { name => "white_mask",
         label => "masks cortical WM",
         inputs => [$cls_correct],
         outputs => [$white_masked_mnc],
         args => ["mask_cortical_white_matter", $pve_prefix,
           $white_masked_mnc, 3],
         prereqs => ["pve_stage"] });

      $pipeline->addStage(
         { name => "extract_white_surface",
         label => "Create WM surface (82k)",
         inputs => [$white_masked_mnc],
         outputs => [$white_tmp],
         args => ["extract_white_surface", $white_masked_mnc,
           $white_surf_prefix, 2.5],
         prereqs => ["white_mask"] });

      $pipeline->addStage(
         { name => "calibrate_white",
         label => "calibrate 82k-WM-surface with gradient field",
         inputs => [$white_tmp, $cls_correct, $skel_csf, $t1_tal_mnc],
         outputs => [$white_surface_82k],
         args => ["calibrate_white", $t1_tal_mnc, $cls_correct, $skel_csf,
           $white_tmp, $white_surface_82k],
         prereqs => ["extract_white_surface", "pve_stage"] });

      $pipeline->addStage(
         { name => "laplace_field",
         label => "create laplacian field in the cortex",
         inputs => [$skel_csf, $white_surface_82k, $cls_correct],
         outputs => [$laplace_field],
         args => ["make_asp_grid", $skel_csf, $white_surface_82k, $cls_correct,
           $laplace_field],
         prereqs => ["calibrate_white"] });

      if ($claspOption eq "smallOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "gray_surface_82k",
            label => "expand to pial surface (82k GM surface)",
            inputs => [$cls_correct, $white_surface_82k, $laplace_field],
            outputs => [$gray_surface_82k],
            args => ["expand_from_white", $cls_correct, $white_surface_82k,
              $gray_surface_82k, $laplace_field],
            prereqs => ["laplace_field"] });
   
         $pipeline->addStage(
            { name => "mid_surface_82k", 
            label => "create intermediate 82k surface",
            inputs => [$white_surface_82k, $gray_surface_82k],
            outputs => [$mid_surface_82k],
            args => ["average_surfaces", $mid_surface_82k, "none", "none", 1, 
              $gray_surface_82k, $white_surface_82k],
            prereqs => ["gray_surface_82k"] });

      }

#CLAUDE: 328k surfaces will not work in this way.
#        - must always create 82k surfaces no matter what
#        - must converge 328k white surface
#        - generate laplacian field based on 328k
#        - use -refine switch in extract_white_surface and expand_from_white
#      
      if ($claspOption eq "largeOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage( 
            { name => "subdivide_white",
            label => "subdivide 82k-WM-surface creating 328k-WM-surface",
            inputs => [$white_surface_82k],
            outputs => [$white_surface_328k],
            args => ["subdivide_polygons", $white_surface_82k, 
              $white_surface_328k],
            prereqs => ["calibrate_white"] });
   
         $pipeline->addStage(
            { name => "gray_surface_328k",
            label => "expand to pial surface (328k GM surface)",
            inputs => [$cls_correct, $white_surface_328k, $laplace_field],
            outputs => [$gray_surface_328k],
            args => ["expand_from_white", $cls_correct, $white_surface_328k,
              $gray_surface_328k, $laplace_field, 327680],
            prereqs => ["subdivide_white", "laplace_field"] });
   
         $pipeline->addStage(
            { name => "mid_surface_328k", 
            label => "create intermediate 328k surface",
            inputs => [$white_surface_328k, $gray_surface_328k],
            outputs => [$mid_surface_328k],
            args => ["average_surfaces", $mid_surface_328k, "none", "none", 1, 
              $gray_surface_328k, $white_surface_328k],
            prereqs => ["gray_surface_328k"] });
      }

      $pipeline->addStage(
         { name => "surface_quality_checks",
         label => "surface quality checks on 82k surface",
         inputs => [$white_surface_82k, $gray_surface_82k],
         outputs => [],
         args => ["surface_qc", $white_masked_mnc, $cls_correct, 
           $white_surface_82k,, $gray_surface_82k],
         prereqs => ["extract_white_surface", "gray_surface_82k"] });

   }

   #############################
   ##### The t_link stages #####
   #############################
   
   # Explanation:
   # Since each vertex on the gray-surface is linked to vertex on the
   # white-surface, a reliable metric to measure cortical thickness is the distance
   # between linked vertices. This is more likely to be biologically meaningful
   # than many other metrics of cortical thickness, and is referred to as the
   # 't_link' metric. The following stages calculate the t_link thickness in
   # stereotaxic space, then in native space. The latter is achieved by applying
   # the reverse of the linear transform on the volume (therefore taking the volume
   # back to native space), then calculating thickness. Both sets of cortical
   # thickness values are then smoothed using a diffusion-smoothing kernel that is
   # applied on the cortical surface.

   unless ($VBC eq "noVBC") {
      if ($claspOption eq "smallOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "dump_rms_82k",
            label => "t-link thickness (82k surfaces)",
            inputs => [$gray_surface_82k, $white_surface_82k],
            outputs => [$rms_thickness_82k],
            args => ["cortical_thickness", "-tlink", $gray_surface_82k, $white_surface_82k, 
              $rms_thickness_82k],
            prereqs => ["gray_surface_82k"] });
   
         $pipeline->addStage(
            { name => "rms_thickness_82k_20mmFWHM",
            label => "20mmFWHM blurred thickness (82k surfaces)",
            inputs => [$mid_surface_82k, $rms_thickness_82k],
            outputs => [$rms_thickness_82k_20mmFWHM],
            args => ["diffuse", "-kernel", 20, "-iterations", 1000,
              "-parametric", 1, $mid_surface_82k, $rms_thickness_82k,
              $rms_thickness_82k_20mmFWHM],
            prereqs => ["dump_rms_82k", "mid_surface_82k"] });
      
         $pipeline->addStage(
            { name => "rms_thickness_82k_30mmFWHM",
            label => "30mmFWHM blurred thickness (82k surfaces)",
            inputs => [$mid_surface_82k, $rms_thickness_82k],
            outputs => [$rms_thickness_82k_30mmFWHM],
            args => ["diffuse", "-kernel", 30, "-iterations", 1000,
               "-parametric", 1, $mid_surface_82k, $rms_thickness_82k,
              $rms_thickness_82k_30mmFWHM],
            prereqs => ["dump_rms_82k", "mid_surface_82k"] });
   
         $pipeline->addStage(
            { name => "rms_thickness_82k_40mmFWHM",
            label => "40mmFWHM blurred thickness (82k surfaces)",
            inputs => [$mid_surface_82k, $rms_thickness_82k],
            outputs => [$rms_thickness_82k_40mmFWHM],
            args => ["diffuse", "-kernel", 40, "-iterations", 1000,
               "-parametric", 1, $mid_surface_82k, $rms_thickness_82k,
              $rms_thickness_82k_40mmFWHM],
            prereqs => ["dump_rms_82k", "mid_surface_82k"] });
   
         if ($surfaceFWHM ne 20) {  
            $pipeline->addStage(
               { name => "rms_thickness_82k_additional_blur",
               label => "thickness blurred: additional kernel (82k surfaces)",
               inputs => [$mid_surface_82k, $rms_thickness_82k],
               outputs => [$rms_thickness_82k_additional_blur],
               args => ["diffuse", "-kernel", $surfaceFWHM, "-iterations", 1000,
                  "-parametric", 1, $mid_surface_82k, $rms_thickness_82k,
               $rms_thickness_82k_additional_blur],
               prereqs => ["dump_rms_82k", "mid_surface_82k"] });
         }
         
   
         $pipeline->addStage(
            { name => "native_rms_82k",
            label => "native thickness (82k surfaces)",
            inputs => [$white_surface_82k, $gray_surface_82k, $t1_tal_xfm],
            outputs => [$native_rms_82k],
            args => ["native_rms_and_blur", "-kernel", 0, $white_surface_82k, 
              $gray_surface_82k, $t1_tal_xfm, $native_rms_82k],
            prereqs => ["gray_surface_82k"] });
      
         $pipeline->addStage(
            { name => "native_rms_82k_20mmFWHM",
            label => "20mmFWHM blurred native thickness (82k surfaces)",
            inputs => [$white_surface_82k, $gray_surface_82k, $t1_tal_xfm],
            outputs => [$native_rms_82k_20mmFWHM],
            args => ["native_rms_and_blur", $white_surface_82k, $gray_surface_82k,
              $t1_tal_xfm, $native_rms_82k_20mmFWHM],
            prereqs => ["gray_surface_82k"] });
   
         $pipeline->addStage(
            { name => "native_rms_82k_30mmFWHM",
            label => "30mmFWHM blurred native thickness (82k surfaces)",
            inputs => [$white_surface_82k, $gray_surface_82k, $t1_tal_xfm],
            outputs => [$native_rms_82k_30mmFWHM],
            args => ["native_rms_and_blur", "-kernel", 30, $white_surface_82k, 
              $gray_surface_82k,$t1_tal_xfm, $native_rms_82k_30mmFWHM],
            prereqs => ["gray_surface_82k"] });    
   
         $pipeline->addStage(
            { name => "native_rms_82k_40mmFWHM",
            label => "40mmFWHM blurred native thickness (82k surfaces)",
            inputs => [$white_surface_82k, $gray_surface_82k, $t1_tal_xfm],
            outputs => [$native_rms_82k_40mmFWHM],
            args => ["native_rms_and_blur", "-kernel", 40, $white_surface_82k, 
              $gray_surface_82k,$t1_tal_xfm, $native_rms_82k_40mmFWHM],
            prereqs => ["gray_surface_82k"] });
      
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "native_rms_82k_additional_blur",
               label => "native thickness blurred: additional kernel (82k surfaces)",
               inputs => [$white_surface_82k, $gray_surface_82k, $t1_tal_xfm],
               outputs => [$native_rms_82k_additional_blur],
               args => ["native_rms_and_blur", "-kernel", $surfaceFWHM, $white_surface_82k, 
                 $gray_surface_82k, $t1_tal_xfm, $native_rms_82k_additional_blur],
               prereqs => ["gray_surface_82k"] });
         }
      }    
   
      if ($claspOption eq "largeOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "dump_rms_328k",
            label => "t-link thickness (328k surfaces)",
            inputs => [$gray_surface_328k, $white_surface_328k],
            outputs => [$rms_thickness_328k],
            args => ["dump_rms", $gray_surface_328k, $white_surface_328k, $rms_thickness_328k],
            prereqs => ["gray_surface_328k"] });
   
         $pipeline->addStage(
            { name => "rms_thickness_328k_20mmFWHM",
            label => "20mmFWHM blurred thickness (328k surfaces)",
            inputs => [$mid_surface_328k, $rms_thickness_328k],
            outputs => [$rms_thickness_328k_20mmFWHM],
            args => ["diffuse", "-kernel", 20, "-iterations", 1000,
               "-parametric", 1, $mid_surface_328k, $rms_thickness_328k,
              $rms_thickness_328k_20mmFWHM],
            prereqs => ["dump_rms_328k", "mid_surface_328k"] });
   
         $pipeline->addStage(
            { name => "rms_thickness_328k_30mmFWHM",
            label => "30mmFWHM blurred thickness (328k surfaces)",
            inputs => [$mid_surface_328k, $rms_thickness_328k],
            outputs => [$rms_thickness_328k_30mmFWHM],
            args => ["diffuse", "-kernel", 30, "-iterations", 1000,
               "-parametric", 1, $mid_surface_328k, $rms_thickness_328k,
              $rms_thickness_328k_30mmFWHM],
            prereqs => ["dump_rms_328k", "mid_surface_328k"] });  
   
         $pipeline->addStage(
            { name => "rms_thickness_328k_40mmFWHM",
            label => "40mmFWHM blurred thickness (328k surfaces)",
            inputs => [$mid_surface_328k, $rms_thickness_328k],
            outputs => [$rms_thickness_328k_40mmFWHM],
            args => ["diffuse", "-kernel", 40, "-iterations", 1000,
               "-parametric", 1, $mid_surface_328k, $rms_thickness_328k,
              $rms_thickness_328k_40mmFWHM],
            prereqs => ["dump_rms_328k", "mid_surface_328k"] });
      
         if ($surfaceFWHM ne 20) {  
            $pipeline->addStage(
               { name => "rms_thickness_328k_additional_blur",
               label => "thickness blurred: additional kernel (328k surfaces)",
               inputs => [$mid_surface_328k, $rms_thickness_328k],
               outputs => [$rms_thickness_328k_additional_blur],
               args => ["diffuse", "-kernel", $surfaceFWHM, "-iterations", 1000,
                  "-parametric", 1, $mid_surface_328k, $rms_thickness_328k,
                 $rms_thickness_328k_additional_blur],
               prereqs => ["dump_rms_328k", "mid_surface_328k"] });  
         }  
   
         $pipeline->addStage(
            { name => "native_rms_328k",
            label => "native thickness (328k surfaces)",
            inputs => [$white_surface_328k, $gray_surface_328k, $t1_tal_xfm],
            outputs => [$native_rms_328k],
            args => ["native_rms_and_blur", "-kernel", 0, $white_surface_328k, 
              $gray_surface_328k, $t1_tal_xfm, $native_rms_328k],
            prereqs => ["gray_surface_328k"] });                                

   
         $pipeline->addStage(
            { name => "native_rms_328k_20mmFWHM",
            label => "20mmFWHM blurred native thickness (328k surfaces)",
            inputs => [$white_surface_328k, $gray_surface_328k, $t1_tal_xfm],
            outputs => [$native_rms_328k_20mmFWHM],
            args => ["native_rms_and_blur", $white_surface_328k, $gray_surface_328k,
              $t1_tal_xfm, $native_rms_328k_20mmFWHM],
            prereqs => ["gray_surface_328k"] });
   
         $pipeline->addStage(
            { name => "native_rms_328k_30mmFWHM",
            label => "30mmFWHM blurred native thickness (328k surfaces)",
            inputs => [$white_surface_328k, $gray_surface_328k, $t1_tal_xfm],
            outputs => [$native_rms_328k_30mmFWHM],
            args => ["native_rms_and_blur", "-kernel", 30, $white_surface_328k, 
              $gray_surface_328k, $t1_tal_xfm, $native_rms_328k_30mmFWHM],
            prereqs => ["gray_surface_328k"] });    
   
         $pipeline->addStage(
            { name => "native_rms_328k_40mmFWHM",
            label => "40mmFWHM blurred native thickness (328k surfaces)",
            inputs => [$white_surface_328k, $gray_surface_328k, $t1_tal_xfm],
            outputs => [$native_rms_328k_40mmFWHM],
            args => ["native_rms_and_blur", "-kernel", 40, $white_surface_328k, 
              $gray_surface_328k, $t1_tal_xfm, $native_rms_328k_40mmFWHM],
            prereqs => ["gray_surface_328k"] });
      
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "native_rms_328k_additional_blur",
               label => "native thickness blurred: additional kernel (328k surfaces)",
               inputs => [$white_surface_328k, $gray_surface_328k, $t1_tal_xfm],
               outputs => [$native_rms_328k_additional_blur],
               args => ["native_rms_and_blur", "-kernel", $surfaceFWHM, $white_surface_328k, 
                 $gray_surface_328k, $t1_tal_xfm, $native_rms_328k_additional_blur],
               prereqs => ["gray_surface_328k"] });
         }
      }  
   }
    
   #############################################################
   ##### The Cortical Parcellation and Surface Area stages #####
   #############################################################
   
   # Explanation:
   # Once the surfaces, thickness values and the ANIMAL labels have been produced,
   # it is now possible to intersect the labels of the brain lobes with the
   # cortical surfaces. This will allow the calculation of mean cortical thickness
   # values for these lobes, as well as an estimate of cortical surface area for
   # each lobe. All of this is done in native space.

   unless ($VBC eq "noVBC" or $animal eq "noANIMAL") {
         $pipeline->addStage(
            { name => "xfm_native",
            label => "invert talairach transform",
            inputs => [$t1_tal_xfm],
            outputs => [$tal_to_native_xfm],
            args => ["xfminvert", $t1_tal_xfm, $tal_to_native_xfm],
            prereqs => ["register"] });
         
      if ($claspOption eq "smallOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "animal_surface_intersect_82k",
            label => "intersect segmentation with 82k-GM-surface",
            inputs => [$stx_labels, $gray_surface_82k],
            outputs => [$stx_surface_labels_82k],
            args => ["volume_object_evaluate", $stx_labels, $gray_surface_82k,
               $stx_surface_labels_82k],
            prereqs => ["segment", "gray_surface_82k"] });
      
         $pipeline->addStage(
            { name => "surface_lobe_labels_82k",
            label => "segment 82k-GM-surface into lobes",
            inputs => [$stx_surface_labels_82k],
            outputs => [$stx_surface_lobes_82k],
            args => ["remap_to_lobes", $stx_surface_labels_82k, $stx_surface_lobes_82k],
            prereqs => ["animal_surface_intersect_82k"] });
         
         $pipeline->addStage(
            { name => "native_gray_surface_82k",
            label => "transform 82k-GM-surface to native space",
            inputs => [$gray_surface_82k, $tal_to_native_xfm],
            outputs => [$native_gray_surface_82k],
            args => ["transform_objects", $gray_surface_82k, $tal_to_native_xfm,
               $native_gray_surface_82k],
            prereqs => ["gray_surface_82k", "xfm_native"] });
      
         unless ($cortexArea eq "noCortexArea") { 
            $pipeline->addStage(
               { name => "lobe_areas_82k",
               label => "surface areas of lobes (82k-GM-surface)",
               inputs => [$native_gray_surface_82k, $stx_surface_lobes_82k],
               outputs => [$native_lobe_areas_82k],
               args => ["cortex_area", "-surface", $native_gray_surface_82k,
                  "-zone", $stx_surface_lobes_82k, "-output", $native_lobe_areas_82k],
               prereqs => ["native_gray_surface_82k", "surface_lobe_labels_82k"] });
         }
         
         $pipeline->addStage(
            { name => "regional_thickness_82k_20mmFWHM",
            label => "20mm-blurred regional thickness (82k surfaces)",
            inputs => [$stx_surface_lobes_82k, $native_rms_82k_20mmFWHM],
            outputs => [$native_lobe_thickness_82k_20mmFWHM],
            args => ["regional_thickness", $native_rms_82k_20mmFWHM, $stx_surface_lobes_82k,
               $native_lobe_thickness_82k_20mmFWHM],
            prereqs => ["surface_lobe_labels_82k", "native_rms_82k_20mmFWHM"] });
         
         $pipeline->addStage(
            { name => "regional_thickness_82k_30mmFWHM",
            label => "30mm-blurred regional thickness (82k surfaces)",
            inputs => [$stx_surface_lobes_82k, $native_rms_82k_30mmFWHM],
            outputs => [$native_lobe_thickness_82k_30mmFWHM],
            args => ["regional_thickness", $native_rms_82k_30mmFWHM, $stx_surface_lobes_82k,
               $native_lobe_thickness_82k_30mmFWHM],
            prereqs => ["surface_lobe_labels_82k", "native_rms_82k_30mmFWHM"] });
         
         $pipeline->addStage(
            { name => "regional_thickness_82k_40mmFWHM",
            label => "40mm-blurred regional thickness (82k surfaces)",
            inputs => [$stx_surface_lobes_82k, $native_rms_82k_40mmFWHM],
            outputs => [$native_lobe_thickness_82k_40mmFWHM],
            args => ["regional_thickness", $native_rms_82k_40mmFWHM, $stx_surface_lobes_82k,
               $native_lobe_thickness_82k_40mmFWHM],
            prereqs => ["surface_lobe_labels_82k", "native_rms_82k_40mmFWHM"] });
         
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "regional_thickness_82k_additional_blur",
               label => "regional thickness blurred: additional kernel (82k surfaces)",
               inputs => [$stx_surface_lobes_82k, $native_rms_82k_additional_blur],
               outputs => [$native_lobe_thickness_82k_additional_blur],
               args => ["regional_thickness", $native_rms_82k_additional_blur, $stx_surface_lobes_82k,
                  $native_lobe_thickness_82k_additional_blur],
               prereqs => ["surface_lobe_labels_82k", "native_rms_82k_additional_blur"] });
         }
      }
   
      if ($claspOption eq "largeOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "animal_surface_intersect_328k",
            label => "intersect segmentation with 328k-GM-surface",
            inputs => [$stx_labels, $gray_surface_328k],
            outputs => [$stx_surface_labels_328k],
            args => ["volume_object_evaluate", $stx_labels, $gray_surface_328k,
               $stx_surface_labels_328k],
            prereqs => ["segment", "gray_surface_328k"] });
         
         $pipeline->addStage(
            { name => "surface_lobe_labels_328k",
            label => "segment 328k-GM-surface into lobes",
            inputs => [$stx_surface_labels_328k],
            outputs => [$stx_surface_lobes_328k],
            args => ["remap_to_lobes", $stx_surface_labels_328k, $stx_surface_lobes_328k],
            prereqs => ["animal_surface_intersect_328k"] });
         
         $pipeline->addStage(
            { name => "native_gray_surface_328k",
            label => "transform 328k-GM-surface to native space",
            inputs => [$gray_surface_328k, $tal_to_native_xfm],
            outputs => [$native_gray_surface_328k],
            args => ["transform_objects", $gray_surface_328k, $tal_to_native_xfm,
               $native_gray_surface_328k],
            prereqs => ["gray_surface_328k", "xfm_native"] });
      
         unless ($cortexArea eq "noCortexArea") {
            $pipeline->addStage(
               { name => "lobe_areas_328k",
               label => "surface areas of lobes (328k-GM-surface)",
               inputs => [$native_gray_surface_328k, $stx_surface_lobes_328k],
               outputs => [$native_lobe_areas_328k],
               args => ["cortex_area", "-surface", $native_gray_surface_328k,
                  "-zone", $stx_surface_lobes_328k, "-output", $native_lobe_areas_328k],
               prereqs => ["native_gray_surface_328k", "surface_lobe_labels_328k"] });
         }
      
         $pipeline->addStage(
            { name => "regional_thickness_328k_20mmFWHM",
            label => "20mm-blurred regional thickness (328k surfaces)",
            inputs => [$stx_surface_lobes_328k, $native_rms_328k_20mmFWHM],
            outputs => [$native_lobe_thickness_328k_20mmFWHM],
            args => ["regional_thickness", $native_rms_328k_20mmFWHM, $stx_surface_lobes_328k,
               $native_lobe_thickness_328k_20mmFWHM],
            prereqs => ["surface_lobe_labels_328k", "native_rms_328k_20mmFWHM"] });
         
         $pipeline->addStage(
            { name => "regional_thickness_328k_30mmFWHM",
            label => "30mm-blurred regional thickness (328k surfaces)",
            inputs => [$stx_surface_lobes_328k, $native_rms_328k_30mmFWHM],
            outputs => [$native_lobe_thickness_328k_30mmFWHM],
            args => ["regional_thickness", $native_rms_328k_30mmFWHM, $stx_surface_lobes_328k,
               $native_lobe_thickness_328k_30mmFWHM],
            prereqs => ["surface_lobe_labels_328k", "native_rms_328k_30mmFWHM"] });
         
         $pipeline->addStage(
            { name => "regional_thickness_328k_40mmFWHM",
            label => "40mm-blurred regional thickness (328k surfaces)",
            inputs => [$stx_surface_lobes_328k, $native_rms_328k_40mmFWHM],
            outputs => [$native_lobe_thickness_328k_40mmFWHM],
            args => ["regional_thickness", $native_rms_328k_40mmFWHM, $stx_surface_lobes_328k,
               $native_lobe_thickness_328k_40mmFWHM],
            prereqs => ["surface_lobe_labels_328k", "native_rms_328k_40mmFWHM"] });
         
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "regional_thickness_328k_additional_blur",
               label => "regional thickness blurred: additional kernel (328k surfaces)",
               inputs => [$stx_surface_lobes_328k, $native_rms_328k_additional_blur],
               outputs => [$native_lobe_thickness_328k_additional_blur],
               args => ["regional_thickness", $native_rms_328k_additional_blur, $stx_surface_lobes_328k,
                  $native_lobe_thickness_328k_additional_blur],
               prereqs => ["surface_lobe_labels_328k", "native_rms_328k_additional_blur"] });
         }
      }
   }

   ######################################################
   ##### The non-linear surface registration stages #####
   ######################################################
   
   # Explanation:
   # Once the cortical surfaces are produced, they need to be aligned with the
   # surfaces of other brains in the data set so cortical thickness data could be
   # compared across subjects. To achieve this, SURFREG performs a non-linear
   # registration of the surfaces to a pre-defined template surface. This transform
   # is then applied (by resampling) in native space.
 
   unless ($VBC eq "noVBC" or $surfReg eq "noSurfReg") {
      if ($claspOption eq "smallOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "surface_dataterm_82k",
            label => "WM surface depth map (82k surfaces)",
            inputs => [$white_surface_82k],
            outputs => [$dataterm_82k],
            args => ["surface-data-term-1", $white_surface_82k, $dataterm_82k],
            prereqs => ["calibrate_white"] });
   
         $pipeline->addStage(
            { name => "sphere-register_82k",
            label => "register 82k-WM-surface nonlinearly",
            inputs => [$dataterm_82k],
            outputs => [$surface_mapping_82k],
            args => ["sphere-register", $smallSurfModelDataTerm, $dataterm_82k, $surface_mapping_82k],
            prereqs => ["surface_dataterm_82k"] });

         $pipeline->addStage(
            { name => "resample_82k",
            label => "nonlinear resample thickness (82k surfaces)",
            inputs => [$rms_thickness_82k, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_82k],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $rms_thickness_82k, $surface_mapping_82k, $rsl_82k],
            prereqs => ["sphere-register_82k", "dump_rms_82k"] });
      
         $pipeline->addStage(
            { name => "resample_82k_20mmFWHM",
            label => "nonlinear resample 20mm-blurred thickness (82k surfaces)",
            inputs => [$rms_thickness_82k_20mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_82k_20mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $rms_thickness_82k_20mmFWHM, $surface_mapping_82k, $rsl_82k_20mmFWHM],
            prereqs => ["sphere-register_82k", "rms_thickness_82k_20mmFWHM"] });

         $pipeline->addStage(
            { name => "resample_82k_30mmFWHM",
            label => "nonlinear resample 30mm-blurred thickness (82k surfaces)",
            inputs => [$rms_thickness_82k_30mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_82k_30mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $rms_thickness_82k_30mmFWHM, $surface_mapping_82k, $rsl_82k_30mmFWHM],
            prereqs => ["sphere-register_82k", "rms_thickness_82k_30mmFWHM"] });

         $pipeline->addStage(
            { name => "resample_82k_40mmFWHM",
            label => "nonlinear resample 40mm-blurred thickness (82k surfaces)",
            inputs => [$rms_thickness_82k_40mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_82k_40mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $rms_thickness_82k_40mmFWHM, $surface_mapping_82k, $rsl_82k_40mmFWHM],
            prereqs => ["sphere-register_82k", "rms_thickness_82k_40mmFWHM"] });
         
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "resample_82k_additional_blur",
               label => "nonlinear resample thickness blurred: additional kernel (82k surfaces)",
               inputs => [$rms_thickness_82k_additional_blur, $surface_mapping_82k, $white_surface_82k],
               outputs => [$rsl_82k_additional_blur],
               args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
                 $rms_thickness_82k_additional_blur, $surface_mapping_82k, $rsl_82k_additional_blur],
               prereqs => ["sphere-register_82k", "rms_thickness_82k_additional_blur"] });
         }

         $pipeline->addStage(
            { name => "native_resample_82k",
            label => "nonlinear resample native thickness (82k surfaces)",
            inputs => [$native_rms_82k, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_native_82k],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $native_rms_82k, $surface_mapping_82k, $rsl_native_82k],
            prereqs => ["sphere-register_82k", "native_rms_82k"] });
   
         $pipeline->addStage(
            { name => "native_resample_82k_20mmFWHM",
            label => "nonlinear resample 20mm-blurred native thickness (82k surfaces)",
            inputs => [$native_rms_82k_20mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_native_82k_20mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $native_rms_82k_20mmFWHM, $surface_mapping_82k, $rsl_native_82k_20mmFWHM],
            prereqs => ["sphere-register_82k", "native_rms_82k_20mmFWHM"] });
   
         $pipeline->addStage(
            { name => "native_resample_82k_30mmFWHM",
            label => "nonlinear resample 30mm-blurred native thickness (82k surfaces)",
            inputs => [$native_rms_82k_30mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_native_82k_30mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $native_rms_82k_30mmFWHM, $surface_mapping_82k, $rsl_native_82k_30mmFWHM],
            prereqs => ["sphere-register_82k", "native_rms_82k_30mmFWHM"] });

         $pipeline->addStage(
            { name => "native_resample_82k_40mmFWHM",
            label => "nonlinear resample 40mm-blurred native thickness (82k surfaces)",
            inputs => [$native_rms_82k_40mmFWHM, $surface_mapping_82k, $white_surface_82k],
            outputs => [$rsl_native_82k_40mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
              $native_rms_82k_40mmFWHM, $surface_mapping_82k, $rsl_native_82k_40mmFWHM],
            prereqs => ["sphere-register_82k", "native_rms_82k_40mmFWHM"] });
      
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "native_resample_82k_additional_blur",
               label => "nonlinear resample native thickness blurred: additional kernel (82k surfaces)",
               inputs => [$native_rms_82k_additional_blur, $surface_mapping_82k, $white_surface_82k],
               outputs => [$rsl_native_82k_additional_blur],
               args => ["surface-resample", $smallSurfRegModel, $white_surface_82k,
                 $native_rms_82k_additional_blur, $surface_mapping_82k, $rsl_native_82k_additional_blur],
               prereqs => ["sphere-register_82k", "native_rms_82k_additional_blur"] });
         }
      }
   
      if ($claspOption eq "largeOnly" or $claspOption eq "largeAddition") {
         $pipeline->addStage(
            { name => "surface_dataterm_328k",
            label => "WM surface depth map (328k surfaces)",
            inputs => [$white_surface_328k],
            outputs => [$dataterm_328k],
            args => ["surface-data-term-1", "-dt_extra 3", $white_surface_328k, $dataterm_328k],
            prereqs => ["subdivide_white", "calibrate_white"] });
   
         $pipeline->addStage(
            { name => "sphere-register_328k",
            label => "register 328k-WM-surfaces nonlinearly",
            inputs => [$dataterm_328k],
            outputs => [$surface_mapping_328k],
            args => ["sphere-register", $largeSurfModelDataTerm, $dataterm_328k, $surface_mapping_328k],
            prereqs => ["surface_dataterm_328k"] });
      
         $pipeline->addStage(
            { name => "resample_328k",
            label => "nonlinear resample thickness (328k surfaces)",
            inputs => [$rms_thickness_328k, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_328k],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
              $rms_thickness_328k, $surface_mapping_328k, $rsl_328k],
            prereqs => ["sphere-register_328k", "dump_rms_328k"] });
                                                  
         $pipeline->addStage(
            { name => "resample_328k_20mmFWHM",
            label => "nonlinear resample 20mm-blurred thickness (328k surfaces)",
            inputs => [$rms_thickness_328k_20mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_328k_20mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
              $rms_thickness_328k_20mmFWHM, $surface_mapping_328k, $rsl_328k_20mmFWHM],
            prereqs => ["sphere-register_328k", "rms_thickness_328k_20mmFWHM"] });

         $pipeline->addStage(
            { name => "resample_328k_30mmFWHM",
            label => "nonlinear resample 30mm-blurred thickness (328k surfaces)",
            inputs => [$rms_thickness_328k_30mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_328k_30mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
              $rms_thickness_328k_30mmFWHM, $surface_mapping_328k, $rsl_328k_30mmFWHM],
            prereqs => ["sphere-register_328k", "rms_thickness_328k_30mmFWHM"] });

         $pipeline->addStage(
            { name => "resample_328k_40mmFWHM",
            label => "nonlinear resample 40mm-blurred thickness (328k surfaces)",
            inputs => [$rms_thickness_328k_40mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_328k_40mmFWHM],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
              $rms_thickness_328k_40mmFWHM, $surface_mapping_328k, $rsl_328k_40mmFWHM],
            prereqs => ["sphere-register_328k", "rms_thickness_328k_40mmFWHM"] });
      
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "resample_328k_additional_blur",
               label => "nonlinear resample thickness blurred: additional kernel (328k surfaces)",
               inputs => [$rms_thickness_328k_additional_blur, $surface_mapping_328k, $white_surface_328k],
               outputs => [$rsl_328k_additional_blur],
               args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
                 $rms_thickness_328k_additional_blur, $surface_mapping_328k, $rsl_328k_additional_blur],
               prereqs => ["sphere-register_328k", "rms_thickness_328k_additional_blur"] });
         }

         $pipeline->addStage(
            { name => "native_resample_328k",
            label => "nonlinear resample native thickness (328k surfaces)",
            inputs => [$native_rms_328k, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_native_328k],
            args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
              $native_rms_328k, $surface_mapping_328k, $rsl_native_328k],
            prereqs => ["sphere-register_328k", "native_rms_328k"] });
      
         $pipeline->addStage(
            { name => "native_resample_328k_20mmFWHM",
            label => "nonlinear resample 20mm-blurred native thickness (328k surfaces)",
            inputs => [$native_rms_328k_20mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_native_328k_20mmFWHM],
            args => ["surface-resample", $largeSurfRegModel, $white_surface_328k,
              $native_rms_328k_20mmFWHM, $surface_mapping_328k, $rsl_native_328k_20mmFWHM],
            prereqs => ["sphere-register_328k", "native_rms_328k_20mmFWHM"] });
   
         $pipeline->addStage(
            { name => "native_resample_328k_30mmFWHM",
            label => "nonlinear resample 30mm-blurred native thickness (328k surfaces)",
            inputs => [$native_rms_328k_30mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_native_328k_30mmFWHM],
            args => ["surface-resample", $largeSurfRegModel, $white_surface_328k,
              $native_rms_328k_30mmFWHM, $surface_mapping_328k, $rsl_native_328k_30mmFWHM],
            prereqs => ["sphere-register_328k", "native_rms_328k_30mmFWHM"] });

         $pipeline->addStage(
            { name => "native_resample_328k-40mmFWHM",
            label => "nonlinear resample 40mm-blurred native thickness (328k surfaces)",
            inputs => [$native_rms_328k_40mmFWHM, $surface_mapping_328k, $white_surface_328k],
            outputs => [$rsl_native_328k_40mmFWHM],
            args => ["surface-resample", $largeSurfRegModel, $white_surface_328k,
              $native_rms_328k_40mmFWHM, $surface_mapping_328k, $rsl_native_328k_40mmFWHM],
            prereqs => ["sphere-register_328k", "native_rms_328k_40mmFWHM"] });
      
         if ($surfaceFWHM ne 20) {
            $pipeline->addStage(
               { name => "native_resample_328k_additional_blur",
               label => "nonlinear resample native thickness blurred: additional kernel (328k surfaces)",
               inputs => [$native_rms_328k_additional_blur, $surface_mapping_328k, $white_surface_328k],
               outputs => [$rsl_native_328k_additional_blur],
               args => ["surface-resample", $smallSurfRegModel, $white_surface_328k,
                 $native_rms_328k_additional_blur, $surface_mapping_328k, $rsl_native_328k_additional_blur],
               prereqs => ["sphere-register_328k", "native_rms_328k_additional_blur"] });
         }
      }
   }
    
   ##################################
   ##### The verification stage #####
   ##################################
   
   # Explanation:
   # For purposes of rapid quality assessments of the output of this pipeline,
   # the following stages produce an image file in '.png' format that show-cases
   # the output of the main stages of the pipeline.
      
   ######### This is somewhat complex since the content of the image 
   ######### will depend on which stages are being run.
    
   my @baseRow = ("create_verify_image", $verify, "-clobber", "-width", 1200, 
               "-row", "color:gray", "overlay:${cortex}:green", $t1_tal_mnc);
   my @baseInputs = ($t1_tal_mnc);
   my @multispectralRows = ("-row", "color:gray", "overlay:${cortex}:green", 
               $t2_tal_mnc, "-row", "color:gray", "overlay:${cortex}:green}", $pd_tal_mnc);
   my @multispectralInputs = ($t2_tal_mnc, $pd_tal_mnc);
   my @clsRow = ("-row", "color:gray", $cls_four);
   my @clsInputs = ($cls_correct);
   my @segRow = ("-row", "color:label", $stx_labels);
   my @segInputs = ($stx_labels);
   my @claspRow = ("-row", "color:gray", "overlay:${white_surface_82k}:green:0.5",
               "overlay:${gray_surface_82k}:blue:0.5", $cls_correct);
   my @claspLargeRow = ("-row", "color:gray", "overlay:${white_surface_328k}:green:0.5",
               "overlay:${gray_surface_328k}:blue:0.5", $cls_correct);
   my @claspInputs = ($white_surface_82k, $gray_surface_82k);
   my @claspLargeInputs = ($white_surface_328k, $gray_surface_328k);
   my @verifyPrereqs = "pve_stage";
   my @verifyRows = @baseRow;
   my @verifyInputs = @baseInputs;

   push @verifyRows, @multispectralRows if ($inputType eq "multispectral");
   push @verifyInputs, @multispectralInputs if ($inputType eq "multispectral");
   push @verifyRows, @clsRow;
   push @verifyInputs, @clsInputs;
   push @verifyRows, @segRow unless ($animal eq "noANIMAL");
   push @verifyInputs, @segInputs unless ($animal eq "noANIMAL");
   push @verifyPrereqs, "segment" unless ($animal eq "noANIMAL");
   push @verifyRows, @claspRow 
            if ($VBC eq "VBC" and $claspOption ne "largeOnly");
   push @verifyInputs, @claspInputs
            if ($VBC eq "VBC" and $claspOption ne "largeOnly");
   push @verifyPrereqs, "mid_surface_82k"
            if ($VBC eq "VBC" and $claspOption ne "largeOnly");
   push @verifyRows, @claspLargeRow 
            if ($VBC eq "VBC" and $claspOption ne "smallOnly");
   push @verifyInputs, @claspLargeInputs
            if ($VBC eq "VBC" and $claspOption ne "smallOnly");
   push @verifyPrereqs, "mid_surface_328k"
            if ($VBC eq "VBC" and $claspOption ne "smallOnly");

   
   $pipeline->addStage(
      { name => "verify",
      label => "create verification image",
      inputs => \@verifyInputs,
      outputs => [$verify],
      args => \@verifyRows,
      prereqs => \@verifyPrereqs });    




#####################
# Pipeline management
#####################

############# Rerun any failures from a previous run of this subjects pipe
    
   $pipeline->resetFailures();

############# Reset running jobs if that's what the user wants (the default 
############# is to overwrite running jobs).

   if ($resetRunning) {
     $pipeline->resetRunning();
   }

############# Restart all stages; restart from a given stage;
############# or continue from current status.
    
   $pipeline->updateStatus();
   if ($reset) {
      if ($reset eq "resetAll") {
        $pipeline->resetAll();
      } else {
        $pipeline->resetFromStage($reset);
      }
   }

############# Add this pipe to our happy array of pipes

   $pipes->addPipe($pipeline);

}

############# Now run whatever it is that the user wanted done
   
   if ($command eq "printStatus" ) {
     $pipes->printUnfinished();
   }
   
   elsif ($command eq "printStatusReport") {
     $pipes->printStatusReport($statusReportFile);
   }
   
   elsif ($command eq "statusFromFiles") {
     $pipes->updateFromFiles();
     $pipes->printUnfinished();
   }
   
   elsif ($command eq "printStages") {
     $pipes->printStages();
   }
   
   elsif ($command eq "makeGraph") {
     $pipes->createDotGraph("dependency-graph.dot");
   }
   
   elsif ($command eq "makeFilenameGraph") {
     $pipes->createFilenameDotGraph("filename-dependency-graph.dot","${base}/$dsids[0]/");
   }
   
   elsif ($command eq "run") { 
     # register all the programs
     $pipes->registerPrograms();
     $pipes->run();
   }
   
   else {
     print "huh? Grunkle little gnu, grunkle\n";
   }

############# Voila!! #############
