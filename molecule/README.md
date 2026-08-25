<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## What the suite can and cannot tell you

Excalidraw is a single-page application and nothing else: a compiled bundle of HTML, CSS and JavaScript handed to a web server, with no backend of its own. Drawings live in the browser, and collaboration — where it is enabled at all — goes to a separate server that [`ansible-role-excalidraw-room`](https://github.com/mother-of-all-self-hosting/ansible-role-excalidraw-room) deploys.

So the suite proves that the web server the role configured is serving Excalidraw's compiled bundle on the port the role was told to publish, that values only this role's templates could have produced reached the container and (for the self-built image) the process, and which version of the server is running. It does not execute any JavaScript, so a bundle that is served correctly but misbehaves in a browser would pass.

"It answered 200" carries no information in the self-build scenario: `SERVER_FALLBACK_PAGE` makes Static Web Server answer with the application shell for every path in existence, including the ones that do not exist. The content type of a hashed asset is what discriminates there, and both scenarios assert what a deliberately absent asset comes back as, so that the content-type check is known to be falsifiable.

Shared assertions live in [`verify_tasks.yml`](verify_tasks.yml); each scenario's own `verify.yml` adds what only applies to it.

## Scenarios

Currently these testing scenarios are available:

### `default`

Tests an installation of the pre-built image Excalidraw publishes on Docker Hub, which ends in nginx with its stock configuration. Being a plain file server, it answers 404 for paths it has no file for, and the scenario asserts that — it is both the negative control for its own probes and what would notice if Excalidraw changed the server its image is built on. The scenario also turns the Traefik labels on, asserts what `templates/labels.j2` rendered onto the container, and asserts that an untouched Excalidraw build still carries the `oss-collab.excalidraw.com` string that the role's collaboration-server rewrite anchors on.

### `default-selfbuild`

Tests the image this role builds itself, which is what it does by default: Excalidraw compiled from source and served by Static Web Server as an unprivileged user with a read-only root filesystem. The scenario reads the server's own startup announcement out of the journal and asserts its version, bound port, document root, fallback page and log level against what the role was configured to render; asserts that missing paths fall back to the application shell rather than to JavaScript; and asserts that the collaboration-server URL the role compiled into the bundle is the one the scenario configured, and that Excalidraw's own is gone.

The idempotence step is left out of this scenario on purpose. The role writes its own `Dockerfile` and `.dockerignore` over the ones Excalidraw ships and rewrites `VITE_APP_WS_SERVER_URL` in the checkout, so `ansible.builtin.git` finds local modifications to discard on every run and reports itself as changed.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
