#!/bin/sh
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

# Usage: appimage.sh <ladybird checkout> <AppDir> <output dir>
set -eu

src="$1"
appdir="$2"
out="$3"

date="$(TZ=UTC0 git -C "${src}" log -1 --format=%cd --date=format-local:%Y%m%d)"
sha="$(git -C "${src}" rev-parse --short=7 HEAD)"
export VERSION="${date}.git${sha}"

# A build container has no FUSE to mount the linuxdeploy AppImages with.
export APPIMAGE_EXTRACT_AND_RUN=1
export EXTRA_PLATFORM_PLUGINS="libqwayland.so"
# The strip bundled in linuxdeploy predates the .relr.dyn section that lld writes.
export NO_STRIP=1

mkdir -p "${out}"
cd "${out}"

linuxdeploy \
  --appdir "${appdir}" \
  --executable "${appdir}/usr/bin/Ladybird" \
  --deploy-deps-only "${appdir}/usr/libexec" \
  --desktop-file "${appdir}/usr/share/applications/org.ladybird.Ladybird.desktop" \
  --icon-file "${appdir}/usr/share/icons/hicolor/scalable/apps/org.ladybird.Ladybird.svg" \
  --plugin qt \
  --output appimage
