LibreCrawl is a self-hosted website crawler for SEO audits. Crawl sites from
your own server, review the results in a web interface, and export them or
drive crawls through the REST API.

### Features

* **Page audit:** status code, title, meta description, headings, word count,
  response time, OpenGraph and Twitter tags, and JSON-LD structured data for
  every URL.
* **Issues:** errors and warnings from SEO, content, performance,
  accessibility, indexability and duplicate-content checks.
* **Links:** internal and external links with their status codes, anchor text
  and placement (navigation, body or footer).
* **Site structure:** an interactive graph of the links between pages,
  coloured by response status.
* **History and export:** saved crawls you can reload, with exports to CSV,
  Excel, JSON or XML.
* **JavaScript rendering:** optional Chromium rendering for sites that build
  their pages in the browser. Off by default.

### This package

* Only accounts created by the operator can sign in. Registration and guest
  access are disabled.
* Users, settings and crawls are stored in SQLite under `/app/data` and
  included in Cloudron backups. The database is snapshotted before a new
  LibreCrawl version migrates it.
* A daily task removes finished crawls older than 90 days. The period can be
  changed.
* Memory defaults to 2 GiB, enough for one large HTML crawl at a time. Allow
  4 GiB for several large crawls in the same hour, or for JavaScript rendering
  beyond small sites.

**Security:** anyone who can sign in can make the server crawl any address it
can reach, including private networks and other apps on this Cloudron. Create
accounts only for people and sites you trust.

[LibreCrawl](https://github.com/PhialsBasement/LibreCrawl) is open source under
the MIT licence. This package is maintained independently of the LibreCrawl
project.
