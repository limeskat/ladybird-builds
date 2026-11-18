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

# Usage: build.sh <ladybird checkout> <staging root> [prefix]
set -eu

src="$1"
root="$2"
prefix="${3:-/usr}"
jobs="${JOBS:-$(nproc)}"
scripts="$(cd "$(dirname "$0")" && pwd)"

cache="${LADYBIRD_CACHE_DIR:-${src}/Build/caches}"
mkdir -p "${cache}/vcpkg-binary-cache"

cd "${src}"

VCPKG_MAX_CONCURRENCY="${jobs}" ./Meta/ladybird.py vcpkg --preset Distribution

# The default -march=native would crash on any CPU older than the build host's.
cmake --preset Distribution \
  -DCMAKE_C_COMPILER="${CC:-clang}" \
  -DCMAKE_CXX_COMPILER="${CXX:-clang++}" \
  -DCMAKE_INSTALL_PREFIX="${prefix}" \
  -DLAGOM_USE_LINKER=lld \
  -DLADYBIRD_CACHE_DIR="${cache}" \
  -DENABLE_CI_BASELINE_CPU=ON \
  -DENABLE_LTO_FOR_RELEASE=OFF \
  -DENABLE_INSTALL_FREEDESKTOP_FILES=ON \
  -DENABLE_INSTALL_HEADERS=OFF \
  -DBUILD_TESTING=OFF

if [ "${BUILD_STEP:-}" = configure ]; then
  exit 0
fi

# shard.py compiles outside ninja, so generate every header first, and Rust crates write the FFI ones.
if [ -n "${BUILD_SHARD:-}" ]; then
  cmake --build Build/distribution --parallel "${jobs}" --target ladybird_codegen_accumulator
  ninja -C Build/distribution -t targets all | sed -n 's/^\([A-Za-z0-9_]*-build\): phony$/\1/p' >crates
  xargs cmake --build Build/distribution --parallel "${jobs}" --target <crates
  ninja -C Build/distribution -t compdb >Build/distribution/compdb.json
  # ccache hashes the locale, and Python would otherwise set LC_CTYPE for every compile it starts.
  PYTHONCOERCECLOCALE=0 exec python3 "${scripts}/shard.py" "${BUILD_SHARD}" "${jobs}"
fi

cmake --build Build/distribution --parallel "${jobs}"
DESTDIR="${root}" cmake --install Build/distribution --component ladybird_Runtime
DESTDIR="${root}" cmake --install Build/distribution --component ladybird_Freedesktop

find "${root}" -name '*.a' -delete
