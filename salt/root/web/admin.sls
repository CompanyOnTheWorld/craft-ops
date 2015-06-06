# -*- mode: yaml -*-
# vim: set ft=yaml ts=2 sw=2 et sts=2 :

{% from "stackstrap/env/macros.sls" import env -%}

{% set project = pillar -%}
{% set project_name = project['name'] -%}

{% set user = 'ubuntu' -%}
{% set group = 'ubuntu' -%}

{% set home = "/home/"+user -%}
{% set project_path = "/project" -%}

{% set aws_access_key = project['aws']['access_key'] -%}
{% set aws_secret_key = project['aws']['secret_key'] -%}
{% set bitbucket_user = project['bitbucket']['user'] -%}
{% set bitbucket_pass_token = project['bitbucket']['token'] -%}

{{ env(user, group) }}

python_requirements:
  cmd:
    - run
    - name: "pip install -r {{ project_path }}/salt/root/web/files/requirements.txt"

admin_private_key:
  file.managed:
    - name: {{ home }}/.ssh/web.pem
    - source: salt://web/files/web.pem
    - makedirs: True
    - user: {{ user }}
    - mode: 600

admin_profile_setup:
  file.managed:
    - source: salt://web/files/ssh_profile_admin
    - name: {{ home }}/.profile
    - user: {{ user }}
    - template: jinja
    - defaults:
      project_path: {{ project_path }}
      {% if aws_access_key %}
      aws_access_key: {{ aws_access_key }}
      aws_secret_key: {{ aws_secret_key }}
      {% endif %}
      {% if bitbucket_user %}
      bitbucket_user: {{ bitbucket_user }}
      bitbucket_pass_token: {{ bitbucket_pass_token }}
      {% endif %}
