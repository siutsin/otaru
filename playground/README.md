# Launch Local Playground

This repository provides a simple setup for launching a local Kubernetes playground using [Multipass](https://multipass.run/).

The playground will consist of multiple Kubernetes master and worker nodes, as well as an external etcd cluster, all running locally on your machine.
This setup is ideal for development, testing, or learning Kubernetes in a local environment.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Homebrew**: A package manager for macOS (or other OS's equivalent package manager).
- **Multipass**: A lightweight VM manager.

## Installation Steps

### 1. Install Multipass

First, you need to install Multipass using Homebrew:

```shell
brew install multipass
```

### 2. Launch nodes

```shell
./playground/up.sh
```

### 3. Install CNI

```shell
./playground/cni.sh
```
