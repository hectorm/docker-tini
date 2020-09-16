m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& sed -i 's/^#\s*\(deb-src\s\)/\1/g' /etc/apt/sources.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		devscripts \
		file \
		git

# Build CMake with "_FILE_OFFSET_BITS=64"
# (as a workaround for: https://gitlab.kitware.com/cmake/cmake/-/issues/20568)
WORKDIR /tmp/
RUN DEBIAN_FRONTEND=noninteractive apt-get build-dep -y cmake
RUN apt-get source cmake && mv ./cmake-*/ ./cmake/
WORKDIR /tmp/cmake/
RUN DEB_BUILD_PROFILES='stage1' \
	DEB_BUILD_OPTIONS='parallel=auto nocheck' \
	DEB_CFLAGS_SET='-D _FILE_OFFSET_BITS=64' \
	DEB_CXXFLAGS_SET='-D _FILE_OFFSET_BITS=64' \
	debuild -b -uc -us
RUN dpkg -i /tmp/cmake_*.deb /tmp/cmake-data_*.deb

# Build Tini
ARG TINI_TREEISH=v0.19.0
ARG TINI_REMOTE=https://github.com/krallin/tini.git
RUN mkdir /tmp/tini/
WORKDIR /tmp/tini/
RUN git clone "${TINI_REMOTE:?}" ./
RUN git checkout "${TINI_TREEISH:?}"
RUN git submodule update --init --recursive
ENV CFLAGS='-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37'
RUN cmake ./ -DCMAKE_INSTALL_PREFIX=/usr
RUN make -j"$(nproc)"
RUN make install
RUN file /usr/bin/tini-static
RUN /usr/bin/tini-static --version

##################################################
## "tini" stage
##################################################

FROM scratch AS tini

# Copy Tini binary
COPY --from=build /usr/bin/tini-static /usr/bin/tini

ENTRYPOINT ["/usr/bin/tini", "--"]
