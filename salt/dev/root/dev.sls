# -*- mode: yaml -*-
# vim: set ft=ruby ts=2 sw=2 et sts=2 :

include:
  - stackstrap.env
  - stackstrap.virtualenv
  - stackstrap.supervisor
  - stackstrap.nginx
  - stackstrap.php5.fpm
  - stackstrap.mysql.server
  - stackstrap.mysql.client
  - stackstrap.rvmruby
  - stackstrap.nvmnode

{% from "stackstrap/utils/users.sls" import skeleton -%}
{% from "stackstrap/supervisor/macros.sls" import supervise -%}
{% from "stackstrap/nginx/macros.sls" import nginxsite %}
{% from "stackstrap/php5/macros.sls" import php5_fpm_instance %}
{% from "stackstrap/mysql/macros.sls" import mysql_user_db %}
{% from "stackstrap/env/macros.sls" import stackstrap_env %}
{% from "stackstrap/rvmruby/macros.sls" import rvmruby %}
{% from "stackstrap/nvmnode/macros.sls" import nvmnode %}

{% set project = pillar -%}
{% set short_name = project['short_name'] -%}

{% set aws_access_key = project['aws_access_key'] -%}
{% set aws_secret_key = project['aws_secret_key'] -%}
{% set bitbucket_user = project['bitbucket_user'] -%}
{% set bitbucket_pass_token = project['bitbucket_pass_token'] -%}

{% set app_user = project['dev']['user'] -%}
{% set app_group = project['dev']['group'] -%}
{% set home = "/home/" + app_user -%}
{% set virtualenv = home + "/virtualenv" -%}
{% set app_path = home + "/apps/" + short_name -%}

{% set git_repo = project['git']['repo'] %}
{% set git_email = project['git']['email'] %}
{% set git_name = project['git']['name'] %}

{% set mysql_user = short_name %}
{% set mysql_pass = short_name %}
{% set mysql_db = short_name %}

{{ mysql_user_db(mysql_user, mysql_pass) }}

{% set uploads_path = app_path + "/public/assets" -%}
{% set craft_path = app_path + "/vendor/Craft-Release-master" -%}

{{ app_user }}_mysql_import:
  cmd.run:
    - name: unzip -p {{ app_path }}/salt/dev/root/files/craft-cms-backup.zip | mysql -u {{ mysql_user }} -p{{ mysql_pass }} {{ mysql_user }}

{{ skeleton(app_user, 1000, 1000, remove_groups=False) }}

{{ stackstrap_env(short_name, app_user, app_group) }}

{{ app_user }}_ssh_config:
  file.managed:
    - name: {{ home }}/.ssh/config
    - source: salt://files/ssh_config
    - template: jinja
    - makedirs: True
    - user: {{ app_user }}

{{ app_user }}_ssh_known_hosts:
  ssh_known_hosts:
    - name: bitbucket.org
    - present
    - user: {{ app_user }}

{{ short_name }}_virtualenv:
  cmd:
    - run
    - name: "virtualenv {{ virtualenv }} && rm -f {{ virtualenv }}/lib*/*/no-global-site-packages.txt"
    - unless: "test -d {{ virtualenv }}"
    - user: vagrant
    - require:
      - pkg: virtualenv_pkgs

{{ short_name }}_requirements:
  cmd:
    - run
    - name: "source {{ virtualenv }}/bin/activate; pip install -r {{ app_path }}/salt/dev/root/files/requirements.txt"
    - shell: /bin/bash
    - env:
        SHORT_NAME: {{ short_name }}
    - user: vagrant
    - require:
      - cmd: {{ short_name }}_virtualenv

{{ rvmruby(short_name, app_user, app_group,
           rvm_globals=['filewatcher']) 
}}

{{ nvmnode(short_name, app_user, app_group,
           ignore_package_json=True,
           node_globals=['bower', 'grunt', 'node-sass', 'harp']) 
}}

install_harp:
  cmd.run:
    - name: /bin/bash -c "source ~/.nvm/nvm.sh; npm install -g harp"
    - user: {{ app_user }}
    - unless: /bin/bash -c "source ~/.nvm/nvm.sh; npm -g ls harp | grep harp"
    - check_cmd:
      - /bin/true
    - require:
      - cmd: vagrant_install_node

  
{{ php5_fpm_instance(short_name, '5000', app_user, app_group,
                     envs={
                       'CRAFT_ENVIRONMENT': 'local',
                       'CRAFT_PATH': craft_path,
                       'APP_PATH': app_path,
                       'UPLOADS_PATH': uploads_path,
			                 'MYSQL_USER': mysql_user,
			                 'MYSQL_PASS': mysql_pass,
			                 'MYSQL_DB': mysql_db
		                 })
}}

{{ nginxsite(short_name, app_user, app_group,
             template="salt://files/craft-cms.conf",
	           create_root=False,
	           root="public",
             listen="8000",
             server_name="_",
             static=app_path+"/public/static",
             cors="*",
             defaults={
                'port': '5000'
             })
}}

{{ app_path }}/craft/plugins:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 755
    - makedirs: True

{{ app_path }}/craft/storage:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 755
    - makedirs: True

{{ app_path }}/vendor:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 755
    - makedirs: True

download_craft_guzzle_plugin:
  archive.extracted:
    - name: {{ app_path }}/vendor
    - source: https://github.com/davist11/craft-guzzle/archive/master.tar.gz 
    - source_hash: md5=8758bcc8e33ba59dacca7c3ead7a31eb
    - archive_format: tar
    - user: {{ app_user }}
    - group: {{ app_group }}
    - if_missing: {{ app_path }}/vendor/craft-guzzle-master

download_craft:
  archive.extracted:
    - name: {{ app_path }}/vendor
    - source: https://github.com/pixelandtonic/Craft-Release/archive/master.tar.gz 
    - source_hash: md5=0cf267bac9a021a4adcbf983dfd0f8ef
    - archive_format: tar
    - user: {{ app_user }}
    - group: {{ app_group }}
    - if_missing: {{ craft_path }}

{{ craft_path }}:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - makedirs: True
    - recurse:
      - user
      - group

{{ craft_path }}/config:
  file.symlink:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - target: {{ app_path }}/craft/config

{{ craft_path }}/plugins:
  file.symlink:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - target: {{ app_path }}/craft/plugins

{{ craft_path }}/storage:
  file.symlink:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - target: {{ app_path }}/craft/storage

{{ craft_path }}/templates:
  file.symlink:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - target: {{ app_path }}/templates

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
  cmd:
    - run
    - name: curl -sS https://getcomposer.org/installer | php
    - user: {{ app_user }}
    - unless: test -e {{ home }}/composer.phar
    - require:
      - pkg: php5-fpm

/usr/local/bin/composer:
  file.symlink:
    - target: {{ home }}/composer.phar

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

{{ home }}/.aws:
  file.directory:
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 755 

{{ home }}/.aws/config:
  file.managed:
    - source: salt://files/aws.config
    - template: jinja
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 600
    - defaults:
        aws_access_key: {{ aws_access_key }} 
        aws_secret_key: {{ aws_secret_key }} 
        region: us-east-1

{{ home }}/.bitbucket:
  file.managed:
    - source: salt://files/bitbucket.conf
    - template: jinja
    - user: {{ app_user }}
    - group: {{ app_group }}
    - mode: 600
    - defaults:
        bitbucket_user: {{ bitbucket_user }}
        bitbucket_pass_token: {{ bitbucket_pass_token }}

install_vagrant:
  pkg.installed:
    - sources: 
      - vagrant: https://dl.bintray.com/mitchellh/vagrant/vagrant_1.7.2_x86_64.deb

install_vagrant_aws:
  cmd.run:
    - name: source ~/.profile; vagrant plugin install vagrant-aws
    - user: {{ app_user }}
    - unless: vagrant plugin list | grep 'vagrant-aws'
    - require:
      - pkg: install_vagrant

{{ supervise("dev", home, app_user, app_group, {
        "watcher": {
            "command": "\"filewatcher '**/*.*' 'harp compile "+app_path+"/assets "+app_path+"/public/static'\"",
            "directory": app_path,
            "user": app_user
        }
    })
}}

redacted_font:
  archive.extracted:
    - name: {{ app_path }}/vendor
    - source: https://github.com/christiannaths/Redacted-Font/archive/old-sources.zip
    - source_hash: md5=9ff6e2ca3a69586a97235c292003ab78
    - archive_format: zip
    - if_missing: {{ app_path }}/vendor/Redacted-Font-old-sources
    - user: {{ app_user }}
    - group: {{ app_group }}

{{ app_user }}_ssh_profile:
  file.managed:
    - source: salt://files/ssh_profile
    - name: {{ home }}/.profile
    - template: jinja
    - require:
      - user: {{ app_user }}
    - defaults:
      app_path: {{ app_path }}
      mysql_user: {{ mysql_user }}
      mysql_pass: {{ mysql_pass }}
      mysql_db: {{ mysql_db }}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      bitbucket_user: {{ bitbucket_user }}
      bitbucket_pass_token: {{ bitbucket_pass_token }}
      uploads_path: {{ uploads_path }}
      craft_path: {{ craft_path }}

{{ app_user }}_git_config:
  file.managed:
    - source: salt://files/git_config
    - name: {{ home }}/.gitconfig
    - template: jinja
    - require:
      - user: {{ app_user }}
    - defaults:
      home: {{ home }}
      git_email: {{ git_email }}
      git_name: {{ git_name }}

# vim: set ft=yaml ts=2 sw=2 sts=2 et ai :
