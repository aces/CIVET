# Require autoconf 2.57 or newer.
AC_PREREQ([2.57])

# The arguments are package name, and package version.
AC_INIT([civet],[2.1.1],[Claude Lepage <claude@bic.mni.mcgill.ca>])
AC_CONFIG_SRCDIR([epm-header.in])

# The argument is the name of the generated header file.
# It is recommended to leave it as "config.h".
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_INSTALL
# AC_PROG_GZIP

# Finish up by writing output files.
AC_CONFIG_FILES([Makefile])

AC_ARG_ENABLE(animal,
    [  --enable-animal         enable ANIMAL segmentation functionality],
    [ case "${enableval}" in
      yes) animal=true ;;
      no) animal=false ;;
      *) AC_MSG_ERROR(bad value ${enableval} for --enable-animal) ;;
      esac],
    [animal=false])

AM_CONDITIONAL(ANIMAL, test x$enableval = xtrue)

if test x$animal = xtrue; then
  AC_SUBST(ANIMAL,1)
else
  AC_SUBST(ANIMAL,0)
fi

AM_INIT_AUTOMAKE

AC_OUTPUT(epm-header
	  src/CIVET_Processing_Pipeline)

