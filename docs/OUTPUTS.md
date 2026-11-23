# The outputs

Every build writes the whole site into `_site/` at the repo root. Each output is made from the manifest, the guides and the images they show, the templates and the files beside them, and nothing else, so the same sources always build the same site.

| Path                         | What it is                                                     | Written when                                    |
| ---------------------------- | -------------------------------------------------------------- | ----------------------------------------------- |
| `index.html`                 | The landing page, from `index.html.erb`                        | both templates are there                        |
| `guides/<slug>/index.html`   | Each guide, through `layout.html.erb`                          | both templates are there                        |
| `guides/<slug>.md`           | Each guide's markdown copy                                     | always                                          |
| `assets/<path>`              | Each image a guide shows, at its path from the repo root       | always                                          |
| any other path               | Each other file beside the manifest, at the same path          | both templates are there                        |
| `llms.txt`                   | The index of the guides for agents                             | `site.url` is set                               |
| `llms-full.txt`              | Every guide's markdown copy in one file                        | `outputs.llms_full` is true                     |
| `sitemap.xml` and `robots.txt` | The page list for search engines                             | `site.url` is set                               |
| `<old path>/index.html`      | A redirect stub for each of the manifest's `redirects`         | always                                          |
| `search.json`                | The search index                                               | always                                          |

A build deletes any file in `_site/` it did not write this time, and any folder left empty, so `_site/` always holds exactly one build. If two outputs would write the same path, such as a redirect stub and a file copied from beside the manifest, the build reports an `output` problem and writes nothing.

## HTML pages

Each guide is rendered through the layout at `/guides/<slug>/`, and the landing page at `/`. [The layout](LAYOUT.md) is the contract for both: what each template is given and what the body holds.

## Markdown copies

Each guide is also written as markdown, at `/guides/<slug>.md`, for agents and for anyone who would rather read the source. A copy is the guide as written, with two kinds of change:

- A link to another guide points at that guide's copy, keeping its `#fragment`: `[the checks](CHECKS.md#image)` becomes `[the checks](/guides/checks.md#image)`.
- An image points at its copy on the site: its full URL under `site.url`, or its `/assets/` path without one.

Everything else is kept byte for byte, including code blocks, code spans, alert blocks and Mermaid fences. A link-shaped string inside a code span or a code block is left alone.

## llms.txt

`/llms.txt` tells an agent what documentation exists and where to read it as markdown. It is generated from the manifest, so it can't drift from the guides:

```text
# bearings

> A themeless docs engine: plain markdown guides in, a checked static site and llms.txt out.

## Start here

- [Getting started](https://bearings.bottrall.dev/guides/getting-started.md): Install bearings, add the two Rakefile lines and build a first site
```

It has `site.name` as its title, `site.summary` quoted beneath, and a section for each group, listing each page's title, the full URL of its markdown copy and its description. Without a `site.url` it can't give full URLs, so it is not written, and the build reports an `llms` warning.

With `outputs.llms_full: true`, `/llms-full.txt` holds every guide's markdown copy, in reading order, each ending in a newline and separated from the next by a blank line. It needs no `site.url`.

## search.json

`/search.json` is the data for a search box in the layout. bearings writes the index and nothing else: the search box and its script are the layout's.

It is a JSON array with an entry for each section of each page, in reading order. Here is one entry, with its text cut short:

```json
[
  {
    "title": "The outputs",
    "heading": "search.json",
    "text": "/search.json is the data for a search box in the layout.",
    "url": "/guides/outputs/#searchjson"
  }
]
```

| Field     | What it is                                                                                          |
| --------- | --------------------------------------------------------------------------------------------------- |
| `title`   | The page's title.                                                                                   |
| `heading` | The section's heading, or `null` for the text before a page's first heading.                        |
| `text`    | The section's text, with the markup removed and the whitespace collapsed. Code blocks are included. |
| `url`     | The section's URL, with the heading's `id` as its fragment; the page's URL for the text before it.  |

Any heading, of any level, starts a new section. The layout is given the index's path as `search_index_url`.

## sitemap.xml and robots.txt

`/sitemap.xml` lists the site's root URL and each page's canonical URL, in reading order. `/robots.txt` allows everything and points at the sitemap:

```text
User-agent: *
Allow: /

Sitemap: https://bearings.bottrall.dev/sitemap.xml
```

Both need full URLs, so without a `site.url` neither is written, and the build reports a `sitemap` warning.

## Redirect stubs

Each of the manifest's `redirects` writes a small HTML page at the old path, `/guides/setup/` writing `guides/setup/index.html`. The page sends the browser on to the new path at once, with a refresh `meta` tag, names the new path's full URL under `site.url` (or the path itself, without one) as its canonical link, and links to it for anyone whose browser doesn't follow the refresh.

`rake docs:check` reports a redirect that points nowhere, one that points at another redirect, and one that would replace a page; [The checks](CHECKS.md#redirect) has the details.

## Images

Each image a guide shows is copied to `/assets/<path>`, where `<path>` is its path from the repo root. [Diagrams and images](DIAGRAMS_AND_IMAGES.md#images) covers what else is done to an image on its way into a page.
