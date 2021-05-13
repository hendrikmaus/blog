_default:
  @just --list

@deploy user host:
  zola build && rsync -avz --delete public/ {{user}}@{{host}}:/var/www/virtual/{{user}}/blog.hendrikmaus.dev
