# -*- mode: yaml -*-
# vim: set ft=ruby ts=2 sw=2 et sts=2 :

include:
  - stackstrap.env
  - stackstrap.virtualenv

{% from "stackstrap/env/macros.sls" import stackstrap_env -%}
{% from "stackstrap/nvmnode/macros.sls" import nvmnode %}

{% set project = pillar -%}
{% set project_name = project['name'] -%}

{% set user = 'ubuntu' -%}
{% set group = 'ubuntu' -%}

{% set home = "/home/"+user -%}
{% set project_path = "/project" -%}
{% set virtualenv = home+"/virtualenv" -%}

{% set aws_access_key = project['aws_access_key'] -%}
{% set aws_secret_key = project['aws_secret_key'] -%}
{% set bitbucket_user = project['bitbucket_user'] -%}
{% set bitbucket_pass_token = project['bitbucket_pass_token'] -%}

{{ stackstrap_env(project_name, user, group) }}

{{ nvmnode(project_name, user, group,
           ignore_package_json=True,
           node_globals=['bower', 'grunt', 'node-sass', 'harp']) 
}}

{{ user }}_install_harp:
  cmd.run:
    - name: /bin/bash -c "source ~/.nvm/nvm.sh; npm install -g harp"
    - user: {{ user }}
    - unless: /bin/bash -c "source ~/.nvm/nvm.sh; npm -g ls harp | grep harp"
    - check_cmd:
      - /bin/true
    - require:
      - cmd: {{ user }}_install_node

admin_virtualenv:
  cmd:
    - run
    - name: "virtualenv {{ virtualenv }} && rm -f {{ virtualenv }}/lib*/*/no-global-site-packages.txt"
    - unless: "test -d {{ virtualenv }}"
    - user: {{ user }}
    - require:
      - pkg: virtualenv_pkgs

admin_requirements:
  cmd:
    - run
    - name: "source {{ virtualenv }}/bin/activate; pip install -r {{ project_path }}/salt/web/root/files/requirements.txt"
    - shell: /bin/bash
    - env:
        SHORT_NAME: {{ project_name }}
    - user: {{ user }}
    - require:
      - cmd: admin_virtualenv

admin_private_key:
  file.managed:
    - name: {{ home }}/.ssh/web.pem
    - source: salt://files/web.pem
    - makedirs: True
    - user: {{ user }}
    - mode: 600

admin_profile_setup:
  file.managed:
    - source: salt://files/ssh_profile_admin
    - name: {{ home }}/.profile
    - user: {{ user }}
    - template: jinja
    - defaults:
      project_path: {{ project_path }}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      bitbucket_user: {{ bitbucket_user }}
      bitbucket_pass_token: {{ bitbucket_pass_token }}
