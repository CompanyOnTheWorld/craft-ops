# -*- mode: ruby -*-
# vim: set ft=ruby ts=2 sw=2 et sts=2 :

require 'yaml'

public
def deep_merge!(other_hash)
  merge!(other_hash) do |key, oldval, newval|
    oldval.class == self.class ? oldval.deep_merge!(newval) : newval
  end
end

defaults = YAML::load_file('defaults.conf')
defaults.deep_merge!(YAML::load_file('project.conf'))

$project = defaults

if File.exist?(ENV['HOME']+'/ops.conf')
  $project.deep_merge!(YAML::load_file(ENV['HOME']+'/ops.conf'))
end
if File.exist?('private.conf')
  $project.deep_merge!(YAML::load_file('private.conf'))
end

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.define "dev" do |dev|

    dev.vm.box = $project['dev']['vagrant']['box']
    dev.vm.box_url = $project['dev']['vagrant']['box_url']
    dev.vm.box_download_checksum_type = $project['dev']['vagrant']['box_download_checksum_type']
    dev.vm.box_download_checksum = $project['dev']['vagrant']['box_download_checksum']

    dev.ssh.forward_agent = true

    dev.vm.network "forwarded_port", guest: 8000, host: 8000

    dev.vm.synced_folder ".", "/project"

    if File.exist?(ENV['HOME']+'/ops.conf')
      dev.vm.provision :file,
        source: '~/ops.conf',
        destination: $project['dev']['ops_conf_path']
    end

    dev.vm.provision :shell,
      path: $salt_install,
      :args => '-P',
      :keep_color => true

    dev.vm.provision :shell,
      inline: 'sudo cp /project/salt/config/dev.conf /etc/salt/minion'

    dev.vm.provision :shell,
      path: $stackstrap_install,
      :args => "--project_config='#{$project.to_json}'",
      :keep_color => true

    if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
      dev.vm.provision :shell,
        inline: 'sudo salt-call grains.setval vagrant_host_os windows'
    elsif (/darwin/ =~ RUBY_PLATFORM) != nil
      dev.vm.provision :shell,
        inline: 'sudo salt-call grains.setval vagrant_host_os osx'
    else
      dev.vm.provision :shell,
        inline: 'sudo salt-call grains.setval vagrant_host_os linux'
    end

    dev.vm.provision :shell,
      inline: "sudo salt-call state.highstate --retcode-passthrough --log-level=info pillar='#{$project.to_json}'",
      :keep_color => true

  end

  config.vm.define "web" do |web|
    web.vm.synced_folder ".", "/project",
      type: "rsync",
      rsync__exclude: [".git/", "vendor/", "node_modules/", "bower_components/"]

    web.vm.box = $project['web']['vagrant']['box']
    web.vm.box_url = $project['web']['vagrant']['box_url']

    web.vm.provider :aws do |aws, override|
      aws.access_key_id = $project['aws']['access_key']
      aws.secret_access_key = $project['aws']['secret_key']

      aws.ami = $project['aws']['ami_id']
      aws.keypair_name = $project['name']
      aws.region = $project['aws']['region']
      aws.instance_type = $project['aws']['instance_type']
      aws.elastic_ip = $project['aws']['elastic_ip']
      aws.security_groups = $project['aws']['security_groups']
      aws.subnet_id = $project['aws']['subnet_id']
      aws.associate_public_ip = true
      aws.tags = {
        'Roles' => 'web',
        'Stages' => 'preview, staging, production'
      }

      override.ssh.username = $project['web']['admin']['user']
      override.ssh.private_key_path = $project['web']['admin']['private_key_path']
    end

    web.vm.provision :shell,
      path: $salt_install,
      :args => "-P",
      :keep_color => true

    web.vm.provision :shell,
      inline: 'sudo cp /project/salt/config/web.conf /etc/salt/minion'

    web.vm.provision :shell,
      path: $stackstrap_install,
      :args => "--project_config='#{$project.to_json}'",
      :keep_color => true

    web.vm.provision :shell,
      inline: "sudo salt-call state.highstate --retcode-passthrough --log-level=info pillar='#{$project.to_json}'",
      :keep_color => true

  end

end

$salt_install = "https://raw.githubusercontent.com/saltstack/salt-bootstrap/stable/bootstrap-salt.sh"
$stackstrap_install = "https://raw.githubusercontent.com/stackstrap/install/master/stackstrap.sh"
