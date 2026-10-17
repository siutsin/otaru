# browserless

This chart deploys the browserless Chromium service that agents use
to browse the web from inside the cluster.

Drive it with the client kit in `hack/browserless-client/`. The kit
is the supported way to connect: it sends the Hydra JWT in the
Authorization header and applies the human-like browsing stack.
