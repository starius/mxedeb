# mxedeb, Build DEB packages from MXE packages

## Requirements

See [Debian requirements of MXE][mxe-req].

Requirements of mxedeb: lua, tsort, fakeroot, dpkg-deb.

## Usage

[Download MXE][mxe-download]

Copy `mxedeb.lua` to root `mxe` dir.

Run `lua mxedeb.lua`

Debian packages `.deb` are written to `*.deb` files.

[mxe-download]: http://mxe.cc/#download
[mxe-req]: http://mxe.cc/#requirements-debian
