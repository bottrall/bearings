# The checks

If `rake docs:check` passes, the site is correct: every guide is listed, every link and anchor resolves in every output, every example parses, every constant a guide names exists, and every image and diagram is there and described. When it fails, each problem names the markdown source and line to fix.

A run reports every problem it finds, from every step it could reach, and exits with status 1 if any of them is an error. A warning is printed but doesn't fail the run.

> [!IMPORTANT]
> No check can be turned off. A check that raises a false alarm is a bug in bearings: [report it](https://github.com/bottrall/bearings/issues), rather than working around it in the guide.

## Reading a report

Each problem is printed with its file, its line, the check that found it, what is wrong, and a hint on the line below. They are sorted by file, then line:

```text
docs/GUIDE.md:12: [image] shows an image with no alt text
  describe the image in its alt text; it is all an agent or a screen reader gets
docs/GUIDE.md:30: [anchor] links to `#instal`, but guides/guide/index.html has no id `instal`
  point the fragment at an id on that page, such as a heading's
```

With `FORMAT=json`, the same problems are printed as one JSON array, `[]` when there are none:

```json
[
  {
    "check": "image",
    "level": "error",
    "file": "docs/GUIDE.md",
    "line": 12,
    "message": "shows an image with no alt text",
    "hint": "describe the image in its alt text; it is all an agent or a screen reader gets"
  }
]
```

`level` is `error` or `warning`, and `hint` may be `null`.

## Problems in every build

These come from building the site, so `rake docs` and `rake docs:serve` report them too:

| Check      | Level   | Message                                                                     | What to do                                                                  |
| ---------- | ------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `manifest` | error   | was not found, or a problem in the manifest                                 | [When the manifest is wrong](/guides/manifest.md#when-the-manifest-is-wrong) lists them all |
| `layout`   | error   | was not found                                                               | Add `layout.html.erb` and `index.html.erb` beside the manifest              |
| `source`   | error   | is listed in the manifest but was not found                                 | Add the guide, or remove its page from the manifest                         |
| `title`    | error   | has no "# " title line                                                      | Start the guide with a `# Title` line                                       |
| `version`  | error   | has no version                                                              | Set `VERSION = '…'` in the file, or point `site.version` at the one that does |
| `link`     | error   | links to `FILE.md`, which is not a page                                     | Point the link at a guide the manifest lists, or list that guide            |
| `llms`     | warning | has no `site.url`, so llms.txt was not written                              | Set `site.url`                                                              |
| `sitemap`  | warning | has no `site.url`, so sitemap.xml and robots.txt were not written           | Set `site.url`                                                              |
| `output`   | error   | n output files have this path                                               | Give each output its own path                                               |

A guide may link to any markdown file GitHub can show, but on the site only a guide the manifest lists has a page, so a link to any other markdown file is a `link` problem. Link to a file outside the guides by its full URL on GitHub instead.

The rest of this guide covers the checks only `rake docs:check` runs.

## unlisted and description

Every markdown file in a folder the manifest [watches](/guides/manifest.md#watch) must be a page, and every page needs a description.

| Check         | Level | Message                                                       |
| ------------- | ----- | ------------------------------------------------------------- |
| `unlisted`    | error | is in a watched folder but no page in the manifest lists it   |
| `description` | error | has no description in the manifest                            |

## code

Every fenced `ruby`, `json` and `yaml` block in a guide must parse: Ruby with Prism, JSON with Ruby's JSON parser, and YAML with Psych, which accepts any valid YAML, aliases and dates included. A block in any other language is not checked, nor is an indented one.

| Check  | Level | Message                                                   |
| ------ | ----- | --------------------------------------------------------- |
| `code` | error | the ruby example does not parse: what the parser reported |

The line is the line of the error, not of the fence. Show code you left out as a comment, not as `...`, which is seldom valid where it stands.

## constant

With `site.namespaces` set, every constant under those namespaces that a guide names must be declared in the repo's RBS signatures, in `sig/`. A renamed or deleted class is then a failing check rather than a stale guide.

The check reads every fenced `ruby` block and every inline code span, as Ruby, so `` `MyGem::Client.new` `` in a sentence counts as naming `MyGem::Client`. Only names under a listed namespace are checked, the namespace itself included; a constant a `ruby` block on the same page defines counts as declared. It needs the `rbs` gem, and without `site.namespaces` it doesn't run.

| Check      | Level | Message                                                          |
| ---------- | ----- | ---------------------------------------------------------------- |
| `constant` | error | names `MyGem::Clinet`, which the RBS signatures do not declare   |

The hint suggests the closest declared name, if one is close.

## diagram

Every Mermaid diagram must have a type and a title. [Diagrams and images](/guides/diagrams-and-images.md#mermaid-diagrams) explains why.

| Check     | Level   | Message                                                                |
| --------- | ------- | ---------------------------------------------------------------------- |
| `diagram` | error   | has an empty diagram                                                   |
| `diagram` | error   | has a diagram whose first line names no Mermaid diagram type           |
| `diagram` | warning | has a diagram with no accTitle line, the alt text that describes it    |

The first line may come after Mermaid front matter and `%%` comment lines, as Mermaid allows.

## image

Every image a guide shows must be there, described and small enough, and every image in a watched folder must be shown.

| Check   | Level   | Message                                                          |
| ------- | ------- | ---------------------------------------------------------------- |
| `image` | error   | shows an image with no alt text                                  |
| `image` | error   | shows `images/flow.png`, which was not found                     |
| `image` | error   | shows `images/flow.png`, which is 412 KB, over the 300 KB limit  |
| `image` | warning | loads `https://example.com/flow.png` from another site           |
| `image` | error   | is in a watched folder but no guide shows it                     |

The limit is the manifest's `checks.image_limit_kb`. In a watched folder, a file is an image if it ends in `.avif`, `.gif`, `.jpeg`, `.jpg`, `.png`, `.svg` or `.webp`.

## redirect

Each of the manifest's `redirects` must lead somewhere. Each problem is reported on the redirect's line in the manifest.

| Check      | Level | Message                                                                                            |
| ---------- | ----- | -------------------------------------------------------------------------------------------------- |
| `redirect` | error | redirect from `/old/` would replace a page of the site                                             |
| `redirect` | error | redirect from `/old/` points to `/new/`, another redirect                                          |
| `redirect` | error | redirect from `/old/` points to `/new/`, which is not a page or file in the site                   |

For a redirect to another redirect, the hint names the path to point at instead.

## link and anchor

Every internal link in every output must lead to a file the site writes, and every `#fragment` in an HTML page must name an `id` on the page it points at. The check reads:

- each guide's HTML page, including the links the layout adds;
- each guide's markdown copy;
- the landing page;
- `llms.txt`.

A link with a scheme, such as `https:` or `mailto:`, or one starting with `//`, is external and not checked here. A full URL under `site.url` is internal and checked like any other. A link shown as code is text, not a link.

| Check    | Level | Message                                                                    |
| -------- | ----- | -------------------------------------------------------------------------- |
| `link`   | error | links to `/guides/gone/`, which is not a file in the site                  |
| `link`   | error | its copy guides/start.md links to `/gone.md`, which is not a file in the site |
| `anchor` | error | links to `/guides/start/#instal`, but guides/start/index.html has no id `instal` |

Each problem points at the line it was written on: the guide's line for a link in a guide, line 1 of `layout.html.erb` for a link the layout adds, of `index.html.erb` for one on the landing page, and of the manifest for one in `llms.txt`.

## The README's links

When the repo has a `README.md`, its relative links must lead to files in the repo, and its anchors to headings that exist: one of its own, or one on the page of a guide it links to. These are reported in `README.md` as `link` and `anchor` problems:

| Check    | Level | Message                                                                   |
| -------- | ----- | ------------------------------------------------------------------------- |
| `link`   | error | links to `docs/GONE.md`, which is not a file in the repo                  |
| `anchor` | error | links to `LICENSE#terms`, an anchor in a file that is not a guide         |
| `anchor` | error | links to `docs/START.md#instal`, but guides/start/index.html has no id `instal` |

## External links

`rake docs:check` never makes a network request. `rake docs:check:external` is the check that does: it requests every `http` and `https` link in the guides, each distinct URL once, following up to five redirects and waiting up to ten seconds for each.

| Check            | Level   | Message                                                       |
| ---------------- | ------- | ------------------------------------------------------------- |
| `external-links` | error   | https://example.com/gone returned HTTP 404                    |
| `external-links` | error   | https://example.com/ could not be fetched: why it failed      |
| `external-links` | warning | https://example.com/ could not be fetched: timed out after 10s |

A timeout is only a warning, since the site may just be slow. Run it now and then, or on a schedule, rather than on every change: a site that is down for a minute shouldn't fail a build.
