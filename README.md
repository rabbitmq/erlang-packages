# RabbitMQ Erlang and Elixir Packages

GitHub Actions workflows to build and distribute Erlang and Elixir packages.

## Erlang

### Debian

Built from [Erlang/OTP packages for Debian and Ubuntu](https://github.com/rabbitmq/erlang-debian-package) repository.

* Update the `erlang-deb-configuration.json` file with Debian-based Linux distributions and Erlang major versions. 
* Run the generation script:
```shell
./generate.py erlang deb
```
* Commit and push the changes (in `erlang-deb-configuration.json` and in `.github/workflows`).

### RPM

Built from [Zero-dependency Erlang RPM for RabbitMQ](https://github.com/rabbitmq/erlang-rpm) repository.

* Update the `erlang-rpm-configuration.json` file with CentOS-based Linux distributions and Erlang major versions. 
* Run the generation script:
```shell
./generate.py erlang rpm
```
* Commit and push the changes (in `erlang-rpm-configuration.json` and in `.github/workflows`).

## Elixir

### Debian

Built from [Elixir packages for Debian and Ubuntu](https://github.com/rabbitmq/elixir-debian-package) repository.

* Update the `elixir-deb-configuration.json` file with Debian-based Linux distributions and Elixir versions. 
* Run the generation script:
```shell
./generate.py elixir deb
```
* Commit and push the changes (in `elixir-deb-configuration.json` and in `.github/workflows`).

# License and Copyright

(c) 2023 Broadcom. All Rights Reserved.
The term "Broadcom" refers to Broadcom Inc. and/or its subsidiaries.

This package, the Concourse Cloudsmith Resource, is licensed
under the Mozilla Public License 2.0 ("MPL").

See [LICENSE](./LICENSE).
