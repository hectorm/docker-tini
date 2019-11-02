m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:18.04]], [[FROM docker.io/ubuntu:18.04]]) AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		cmake \
		file \
		git

# Build Tini
ARG TINI_TREEISH=v0.18.0
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
