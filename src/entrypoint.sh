#!/usr/bin/env bash
#
# Copyright (C) 2024 Intel Corporation.
#
# SPDX-License-Identifier: Apache-2.0
#

# Platform metrics
echo "Starting platform data collection"

echo "Starting sar collection"
touch /tmp/results/cpu_usage.log
chown 1000:1000 /tmp/results/cpu_usage.log
sar 1 >& /tmp/results/cpu_usage.log &

echo "Starting free collection"
touch /tmp/results/memory_usage.log
chown 1000:1000 /tmp/results/memory_usage.log
free -s 1 >& /tmp/results/memory_usage.log &

echo "Starting iotop collection"
touch /tmp/results/disk_bandwidth.log
chown 1000:1000 /tmp/results/disk_bandwidth.log
iotop -o -P -b >& /tmp/results/disk_bandwidth.log &

is_xeon=`lscpu | grep -i xeon | wc -l`

if [ "$is_xeon"  == "1"  ]
  then
    echo "Starting pcm-memory collection"
    touch /tmp/results/pcm-memory.csv
    chown 1000:1000 /tmp/results/pcm-memory.csv
    /opt/intel/pcm-bin/bin/pcm-memory 1 -silent -nc -csv=/tmp/results/pcm-memory.csv &

    echo "Starting pcm-power collection"
    touch /tmp/results/pcm-power.log
    chown 1000:1000 /tmp/results/pcm-power.log
    /opt/intel/pcm-bin/bin/pcm-power >& /tmp/results/pcm-power.log &
  fi

echo "Starting general pcm collection"
touch /tmp/results/pcm.csv
chown 1000:1000 /tmp/results/pcm.csv
/opt/intel/pcm-bin/bin/pcm 1 -silent -nc -nsys -csv=/tmp/results/pcm.csv &

# Intel Top
# shellcheck disable=SC2086 # Intended work splitting
gpudevices=$(intel_gpu_top -L  | grep card | awk '{print $1,$5;}' | sed ":a;N;s/\n/@/g")
echo "gpudevices found $gpudevices"

if [ -z "$gpudevices" ]
then
    echo "No valid GPU gpudevices found"
	exit 1
fi

IFS='@'
for device in $gpudevices
do
    # shellcheck disable=SC2086 # Intended work splitting
    dev=$(echo $device | awk '{print $1}')
    echo "$dev"
    # shellcheck disable=SC2086 # Intended work splitting
    deviceId=$(echo $device | awk '{print $2}' | sed -E 's/.*?device=//' | cut -f1 -d",")
    echo "$deviceId"
    # shellcheck disable=SC2086 # Intended work splitting
    deviceNum=$(echo $dev | sed -E 's/.*?card//')
    echo "device number: $deviceNum"
    touch /tmp/results/igt$deviceNum-$deviceId.csv
    chown 1000:1000 /tmp/results/igt$deviceNum-$deviceId.csv
    # shellcheck disable=SC2086 # Intended work splitting
    intel_gpu_top -d pci:card=$deviceNum -o /tmp/results/igt$deviceNum-$deviceId.csv &
    echo "Starting igt capture for $device in igt$deviceNum-$deviceId.csv"
done

# XPU Metrics
export PYTHONUNBUFFERED=1
socket_folder=${XPUM_SOCKET_FOLDER:-/tmp}
rest_host=${XPUM_REST_HOST:-0.0.0.0}
rest_port=${XPUM_REST_PORT:-29999}
rest_no_tls=${XPUM_REST_NO_TLS:-0}
/usr/bin/xpumd -s ${socket_folder} &
until [ -e ${socket_folder}/xpum_p.sock ]; do sleep 0.1; done

if [ "${rest_no_tls}" != "1" ]
then
  rest_tls_param="--certfile conf/cert.pem --keyfile conf/key.pem"
fi

echo "Starting XPU Manager service"
cd /usr/lib/xpum/rest && exec gunicorn ${rest_tls_param} --bind ${rest_host}:${rest_port} --worker-class gthread --threads 10 --worker-connections 1000 -w 1 'xpum_rest_main:main()' &

sleep 5
echo "Start collecting XPU data"

# shellcheck disable=SC2086 # Intended work splitting
xpudevices=$(xpumcli discovery -j  | grep '"device_id":' | sed ":a;N;s/\n/@/g")
echo "xpudevices found $xpudevices"

if [ -z "$xpudevices" ]
then
    echo "No valid GPU xpudevices found"
	exit 1
fi

IFS='@'
for device in $xpudevices
do
    # shellcheck disable=SC2086 # Intended work splitting
    deviceId=$(echo $device | awk '{print $2}' | cut -f1 -d",")
    echo "$deviceId"
    xpumcli dump --rawdata --start -d $deviceId -m 0,5,22,24,25 -j
done

while true
do
	echo "Capturing system metrics"
	sleep 15
done