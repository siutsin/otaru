# Agent Instructions

## Arrow Direction

Use **action initiator** style. The arrow points FROM the initiator TO the target.

| Action | Arrow Direction         | Example                          |
|--------|-------------------------|----------------------------------|
| Pull   | Initiator → Source      | `ArgoCD → GitHub` (ArgoCD pulls) |
| Push   | Initiator → Destination | `GitHub → Cloudflare` (webhook)  |
| Fetch  | Initiator → Source      | `Client → Server`                |
| Send   | Initiator → Destination | `Server → Client`                |

Examples:

- `argocd >> Edge(label="Pull") >> github`
- `github >> Edge(label="Webhook") >> cloudflare`
- `master >> Edge(label="state") >> etcd`

## Icon Selection

Priority order:

1. Built-in icons from the diagrams library
2. Custom icons documented in `README.md`
3. Official logos from project websites (ensure proper licensing)

All custom icons in `assets/icons/` must be **512x512 pixels**:

```bash
magick icon-name.png -resize 512x512 icon-name.png
```
