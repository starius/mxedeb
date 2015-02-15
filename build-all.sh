#!/bin/bash

# Usage:
# $ git clone https://github.com/starius/mxedeb
# $ cd mxedeb
# $ ./build-all.sh

git clone -b stable https://github.com/mxe/mxe.git mxestable
cp -ra mxestable mxestable-i686-pc-mingw32
cp -ra mxestable mxestable-x86_64-w64-mingw32
cp -ra mxestable mxestable-i686-w64-mingw32
git clone -b master https://github.com/mxe/mxe.git mxemaster
cp -ra mxemaster mxemaster-i686-w64-mingw32.static
cp -ra mxemaster mxemaster-x86_64-w64-mingw32.static
cp -ra mxemaster mxemaster-i686-w64-mingw32.shared
cp -ra mxemaster mxemaster-x86_64-w64-mingw32.shared

function build_for_target {
    cd $1-$2
    MXE_TARGETS=$2 lua ../mxedeb.lua | tee mxedeb.log
    cd ..
}

MXE_VERSION=0.23
build_for_target mxestable i686-pc-mingw32
build_for_target mxestable x86_64-w64-mingw32
build_for_target mxestable i686-w64-mingw32

MXE_VERSION=trunc
build_for_target mxemaster i686-w64-mingw32.static
build_for_target mxemaster x86_64-w64-mingw32.static
build_for_target mxemaster i686-w64-mingw32.shared
build_for_target mxemaster x86_64-w64-mingw32.shared
