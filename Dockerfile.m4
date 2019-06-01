m4_changequote([[, ]])

##################################################
## "build-tini" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:18.04]], [[FROM docker.io/ubuntu:18.04]]) AS build-tini
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
RUN mkdir -p /tmp/tini/ && cd /tmp/tini/ \
	&& git clone "${TINI_REMOTE}" ./ \
	&& git checkout "${TINI_TREEISH}" \
	&& git submodule update --init --recursive
RUN cd /tmp/tini/ \
	&& export CFLAGS='-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37' \
	&& cmake . -DCMAKE_INSTALL_PREFIX=/usr \
	&& make -j"$(nproc)" \
	&& make install \
	&& file /usr/bin/tini && /usr/bin/tini --version \
	&& file /usr/bin/tini-static && /usr/bin/tini-static --version

##################################################
## "tini" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:18.04]], [[FROM docker.io/ubuntu:18.04]]) AS tini
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Copy Tini build
COPY --from=build-tini --chown=root:root /usr/bin/tini /usr/bin/tini
COPY --from=build-tini --chown=root:root /usr/bin/tini-static /usr/bin/tini-static

ENTRYPOINT ["/usr/bin/tini", "--"]
