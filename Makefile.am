AUTOMAKE_OPTIONS = check-news
## ACLOCAL_AMFLAGS = -I local_m4

MNI_MODELS = mni-models

# mess with the data install directory
bindir = $(prefix)/CIVET-$(VERSION)/
pkgdatadir = $(bindir)/models/
progsdir = $(bindir)/progs/

bin_SCRIPTS = \
        src/average_surface_builder_mc.pl \
        src/CIVET_Processing_Pipeline \
        src/CIVET_QC_Pipeline \
        src/Classify.pm \
        src/Clean_Scans.pm \
        src/Cortex_Mask.pm \
        src/Cortical_Measurements.pm \
        src/Linear_Transforms.pm \
        src/Link_Native.pm \
        src/MRI_Image.pm \
        src/Non_Linear_Transforms.pm \
        src/Processing_Pipeline_Main.pm \
        src/Segment.pm \
        src/Skull_Masking.pm \
        src/Surface_Fit.pm \
        src/Surface_Register.pm \
        src/VBM.pm \
        src/Verify_Image.pm

progs_SCRIPTS = \
        progs/asymmetry_cortical_thickness \
        progs/asymmetry_position_map \
        progs/asymmetry_vbm_map \
        progs/best1stepnlreg.pl \
        progs/bestlinreg.pl \
        progs/bestsurfreg.pl \
        progs/brain_mask_qc \
        progs/cerebral_volume \
        progs/civet_qc \
        progs/classify_qc \
        progs/clean_native_scan \
        progs/cortical_area_stats \
        progs/cortical_mask \
        progs/cortical_volume_stats \
        progs/diff_civet.pl \
        progs/extract_wm_hemispheres \
        progs/geom_surfreg.pl \
        progs/gyrification_index \
        progs/lobe_area \
        progs/lobe_stats \
        progs/make_asp_grid \
        progs/mean_curvature \
        progs/multispectral_stx_registration \
        progs/nuc_inorm_stage \
        progs/remove_skull \
        progs/surface_fit_classify \
        progs/surface_qc \
        progs/surf_qc_image \
        progs/talto6 \
        progs/talto7 \
        progs/verify_atlas \
        progs/verify_clasp \
        progs/verify_image \
        progs/verify_laplacian \
        progs/verify_surfsurf

# installed data

modelsdir = $(bindir)/models/

icbmdir = $(bindir)/models/icbm/
icbmaaldir = $(bindir)/models/icbm/AAL/
icbmdktdir = $(bindir)/models/icbm/DKT/
icbmlobesdir = $(bindir)/models/icbm/lobes/
icbmgyridir = $(bindir)/models/icbm/gyri/

colindir = $(bindir)/models/colin/
colinaaldir = $(bindir)/models/colin/AAL/
colindktdir = $(bindir)/models/colin/DKT/
colinlobesdir = $(bindir)/models/colin/lobes/
colingyridir = $(bindir)/models/colin/gyri/

samirdir = $(bindir)/models/samir/
samiraaldir = $(bindir)/models/samir/AAL/
samirdktdir = $(bindir)/models/samir/DKT/
samirlobesdir = $(bindir)/models/samir/lobes/
samirgyridir = $(bindir)/models/samir/gyri/

models_DATA = \
        models/Cerebellum_Ventricles_SubCortical_Mask-1.2.0.mnc \
        models/Cerebellum_Ventricles_SubCortical_Mask-2009s.mnc \
        models/Cerebellum_Ventricles_SubCortical_Mask-ADNIhi.mnc \
        models/Cerebellum_Ventricles_SubCortical_Mask.mnc \
        models/flip_right.xfm \
        models/hemi_left_mask.mnc \
        models/hemi_right_mask.mnc \
        models/identity.xfm \
        models/midline_mask.mnc \
        models/slide_left.xfm \
        models/slide_right.xfm

icbm_DATA = \
        models/icbm/icbm_avg_mid_sym_mc_left_hires.obj \
        models/icbm/icbm_avg_mid_sym_mc_left.obj \
        models/icbm/icbm_avg_mid_sym_mc_right_hires.obj \
        models/icbm/icbm_avg_mid_sym_mc_right.obj \
        models/icbm/icbm_avg_white_sym_mc_left_hires.obj \
        models/icbm/icbm_avg_white_sym_mc_left.obj \
        models/icbm/icbm_avg_white_sym_mc_mask_left.txt \
        models/icbm/icbm_avg_white_sym_mc_mask_right.txt \
        models/icbm/icbm_avg_white_sym_mc_right_hires.obj \
        models/icbm/icbm_avg_white_sym_mc_right.obj
icbmaal_DATA = \
        models/icbm/AAL/AAL_license.txt \
        models/icbm/AAL/AAL_README.txt \
        models/icbm/AAL/icbm_avg_mid_mc_AAL_left.txt \
        models/icbm/AAL/icbm_avg_mid_mc_AAL_right.txt
icbmdkt_DATA = \
        models/icbm/DKT/DKTatlas40.labels \
        models/icbm/DKT/icbm_avg_mid_mc_dkt40_left.txt \
        models/icbm/DKT/icbm_avg_mid_mc_dkt40_right.txt \
        models/icbm/DKT/README
icbmgyri_DATA = \
        models/icbm/gyri/icbm_avg_mid_sym_mc_gyri_left.txt \
        models/icbm/gyri/icbm_avg_mid_sym_mc_gyri_right.txt
icbmlobes_DATA = \
        models/icbm/lobes/icbm_avg_mid_sym_mc_atlas_left.txt \
        models/icbm/lobes/icbm_avg_mid_sym_mc_atlas_right.txt \
        models/icbm/lobes/README

colin_DATA = \
        models/colin/colin_mid_mc_left_hires.obj \
        models/colin/colin_mid_mc_left.obj \
	models/colin/colin_mid_mc_right_hires.obj \
        models/colin/colin_mid_mc_right.obj \
        models/colin/colin_white_mc_left.obj \
        models/colin/colin_white_mc_mask_left.txt \
        models/colin/colin_white_mc_mask_right.txt \
        models/colin/colin_white_mc_right.obj
colinaal_DATA = \
        models/colin/AAL/AAL_atlas_colin_mc_hires_left.txt \
        models/colin/AAL/AAL_atlas_colin_mc_hires_right.txt \
        models/colin/AAL/AAL_license.txt \
	models/colin/AAL/AAL_README.txt
colingyri_DATA = \
        models/colin/gyri/surface_gyri_colin_mc_left.txt \
        models/colin/gyri/surface_gyri_colin_mc_right.txt
colinlobes_DATA = \
        models/colin/lobes/surface_atlas_colin_mc_left.txt \
        models/colin/lobes/surface_atlas_colin_mc_right.txt \
        models/colin/lobes/README

samir_DATA = \
	models/samir/samir_mid_left_hires.obj \
	models/samir/samir_mid_left.obj \
	models/samir/samir_mid_right_hires.obj \
	models/samir/samir_mid_right.obj \
	models/samir/samir_white_left.obj \
	models/samir/samir_white_mc_mask_left.txt \
	models/samir/samir_white_mc_mask_right.txt \
	models/samir/samir_white_right.obj
samirgyri_DATA = \
        models/samir/gyri/surface_gyri_samir_mc_left.txt \
        models/samir/gyri/surface_gyri_samir_mc_right.txt
samirlobes_DATA = \
        models/samir/lobes/surface_atlas_samir_mc_left.txt \
        models/samir/lobes/surface_atlas_samir_mc_right.txt

EXTRA_DIST = \
        $(bin_SCRIPTS) \
        $(progs_SCRIPTS) \
        $(models_DATA) \
        $(icbm_DATA) \
        $(icbmaal_DATA) \
        $(icbmdkt_DATA) \
        $(icbmgyri_DATA) \
        $(icbmlobes_DATA) \
        $(colin_DATA) \
        $(colinaal_DATA) \
        $(colindkt_DATA) \
        $(colingyri_DATA) \
        $(colinlobes_DATA) \
        $(samir_DATA) \
        $(samiraal_DATA) \
        $(samirdkt_DATA) \
        $(samirgyri_DATA) \
        $(samirlobes_DATA) \
	epm-header.in

# gunzip rule
%: %.gz
	$(gzip) -d -c $< > $@

