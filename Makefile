# Copyright © 2024 Intel Corporation. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

.PHONY: build-benchmark-docker docs docs-builder-image build-docs serve-docs clean

MKDOCS_IMAGE ?= asc-mkdocs

build-benchmark-docker:
	cd docker && $(MAKE) build-all

clean:
	docker rm -f $(docker ps -aq)