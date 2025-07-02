# Sbup
A Script for Updating SBCL Installations

## Installation
Clone the repository and navigate to the top directory.

It is recommended to install `sbup` in a directory that is on the user's search path, under the user's home directory.

The makefile installs `sbup` in `~/bin` by default:

```none
make install
```

Use `INSTALL_DIR` to override the default installation directory:

```none
make install INSTALL_DIR=/usr/local/bin
```

Some users may need to run `sudo make install INSTALL_DIR=<install_path>` to gain write permissions for system-wide locations like `/usr/local/bin`.

If `sbup` has been installed as above, it can later be removed by navigating back to the top directory of the repository and running `make uninstall`, or possibly `sudo make uninstall`.

To facilitate development `make reinstall` can be used. This is equivalent to invoking `make uninstall` followed by `make install`.
