# Require autoconf 2.57 or newer.
AC_PREREQ([2.57])

# The arguments are package name, and package version.
AC_INIT([civet],[2.0.0],[Claude Lepage <claude@bic.mni.mcgill.ca>])
AC_CONFIG_SRCDIR([epm-header.in])

AM_INIT_AUTOMAKE

# The argument is the name of the generated header file.
# It is recommended to leave it as "config.h".
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_INSTALL
# AC_PROG_GZIP

# Finish up by writing output files.
AC_CONFIG_FILES([Makefile])
AC_OUTPUT(epm-header)
