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

################################################################################
FROM debian:sid-slim@sha256:07a3205e8583fdff12d2b05bd030f50437e9fd340ee616df0c05dc77af75767b AS builder
ARG RUST_TOOLCHAIN
ARG LLVM_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
  RUSTUP_HOME=/opt/rustup \
  CARGO_HOME=/opt/cargo \
  PATH=/opt/cargo/bin:$PATH \
  CC=clang-${LLVM_VERSION} \
  CXX=clang++-${LLVM_VERSION} \
  CCACHE_DIR=/w/cache/ccache \
  CCACHE_MAXSIZE=3G \
  LADYBIRD_CACHE_DIR=/w/cache/ladybird

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  autoconf autoconf-archive automake build-essential ca-certificates ccache \
  clang-${LLVM_VERSION} cmake curl dpkg-dev file fonts-liberation2 git \
  glslang-tools libcurl4-openssl-dev libdrm-dev libegl1-mesa-dev \
  libgl1-mesa-dev libncurses-dev libpulse-dev libssl-dev libtool libxcb-icccm4-dev \
  lld-${LLVM_VERSION} nasm ninja-build pkg-config python3 python3-venv \
  qt6-base-private-dev qt6-positioning-dev qt6-tools-dev-tools qt6-wayland \
  tar unzip xz-utils zip && \
  rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal \
  --default-toolchain "${RUST_TOOLCHAIN}" --component rustfmt,clippy

RUN git config --system --add safe.directory '*'

WORKDIR /w
