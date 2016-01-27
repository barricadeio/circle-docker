#!/usr/bin/env bash

set -o errexit

DOCKER_STEP=$1
DOCKER_IMAGE=$2

do_env(){
  # Docker environment
  docker version
  docker info
}

do_error(){
  # Print an error message
  echo "$1"
  exit 1
}

do_check(){
  # Check whether a particular variable has been set
  # (this is why we don't set -o nounset)
  if [ -z ${!1} ] ; then
    do_error "$1 must be set."
  fi
}

do_cached_build(){
  # Use Circle's cache to improve build times
  do_check DOCKER_REGISTRY
  do_check DOCKER_IMAGE
  do_check CIRCLE_BRANCH
  do_check CIRCLE_BUILD_NUM
  echo "Restoring image cache..."

  if [ -e ~/docker/${DOCKER_IMAGE}.tar ]; then
    docker load -i ~/docker/${DOCKER_IMAGE}.tar
  fi

  do_build

  echo "Caching image..."
  mkdir -p ~/docker
  docker save $DOCKER_REGISTRY/$DOCKER_IMAGE:$CIRCLE_BRANCH-$CIRCLE_BUILD_NUM > ~/docker/${DOCKER_IMAGE}.tar
}

do_build(){
  # Build Docker image with Docker tag as CircleCI build number
  do_check DOCKER_REGISTRY
  do_check DOCKER_IMAGE
  do_check CIRCLE_BRANCH
  do_check CIRCLE_BUILD_NUM
  echo "Building..."

  docker build -t $DOCKER_REGISTRY/$DOCKER_IMAGE:$CIRCLE_BRANCH-$CIRCLE_BUILD_NUM .
}

do_push(){
  # Tag and push an image to the registry for this build, and create a latest tag
  do_check DOCKER_REGISTRY
  do_check DOCKER_IMAGE
  do_check CIRCLE_BRANCH
  do_check CIRCLE_BUILD_NUM
  echo "Pushing and tagging..."

  # Push to Docker registry
  docker push $DOCKER_REGISTRY/$DOCKER_IMAGE:$CIRCLE_BRANCH-$CIRCLE_BUILD_NUM

  # Tag latest of each branch
  docker tag $DOCKER_REGISTRY/$DOCKER_IMAGE:$CIRCLE_BRANCH-$CIRCLE_BUILD_NUM $DOCKER_REGISTRY/$DOCKER_IMAGE:latest-$CIRCLE_BRANCH

  # Push the latest image of each branch tp barricade's docker registry
  docker push $DOCKER_REGISTRY/$DOCKER_IMAGE:latest-$CIRCLE_BRANCH
}

do_login(){
  do_check DOCKER_REGISTRY
  do_check DOCKER_USER
  do_check DOCKER_PASSWORD
  do_check DOCKER_EMAIL

  docker login -u $DOCKER_USER -p $DOCKER_PASSWORD -e $DOCKER_EMAIL $DOCKER_REGISTRY
}

do_config(){
  if [ ! -e ~/.docker/config.json ] ; then
    do_login
  fi
}

do_help(){
  cat <<- EndHelp
circle-docker - helper for pushing Docker images from CircleCI

Commands:

build <image name>           Build an image.
cached_build <image name>    Build an image using the Circle cache directory.
push  <image name>           Push a build to the registry.

This tool expects the following enviroment variables (in addition to Circle's built in ones):
- DOCKER_USER
- DOCKER_PASSWORD
- DOCKER_EMAIL
- DOCKER_REGISTRY
EndHelp
}

# Run
case ${DOCKER_STEP} in
  build)
    do_config
    do_build
    ;;
  cached_build)
    do_config
    do_cached_build
    ;;
  push)
    do_config
    do_push
    ;;
  env)
    do_env
    ;;
  *)
  do_help
  exit 1
    ;;
esac
