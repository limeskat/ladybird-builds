# Ladybird Builds

Unofficial packages of the [Ladybird](https://ladybird.org) browser, built every week from upstream `master`. Ladybird doesn't publish binaries of its own before its alpha, and this repository fills that gap.

## Install

Each release is tagged with the upstream commit date and short hash, such as `20261005.gitfc5e9c7`, and carries one file per system.

| System | File |
| --- | --- |
| Debian sid | `ladybird_0~<date>.git<hash>+sid_amd64.deb` |
| Ubuntu 26.04 | `ladybird_0~<date>.git<hash>+ubuntu26.04_amd64.deb` |
| Arch Linux x86-64 | `ladybird-git-<date>.<hash>-1-x86_64.pkg.tar.zst` |
| Any other x86-64 Linux with glibc 2.39 or newer | `Ladybird-<date>.git<hash>-x86_64.AppImage` |

On Debian sid:

```sh
gh release download --repo h3nc4/ladybird-builds --pattern '*+sid_amd64.deb'
sudo apt install ./ladybird_*+sid_amd64.deb
```

On Ubuntu 26.04, swap `+sid` for `+ubuntu26.04` in both lines.

On Arch Linux:

```sh
gh release download --repo h3nc4/ladybird-builds --pattern 'ladybird-git-*.pkg.tar.zst'
sudo pacman -U ./ladybird-git-*.pkg.tar.zst
```

Anywhere else:

```sh
gh release download --repo h3nc4/ladybird-builds --pattern '*.AppImage'
chmod +x Ladybird-*.AppImage
./Ladybird-*.AppImage
```

The AppImage needs these from the system. Release `20261005.git4b63acc` was run against them on Ubuntu 24.04 and Debian 13.

| Requirement | Check |
| --- | --- |
| glibc 2.39 or newer | `ldd --version` |
| libstdc++ from GCC 13 or newer | `strings "$(ldconfig -p \| awk '/libstdc\+\+\.so\.6 .*x86-64/{print $NF; exit}')" \| grep -x GLIBCXX_3.4.32` |
| a setuid `fusermount3` or `fusermount`, of any version | `command -v fusermount3 fusermount` |
| `libOpenGL.so.0` from libglvnd, packaged as `libopengl0` on Debian and Ubuntu | `ldconfig -p \| grep libOpenGL.so.0` |
| fontconfig, freetype, X11, xcb, wayland-client and zlib | present on any desktop install |

Without FUSE, `./Ladybird-*.AppImage --appimage-extract-and-run` unpacks the image to a temporary directory and runs it from there.

## Before installing

The build targets x86-64-v3, the level that adds AVX2. Intel Haswell and AMD Excavator were the first processors with it. An older CPU stops the browser with an illegal instruction. Check with `/lib64/ld-linux-x86-64.so.2 --help | grep x86-64-v3`, which prints `supported` beside it on a capable machine.

The `.deb` depends on the exact Qt release it was built against, because Ladybird uses Qt's private API. When the distribution moves to a newer Qt, apt holds Qt back or offers to remove `ladybird` until the next weekly build catches up.

The Arch package records upstream's Qt 6.10 minimum instead, since Arch has no private-ABI marker to pin against and holding a single Qt package back is not supported on a rolling release. It is built against the Qt release in `extra` at build time; a later Qt update may need the next build before Ladybird starts again.

Ladybird itself is pre-alpha. Expect sites to break and the browser to crash.

## How it builds

Each `<target>.Dockerfile` describes a build environment, with toolchain and Qt installed and the build itself left to the scripts. `scripts/build.sh` compiles upstream's `Distribution` preset, which links every dependency statically except Qt and the system libraries, targets the x86-64-v3 baseline and skips link-time optimisation. `scripts/deb.sh`, `scripts/appimage.sh` and `scripts/pkgbuild.sh` then package the result. The AppImage is built on Debian 13 and bundles Qt 6.11 from the Qt online archive, since Ladybird needs Qt 6.10 or newer. The Arch package is built in `archlinux:base-devel` and runs `makepkg` as an unprivileged user, since `makepkg` refuses to run as root.

The `Release` workflow runs every Monday at 06:00 UTC and skips a commit already released. For each target, one job builds the vcpkg dependencies, and 4 runners then compile a quarter of the object files apiece into ccache stores uploaded as artifacts. A last job merges those stores and runs the full build, where every compile is a cache hit and only linking and packaging remain. The vcpkg cache is keyed on upstream's `vcpkg.json` and the Dockerfile, so a new Ladybird commit reuses last week's dependencies. The ccache store is saved per run and restored by the next one. Both are saved even when a job runs out of time, and the next run resumes from that point.

To build the Debian package on a local machine:

```sh
git clone --depth 1 https://github.com/LadybirdBrowser/ladybird src
docker build -t ladybird-debian -f debian.Dockerfile \
  --build-arg RUST_TOOLCHAIN="$(sed -n 's/^channel = "\(.*\)"/\1/p' src/rust-toolchain.toml)" .
docker run --rm -v "${PWD}:/w" ladybird-debian scripts/build.sh /w/src /w/root
docker run --rm -v "${PWD}:/w" ladybird-debian scripts/deb.sh /w/src /w/root /w/dist sid
```

The package is written to `dist/`, owned by root.

## License

The build scripts are GPL-3.0-or-later. Ladybird itself is BSD-2-Clause.
