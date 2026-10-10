# Otaru Architecture Diagrams

Architecture diagrams using [diagrams](https://diagrams.mingrammer.com/).

## Prerequisites

- Mise manages Python, Graphviz, and Poetry. From the repository root, run:

```bash
mise trust
mise install
```

## Generate Diagrams

From the project root:

```bash
make generate-diagrams
```

This will automatically format Python code and generate the diagram to `assets/architecture.png`.

To generate with a custom filename:

```bash
make generate-diagrams OUTPUT_FILE=custom-name
```

Output will be saved to `assets/custom-name.png`.

## Custom Icons

Custom icons are stored in `../assets/icons/`.

| Icon                 | Source                                                                           | License                                                                              |
|----------------------|----------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| 1password.png        | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| agentgateway.png     | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| backblaze.png        | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cert-manager.png     | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cloudflared.png      | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cloudnative-pg.png   | [CNCF Artwork](https://github.com/cncf/artwork/blob/main/projects/cloudnativepg) | [Linux Foundation Trademark](https://github.com/cncf/artwork/blob/master/LICENSE.md) |
| external-secrets.png | [External Secrets](https://github.com/external-secrets/external-secrets)         | [Apache 2.0](https://github.com/external-secrets/external-secrets/blob/main/LICENSE) |
| firecrawl.png        | [Lobe Icons](https://github.com/lobehub/lobe-icons)                              | [MIT](https://github.com/lobehub/lobe-icons/blob/master/LICENSE)                     |
| hermes.png           | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| kubernetes.png       | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| llama-cpp.png        | [Dashboard Icons](https://dashboardicons.com/icons/external/llama-cpp)           | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)                            |
| longhorn.png         | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| meta-muse.png        | [Meta Muse](https://ai.meta.com/muse/)                                           | Nominative fair use                                                                  |
| metallb.png          | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| ory.png              | [Simple Icons](https://simpleicons.org/?q=ory)                                   | [CC0 1.0](https://github.com/simple-icons/simple-icons/blob/develop/LICENSE.md)      |
| searxng.png          | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| tailscale.png        | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| unifi.png            | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| webgazer.png         | [WebGazer](https://www.webgazer.io/)                                             | Nominative fair use                                                                  |
