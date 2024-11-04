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

(c) 2023-2024 Broadcom. All Rights Reserved.
The term "Broadcom" refers to Broadcom Inc. and/or its subsidiaries.

The contents of this repository are licensed under the Mozilla Public License 2.0 ("MPL"),
same as RabbitMQ.

The packages produced by this repository are licenced under:

1. Erlang: [Apache 2.0](https://github.com/erlang/otp/blob/master/LICENSE.txt)
2. Elixir: [Apache 2.0](https://github.com/elixir-lang/elixir/blob/main/LICENSE)

See [LICENSE](./LICENSE).
