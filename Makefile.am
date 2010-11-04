AUTOMAKE_OPTIONS = check-news
## ACLOCAL_AMFLAGS = -I local_m4

MNI_MODELS := mni-models

# mess with the data install directory
bindir = $(prefix)/CIVET-$(VERSION)/
pkgdatadir = $(bindir)/models/
progsdir = $(bindir)/progs/

bin_SCRIPTS := \
        src/CIVET_Processing_Pipeline \
        src/CIVET_QC_Pipeline \
        src/Artefact.pm \
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

progs_SCRIPTS := \
        progs/asymmetry_cortical_thickness \
        progs/asymmetry_position_map \
        progs/asymmetry_vbm_map \
        progs/best1stepnlreg.pl \
        progs/bestlinreg.pl \
        progs/bestsurfreg.pl \
        progs/brain_mask_qc \
        progs/cerebral_volume \
        progs/class_art \
        progs/classify_qc \
        progs/cortical_area_stats \
        progs/cortical_volume_stats \
        progs/cortical_mask \
        progs/diff_civet.pl \
        progs/extract_surface_feature \
        progs/extract_two_hemispheres \
        progs/extract_volume_feature \
        progs/extract_wm_hemispheres \
        progs/gyrification_index \
        progs/lobe_area \
        progs/lobe_stats \
        progs/make_asp_grid \
        progs/mean_curvature \
        progs/multispectral_stx_registration \
        progs/nuc_inorm_stage \
        progs/qc_metric_from_bin_mask \
        progs/remove_skull \
        progs/surf_qc_image \
        progs/surface-register-smartest \
        progs/surface-resample2 \
        progs/surface_fit_classify \
        progs/surface_qc \
        progs/talto6 \
        progs/talto7 \
        progs/verify_atlas \
        progs/verify_clasp

# installed data
pkgdata_DATA := \
        models/Cerebellum_Ventricles_SubCortical_Mask.mnc \
        models/hemi_left_mask.mnc \
        models/hemi_right_mask.mnc \
        models/midline_mask.mnc \
        models/surface_atlas.txt \
        models/surf_reg_model_left.obj \
        models/surf_reg_model_right.obj \
        models/surf_reg_model.obj \
        models/surf_reg_model_left.txt \
        models/surf_reg_model_mask.txt \
        models/surf_reg_model_mask2.txt \
        models/identity.xfm \
        models/flip_right.xfm \
        models/slide_left.xfm \
        models/slide_right.xfm

EXTRA_DIST = \
        $(bin_SCRIPTS) \
        $(progs_SCRIPTS) \
        $(pkgdata_DATA) \
	epm-header.in

# gunzip rule
%: %.gz
	$(gzip) -d -c $< > $@

