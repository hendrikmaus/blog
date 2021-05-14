_default:
  @just --list

@deploy user host:
  zola build && rsync -e "ssh -o StrictHostKeyChecking=no" -avz --delete public/ {{user}}@{{host}}:/var/www/virtual/{{user}}/blog.hendrikmaus.dev

docker-build:
  docker build \
    --tag hendrikmaus/blog-builder:${BLOG_BUILDER_VERSION} \
    --build-arg ZOLA_VERSION=0.13.0 \
    --build-arg JUST_VERSION=0.9.2 \
    --build-arg BLOG_BUILDER_VERSION \
    .

docker-push:
  docker push hendrikmaus/blog-builder:${BLOG_BUILDER_VERSION}
