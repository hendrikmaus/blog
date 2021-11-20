+++
title = "GitHub Actions: How to Implement Caching For Releases (Rust as Example)"
date = 2021-11-19T19:43:00+00:00
description = "As of November 2021, GitHub Actions' own caching mechanism does not support to share caches between releases, i.e. a release (git tag) of v1.1.0 cannot re-use the cache built for v1.0.0"

[taxonomies]
tags = ["Post", "CI"]

[extra]
author = "***REMOVED***"
+++

*tl;dr: Please find a working reference implementation on [GitHub](https://github.com/hendrikmaus/github-actions-release-cache-workaround-rust).*

> *If you are reading this at a later point in time, GitHub might have delivered this feature.*

## Context

As of today, which is November 19th 2021, GitHub Actions does support sharing caches between `git tags`, i.e. when building a release of `v1.1.0`, one cannot re-use the cache built when `v1.0.0` was released. That is because the native caching system is built for *branches*.[^docs]

> Aside: this is not entirely true. You *can* build and store a cache on a tag, but you can only re-use it, when building the *very same* tag again.

[^docs]: "(...) the cache action searches for key and restore-keys in the parent branch and upstream branches." [source](https://docs.github.com/en/actions/advanced-guides/caching-dependencies-to-speed-up-workflows#matching-a-cache-key)

## Workaround

Since I like to write Rust code, and it is no mystery that Rust compile times can be long, I built a **very rudimentary** workaround that leverages [GitHub Packages](https://github.com/features/packages)[^packages] to store a build cache.

Please mind that the following approach lacks all the more advanced caching features, but it should still be a good start:

- The cache is only built if the step is reached; i.e. nothing fails early
- The workflow does not check if the very same cache is already in the registry; it will build and upload it anyway
- You have to build and expand the cache by foot, e.g. this is not wrapped in a language specific function
- There is no cache key to include a checksum in
- There is no fallback cache key to pull if a more specific one isn't found
- Any cache built on a branch cannot be re-used by this approach; the first release runs on a cold cache

[^packages]: GitHub Packages supports various storage concepts and is free for open-source projects.

Now, how does it work? We'll leverage the Docker registry feature of GitHub Packages. The workflow will create a `Dockerfile` with a single layer, which is the cache content. The base image is `scratch`, so there is really nothing else in it. The image is pushed, so that subsequent releases can pull it.

> Aside: Why not [GitHub Actions Artifacts](https://docs.github.com/en/actions/advanced-guides/storing-workflow-data-as-artifacts)? They cannot be shared between workflows; they are intended to share data between *jobs* in a *single* workflow.

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
  CACHE_REGISTRY: ghcr.io
  CACHE_IMAGE: ${{ github.repository }}
  CACHE_TAG: release-cache

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

      - name: Log in to the Container registry
        uses: docker/login-action@v1
        with:
          registry: ${{ env.CACHE_REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Restore cache
        run: |
          if ! docker pull "${CACHE_REGISTRY}/${CACHE_IMAGE}:${CACHE_TAG}" &>/dev/null; then
            echo "No cache found"
            exit 0
          fi

          tempdir=$(mktemp -d)
          cd "${tempdir}"

          echo "creating cache container filesystem"
          # this container isn't actually started; we just gain access to its filesystem
          # it also does not contain 'bash", but we need to provide some argument, which is ignored
          docker create -ti --name cache_storage "${CACHE_REGISTRY}/${CACHE_IMAGE}:${CACHE_TAG}" bash
          docker cp cache_storage:cache.tgz .

          echo "expanding cache to disk"
          tar xpzf cache.tgz -P

          echo "cleaning up"
          docker rm cache_storage &>/dev/null
          cd -
          rm -rf "${tempdir}"

      - name: Compile
        uses: actions-rs/cargo@v1
        with:
          command: build
          args: --release

      # ... additional release steps

      - name: Save cache
        run: |
          tempdir=$(mktemp -d)
          cd "${tempdir}"

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
          docker build --tag "${CACHE_REGISTRY}/${CACHE_IMAGE}:${CACHE_TAG}" --file Dockerfile .
          docker push "${CACHE_REGISTRY}/${CACHE_IMAGE}:${CACHE_TAG}"

          echo "cleaning up"
          docker rmi "${CACHE_REGISTRY}/${CACHE_IMAGE}:${CACHE_TAG}"
          cd -
          rm -rf "${tempdir}"

```

As mentioned before, this particular example is focussed on Rust. To adapt it to your use-case, update the list of `paths` to `tar` up and swap out the Rust-specific steps for your own. That should give you a solid place to start.

## Results

In the [reference implementation](https://github.com/hendrikmaus/github-actions-release-cache-workaround-rust), I did two releases:

- Initial release [`1.0.0`](https://github.com/hendrikmaus/github-actions-release-cache-workaround-rust/actions/runs/1484389352) took `1m 28s` to build the release artifact.

- A subsequent release [`1.1.0`](https://github.com/hendrikmaus/github-actions-release-cache-workaround-rust/runs/4273117553), which did not include any code change to be fair, took `7.99s` to build the release artifact.

Once something changes in `Cargo.lock`, I reckon it will update the crates.io index, download the missing/updated crates and then only re-compile what needs to be.

## Conclusion

This topic is a known issue, and it can be tracked at [actions/cache#556](https://github.com/actions/cache/issues/556). I hope that GitHub will one day natively support release caches in the existing infrastructure.

However, this workaround can serve as a solid base to speed up release builds in the meantime.
