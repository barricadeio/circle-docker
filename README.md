# circle-docker

A helper for building with Docker on CircleCI.

## Setup

Your CircleCI project environment should be configured with these environment
variables:

* `DOCKER_REGISTRY` - the URL to your registry
* `DOCKER_USER` - the username for your registry login
* `DOCKER_PASSWORD` - the password for your registry login
* `DOCKER_EMAIL` - the email address associated with your login

If you try to use `circle-docker` without these set, you'll receive a warning
informing you of what's missing.

Set up your `circle.yml` with `machine` dependencies like so:

```yml
machine:
  pre:
  - |
    sudo curl -L -o /usr/bin/docker 'https://s3-external-1.amazonaws.com/circle-downloads/docker-1.9.1-circleci'
    sudo chmod 0755 /usr/bin/docker
    sudo curl -L -o /usr/bin/circle-docker 'https://archive.barricade.io/binaries/circle-docker/circle-docker.sh'
    sudo chmod 0755 /usr/bin/circle-docker
  services:
    - docker
```

This will set up your build envrionment with the latest available Docker (1.9.1), and the `circle-docker` command.

Also, set `dependencies` should include a `cache_directories` section:

```yml
dependencies:
  cache_directories:
    - "~/docker"
```

## Usage

### Building

You'll need to stick an `override` in dependencies so that images can be
cached:

```yml
dependencies:
  override:
      - circle-docker cached_build myapp
```

### Pushing

To push, use deployment hooks, e.g.,:

```yml
deployment:
  production:
    branch: production
    commands:
      - circle-docker push myapp
  testing:
    branch: master
    commands:
      - circle-docker push myapp
```
