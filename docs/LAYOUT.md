# The layout

bearings has no theme and never will. The look of a site belongs to the repo that builds it, in a few files beside the manifest:

| File               | What it is                                                                                                      |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `layout.html.erb`  | The template every guide is rendered through. Required.                                                         |
| `index.html.erb`   | The template for the landing page, `/index.html`. Required.                                                     |
| `404.html.erb`     | The template for the 404 page, `/404.html`, shown for an address the site doesn't have. Optional.               |
| `_<name>.html.erb` | A [partial](#partials): markup the templates share. Never copied into the site.                                 |
| anything else      | Copied into the site as it is, at the same path, hidden files (names starting with `.`) excepted: stylesheets, scripts, fonts, icons, a `CNAME`.  |

If either required template is missing, the build reports a `layout` problem, `was not found`, and writes no HTML pages and none of the files beside the templates; the other outputs are still written.

## How the templates run

Each is ERB, with `-` trimming: a line that starts with `<%-` and ends with `-%>` leaves nothing behind, so a loop leaves no blank lines.

Nothing is escaped for you. `<%= %>` writes a value exactly as it is, which is what `body` needs, since it is HTML. Titles and descriptions come from your own guides and manifest; if one may hold a `<` or an `&`, escape it with `ERB::Util.h`.

A template is Ruby, so a mistake in one raises when it runs. `rake docs:serve` prints the error and keeps serving the last good site.

## What every template gets

| Name      | What it is                                                                                                        |
| --------- | ----------------------------------------------------------------------------------------------------------------- |
| `site`    | The manifest's `site` block: `site.name`, `site.summary`, `site.url`, `site.repo`, `site.version` (the version file's path) and `site.namespaces`. A key the manifest leaves out is `nil`, or an empty list for `namespaces`. |
| `version` | The version read from the file `site.version` names, such as `'1.2.0'`, or `nil` without one.                     |
| `groups`  | The groups, in manifest order. Each has a `label`, its `pages` in order, and `extras`.                            |
| `pages`   | Every page, in reading order.                                                                                     |
| `render`  | Renders a [partial](#partials): `render.call('masthead')` is the HTML of `_masthead.html.erb`.                    |

## What the layout gets as well

| Name               | What it is                                                                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------- |
| `page`             | The page being rendered.                                                                                  |
| `body`             | The guide as HTML, without its `# ` title line, which the layout shows from `page.title`.                 |
| `toc`              | One `{ id:, title: }` hash for each `##` heading in the body, in order. The title is the heading's HTML with its tags removed. |
| `prev_page`        | The page before this one in reading order, or `nil` on the first.                                         |
| `next_page`        | The page after this one, or `nil` on the last.                                                            |
| `search_index_url` | `/search.json`, the [search index](OUTPUTS.md#searchjson), for a layout that offers search.               |

## A page

| Field           | What it is                                                                                         |
| --------------- | -------------------------------------------------------------------------------------------------- |
| `title`         | The text of the guide's first `# ` line.                                                           |
| `description`   | The page's description from the manifest.                                                         |
| `slug`          | The page's slug from the manifest.                                                                 |
| `url`           | `/guides/<slug>/`.                                                                                 |
| `markdown_url`  | `/guides/<slug>.md`, the page's [markdown copy](OUTPUTS.md#markdown-copies).                       |
| `canonical_url` | The page's full URL under `site.url`, or `nil` without one.                                        |
| `edit_url`      | The guide's edit link under `site.repo`, or `nil` without one.                                     |
| `source_path`   | The guide's path from the repo root.                                                               |
| `group_label`   | The label of the page's group.                                                                     |
| `num`           | The page's two-digit number, such as `'03'`; [The manifest](MANIFEST.md#groups) says how it counts. |
| `featured`      | The page's `featured` flag from the manifest.                                                      |
| `extras`        | The page's other keys from the manifest, as a hash with string keys.                               |
| `diagrams?`     | Whether the guide has a Mermaid diagram, so the layout loads Mermaid only where it is needed.     |

Pages are compared by value, so `p == page` picks out the current page in a loop over `pages`.

## What the body holds

The body is kramdown's HTML for the guide, read as GitHub-flavoured markdown, with these changes:

- A link to another guide, such as `[the checks](CHECKS.md#redirect)`, points at that guide's page, `/guides/checks/#redirect`. A link to a markdown file that is not a page is reported as a [`link` problem](CHECKS.md#problems-in-every-build).
- Every heading has an `id`, made the way GitHub makes them, so a link to a heading works in both places.
- Code blocks in a language Rouge highlights are a `div` with the classes `language-<name> highlighter-rouge`, holding a `div class="highlight"` and then a `pre class="highlight"`; a block with no language, a `text` or `plaintext` one, or one Rouge doesn't know is a bare `pre` holding a `code` (with the class `language-<name>` when it names a language), so a layout styles both shapes. The tokens are `span`s with Rouge's short class names. The layout's stylesheet colours them; `rougify style github` prints one such stylesheet.
- An alert block, a quote that starts with `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]`, becomes a `div` with the classes `alert alert-note` (or `-tip`, and so on), holding a `p class="alert-title"` with the kind's name and then the quote's text.
- A Mermaid diagram becomes a `pre class="mermaid"` holding its source, and an image points at its copy under `/assets/`; [Diagrams and images](DIAGRAMS_AND_IMAGES.md) covers both.

The body holds only structure and class names. How an alert or a code block looks is the stylesheet's job.

## The landing page

`index.html.erb` becomes `/index.html`. It gets `site`, `version`, `groups`, `pages` and `render`, but no `page` or `body`: it is not a guide. A landing page usually says what the project is and lists the guides with their descriptions.

## The 404 page

`404.html.erb` becomes `/404.html`: `rake docs:serve` answers a path the site doesn't have with it, and GitHub Pages does the same. Like the landing page, it gets `site`, `version`, `groups`, `pages` and `render`, so it can show the version and list the guides. It is shown at whatever address was asked for, so start its links with `/`.

The template is optional. A 404 page that needs none of those values can be a plain `404.html`, copied like the other files beside the templates. A site with both would write `/404.html` twice, so the build reports an [`output` problem](CHECKS.md#problems-in-every-build).

## Partials

A partial is markup that more than one template shows, such as a site header, written once. It is a file named `_<name>.html.erb` in the manifest's folder, and `render.call('<name>')` gives its HTML to the template that asks:

```erb
<body>
  <%= render.call('masthead') %>
```

`_masthead.html.erb` is ERB like the templates, and gets every value the template rendering it has: `page` and `body` from the layout, but not from the landing page or the 404 page. It gets `render` too, so a partial can render another.

Values given after the name go to the partial as well, in place of any the template has under the same name:

```erb
<%= render.call('head', title: page.title) %>
```

Here `_head.html.erb` can use `title`, so each template gives the one partial its own.

Only a file in the manifest's folder itself is a partial; one in a subfolder is copied like any other file. Rendering a partial that has no file raises a `KeyError` naming the file.

## The files beside them

Every other file in the manifest's folder, in any subfolder, except partials and hidden files (names starting with `.`), is copied into the site at the same path: `docs-site/site.css` is served at `/site.css`, `docs-site/fonts/body.woff2` at `/fonts/body.woff2`. Point at them from the templates by those paths.

## bearings' own layout

bearings builds its own site from these guides, with a layout written only against what this guide describes: [layout.html.erb](https://github.com/bottrall/bearings/blob/main/docs-site/layout.html.erb), [index.html.erb](https://github.com/bottrall/bearings/blob/main/docs-site/index.html.erb), the partials they share, [_head.html.erb](https://github.com/bottrall/bearings/blob/main/docs-site/_head.html.erb) and [_masthead.html.erb](https://github.com/bottrall/bearings/blob/main/docs-site/_masthead.html.erb), [site.css](https://github.com/bottrall/bearings/blob/main/docs-site/site.css) and [404.html.erb](https://github.com/bottrall/bearings/blob/main/docs-site/404.html.erb). It is not a theme, and the gem does not ship it: copy what is useful.
