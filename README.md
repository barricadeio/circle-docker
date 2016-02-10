# circle-docker

A helper for building with Docker on CircleCI.

Once set up, this will cache builds, tag them with branch and build details,
and push them to a registry.

You end up with builds like `myapp:latest-master` for the latest rolling
build and `myapp:master-42` for a specific Circle CI build number.

Optionally, [circle-docker can be configured to send progress notifications via Slack](#slack-integration).

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
    sudo curl -L -o /usr/bin/circle-docker 'https://raw.githubusercontent.com/barricadeio/circle-docker/v0.2.0/circle-docker.sh'
    sudo chmod 0755 /usr/bin/circle-docker
  services:
    - docker
```

This will set up your build envrionment with the `circle-docker` command.

Also, `dependencies` should include a `cache_directories` section:

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
    - circle-docker env
    - circle-docker cached_build myapp
```

The `circle-docker env` command outputs some debug information about Docker (not required, just useful).

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

## Slack Integration

You can optionally configure Slack notifications for build progress via
webhooks.

To do so, set an environment variable called `SLACK_WEBHOOK` in your project
environment with the webhook URL. [You can read more about Slack webhooks here.](https://api.slack.com/incoming-webhooks)

By default, this will send notifications to your `#general` channel. This can
be overridden by setting a `SLACK_CHANNEL` environment variable.

When set up, you get notifications when a build has started, when it's begun
pushing, and when it has completed:

![Example of Slack notifications](http://i.imgur.com/U7sPELl.png)
