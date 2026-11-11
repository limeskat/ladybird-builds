#!/bin/bash
# Copyright (C) 2026  Henrique Almeida
# This file is part of Ladybird Builds.
#
# Ladybird Builds is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ladybird Builds is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ladybird Builds.  If not, see <https://www.gnu.org/licenses/>.

# Usage: pkgbuild.sh <ladybird checkout> <staging root> <output dir>
set -euo pipefail

src="$1"
root="$2"
out="$3"

date="$(TZ=UTC0 git -C "${src}" log -1 --format=%cd --date=format-local:%Y%m%d)"
sha="$(git -C "${src}" rev-parse --short=7 HEAD)"
pkgname="ladybird-git"
pkgver="${date}.${sha}"
qtver="$(pacman -Q qt6-base | cut -d' ' -f2)"

# makepkg refuses to run as root, so everything below happens in the builder's
# home. The staging root stays where the build put it; it is only read here.
work=/home/builder/build
rm -rf "${work}"
mkdir -p "${work}/out"

# Runtime dependencies: every shared library the installed binaries load, mapped
# back to the package that ships it. Libraries inside the staging root are part
# of this package and are skipped.
while IFS= read -r file; do
  file -b "${file}" | grep -q '^ELF' || continue
  LD_LIBRARY_PATH="${root}/usr/lib:${root}/usr/lib64" ldd "${file}" 2>/dev/null || true
done < <(find "${root}" -type f -perm -u+x) |
  sed -n -e 's/^[[:space:]]*[^ ]* => \(\/[^ ]*\).*/\1/p' \
    -e 's/^[[:space:]]*\(\/[^ ]*\.so[^ ]*\) (0x.*/\1/p' |
  grep -v "^${root}/" | sort -u >"${work}/libs"

while IFS= read -r lib; do
  pacman -Qoq "${lib}" 2>/dev/null || true
done <"${work}/libs" | sort -u >"${work}/packages"

depends=()
while IFS= read -r package; do
  [ -n "${package}" ] || continue
  [ "${package}" = qt6-base ] && continue
  depends+=("'${package}'")
done <"${work}/packages"
# Ladybird links Qt's private API, which only holds within one Qt release. Arch
# ships no private ABI marker, so record upstream's minimum instead of pinning
# the exact build and blocking every later system upgrade.
depends+=("'qt6-base>=6.10'")
depends+=("'ttf-liberation'")

cat >"${work}/PKGBUILD" <<EOF
pkgname=${pkgname}
pkgver=${pkgver}
pkgrel=1
pkgdesc="Ladybird web browser, unofficial snapshot built from upstream ${sha} (Qt ${qtver%%-*})"
arch=('x86_64')
url="https://github.com/h3nc4/ladybird-builds"
license=('BSD-2-Clause')
packager="Ladybird Builds <https://github.com/h3nc4/ladybird-builds>"
depends=(${depends[*]})
provides=('ladybird')
conflicts=('ladybird')
options=(!debug)

package() {
  cp -a "${root}/." "\${pkgdir}/"
  ln -s Ladybird "\${pkgdir}/usr/bin/ladybird"
}
EOF

chown -R builder:builder "${work}"
su - builder -c "cd '${work}' && PKGDEST='${work}/out' makepkg --force --nodeps --noconfirm"

mkdir -p "${out}"
cp "${work}"/out/*.pkg.tar.zst "${out}/"
ls -l "${out}"/*.pkg.tar.zst
