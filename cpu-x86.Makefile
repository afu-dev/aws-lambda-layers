# Load .env file if it exists
-include .env
export # export all variables defined in .env
export CPU = x86
export CPU_PREFIX =


# - Build all layers
# - Publish all Docker images to Docker Hub
# - Publish all layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
everything: clean upload-layers upload-to-docker-hub


base-devel:
	cd base-devel && $(MAKE) build-x86


# Build Docker images *locally*
docker-images:
	PHP_VERSION=80 docker buildx bake --load
	PHP_VERSION=81 docker buildx bake --load
	PHP_VERSION=82 docker buildx bake --load


# Build Lambda layers (zip files) *locally*
layers: docker-images layer-php-80 layer-php-81 layer-php-82 layer-php-80-fpm layer-php-81-fpm layer-php-82-fpm
	# Handle this layer specifically
	./utils/docker-zip-dir.sh bref/php-80-console-zip console
# This rule matches with a wildcard, for example `layer-php-80`.
# The `$*` variable will contained the matched part, in this case `php-80`.
layer-%:
	./utils/docker-zip-dir.sh bref/$* $*


# Upload the layers to AWS Lambda
upload-layers: layers
	# Upload the function layers to AWS
	LAYER_NAME=php-80 $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-81 $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-82 $(MAKE) -C ./utils/lambda-publish publish-parallel

	# Upload the FPM layers to AWS
	LAYER_NAME=php-80-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-81-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-82-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel

	# Upload the console layer to AWS
	LAYER_NAME=console $(MAKE) -C ./utils/lambda-publish publish-parallel


# Build and publish Docker images to Docker Hub.
upload-to-docker-hub: docker-images
	# While in beta we tag and push the `:2` version, later we'll push `:latest` as well
	for image in \
	  "bref/php-80" "bref/php-80-fpm" "bref/php-80-console" "bref/build-php-80" "bref/php-80-fpm-dev" \
	  "bref/php-81" "bref/php-81-fpm" "bref/php-81-console" "bref/build-php-81" "bref/php-81-fpm-dev" \
	  "bref/php-82" "bref/php-82-fpm" "bref/php-82-console" "bref/build-php-82" "bref/php-82-fpm-dev"; \
	do \
		docker tag $$image $$image:2 ; \
		docker push $$image:2 ; \
	done
	# TODO: when v2 becomes "latest", we should also push "latest" tags
	# We could actually use `docker push --all-tags` at the end probably?


test:
	cd tests && $(MAKE) test


clean:
	# Remove zip files
	rm -f output/*.zip
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/fpm-internal-src
	docker image rm --force bref/build-php-80
	docker image rm --force bref/build-php-81
	docker image rm --force bref/build-php-82
	docker image rm --force bref/php-80
	docker image rm --force bref/php-81
	docker image rm --force bref/php-82
	docker image rm --force bref/php-80-zip
	docker image rm --force bref/php-81-zip
	docker image rm --force bref/php-82-zip
	docker image rm --force bref/php-80-fpm
	docker image rm --force bref/php-81-fpm
	docker image rm --force bref/php-82-fpm
	docker image rm --force bref/php-80-fpm-zip
	docker image rm --force bref/php-81-fpm-zip
	docker image rm --force bref/php-82-fpm-zip
	docker image rm --force bref/php-80-fpm-dev
	docker image rm --force bref/php-81-fpm-dev
	docker image rm --force bref/php-82-fpm-dev
	docker image rm --force bref/php-80-console
	docker image rm --force bref/php-81-console
	docker image rm --force bref/php-82-console
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune

.PHONY: base-devel
