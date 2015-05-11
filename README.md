# Craft Ops

`Craft Ops` is a template which uses automation tools to build you a virtual
DevOps environment which is tailored for [Craft CMS][craft_link]. Craft itself
is already incredibly easy to setup with tools like MAMP, and this project
aims to stay that way. This project's aim is to get you past the process
of dragging files over to FTP and working with efficiency in mind, while also
learning a thing or two about Linux.

To start, the ops workflows will be built around the use of AWS and Bitbucket.
These products both offer free options and can be fully automated.

Please also note that use of Craft is subject to their own
[license agreement][craft_license].

##### Requirements

- [Vagrant][vagrant_link]
- [VirtualBox][virtualbox_link]

> This has not been tested on Windows, but support is welcome :)

## Getting Started

Clone this repo as the name of your project.

```
git clone https://github.com/stackstrap/craft-ops.git project_name
```

You will need to enter same `project_name` into [`project.conf`][project_conf_link].

> Keep your `project_name` short and without special characters.

**Then just build the `dev` vm:**

```
vagrant up dev
```

[craft_link]: https://buildwithcraft.com/
[craft_license]: https://buildwithcraft.com/license
[project_conf_link]: https://github.com/stackstrap/craft-ops/blob/master/project.conf
[vagrant_link]: http://vagrantup.com
[virtualbox_link]: http://virtualbox.org
