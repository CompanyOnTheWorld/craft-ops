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

    dev.vm.box = "stackstrap/craft-ops"

    dev.ssh.forward_agent = true

    dev.vm.network "forwarded_port", guest: 8000, host: 8000

    dev.vm.synced_folder ".", "/project"

    if File.exist?(ENV['HOME']+'/ops.conf')
      dev.vm.provision :file, source: '~/ops.conf', destination: $project['dev']['ops_conf_path']
    end

    dev.vm.provision :salt do |salt|
      salt.install_type = "git"
      salt.install_args = "v2015.5.0"
      salt.minion_config = "salt/config/dev.conf"
      salt.pillar($project)
      salt.run_highstate = true
    end

    dev.vm.provider "virtualbox" do |v|
      host = RbConfig::CONFIG['host_os']

      # Give VM 1/4 system memory & access to all cpu cores on the host
      if host =~ /darwin/
        cpus = `sysctl -n hw.ncpu`.to_i
        # sysctl returns Bytes and we need to convert to MB
        mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4
      elsif host =~ /linux/
        cpus = `nproc`.to_i
        # meminfo shows KB and we need to convert to MB
        mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4
      else # sorry Windows folks, I can't help you
        cpus = 2
        mem = 1024
      end

      v.customize ["modifyvm", :id, "--memory", mem]
      v.customize ["modifyvm", :id, "--cpus", cpus]
    end

  end

  config.vm.define "web" do |web|
    web.vm.synced_folder ".", "/project", type: "rsync"

    web.vm.box = $project['web']['vagrant']['box']
    web.vm.box_url = $project['web']['vagrant']['box_url']

    web.vm.provider :aws do |aws, override|
      aws.access_key_id = $project['aws_access_key']
      aws.secret_access_key = $project['aws_secret_key']

      aws.ami = $project['web']['aws']['ami_id']
      aws.keypair_name = $project['name']
      aws.region = $project['web']['aws']['region']
      aws.instance_type = $project['web']['aws']['instance_type']
      aws.elastic_ip = $project['web']['aws']['elastic_ip']
      aws.security_groups = $project['web']['aws']['security_groups']
      aws.subnet_id = $project['web']['aws']['subnet_id']
      aws.associate_public_ip = true
      aws.tags = {
        'Roles' => 'web',
        'Stages' => 'preview, staging, production'
      }

      override.ssh.username = $project['web']['admin']['user']
      override.ssh.private_key_path = $project['web']['admin']['private_key_path']
    end

    if File.exist?(ENV['HOME']+'/ops.conf')
      web.vm.provision :file, source: '~/ops.conf', destination: $project['web']['admin']['ops_conf_path']
    end

    web.vm.provision :salt do |salt|
      salt.install_type = "git"
      salt.install_args = "v2015.5.0"
      salt.minion_config = "salt/config/web.conf"
      salt.run_highstate = false
    end

    web.vm.provision :shell, path: $stackstrap_install, :args => "--project_config='#{$project.to_json}'"

  end

  config.vm.define "base" do |base|

    base.vm.box = $project['base']['vagrant']['box']
    base.vm.box_url = $project['base']['vagrant']['box_url']
    base.vm.box_download_checksum_type = $project['base']['vagrant']['box_download_checksum_type']
    base.vm.box_download_checksum = $project['base']['vagrant']['box_download_checksum']

    base.vm.provider "virtualbox" do |v|
      host = RbConfig::CONFIG['host_os']

      # Give VM 1/4 system memory & access to all cpu cores on the host
      if host =~ /darwin/
        cpus = `sysctl -n hw.ncpu`.to_i
        # sysctl returns Bytes and we need to convert to MB
        mem = `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 4
      elsif host =~ /linux/
        cpus = `nproc`.to_i
        # meminfo shows KB and we need to convert to MB
        mem = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024 / 4
      else # sorry Windows folks, I can't help you
        cpus = 2
        mem = 1024
      end

      v.customize ["modifyvm", :id, "--memory", mem]
      v.customize ["modifyvm", :id, "--cpus", cpus]
    end

    base.ssh.forward_agent = true

    base.vm.synced_folder ".", "/project"

    base.vm.provision :salt do |salt|
      salt.install_type = "git"
      salt.install_args = "v2015.5.0"
      salt.minion_config = "salt/config/base.conf"
      salt.run_highstate = false
    end

    base.vm.provision :shell, path: $stackstrap_install

  end

end

$stackstrap_install = "https://raw.githubusercontent.com/stackstrap/install/master/stackstrap.sh"

