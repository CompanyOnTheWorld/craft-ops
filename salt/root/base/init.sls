# -*- mode: yaml -*-
# vim: set ft=yaml ts=2 sw=2 et sts=2 :

include:
  - stackstrap.env
  - stackstrap.supervisor
  - stackstrap.nginx
  - stackstrap.php5.fpm
  - stackstrap.mysql.server
  - stackstrap.mysql.client

nodejs.ppa:
  pkgrepo.managed:
    - humanname: NodeSource Node.js Repository
    - name: deb https://deb.nodesource.com/node_0.12 {{ grains['oscodename'] }} main
    - dist: {{ grains['oscodename'] }}
    - file: /etc/apt/sources.list.d/nodesource.list
    - keyid: "68576280"
    - key_url: https://deb.nodesource.com/gpgkey/nodesource.gpg.key
    - keyserver: keyserver.ubuntu.com
    - require_in:
      pkg: nodejs

nodejs:
  pkg.installed:
    - name: nodejs

node_global_bower:
  cmd:
    - run
    - name: npm install -g bower
    - unless: npm -g ls bower | grep bower
    - require:
      - pkg: nodejs

node_global_harp:
  cmd:
    - run
    - name: npm install -g harp
    - unless: npm -g ls harp | grep harp
    - require:
      - pkg: nodejs

remove-nginx-default-conf:
  file:
    - absent
    - names:
      - /etc/nginx/sites-enabled/default
      - /etc/nginx/sites-available/default
    - require:
      - pkg: nginx
    - watch_in:
      - service: nginx

install_composer:
  cmd.run:
    - name: curl -sS https://getcomposer.org/installer | php
    - cwd: /tmp
    - unless: test -e /usr/local/bin/composer
    - require:
      - pkg: php5-fpm

move_composer:
  cmd.run:
    - name: mv composer.phar /usr/local/bin/composer
    - cwd: /tmp
    - require:
      - cmd: install_composer
