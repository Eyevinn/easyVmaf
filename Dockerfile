FROM python:3.8-slim AS base

# setup dependencies versions

ARG	FFMPEG_version=7.0.1 \
ARG	VMAF_version=3.0.0 \
ARG	easyVmaf_hash=fbbf5dc8a9d3c2ccc7c16d00364c603b3f29e609

FROM base as build

# get and install building tools
RUN \
	export TZ='UTC' && \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
	apt-get update -yqq && \
	apt-get install --no-install-recommends\
		ninja-build \
		wget \
		doxygen \
		autoconf \
		automake \
		cmake \
		g++ \
		gcc \
		libdav1d-dev \
		pkg-config \
		make \
		nasm \	
		xxd \
		yasm -y && \
	apt-get autoremove -y && \
    apt-get clean -y && \
	pip3 install --user meson

# install libvmaf
WORKDIR     /tmp/vmaf
RUN \
	export PATH="${HOME}/.local/bin:${PATH}" && \
	echo $PATH &&\
	if [ "$VMAF_version" = "master" ] ; \
	 then wget https://github.com/Netflix/vmaf/archive/${VMAF_version}.tar.gz && \
	 tar -xzf  ${VMAF_version}.tar.gz ; \
	 else wget https://github.com/Netflix/vmaf/archive/v${VMAF_version}.tar.gz && \
	 tar -xzf  v${VMAF_version}.tar.gz ; \ 
	fi && \
	cd vmaf-${VMAF_version}/libvmaf/ && \
	meson build --buildtype release -Dbuilt_in_models=true && \
	ninja -vC build && \
	ninja -vC build test && \
	ninja -vC build install && \ 
	mkdir -p /usr/local/share/model  && \
	cp  -R ../model/* /usr/local/share/model && \
        rm -rf /tmp/vmaf

# install ffmpeg
WORKDIR     /tmp/ffmpeg
RUN \
	export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib64/" && \
	export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib64/pkgconfig/" && \
	wget https://www.ffmpeg.org/releases/ffmpeg-${FFMPEG_version}.tar.gz  && \
	tar -xzf ffmpeg-${FFMPEG_version}.tar.gz && \
	cd ffmpeg-${FFMPEG_version} && \
	./configure --enable-libvmaf --enable-version3 --enable-shared --enable-libdav1d && \
	make -j4 && \
	make install && \
	rm -rf /tmp/ffmpeg

# install  easyVmaf
WORKDIR  /app
RUN \
	wget https://github.com/gdavila/easyVmaf/archive/${easyVmaf_hash}.tar.gz && \
	tar -xzf  ${easyVmaf_hash}.tar.gz

FROM base AS release

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib:/usr/local/lib64"

RUN \
	export TZ='UTC' && \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
	apt-get update -yqq && \
	apt-get install -y --no-install-recommends \
		dav1d && \
	apt-get autoremove -y && \
    apt-get clean -y && \
	pip3 install --user ffmpeg-progress-yield

COPY --from=build /usr/local /usr/local/
COPY --from=build /app/easyVmaf-${easyVmaf_hash} /app/easyVmaf/

# app setup
WORKDIR  /app/easyVmaf
ENTRYPOINT [ "python3", "-u", "easyVmaf.py" ]
