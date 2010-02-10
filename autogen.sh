#! /bin/sh

set -e
 
aclocal
autoheader
automake --add-missing --copy
autoreconf
