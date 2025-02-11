# MMS_Helper a quick and easy way to use the Open-Horizon MMS feature
#
# 1. Begin by installing the Open-Horizon Agent, and configuring your creds:
#   $ agent-install.sh
#   $ export HZN_ORG_ID=...
#   $ export HZN_EXCHANGE_USER_AUTH=...
#
# 2. Edit the Makefile variables below as described:
#   YOUR_SERVICE_NAME - the name of your dependent MMS consuming Service
#   YOUR_SERVICE_VERSION - the version of your dependent MMS consuming Service
#   MMS_HELPER_SHARED_VOLUME  - a Docker volume for these conainers to share.
#     Note: you need to mount this in your consuming Service, e.g., in your
#     Service defiinition's deployment string, use something like this:
#       "binds": ["$MMS_HELPER_SHARED_VOLUME:/CONTAINER_DIR:ro"]
#     Note also that if you use a host directory here instead of a volume name,
#     then you need to ensure the directory is writeable by the contaiiner
#     processes (which run under a different user ID).
#   YOUR_OBJECT_TYPE - the object type name for MMS_Helper to monitor
#   YOUR_DOCKERHUB_ID - your DockerHub account name for image "push" commands
#     Note: you need to `docker login` to this before pushing or publishing
#
# 3. Build, push and publish this "mms-helper" service:
#   $ make build
#   $ docker login -u ...
#   $ make push
#   $ make publish-service
#
# 4. Publish a pattern or business policy to deploy this Service. E.g.:
#   $ make publish-pattern
# 
# 5. Register your edge nodes using a pattern or node policy, e.g.:
#   $ make register-pattern
#
# 6. Start using the `hzn mms object publish` command to publish objects of
# the specified YOUR_OBJECT_TYPE. They will show up up in your /CONTAINER_DIR
# within your container, named using the object IDs you published them with,
# If you used the pattern above, and set the OPTIONAL variables, then:
#   $ make publish-object
# to send the example file object to your dependendency Service running on
# every node registered with the example pattern.

# Please edit these appropriately (as described above)
YOUR_SERVICE_NAME:=tensorflow-server
YOUR_SERVICE_VERSION:=1.0.3
MMS_HELPER_SHARED_VOLUME:=tensorflow_volume
YOUR_OBJECT_TYPE:=tensorflow-object
QUAY_REGISTRY:=quay.io/ibmtechgarage

# Optionally specify an example file to send as an MMS object. If you do so,
# a file named with the path in MODEL_FILE must be present.
MODEL_ID:=mnist.tar.gz
MODEL_FILE:=./mnist.tar.gz
MODEL_CONFIG_ID:=models.config
MODEL_CONFIG_FILE:=./models.config
MMS_HELPER_OBJECT_DEF=mms-model-deploy.json

# The "helper" utility is useful for things like this so I included it.
ARCH:=`./helper -a`

# Variables for MMS_Helper container/service/pattern (optionally edit these)
# Note that service and container may have differen names and versions.
MMS_HELPER_SERVICE_VERSION:=1.0.9
MMS_HELPER_SERVICE_NAME:=mms-helper
MMS_HELPER_CONTAINER:=$(QUAY_REGISTRY)/$(MMS_HELPER_SERVICE_NAME)_$(ARCH):$(MMS_HELPER_SERVICE_VERSION)
# For DockerHub, leave the variable below as it is (empty).
# For secure registries set it using:  -r "registry.wherever.com:myid:mypw"`
MMS_HELPER_CONTAINER_CREDS:=
MMS_HELPER_PATTERN_NAME:=mms-helper-pattern
MMS_HELPER_POLICY_NAME:=mms-helper-deploy-policy.json

update: build push publish-service publish-deployment-policy

build: Makefile Dockerfile mms_helper.py
	docker build -t $(MMS_HELPER_CONTAINER) .

dev:
	docker run -it -v `pwd`:/outside -v $(MMS_HELPER_SHARED_VOLUME):/shared_dir:rw $(MMS_HELPER_CONTAINER) bin/bash

push:
	docker push $(MMS_HELPER_CONTAINER)

publish-service: validate-creds
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(MMS_HELPER_SERVICE_NAME)" \
        SERVICE_VERSION="$(MMS_HELPER_SERVICE_VERSION)"\
        SERVICE_CONTAINER="$(MMS_HELPER_CONTAINER)" \
        YOUR_SERVICE_NAME="$(YOUR_SERVICE_NAME)" \
        YOUR_SERVICE_VERSION="$(YOUR_SERVICE_VERSION)"\
        YOUR_OBJECT_TYPE="$(YOUR_OBJECT_TYPE)"\
        MMS_HELPER_SHARED_VOLUME="$(MMS_HELPER_SHARED_VOLUME)"\
        hzn exchange service publish -O $(MMS_HELPER_CONTAINER_CREDS) -f service.json

publish-pattern:
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(MMS_HELPER_SERVICE_NAME)" \
        SERVICE_VERSION="$(MMS_HELPER_SERVICE_VERSION)"\
        PATTERN_NAME="$(MMS_HELPER_PATTERN_NAME)" \
	hzn exchange pattern publish -f pattern.json

publish-deployment-policy:
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(MMS_HELPER_SERVICE_NAME)" \
        SERVICE_VERSION="$(MMS_HELPER_SERVICE_VERSION)"\
        POLICY_NAME="$(MMS_HELPER_POLILCY_NAME)" \
	hzn exchange deployment addpolicy --json-file=$(MMS_HELPER_POLICY_NAME).json --no-constraints "$(MMS_HELPER_POLICY_NAME)"

register-policy:
	hzn register --policy "$(MMS_HELPER_POLICY_NAME)"

register-pattern:
	hzn register --pattern "$(MMS_HELPER_PATTERN_NAME)"

publish-model:
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(MMS_HELPER_SERVICE_NAME)" \
        SERVICE_VERSION="$(MMS_HELPER_SERVICE_VERSION)" \
        OBJECT_TYPE="$(YOUR_OBJECT_TYPE)" \
        FILE_ID="$(MODEL_ID)" \
	hzn mms object publish --object=$(MODEL_FILE) --def=$(MMS_HELPER_OBJECT_DEF)

publish-model-config:
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(MMS_HELPER_SERVICE_NAME)" \
        SERVICE_VERSION="$(MMS_HELPER_SERVICE_VERSION)" \
        OBJECT_TYPE="$(YOUR_OBJECT_TYPE)" \
        FILE_ID="$(MODEL_CONFIG_ID)" \
	hzn mms object publish --object=$(MODEL_CONFIG_FILE) --def=$(MMS_HELPER_OBJECT_DEF)

validate-creds:
	@if [ -z "${HZN_ORG_ID}" ]; \
          then { echo "***** ERROR: \"HZN_ORG_ID\" is not set!"; exit 1; }; \
          else echo "Using Exchange Org ID: \"${HZN_ORG_ID}\""; \
        fi
	@if [ -z "${HZN_EXCHANGE_USER_AUTH}" ]; \
          then { echo "***** ERROR: \"EXCHANGE_USER_AUTH\" is not set!"; exit 1; }; \
          else echo "Using Exchange user creds: \"${EXCHANGE_USER_AUTH}\""; \
        fi
	@sleep 1

clean:
	-hzn unregister -f
	-hzn exchange service remove -f "${HZN_ORG_ID}/$(MMS_HELPER_SERVICE_NAME)_$(MMS_HELPER_SERVICE_VERSION)_$(ARCH)"
	-docker rmi -f "$(MMS_HELPER_CONTAINER)"

.PHONY: build dev push publish-service publish-pattern publish-object publish-deployment-policy validate-creds clean
