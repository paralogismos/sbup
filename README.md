# Sbup
A Script for Updating SBCL Installations

## Installation
Clone the repository and navigate to the top directory.

It is recommended to install Sbup in a directory that is on the user's search path, under the user's home directory: `~/bin` is a good choice.

```none
make install INSTALL_DIR=~/bin
```

The default directory is `/usr/local/bin`: some users may need to run `sudo make install` to gain write permissions for this directory. To install Sbup in the default directory run:

```none
make install
```

If Sbup has been installed as above, it can later be removed by navigating back to the top directory of the repository and running `make uninstall`, or possibly `sudo make uninstall`.
