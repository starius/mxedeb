# mxedeb
Build DEB packages from MXE packages

## Requirements
See [Debian requirements of
MXE](http://mxe.cc/#requirements-debian).

Requirements of mxedeb: lua, tsort, fakeroot, dpkg-deb.

# Usage
```bash
$ git clone https://github.com/starius/mxedeb
$ cd mxedeb
$ ./build-all.sh
```
Debian packages `.deb` are written to `mxe*-*/*.deb` files.
