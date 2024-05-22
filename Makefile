# Copyright © 2024 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

.PHONY: build run down build-benchmark-docker clean

build:
	docker build --build-arg HTTPS_PROXY=${HTTPS_PROXY} --build-arg HTTP_PROXY=${HTTP_PROXY} -t performance-tools:dev -f Dockerfile .

run:
	log_dir=./results docker compose -f src/docker-compose.yaml up

down:
	log_dir=./results docker compose -f src/docker-compose.yaml down

build-benchmark-docker:
	cd docker && $(MAKE) build-all

clean:
	docker rm -f $(docker ps -aq)