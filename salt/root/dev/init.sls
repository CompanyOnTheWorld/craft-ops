# -*- mode: yaml -*-
# vim: set ft=yaml ts=2 sw=2 et sts=2 :

{% from "stackstrap/supervisor/macros.sls" import supervise -%}
{% from "stackstrap/nginx/macros.sls" import nginxsite %}
{% from "stackstrap/php5/macros.sls" import php5_fpm_instance %}
{% from "stackstrap/mysql/macros.sls" import mysql_user_db %}
{% from "stackstrap/env/macros.sls" import env %}

{% set project = pillar -%}

{% set project_name = project['name'] -%}
{% set aws_access_key = project['aws']['access_key'] -%}
{% set aws_secret_key = project['aws']['secret_key'] -%}
{% set bitbucket_user = project['bitbucket']['user'] -%}
{% set bitbucket_pass_token = project['bitbucket']['token'] -%}

{% set user = project['dev']['user'] -%}
{% set group = project['dev']['group'] -%}
{% set home = "/home/" + user -%}
{% set project_path = project['dev']['path'] -%}
{% set assets_path = project['dev']['path'] + "/assets" -%}

{% set git_repo = project['git']['repo'] %}
{% set git_email = project['git']['email'] %}
{% set git_name = project['git']['name'] %}

{% set mysql_user = project['dev']['mysql_user'] %}
{% set mysql_pass = project['dev']['mysql_pass'] %}
{% set mysql_db = project['dev']['mysql_db'] %}

{{ mysql_user_db(mysql_user, mysql_pass) }}

{% set uploads_path = project_path + "/public/assets" -%}
{% set php_vendor_path = home + "/vendor" -%}
{% set craft_path = php_vendor_path + "/Craft-Release-master" -%}

python_requirements:
  pip.installed:
    - requirements: salt://dev/files/requirements.txt

configure_legit_remote:
  cmd.run:
    - name: git config legit.remote origin
    - user: {{ user }}
    - cwd: {{ project_path }}
    - require:
      - pip: python_requirements

install_legit_aliases:
  cmd.run:
    - name: legit install
    - cwd: {{ project_path }}
    - user: {{ user }}
    - require:
      - pip: python_requirements

{{ user }}_mysql_import:
  cmd.run:
    - name: unzip -p {{ project_path }}/salt/root/dev/files/craft-cms-backup.zip | mysql -u {{ mysql_user }} -p{{ mysql_pass }} {{ mysql_db }}
    - unless: mysql -u {{ mysql_user }} -p{{ mysql_pass }} {{ mysql_db }} -e "SHOW TABLES LIKE 'craft_info'" | grep 'craft_info'

{{ env(user, group) }}

{{ user }}_ssh_config:
  file.managed:
    - name: {{ home }}/.ssh/config
    - source: salt://dev/files/ssh_config
    - template: jinja
    - makedirs: True
    - user: {{ user }}
  
{{ php5_fpm_instance(user, group, '5000',
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

{{ nginxsite(user, group,
             template="salt://dev/files/craft-cms.conf",
	           root="public",
             listen="8000",
             server_name="_",
             cors="*",
             defaults={
                'port': '5000'
             })
}}

{{ php_vendor_path }}:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}

{{ uploads_path }}:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}

{{ home }}/plugins:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}

{{ home }}/storage:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}

download_craft:
  archive.extracted:
    - name: {{ php_vendor_path }}
    - source: {{ project['craft']['source'] }}
    - source_hash: {{ project['craft']['source_hash'] }}
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
    - target: {{ home }}/plugins

{{ craft_path }}/storage:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ home }}/storage

{{ craft_path }}/templates:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ project_path }}/templates

download_craft_guzzle_plugin:
  archive.extracted:
    - name: {{ php_vendor_path }}
    - source: https://github.com/davist11/craft-guzzle/archive/master.tar.gz 
    - source_hash: md5=8758bcc8e33ba59dacca7c3ead7a31eb
    - archive_format: tar
    - user: {{ user }}
    - group: {{ group }}
    - if_missing: {{ php_vendor_path }}/craft-guzzle-master

{{ php_vendor_path }}/craft-guzzle-master:
  file.directory:
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - recurse:
      - user
      - group

{{ home }}/plugins/guzzle:
  file.symlink:
    - user: {{ user }}
    - group: {{ group }}
    - target: {{ php_vendor_path }}/craft-guzzle-master/guzzle

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

{% if aws_access_key %}
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
{% endif %}

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

node_global_wetty:
  cmd:
    - run
    - name: npm install -g wetty
    - unless: npm -g ls wetty | grep wetty
    - require:
      - pkg: nodejs

{{ supervise("dev", home, user, group, {
        "harp": {
            "command": "harp server",
            "directory": assets_path,
            "user": user
        },
        "wetty": {
          "command": "wetty -p 3000 --sshuser=vagrant",
            "directory": project_path,
            "user": user
        }
    })
}}

/etc/rc.local:
  file.managed:
    - source: salt://dev/files/rc.local
    - template: jinja
    - defaults:
        home: {{ home }}
        name: dev

{{ user }}_bowerrc:
  file.managed:
    - user: {{ user }}
    - group: {{ group }}
    - source: salt://dev/files/.bowerrc
    - name: {{ home }}/.bowerrc
    - require:
      - user: {{ user }}

install_bower_components:
  cmd.run:
    - name: bower install
    - cwd: {{ project_path }}
    - user: {{ user }}
    - require:
      - file: {{ user }}_bowerrc

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
      {% if aws_access_key %}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      {% endif %}
      {% if bitbucket_user %}
      bitbucket_user: {{ bitbucket_user }}
      bitbucket_pass_token: {{ bitbucket_pass_token }}
      {% endif %}
      uploads_path: {{ uploads_path }}
      craft_path: {{ craft_path }}

# vim: set ft=yaml ts=2 sw=2 sts=2 et ai :
