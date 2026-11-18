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

ARG RUST_TOOLCHAIN
ARG LLVM_VERSION="21"
ARG QT_VERSION="6.11.3"
ARG AQTINSTALL_VERSION="3.3.0"

################################################################################
FROM debian:13-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS builder
ARG RUST_TOOLCHAIN
ARG LLVM_VERSION
ARG QT_VERSION
ARG AQTINSTALL_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
  RUSTUP_HOME=/opt/rustup \
  CARGO_HOME=/opt/cargo \
  PATH=/opt/cargo/bin:$PATH \
  CC=clang-${LLVM_VERSION} \
  CXX=clang++-${LLVM_VERSION} \
  CCACHE_DIR=/w/cache/ccache \
  CCACHE_MAXSIZE=3G \
  LADYBIRD_CACHE_DIR=/w/cache/ladybird \
  CMAKE_PREFIX_PATH=/opt/qt/${QT_VERSION}/gcc_64 \
  QMAKE=/opt/qt/${QT_VERSION}/gcc_64/bin/qmake \
  LD_LIBRARY_PATH=/opt/qt/${QT_VERSION}/gcc_64/lib

# Trixie stops at clang 19, which rejects the constexpr tables of vcpkg's zmij, so clang comes from apt.llvm.org
ADD --chmod=644 --checksum=sha256:8b2a587ffd672c4687e7581dad4b2f6c1bb2ad6b480cd9771ba2ff48e0b8c75d \
  https://apt.llvm.org/llvm-snapshot.gpg.key /usr/share/keyrings/llvm.asc

# The LLVM source is added once ca-certificates exists, since apt.llvm.org only serves https
# apt.llvm.org once went unresolvable for longer than the 3 default retries last, and `--error-on=any` fails here instead of at the install
RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  echo "deb [signed-by=/usr/share/keyrings/llvm.asc] https://apt.llvm.org/trixie/ llvm-toolchain-trixie-${LLVM_VERSION} main" \
  > /etc/apt/sources.list.d/llvm.list && \
  apt-get -o Acquire::Retries=8 update --error-on=any && \
  apt-get install -y --no-install-recommends \
  autoconf autoconf-archive automake build-essential ca-certificates ccache \
  clang-${LLVM_VERSION} cmake curl file git glslang-tools \
  libcurl4-openssl-dev libdbus-1-3 libdrm-dev libegl1-mesa-dev \
  libfontconfig1 libgl1-mesa-dev libglib2.0-dev libncurses-dev libpulse-dev libssl-dev \
  libtool libwayland-client0 libwayland-cursor0 libwayland-egl1 \
  libxcb-cursor0 libxcb-icccm4 libxcb-icccm4-dev libxcb-image0 libxcb-keysyms1 \
  libxcb-render-util0 libxcb-shape0 libxcb-xkb1 libxkbcommon-dev \
  libxkbcommon-x11-0 lld-${LLVM_VERSION} nasm ninja-build pkg-config \
  python3 python3-venv tar unzip xz-utils zip && \
  rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/aqt && \
  /opt/aqt/bin/pip install --no-cache-dir "aqtinstall==${AQTINSTALL_VERSION}" && \
  /opt/aqt/bin/aqt install-qt -O /opt/qt linux desktop "${QT_VERSION}" linux_gcc_64 -m qtpositioning qtserialport && \
  rm -rf /opt/aqt

ADD --chmod=755 --checksum=sha256:c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage \
  /usr/local/bin/linuxdeploy
ADD --chmod=755 --checksum=sha256:15106be885c1c48a021198e7e1e9a48ce9d02a86dd0a1848f00bdbf3c1c92724 \
  https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/1-alpha-20250213-1/linuxdeploy-plugin-qt-x86_64.AppImage \
  /usr/local/bin/linuxdeploy-plugin-qt

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
  --default-toolchain "${RUST_TOOLCHAIN}" --component rustfmt,clippy

RUN git config --system --add safe.directory '*'

WORKDIR /w
