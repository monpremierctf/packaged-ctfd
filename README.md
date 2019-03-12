# A packaged installation of CTFD

This is a packaged installation of [CTFd](https://github.com/CTFd/CTFd) in a standalone script aimed to be run on a CentOS 7.4+ server.

## Execution requirements

The machine running the script should :

- run a CentOS / RedHat base capable of executing docker (CentOS 7+).
- be able to reach the internet to retrieve docker images, if a proxy is needed it should be present in the environment before executing the script.

The script must be run as the user **root** or with the `sudo` command.

## Instructions to run the script

By default the script is interactive : it will prompt if you accept default parameters and will let you overwrite them.
However it is possible to make the script completely autonomous by using the options `--domain=DOMAIN`.

## Contributing

### Modify the installation logic

The script is built using [`makeself`](https://makeself.io) : it creates a tar archive containing all the directory `./package` and embed it in the `installer.run` file.
Once executed the tar archive is expanded and the file `./package/bootstrap.sh` is run.

As a result if you want to modify the provisioning logic the file `./package/bootstrap.sh` should be modified.

### Making your own `installer.run` script file

The build is done with the `make` command, the file `Makefile` defines a `.PHONY` target called **package** which aliases **installer.run**.
