# Craft Ops

`Craft Ops` is a template which uses automation tools to build you a virtual
DevOps environment tailored for [Craft CMS][craft_link]. Craft itself
is already incredibly easy to setup with tools like MAMP, and this project
aims to stay that way. This aim is to get you past the process
of dragging files over to FTP and working with efficiency in mind.

To start, the ops workflows will be built around the use of AWS and Bitbucket.
These products both offer free options and can be fully automated. They
also offer quality prices that work for small contractors.

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

Come up with "short name" and "project name" values your project. The `short_name`
value will be used to label things in the system. It should be short and easy to
type, also leave out special characters or things could fail. The `project_name`
value will be used to label things that need to be very specific like the name
of a git repo.

You will need to enter these values into the [`project.conf`][project_conf_link] file.

Then just build the `dev` vm:

```
vagrant up dev
```

[craft_link]: https://buildwithcraft.com/
[craft_license]: https://buildwithcraft.com/license
[project_conf_link]: https://github.com/stackstrap/craft-ops/blob/master/project.conf
[vagrant_link]: http://vagrantup.com
[virtualbox_link]: http://virtualbox.org
