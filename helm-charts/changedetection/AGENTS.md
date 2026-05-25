# Changedetection Agent Guide

Keep this chart as the source of truth for the Changedetection workload and its
browser companion. Prefer GitOps changes; only patch the live cluster for urgent
diagnostics or recovery, then backport the chart change.

## Essentials

- Keep private values in the ExternalSecret-backed `config.yaml`.
- Keep normal runtime environment in `values.yaml` under `deployment.env`.
- Remember that the UI persists many settings in `/datastore`; an env default
  may not overwrite an existing UI/datastore value.
- Use the browser backend for pages that need JavaScript, cookies, or a
  persistent browser profile. It can reduce simple blocking, but it is not a
  proxy service and cannot bypass all bot protection.
- Keep fetch and browser concurrency conservative unless there is measured
  capacity and low upstream blocking.
- Keep both `NetworkPolicy` and `AuthorizationPolicy` for the browser service:
  they protect different layers.
- For long AI summary requests, check logs and route timeouts before changing
  model configuration. A request may complete after the client sees a timeout.
- For variant-specific product watches, make extraction target the exact
  variant. Generic product metadata often points at a default variant.
- For workload-only changes, restart the workload or let Argo CD reconcile. Do
  not reboot nodes for this app.
- Validate focused changes with `helm template`, then run `make test`.
