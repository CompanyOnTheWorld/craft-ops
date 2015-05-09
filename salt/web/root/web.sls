#
# Salt States for Craft
#

include:
  - stackstrap.nginx
  - stackstrap.php5.fpm
  - stackstrap.mysql.server
  - stackstrap.mysql.client
  - stackstrap.env
  - stackstrap.nvmnode

php5-mcrypt:
  pkg.installed

php-mcrypt-enable:
  cmd.run:
    - name: php5enmod mcrypt
    - require:
      - pkg: php5-mcrypt

php5-restart:
  cmd.run:
    - name: service php5-fpm restart
    - require:
      - cmd: php-mcrypt-enable

install_composer:
  cmd:
    - run
    - name: curl -sS https://getcomposer.org/installer | php -- --install-dir=/opt
    - unless: test -e /opt/composer.phar
    - require:
      - pkg: php5-fpm

/usr/local/bin/composer:
  file.symlink:
    - target: /opt/composer.phar

{% from "stackstrap/utils/users.sls" import skeleton -%}
{% from "stackstrap/env/macros.sls" import stackstrap_env -%}
{% from "stackstrap/nginx/macros.sls" import nginxsite %}
{% from "stackstrap/php5/macros.sls" import php5_fpm_instance %}
{% from "stackstrap/mysql/macros.sls" import mysql_user_db %}
{% from "stackstrap/app/macros.sls" import stackstrap_app %}
{% from "stackstrap/nvmnode/macros.sls" import nvmnode %}

{% set project = pillar -%}
{% set short_name = project['short_name'] %}

{% set stages = project['web']['stages'] %}

{% set aws_access_key = project['aws_access_key'] -%}
{% set aws_secret_key = project['aws_secret_key'] -%}

{% for stage in stages %}

{% set server_name = stages[stage]['server_name'] -%}
{% set app_user = stages[stage]['user'] -%}
{% set app_group = stages[stage]['group'] -%}

{% set home = '/home/' + app_user -%}
{% set app_path = home + '/apps/' + short_name -%}
{% set app_repo = project['git']['repo'] -%}
{% set port = stages[stage]['port'] -%}
{% set uid = stages[stage]['uid'] -%}
{% set gid = stages[stage]['gid'] -%}

{% set mysql_user = stages[stage]['mysql_user'] -%}
{% set mysql_pass = stages[stage]['mysql_pass'] -%}
{% set mysql_db = stages[stage]['mysql_db'] -%}

{% set uploads_path = app_path + "/shared/assets" -%}
{% set craft_path = app_path + "/shared/vendor/Craft-Release-master" -%}

{% set web_server_name = project['web']['server_name'] if (stage == "production") else stage+'.'+project['web']['server_name'] -%}
{% set server_name = server_name + " " + web_server_name %}

{{ skeleton(app_user, uid, gid, remove_groups=False) }}

{{ stackstrap_env(short_name, app_user, app_group) }}

{{ stackstrap_app(short_name, app_user, app_group) }}

{{ nvmnode(short_name, app_user, app_group,
           ignore_package_json=True,
           node_globals=['bower', 'grunt', 'node-sass', 'harp']) 
}}

{{ app_user }}_install_harp:
  cmd.run:
    - name: /bin/bash -c "source ~/.nvm/nvm.sh; npm install -g harp"
    - user: {{ app_user }}
    - unless: /bin/bash -c "source ~/.nvm/nvm.sh; npm -g ls harp | grep harp"
    - check_cmd:
      - /bin/true
    - require:
      - cmd: {{ app_user }}_install_node

{{ php5_fpm_instance(short_name+"_"+stage, port, app_user, app_group,
                     envs={
                      'APP_PATH': app_path,
                      'UPLOADS_PATH': uploads_path,
                      'CRAFT_ENVIRONMENT': stage,
                      'CRAFT_PATH': craft_path,
			                'MYSQL_USER': mysql_user,
			                'MYSQL_PASS': mysql_pass,
			                'MYSQL_DB': mysql_db,
                     })
}}

{{ mysql_user_db(mysql_user, mysql_pass, mysql_db) }}

{{ nginxsite(short_name, app_user, app_group,
             server_name=server_name,
             template="salt://files/craft-cms.conf",
             create_root=False,
             root="current/public",
             cors="*",
             defaults={
                'port': port
             })
}}

{{ app_user }}_authorized_keys:
  file.managed:
    - name: {{ home }}/.ssh/authorized_keys
    - source: salt://files/authorized_keys
    - makedirs: True
    - user: {{ app_user }}

{{ app_user }}_ssh_config:
  file.managed:
    - name: {{ home }}/.ssh/config
    - source: salt://files/ssh_config
    - template: jinja
    - makedirs: True
    - user: {{ app_user }}

{{ app_user }}_private_key:
  file.managed:
    - name: {{ home }}/.ssh/web.pem
    - source: salt://files/web.pem
    - makedirs: True
    - user: {{ app_user }}
    - mode: 600

{{ app_user }}_public_key:
  file.managed:
    - name: {{ home }}/.ssh/web.pub
    - source: salt://files/web.pub
    - makedirs: True
    - user: {{ app_user }}

{{ app_user }}_ssh_known_hosts:
  ssh_known_hosts:
    - name: bitbucket.org
    - present
    - user: {{ app_user }}

{{ app_user }}_app_repo:
  git.latest:
    - name: {{ app_repo }}
    - identity: {{ home }}/.ssh/web.pem
    - user: {{ app_user }}
    - rev: master
    - target: {{ app_path }}/source

{{ app_user }}_download_craft:
  archive.extracted:
    - name: {{ app_path }}/shared/vendor
    - source: https://github.com/pixelandtonic/Craft-Release/archive/master.tar.gz 
    - source_hash: md5=0cf267bac9a021a4adcbf983dfd0f8ef
    - archive_format: tar
    - user: {{ app_user }}
    - group: {{ app_group }}
    - if_missing: {{ app_path }}/shared/vendor/Craft-Release-master

{{ app_path }}/shared/vendor/Craft-Release-master:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - makedirs: True
    - recurse:
      - user
      - group

{{ app_path }}/shared/storage:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - makedirs: True

{{ app_path }}/shared/static:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - makedirs: True

{{ app_user }}_redacted_font:
  archive.extracted:
    - name: {{ app_path }}/shared/vendor
    - source: https://github.com/christiannaths/Redacted-Font/archive/old-sources.zip
    - source_hash: md5=9ff6e2ca3a69586a97235c292003ab78
    - archive_format: zip
    - if_missing: {{ app_path }}/shared/vendor/Redacted-Font-old-sources
    - user: {{ app_user }}
    - group: {{ app_group }}

{{ app_user }}_bowerrc:
  file.managed:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - source: salt://files/.bowerrc
    - name: {{ home }}/.bowerrc
    - template: jinja
    - require:
      - user: {{ app_user }}
    - defaults:
      app_path: {{ app_path }}

{{ app_user }}_profile_setup:
  file.managed:
    - source: salt://files/ssh_profile
    - name: {{ home }}/.profile
    - user: {{ app_user }}
    - template: jinja
    - require:
      - user: {{ app_user }}
    - defaults:
      stage: {{ stage }}
      app_path: {{ app_path }}
      mysql_user: {{ mysql_user }}
      mysql_pass: {{ mysql_pass }}
      mysql_db: {{ mysql_db }}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      uploads_path: {{ uploads_path }}
      craft_path: {{ craft_path }}

#   Get public key from private key:
#
#   $ ssh-keygen -f web.pem -y > web.pub
#

{% endfor %}

# vim: set ft=yaml ts=2 sw=2 sts=2 et ai :
