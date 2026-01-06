# Otaru Architecture Diagrams

Architecture diagrams using [diagrams](https://diagrams.mingrammer.com/).

## Prerequisites

- Python 3.10 or higher
- Graphviz (required by the `diagrams` library)
- Poetry (for dependency management)

Install system dependencies on macOS:

```bash
brew install graphviz poetry
```

## Generate Diagrams

From the project root:

```bash
make generate-diagrams
```

This will automatically format Python code and generate the diagram to `assets/otaru-architecture.png`.

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
| atlantis.png         | [Atlantis](https://github.com/runatlantis/atlantis)                              | [Apache 2.0](https://github.com/runatlantis/atlantis/blob/main/LICENSE)              |
| backblaze.png        | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cert-manager.png     | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cilium.png           | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| cloudnative-pg.png   | [CNCF Artwork](https://github.com/cncf/artwork/blob/main/projects/cloudnativepg) | [Linux Foundation Trademark](https://github.com/cncf/artwork/blob/master/LICENSE.md) |
| external-secrets.png | [External Secrets](https://github.com/external-secrets/external-secrets)         | [Apache 2.0](https://github.com/external-secrets/external-secrets/blob/main/LICENSE) |
| falco.png            | [CNCF Artwork](https://github.com/cncf/artwork/blob/main/projects/falco)         | [Linux Foundation Trademark](https://github.com/cncf/artwork/blob/master/LICENSE.md) |
| longhorn.png         | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| unifi.png            | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
| webgazer.png         | [WebGazer](https://www.webgazer.io/)                                             | Nominative fair use                                                                  |
| wifiman.png          | [Dashboard Icons](https://github.com/homarr-labs/dashboard-icons)                | [Apache 2.0](https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE)       |
