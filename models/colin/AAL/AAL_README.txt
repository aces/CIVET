Description:

This AAL labeling package is specific to the resampled surfaces 
(163842/40962 vertices per hemisphere) generated from CIVET pipeline 
(Ad-Dab'bagh et al, Neuroimage, 2006). Note that the AAL template was 
originally defined on the MNI single brain (Colin27 brain, Tzourio-Mazoyer 
et al., 2002, Neuroimage) and registered to the ICBM surface model
(Lyttelton et al., 2007, Neuroimage). The _mc_ (marching-cubes) version
was obtained by first extracting the cortical surfaces for the Colin brain
(19 scans) using CIVET-1.1.12 and CIVET-2.0.0, creating the population
averages for both CIVET versions, then using Colin-to-Colin surface
registration to map the labels to mc space.

The package includes:

1. icbm_avg_mid_mc_AAL_left.txt: 163842 labels for the ICBM surface model on left hemisphere 
                                 in marching-cubes space
2. icbm_avg_mid_mc_AAL_right.txt: 163842 labels for the ICBM surface model on right hemisphere 
                                  in marching-cubes space
3. AAL_license.txt: reference and license agreement

Note that: 1. bilateral labels are different 
           2. the labelling number and regional name are consistent with the orignal 
              reference (Tzourio-Mazoyer et al., 2002, Neuroimage).
           3. the ICBM surface model refers to the surface after resampling (i.e. surface  
              registration) to the averaged surface model (Lyttelton et al., 2007, Neuroimage).  

Labels:

Number   Abbreviation    Description
27      'REC.L'         'Left Gyrus Rectus'
21      'OLF.L'         'Left Olfactory Cortex'
5       'ORBsup.L'      'Left Supeiror frontal gyrus, orbital part'
25      'ORBsupmed.L'	'Left Superior frontal gyrus, medial orbital'
9       'ORBmid.L'      'Left Middle frontal gyrus orbital part'
15      'ORBinf.L'      'Left Inferior frontal gyrus, orbital part'
3       'SFGdor.L'      'Left Superior frontal gyrus, dorsolateral'
7       'MFG.L'         'Left Middle frontal gyrus'
11      'IFGoperc.L'	'Left Inferior frontal gyrus, opercular part'
13      'IFGtriang.L'	'Left Inferior frontal gyrus, triangular part'
23      'SFGmed.L'      'Left Superior frontal gyrus, medial'
19      'SMA.L'         'Left Supplementary motor area'
69      'PCL.L'         'Left Paracentral lobule'
1       'PreCG.L'       'Left Precentral gyrus'
17      'ROL.L'         'Left Rolandic operculum'
57      'PoCG.L'        'Left Postcentral gyrus'
59      'SPG.L'         'Left Superior parietal gyrus'
61      'IPL.L'         'Left Inferior parietal, but supramarginal and angular gyri'
63      'SMG.L'         'Left Supramarginal gyrus'
65      'ANG.L'         'Left Angular gyrus'
67      'PCUN.L'        'Left Precuneus'
49      'SOG.L'         'Left Superior occipital gyrus'
51      'MOG.L'         'Left Middle occipital gyrus'
53      'IOG.L'         'Left Inferior occipital gyrus'
43      'CAL.L'         'Left Calcarine fissure and surrounding cortex'
45      'CUN.L'         'Left Cuneus'
47      'LING.L'        'Left Lingual gyrus'
55      'FFG.L'         'Left Fusiform gyrus'
79      'HES.L'         'Left Heschl gyrus'
81      'STG.L'         'Left Superior temporal gyrus'
85      'MTG.L'         'Left Middle temporal gyrus'
89      'ITG.L'         'Left Inferior temporal gyrus'
83      'TPOsup.L'      'Left Temporal pole: superior temporal gyrus'
87      'TPOmid.L'      'Left Temporal pole: middle temporal gyrus'
39      'PHG.L'         'Left Parahippocampal gyrus'
31      'ACG.L'         'Left Anterior cingulate and paracingulate gyri'
33      'DCG.L'         'Left Median cingulate and paracingulate gyri'
35      'PCG.L'         'Left Posterior cingulate gyrus'
29      'INS.L'         'Left Insula'
28      'REC.R'         'Right Gyrus Rectus'
22      'OLF.R'         'Right Olfactory Cortex'
6       'ORBsup.R'      'Right Supeiror frontal gyrus, orbital part'
26      'ORBsupmed.R'	'Right Superior frontal gyrus, medial orbital'
10      'ORBmid.R'      'Right Middle frontal gyrus orbital part'
16      'ORBinf.R'      'Right Inferior frontal gyrus, orbital part'
4       'SFGdor.R'      'Right Superior frontal gyrus, dorsolateral'
8       'MFG.R'         'Right Middle frontal gyrus'
12      'IFGoperc.R'	'Right Inferior frontal gyrus, opercular part'
14      'IFGtriang.R'	'Right Inferior frontal gyrus, triangular part'
24      'SFGmed.R'      'Right Superior frontal gyrus, medial'
20      'SMA.R'         'Right Supplementary motor area'
70      'PCL.R'         'Right Paracentral lobule'
2       'PreCG.R'       'Right Precentral gyrus'
18      'ROL.R'         'Right Rolandic operculum'
58      'PoCG.R'        'Right Postcentral gyrus'
60      'SPG.R'         'Right Superior parietal gyrus'
62      'IPL.R'         'Right Inferior parietal, but supramarginal and angular gyri'
64      'SMG.R'         'Right Supramarginal gyrus'
66      'ANG.R'         'Right Angular gyrus'
68      'PCUN.R'        'Right Precuneus'
50      'SOG.R'         'Right Superior occipital gyrus'
52      'MOG.R'         'Right Middle occipital gyrus'
54      'IOG.R'         'Right Inferior occipital gyrus'
44      'CAL.R'         'Right Calcarine fissure and surrounding cortex'
46      'CUN.R'         'Right Cuneus'
48      'LING.R'        'Right Lingual gyrus'
56      'FFG.R'         'Right Fusiform gyrus'
80      'HES.R'         'Right Heschl gyrus'
82      'STG.R'         'Right Superior temporal gyrus'
86      'MTG.R'         'Right Middle temporal gyrus'
90      'ITG.R'         'Right Inferior temporal gyrus'
84      'TPOsup.R'      'Right Temporal pole: superior temporal gyrus'
88      'TPOmid.R'      'Right Temporal pole: middle temporal gyrus'
40      'PHG.R'         'Right Parahippocampal gyrus'
32      'ACG.R'         'Right Anterior cingulate and paracingulate gyri'
34      'DCG.R'         'Right Median cingulate and paracingulate gyri'
36      'PCG.R'         'Right Posterior cingulate gyrus'
30      'INS.R'         'Right Insula'

References:

Ad-Dab'bagh Y, Lyttelton O, Muehlboeck JS, Lepage C, Einarson D, Mok K, Ivanov O, Vincent RD, 
Lerch J, Fombonne E, Evans AC , "The CIVET image-processing environment: A fully automated comprehensive
pipeline for anatomical neuroimaging research", in "Proceedings of the 12th Annual Meeting of the
Organization for Human Brain Mapping", M. Corbetta, ed. (Florence,Italy, NeuroImage), 2006

Lyttelton O, Boucher M, Robbins S, Evans A. 2007. An unbiased iterative group registration 
template for cortical surface analysis. Neuroimage. 34: 1535-44.

Tzourio-Mazoyer N, Landeau B, Papathanassiou D, Crivello F, Etard O,Delcroix N, Mazoyer B, 
Joliot M. 2002. Automated anatomical labeling of activations in SPM using a macroscopic anatomical 
parcellation of the MNI MRI single-subject brain. Neuroimage. 15: 273-289.


