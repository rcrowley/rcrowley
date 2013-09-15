rcrowley's home
===============

This repository is meant to **be** my home directory, which, if you're not provisioning systems with Puppet code that does this for you, is a slightly awkward thing to accomplish.  I do roughly the following with new boxen:

```sh
cd
git init
git remote add "origin" "git://github.com/rcrowley/home.git"
git remote update "origin"
git pull "origin" "master"
```
