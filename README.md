# cloudron-librecrawl-app

<!-- aidevops:badges:start -->
<!-- managed by aidevops badges; edit the template, not this block -->
[![GitHub Actions](https://github.com/marcusquinn/cloudron-librecrawl-app/actions/workflows/loc-badge.yml/badge.svg?branch=main)](https://github.com/marcusquinn/cloudron-librecrawl-app/actions/workflows/loc-badge.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/marcusquinn/cloudron-librecrawl-app/blob/main/LICENSE)

[![Lines of code](docs/metrics/badges/loc.svg)](docs/metrics/repo-metrics.md)
[![Dependencies](docs/metrics/badges/dependencies.svg)](docs/metrics/repo-metrics.md)

[![Languages by lines of code](docs/metrics/badges/languages.svg)](docs/metrics/repo-metrics.md)
<!-- aidevops:badges:end -->
LibreCrawl self-hosted SEO crawler - Cloudron app package

[LibreCrawl](https://github.com/PhialsBasement/LibreCrawl) on Cloudron: an
always-on crawler server that WordPress sites running SEO Pro Stats can sign
in to, crawl themselves on a schedule and import the results.

| Component | Baseline |
| --- | --- |
| Package | 0.1.0 |
| LibreCrawl | Commit `05a1372de8334ca18dec0bc1f7470c62901a9418` (MIT) |
| Cloudron | v9.1.0+ |
| Memory | 2 GiB; increase for Chromium rendering |

Registration and guest access are disabled. Accounts are created by the
operator; no Cloudron proxy authentication blocks REST clients. Session signing
and all database state persist under `/app/data`. A daily retention task removes
finished crawls older than 90 days by default. Chromium rendering is available
but disabled by default; Firefox and WebKit are not installed.

**Network warning:** signed-in users can crawl private addresses, other apps
and the host's Docker network. LibreCrawl has no private-address filter.
Create accounts only for trusted operators and trusted WordPress sites.

- [Install, sign in and administer accounts](docs/README.md)
- [Runtime decisions and upstream limitations](docs/PACKAGING-NOTES.md)
- [Publishing and operator qualification](docs/PUBLISHING.md)
- [Security policy](SECURITY.md)

Build locally with `docker build --platform linux/amd64 -t librecrawl-cloudron:dev .`.
Run `bash test/package-test.sh` and the checks in [CONTRIBUTING.md](CONTRIBUTING.md)
before opening a PR. Image and catalog publication are opt-in operator actions;
the repository contains no hand-written version catalog.

<!-- aidevops:managed-readme:start -->
<!-- managed by aidevops; refresh with managed-readme-helper.sh sync -->
## Star History

![marcusquinn/cloudron-librecrawl-app stars over time](docs/assets/star-history.svg)

## Built with aidevops

This project was created and is maintained with
[aidevops.sh](https://aidevops.sh).

[View marcusquinn on GitHub](https://github.com/marcusquinn) ·
[aidevops repository](https://github.com/marcusquinn/aidevops)
<!-- aidevops:managed-readme:end -->
