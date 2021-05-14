FROM debian

ARG ZOLA_VERSION
ARG JUST_VERSION
ARG BLOG_BUILDER_VERSION

LABEL dev.hendrikmaus.version=${BLOG_BUILDER_VERSION}
LABEL dev.hendrikmaus.maintainer="***REMOVED***"
LABEL dev.hendrikmaus.source=https://github.com/hendrikmaus/blog
LABEL dev.hendrikmaus.tools.zola.source=https://github.com/getzola/zola
LABEL dev.hendrikmaus.tools.zola.version=${ZOLA_VERSION}
LABEL dev.hendrikmaus.tools.just.source=https://github.com/casey/just
LABEL dev.hendrikmaus.tools.just.version=${JUST_VERSION}

RUN apt-get update \
 && apt-get install -y wget rsync openssh-client \
 && wget -q -O - "https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/zola-v${ZOLA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
  | tar xzf - -C /usr/local/bin \
 && wget -q -O - "https://github.com/casey/just/releases/download/v${JUST_VERSION}/just-v${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
  | tar xzf - -C /usr/local/bin

ENTRYPOINT ["/usr/local/bin/just"]

