##############################
#### Surface registration ####
##############################

# Once the cortical surfaces are produced, they need to be aligned with the
# surfaces of other brains in the data set so cortical thickness data could be
# compared across subjects. To achieve this, SURFREG performs a non-linear
# registration of the surfaces to a pre-defined template surface. This transform
# is then applied (by resampling) in native space.

package Surface_Register;
use strict;
use PMP::PMP;
use MRI_Image;

sub create_pipeline {
    my $pipeline_ref = @_[0];
    my $Prereqs = @_[1];
    my $image = @_[2];
    my $surfreg_model = @_[3];
    my $surfreg_dataterm = @_[4];

    my $left_mid_surface = ${$image}->{mid_surface}{left};
    my $right_mid_surface = ${$image}->{mid_surface}{right};
    my $left_dataterm = ${$image}->{dataterm}{left};
    my $right_dataterm = ${$image}->{dataterm}{right};
    my $left_surfmap = ${$image}->{surface_map}{left};
    my $right_surfmap = ${$image}->{surface_map}{right};

# ---------------------------------------------------------------------------
#  Step 1: Compute data term on mid surfaces using Maxime's depth potential.
#          We must use alpha=0.05 to be consistent with Oliver's average
#          surface model.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "dataterm_left_surface",
          label => "WM left surface depth potential",
          inputs => [$left_mid_surface],
          outputs => [$left_dataterm],
          args => ["depth_potential", "-alpha", "0.05", "-depth_potential", 
                   $left_mid_surface, $left_dataterm ],
          prereqs => $Prereqs } );

    ${$pipeline_ref}->addStage( {
          name => "dataterm_right_surface",
          label => "WM right surface depth potential",
          inputs => [$right_mid_surface],
          outputs => [$right_dataterm],
          args => ["depth_potential", "-alpha", "0.05", "-depth_potential", 
                   $right_mid_surface, $right_dataterm ],
          prereqs => $Prereqs } );

# ---------------------------------------------------------------------------
#  Step 2: Surface registration to left hemispheric averaged model.
# ---------------------------------------------------------------------------

    ${$pipeline_ref}->addStage( {
          name => "surface_registration_left",
          label => "register left mid-surface nonlinearly",
          inputs => [$left_mid_surface,$left_dataterm],
          outputs => [$left_surfmap],
          args => ["bestsurfreg.pl", "-clobber", "-min_control_mesh", "80",
                   "-max_control_mesh", "81920",
                   "-convergence_control", "2", "-convergence_threshold", "0.01",
                   "-blur_coef", "1.2", "-neighbourhood_radius", "2.8",
                   "-target_spacing", "1.9", "-search_radius", "0.5",
                   $surfreg_model, $surfreg_dataterm,
                   $left_mid_surface, $left_dataterm, $left_surfmap ],
          prereqs => ["dataterm_left_surface"] });

    ${$pipeline_ref}->addStage( {
          name => "surface_registration_right",
          label => "register right mid-surface nonlinearly",
          inputs => [$right_mid_surface,$right_dataterm],
          outputs => [$right_surfmap],
          args => ["bestsurfreg.pl", "-clobber", "-min_control_mesh", "80",
                   "-max_control_mesh", "81920",
                   "-convergence_control", "2", "-convergence_threshold", "0.01",
                   "-blur_coef", "1.2", "-neighbourhood_radius", "2.8",
                   "-target_spacing", "1.9", "-search_radius", "0.5",
                   $surfreg_model, $surfreg_dataterm,
                   $right_mid_surface, $right_dataterm, $right_surfmap ],
          prereqs => ["dataterm_right_surface"] });

    my $SurfReg_complete = [ "surface_registration_left",
                             "surface_registration_right" ];

    return( $SurfReg_complete );
}

1;
