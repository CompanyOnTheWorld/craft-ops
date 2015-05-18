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
