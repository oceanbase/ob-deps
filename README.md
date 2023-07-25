## What is ob-deps 

Ob-deps is a repository for building dependency packages of [oceanbase](https://github.com/oceanbase/oceanbase).

## Quick start

### Prerequisite

Some tools and dependencies are needed for building these packages. The xxx-build.sh has solved some compilation dependencies. However, considering different build environments, please install the corresponding dependencies on your own build environment according to the prompts.

Oceanbase Efficiency Team provides dockerfile for centos7 & centos8. The xxx-build.dockerfile in /base-images has installed some simple environment dependencies, which may be helpful for you.

### Building

```bash
cd rpm
bash xxx-build.sh
```

### Others

Pkg 'devdeps-oblogmsg' has been opened source in GitHub https://github.com/oceanbase/oblogmsg ;
The used version in OceanBase 'devdeps-oblogmsg-1.0-52022113019.el7.aarch64.rpm' was complied from this [commit](https://github.com/oceanbase/oblogmsg/commit/20588139cc7774c533450729bb60a2ad33b4e0d4).