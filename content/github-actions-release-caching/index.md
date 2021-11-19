+++
title = "GitHub Actions: How to Implement Caching For Releases"
date = 2021-11-19T19:43:00+00:00
description = "As of November 2021, GitHub Actions' own caching mechanism does not support to share caches between releases, i.e. a release (git tag) of v1.1.0 cannot re-use the cache built for v1.0.0"

[taxonomies]
tags = ["Post", "CI"]

[extra]
author = "Hendrik Maus"
+++

> *If you are reading this at a later point in time, GitHub might have delivered this feature.*

## Context

As of today, which is November 19th 2021, GitHub Actions does support sharing caches between `git tags`, i.e. when building a release of `v1.1.0`, one cannot re-use the cache built when `v1.0.0` was released. That is because the native caching system is built for *branches*.

> Aside: this is not entirely true. You *can* build and store a cache on a tag, but you can only re-use it, when building the *very same* tag again.

## Workaround

Since I like to write Rust code, and it is no mystery that Rust compile times can be long, I built a **very rudimentary** workaround that leverages GitHub Packages to store a build cache.

Please mind that the following approach lacks all the more advanced caching features, but it should still be a good start:

- The cache is only built if the step is reached
- The workflow does not check if the very same cache is already in the registry; it will build and upload it anyway
- You have to build and expand the ache by foot, e.g. this is not wrapped in a language specific action
- There is no cache key to include a checksum in
- There is no fallback cache key to pull if a more specific one isn't found

Now, how does it work? We'll leverage the Docker registry feature of GitHub Packages. The workflow will create a `Dockerfile` with a single layer, which is the cache content. The base image is `scratch`, so there is really nothing else in it. The image is pushed, so that subsequent releases can pull it.

> Why not GitHub "Artifacts"? They cannot be shared between workflows.

In order to restore the cache, the workflow will first check if it can pull the cache image. If it can, a neat trick is used to get the content out of it: One can expand the filesystem of a container image without actually *running* the image. In this case, there wouldn't be anything to run inside it really. Once the filesystem was overlayed, the content can be copied out.

Let's see it:

## The Workflow Definition

```yaml
---
name: Release

on:
  release:
    types:
      - published

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}-release-cache

defaults:
  run:
    shell: bash

jobs:
  release:
    name: Release
    runs-on: ubuntu-20.04
    steps:
      - uses: actions/checkout@v2

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true

      - name: Log in to the Container registry
        uses: docker/login-action@v1
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Restore cache
        run: |
          if ! docker pull "${REGISTRY}/${IMAGE_NAME}:latest" &>/dev/null; then
            echo "No cache found"
            exit 0
          fi

          cd $(mktemp -d)

          echo "creating cache container filesystem"
          # this container isn't actually started; we just gain access to its filesystem
          docker create -ti --name cache "${REGISTRY}/${IMAGE_NAME}:latest" bash
          docker cp cache:cache.tgz .

          echo "expanding cache to disk"
          tar xpzf cache.tgz -P

          echo "cleaning up"
          docker rm cache &>/dev/null
          rm cache.tgz

      - name: Compile
        uses: actions-rs/cargo@v1
        with:
          command: build
          args: --release --bin release-caching-test

      - name: Save cache
        run: |
          cd $(mktemp -d)

          paths=()
          paths+=( "$GITHUB_WORKSPACE/target" )
          paths+=( "/usr/share/rust/.cargo/registry/index" )
          paths+=( "/usr/share/rust/.cargo/registry/cache" )
          paths+=( "/usr/share/rust/.cargo/git" )

          echo "building cache tarball"
          tar --ignore-failed-read -cpzf cache.tgz "${paths[@]}" -P

          cat <<-EOF > Dockerfile
          FROM scratch
          LABEL org.opencontainers.image.description="Release cache of ${GITHUB_REPOSITORY}"
          COPY cache.tgz .
          EOF

          echo "building cache container image"
          docker build --tag "${REGISTRY}/${IMAGE_NAME}:latest" --file Dockerfile .
          docker push "${REGISTRY}/${IMAGE_NAME}:latest"
          rm Dockerfile
```

As mentioned before, this particular example is focussed on Rust. To adapt it to your use-case, update the list of `paths` to `tar` up and swap out the Rust-specific steps for your own. That should give you a solid place to start.
