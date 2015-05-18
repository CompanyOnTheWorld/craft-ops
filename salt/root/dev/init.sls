# -*- mode: yaml -*-
# vim: set ft=yaml ts=2 sw=2 et sts=2 :

{% from "stackstrap/supervisor/macros.sls" import supervise -%}
{% from "stackstrap/nginx/macros.sls" import nginxsite %}
{% from "stackstrap/php5/macros.sls" import php5_fpm_instance %}
{% from "stackstrap/mysql/macros.sls" import mysql_user_db %}
{% from "stackstrap/env/macros.sls" import env %}
{% from "stackstrap/rvmruby/macros.sls" import rvmruby %}
{% from "stackstrap/nvmnode/macros.sls" import nvmnode %}

{% set project = pillar -%}
{% set project_name = project['name'] -%}

{% set aws_access_key = project['aws_access_key'] -%}
{% set aws_secret_key = project['aws_secret_key'] -%}
{% set bitbucket_user = project['bitbucket_user'] -%}
{% set bitbucket_pass_token = project['bitbucket_pass_token'] -%}

{% set user = project['dev']['user'] -%}
{% set group = project['dev']['group'] -%}
{% set home = "/home/" + user -%}
{% set virtualenv = home + "/virtualenv" -%}
{% set project_path = "/project" -%}

{% set git_repo = project['git']['repo'] %}
{% set git_email = project['git']['email'] %}
{% set git_name = project['git']['name'] %}

{% set mysql_user = project_name %}
{% set mysql_pass = project_name %}
{% set mysql_db = project_name %}

{{ mysql_user_db(mysql_user, mysql_pass) }}

{% set uploads_path = project_path + "/public/assets" -%}
{% set craft_path = project_path + "/vendor/Craft-Release-master" -%}

{{ user }}_mysql_import:
  cmd.run:
    - name: unzip -p {{ project_path }}/salt/dev/root/files/craft-cms-backup.zip | mysql -u {{ mysql_user }} -p{{ mysql_pass }} {{ mysql_user }}

{{ env(project_name, user, group) }}

{{ user }}_ssh_config:
  file.managed:
    - name: {{ home }}/.ssh/config
    - source: salt://dev/files/ssh_config
    - template: jinja
    - makedirs: True
    - user: {{ user }}

{{ user }}_ssh_known_hosts:
  ssh_known_hosts:
    - name: bitbucket.org
    - present
    - user: {{ user }}

{{ project_name }}_virtualenv:
  cmd:
    - run
    - name: "virtualenv {{ virtualenv }} && rm -f {{ virtualenv }}/lib*/*/no-global-site-packages.txt"
    - unless: "test -d {{ virtualenv }}"
    - user: vagrant
    - require:
      - pkg: virtualenv_pkgs

{{ project_name }}_requirements:
  cmd:
    - run
    - name: "source {{ virtualenv }}/bin/activate; pip install -r {{ project_path }}/salt/root/dev/files/requirements.txt"
    - shell: /bin/bash
    - env:
        SHORT_NAME: {{ project_name }}
    - user: vagrant
    - require:
      - cmd: {{ project_name }}_virtualenv

{{ rvmruby(project_name, user, group,
           rvm_globals=['filewatcher']) 
}}

{{ nvmnode(project_name, user, group,
           ignore_package_json=True,
           node_globals=['bower', 'harp']) 
}}
  
{{ php5_fpm_instance(project_name, '5000', user, group,
                     envs={
                       'CRAFT_ENVIRONMENT': 'local',
                       'CRAFT_PATH': craft_path,
                       'PROJECT_PATH': project_path,
                       'UPLOADS_PATH': uploads_path,
			                 'MYSQL_USER': mysql_user,
			                 'MYSQL_PASS': mysql_pass,
			                 'MYSQL_DB': mysql_db
		                 })
}}

{{ nginxsite(project_name, user, group,
             template="salt://dev/files/craft-cms.conf",
	           create_root=False,
	           root="public",
             listen="8000",
             server_name="_",
             static=project_path+"/public/static",
             cors="*",
             defaults={
                'port': '5000'
             })
}}

{{ project_path }}/craft/plugins:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}
    - mode: 755
    - makedirs: True

{{ project_path }}/craft/storage:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}
    - mode: 755
    - makedirs: True

{{ project_path }}/vendor:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}
    - mode: 755
    - makedirs: True

download_craft_guzzle_plugin:
  archive.extracted:
    - name: {{ project_path }}/vendor
    - source: https://github.com/davist11/craft-guzzle/archive/master.tar.gz 
    - source_hash: md5=8758bcc8e33ba59dacca7c3ead7a31eb
    - archive_format: tar
    - user: {{ user }}
    - group: {{ group }}
    - if_missing: {{ project_path }}/vendor/craft-guzzle-master

{{ project_path }}/craft/plugins/guzzle:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/vendor/craft-guzzle-master/guzzle

download_craft:
  archive.extracted:
    - name: {{ project_path }}/vendor
    - source: https://github.com/pixelandtonic/Craft-Release/archive/master.tar.gz 
    - source_hash: md5=0cf267bac9a021a4adcbf983dfd0f8ef
    - archive_format: tar
    - user: {{ user }}
    - group: {{ group }}
    - if_missing: {{ craft_path }}

{{ craft_path }}:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - recurse:
      - user
      - group

{{ craft_path }}/config:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/craft/config

{{ craft_path }}/plugins:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/craft/plugins

{{ craft_path }}/storage:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/craft/storage

{{ craft_path }}/templates:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/templates

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
    - user: {{ user }}
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
    - user: {{ user }}
    - group: {{ group }}
    - mode: 755 

{{ home }}/.aws/config:
  file.managed:
    - source: salt://dev/files/aws.config
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
    - mode: 600
    - defaults:
        aws_access_key: {{ aws_access_key }} 
        aws_secret_key: {{ aws_secret_key }} 
        region: us-east-1

{{ home }}/.bitbucket:
  file.managed:
    - source: salt://dev/files/bitbucket.conf
    - template: jinja
    - user: {{ user }}
    - group: {{ group }}
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
    - user: {{ user }}
    - unless: vagrant plugin list | grep 'vagrant-aws'
    - require:
      - pkg: install_vagrant

{{ supervise("dev", home, user, group, {
        "watcher": {
            "command": "\"filewatcher '**/*.*' 'harp compile "+project_path+"/assets "+project_path+"/public/static'\"",
            "directory": project_path,
            "user": user
        }
    })
}}

redacted_font:
  archive.extracted:
    - name: {{ project_path }}/vendor
    - source: https://github.com/christiannaths/Redacted-Font/archive/old-sources.zip
    - source_hash: md5=9ff6e2ca3a69586a97235c292003ab78
    - archive_format: zip
    - if_missing: {{ project_path }}/vendor/Redacted-Font-old-sources
    - user: {{ user }}
    - group: {{ group }}

{{ user }}_bowerrc:
  file.managed:
    - user: {{ user }}
    - group: {{ group }}
    - source: salt://dev/files/.bowerrc
    - name: {{ home }}/.bowerrc
    - template: jinja
    - require:
      - user: {{ user }}
    - defaults:
      project_path: {{ project_path }}

{{ user }}_git_config:
  file.managed:
    - user: {{ user }}
    - group: {{ group }}
    - source: salt://dev/files/git_config
    - name: {{ home }}/.gitconfig
    - template: jinja
    - require:
      - user: {{ user }}
    - defaults:
      home: {{ home }}
      git_email: {{ git_email }}
      git_name: {{ git_name }}

{{ user }}_ssh_profile:
  file.managed:
    - user: {{ user }}
    - group: {{ group }}
    - source: salt://dev/files/ssh_profile
    - name: {{ home }}/.profile
    - template: jinja
    - require:
      - user: {{ user }}
    - defaults:
      project_path: {{ project_path }}
      mysql_user: {{ mysql_user }}
      mysql_pass: {{ mysql_pass }}
      mysql_db: {{ mysql_db }}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      bitbucket_user: {{ bitbucket_user }}
      bitbucket_pass_token: {{ bitbucket_pass_token }}
      uploads_path: {{ uploads_path }}
      craft_path: {{ craft_path }}

# vim: set ft=yaml ts=2 sw=2 sts=2 et ai :
