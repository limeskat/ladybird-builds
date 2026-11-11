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

################################################################################
FROM archlinux:base-devel@sha256:fa2d4ce3310ddd90a4208e5168be8ad367da5129af1245f38fd2d803bcbe3239 AS builder
ARG RUST_TOOLCHAIN

ENV RUSTUP_HOME=/opt/rustup \
  CARGO_HOME=/opt/cargo \
  PATH=/opt/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  CC=clang \
  CXX=clang++ \
  CCACHE_DIR=/w/cache/ccache \
  CCACHE_MAXSIZE=3G \
  LADYBIRD_CACHE_DIR=/w/cache/ladybird

# Rolling release: pacman-key is re-seeded first so an image older than the
# current keyring can still verify the packages of a full upgrade.
RUN pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman -Syu --noconfirm && \
  pacman -S --needed --noconfirm \
  autoconf autoconf-archive automake bison ca-certificates ccache clang cmake \
  curl file flex fontconfig freetype2 gettext git glslang gperf libdrm \
  libglvnd libpulse libtool libx11 libxcb libxkbcommon lld m4 mesa nasm ncurses \
  ninja openssl patch perl pkgconf python qt6-base qt6-multimedia \
  qt6-positioning qt6-svg qt6-tools qt6-wayland tar ttf-liberation unzip \
  wayland xcb-util-cursor xcb-util-image xcb-util-keysyms \
  xcb-util-renderutil xcb-util-wm xz zip && \
  rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

# makepkg refuses to run as root, so the package is built as an unprivileged user.
RUN useradd --create-home --shell /bin/bash builder

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
  --default-toolchain "${RUST_TOOLCHAIN}" --component rustfmt,clippy

RUN git config --system --add safe.directory '*'

WORKDIR /w
