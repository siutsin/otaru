# kubernetes-service-patcher

An operator to watch the `kubernetes` service in the `default` namespace and update the service type to `LoadBalancer` instead of `ClusterIP`.

## Description

The `kubernetes-service-patcher` operator monitors the default `kubernetes` service in the `default` namespace and automatically updates its type from `ClusterIP` to
`LoadBalancer`. This is particularly useful in environments like k3s, where the API server runs on the host, and the service type needs to be adjusted to ensure proper external
access to the API server.

In environments like k3s, where the API server is not running as a pod but directly on the host, it’s not trivial to create another service that selects the API server nodes. This
operator simplifies the process by automatically updating the existing `kubernetes` service, ensuring it is consistently configured as a `LoadBalancer`.

The external IP of the `LoadBalancer` should be configured by a separate component such as Cilium's IP Pool with L2 announcement or MetalLB in L2 mode. These components handle the
allocation and advertisement for external IPs to provide external access to the `LoadBalancer` service.

## Getting Started

### Prerequisites

- go version v1.23.0+
- docker version 27.2.0+.
- kubectl version v1.31.0+.
- Access to a Kubernetes v1.30.4+ cluster.

### To Deploy on the cluster

**Build and push your image to the location specified by `IMG`:**

```sh
make docker-build docker-push IMG=ghcr.io/siutsin/otaru-kubernetes-service-patcher:latest
```

**NOTE:** This image ought to be published in the personal registry you specified.
And it is required to have access to pull the image from the working environment.
Make sure you have the proper permission to the registry if the above commands don’t work.

**Install the CRDs into the cluster:**

```sh
make install
```

**Deploy the Manager to the cluster with the image specified by `IMG`:**

```sh
make deploy IMG=ghcr.io/siutsin/otaru-kubernetes-service-patcher:latest
```

> **NOTE**: If you encounter RBAC errors, you may need to grant yourself cluster-admin
> privileges or be logged in as admin.

**Create instances of your solution**
You can apply the samples (examples) from the config/sample:

```sh
kubectl apply -k config/samples/
```

> **NOTE**: Ensure that the samples has default values to test it out.

### To Uninstall

**Delete the instances (CRs) from the cluster:**

```sh
kubectl delete -k config/samples/
```

**Delete the APIs(CRDs) from the cluster:**

```sh
make uninstall
```

**UnDeploy the controller from the cluster:**

```sh
make undeploy
```

## Project Distribution

Following are the steps to build the installer and distribute this project to users.

1. Build the installer for the image built and published in the registry:

    ```sh
    make build-installer IMG=ghcr.io/siutsin/otaru-kubernetes-service-patcher:latest
    ```

   NOTE: The makefile target mentioned above generates an 'install.yaml'
   file in the dist directory. This file contains all the resources built
   with Kustomize, which are necessary to install this project without
   its dependencies.

2. Using the installer

   Users can just run kubectl apply -f <URL for YAML BUNDLE> to install the project, i.e.:

    ```sh
    kubectl apply -f https://raw.githubusercontent.com/siutsin/otaru/master/applications/kubernetes-service-patcher/dist/install.yaml
    ```
