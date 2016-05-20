#!/usr/bin/env bash

set -o errexit

DOCKER_STEP=$1
DOCKER_IMAGE=$2

do_env(){
  # Docker environment
  docker version
  docker info
}

do_slack(){
  do_check SLACK_WEBHOOK

  local BOTNAME=circle-docker
  local CHANNEL=${SLACK_CHANNEL:-"#general"}
  local URL=${SLACK_WEBHOOK}
  local MESSAGE=$1

  curl --connect-timeout 3 --max-time 5 -X POST --data-urlencode "payload={\"channel\": \"${CHANNEL}\", \"username\": \"${BOTNAME}\", \"text\": \"${MESSAGE}\"}" ${URL}
}

do_debug(){
  echo "[$(date +"%T")] $1"
}

do_info(){
  do_debug "$1"
  if [ ! -z "${SLACK_WEBHOOK}" ] ; then
    do_slack "$1"
  fi
}

do_error(){
  # Print an error message
  do_debug "$1"
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

  if [ -e ~/docker/${DOCKER_IMAGE}.tar ]; then
    do_debug "Restoring image cache for ${DOCKER_IMAGE}"
    docker load -i ~/docker/${DOCKER_IMAGE}.tar
  else
    do_debug "No cached image found for ${DOCKER_IMAGE}, continuing without it"
  fi

  do_build

  do_debug "Caching image for ${DOCKER_IMAGE}"
  mkdir -p ~/docker
  docker save ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM} > ~/docker/${DOCKER_IMAGE}.tar
}

do_build(){
  # Build Docker image with Docker tag as CircleCI build number
  do_check DOCKER_REGISTRY
  do_check DOCKER_IMAGE
  do_check CIRCLE_BRANCH
  do_check CIRCLE_BUILD_NUM
  do_info "Building ${DOCKER_IMAGE}"

  docker build -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM} ${DOCKER_BUILD_OPTS} .
}

do_push(){
  # Tag and push an image to the registry for this build, and create a latest tag
  do_check DOCKER_REGISTRY
  do_check DOCKER_IMAGE
  do_check CIRCLE_BRANCH
  do_check CIRCLE_BUILD_NUM
  do_debug "Pushing and tagging ${DOCKER_IMAGE}"

  # Push to Docker registry
  local NUMBERED_BUILD=${DOCKER_IMAGE}:${CIRCLE_BRANCH}-${CIRCLE_BUILD_NUM}
  do_info "Pushing ${NUMBERED_BUILD}"
  docker push ${DOCKER_REGISTRY}/${NUMBERED_BUILD}

  # Tag latest of each branch
  local LATEST_BUILD=${DOCKER_IMAGE}:latest-${CIRCLE_BRANCH}
  do_debug "Tagging ${NUMBERED_BUILD} as ${LATEST_BUILD}"
  docker tag ${DOCKER_REGISTRY}/${NUMBERED_BUILD} ${DOCKER_REGISTRY}/${LATEST_BUILD}

  # Push a 'latest-<branch>' tag to the registry
  do_info "Pushing ${LATEST_BUILD}"
  docker push ${DOCKER_REGISTRY}/${LATEST_BUILD}

  do_info "${NUMBERED_BUILD} has been pushed to the registry and tagged as ${LATEST_BUILD}"
}

do_login(){
  do_check DOCKER_REGISTRY
  do_check DOCKER_USER
  do_check DOCKER_PASSWORD
  do_check DOCKER_EMAIL

  docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} -e ${DOCKER_EMAIL} ${DOCKER_REGISTRY}
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

The following optional environment variables are supported:
- DOCKER_BUILD_OPTS   additional options to the docker build command
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
