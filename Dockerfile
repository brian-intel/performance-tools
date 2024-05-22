#
# Copyright (C) 2024 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

FROM ubuntu:22.04
ENV HOME=/home/nobody
ENV no_proxy=localhost,127.0.0.1
ENV NO_PROXY=localhost,127.0.0.1

# don't ask anything
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update  && \
apt-get install -y --no-install-recommends \
 wget \
  git \
  iotop \
  sysstat \
  jq \
  curl \
  cmake \
  python3-pip \
  build-essential \
  docker.io \
  pciutils \
  python3 \
  python3-pip \
  python3-venv && \
rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY src/requirements.txt /requirements.txt
RUN pip install -r /requirements.txt
RUN pip install gunicorn[gthread]
WORKDIR /opt/venv
RUN find . -name "pip*" -exec rm -rf {} \; ;exit 0
RUN find . -name "*normalizer*" -exec rm -rf {} \; ;exit 0
RUN find . -name "activate*" -exec rm -rf {} \; ;exit 0
RUN find . -name "Activate*" -exec rm -rf {} \; ;exit 0
RUN find . -name "python-wheels" -exec rm -rf {} \; ;exit 0
RUN find . -name "easy_install*" -exec rm -rf {} \; ;exit 0
RUN find . -name "setuptools*" -exec rm -rf {} \; ;exit 0
RUN find . -name "__pycache__" -exec rm -rf {} \; ;exit 0

ENV HOME=/home/nobody
ENV no_proxy=localhost,127.0.0.1
ENV NO_PROXY=localhost,127.0.0.1

# don't ask anything
ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /tmp/work

RUN apt-get update && \
  apt-get install -y --no-install-recommends wget gnupg2 ca-certificates && \
  wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | gpg --dearmor --output /usr/share/keyrings/intel-graphics.gpg && \
  wget https://github.com/intel/xpumanager/releases/download/V1.2.24/xpumanager_1.2.24_20231120.070911.ddc18e8a.u22.04_amd64.deb && \
  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu jammy flex' | \
  tee /etc/apt/sources.list.d/intel.gpu.jammy.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
    dmidecode \
    python3 \
    libnl-genl-3-200 \
    libmfx-tools \
    intel-gsc \
    intel-level-zero-gpu \
    level-zero \
    intel-gpu-tools \
    libdrm2 && \
  apt-get remove -y wget gnupg2 ca-certificates && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/*

RUN ldconfig && dpkg -i --force-all *.deb

WORKDIR /

ENV PATH="/opt/venv/bin:$PATH"

RUN if [ -d "/opt/intel/pcm" ] ; then rm -R /opt/intel/pcm; fi

ENV PCM_DIRECTORY=/opt/intel
RUN echo "Installing PCM" \
    [ ! -d "$PCM_DIRECTORY" ] && mkdir -p "$PCM_DIRECTORY"
RUN cd $PCM_DIRECTORY && \
    git clone --recursive https://github.com/opcm/pcm.git && \
    ls ${PCM_DIRECTORY} && \
    cd $PCM_DIRECTORY/pcm  && \
    mkdir build && \
    cd build && \
    cmake .. && \
    cmake --build .

# Cleanup
RUN mkdir -p "/opt/intel/pcm-bin/bin" && mkdir -p "/opt/intel/pcm-bin/lib" && \
    cp -r "$PCM_DIRECTORY/pcm/build/bin" "/opt/intel/pcm-bin/" && \
    cp -r "$PCM_DIRECTORY/pcm/build/lib" "/opt/intel/pcm-bin/" && \
    rm -rf "$PCM_DIRECTORY/pcm"
  
COPY src/entrypoint.sh entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
