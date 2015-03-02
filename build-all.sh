#!/bin/bash

# Usage:
# $ git clone https://github.com/starius/mxedeb
# $ cd mxedeb
# $ ./build-all.sh

git clone -b master https://github.com/mxe/mxe.git mxemaster
cp -ra mxemaster i686-w64-mingw32.static
cp -ra mxemaster x86_64-w64-mingw32.static
cp -ra mxemaster i686-w64-mingw32.shared
cp -ra mxemaster x86_64-w64-mingw32.shared

function build_for_target {
    cd $1
    MXE_TARGETS=$1 lua ../mxedeb.lua | tee mxedeb.log
    cd ..
}

build_for_target i686-w64-mingw32.static
build_for_target x86_64-w64-mingw32.static
build_for_target i686-w64-mingw32.shared
build_for_target x86_64-w64-mingw32.shared
