# The manifest

The manifest is the only list of what the site holds. A guide is on the site because a page in the manifest names it, never because of the folder it is in, and guides carry no front matter: everything bearings knows about a page that is not in the guide itself is here.

It lives at `docs-site/manifest.yml` unless you pass another path to `Bearings::Rake.install(manifest:)`. Every file path in it is relative to the repo root.

## A full manifest

This one uses every key:

```yaml
site:
  name: My gem
  summary: What my gem does, in one line.
  url: https://docs.example.com
  repo: https://github.com/me/my_gem
  version: lib/my_gem/version.rb
  namespaces:
    - MyGem

watch:
  - docs

redirects:
  /guides/setup/: /guides/getting-started/

outputs:
  llms_full: true

checks:
  image_limit_kb: 200

groups:
  - label: Start here
    tone: teal
    pages:
      - source: docs/GETTING_STARTED.md
        slug: getting-started
        featured: true
        description: Install the gem and run it
      - source: docs/reference/CONFIGURATION.md
        slug: reference/configuration
        description: Every setting and its default
```

Only `site.name` and `groups` are required. bearings' own manifest is [docs-site/manifest.yml](https://github.com/bottrall/bearings/blob/main/docs-site/manifest.yml) in its repo.

## site

| Key          | Value        | Default | What it does                                                                                                                         |
| ------------ | ------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `name`       | text         |         | The site's name: the title of `llms.txt`, and `site.name` in the layout. Required.                                                    |
| `summary`    | text         | none    | One line about the site, quoted under the title of `llms.txt`.                                                                       |
| `url`        | text         | none    | The address the site is published at. Without it there is no `llms.txt`, `sitemap.xml` or `robots.txt`, and pages have no canonical URL. |
| `repo`       | text         | none    | The repo's web address. Each page's `edit_url` is `<repo>/edit/main/<source>`.                                                        |
| `version`    | text         | none    | The path of a file that sets `VERSION = '…'`. Its value is `version` in the layout; a file that sets none is a `version` problem.   |
| `namespaces` | list of text | none    | The constants the [constant check](/guides/checks.md#constant) looks for. Without any, it doesn't run.                                       |

The `url` also changes the markdown copies: an image in a copy points at its full URL on the site, so the copy still shows it when read on its own.

## groups

The site's pages, in reading order, in labelled groups. The order here is the order of the layout's navigation, of the previous and next links, of `llms.txt` and of `llms-full.txt`.

A group takes:

| Key     | Value         | What it does                       |
| ------- | ------------- | ---------------------------------- |
| `label` | text          | The group's heading. Required.     |
| `pages` | list of pages | The group's pages, in order. Required. |

A page takes:

| Key           | Value         | Default | What it does                                                                                                     |
| ------------- | ------------- | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `source`      | text          |         | The guide's path from the repo root, in any folder. Required, and unique.                                        |
| `slug`        | text          |         | The page's URL is `/guides/<slug>/`. Lowercase letters, digits and hyphens, with `/` between segments. Required, and unique. |
| `description` | text          | none    | One line about the page, for the layout and `llms.txt`. The [description check](/guides/checks.md#unlisted-and-description) requires it. |
| `featured`    | true or false | false   | A flag for the layout, which might show the page first or larger. bearings does nothing else with it.            |

The page's title is not in the manifest: it is the guide's first `# ` line.

Pages are numbered `01`, `02` and so on, in manifest order, counting separately for each folder their guides are in. The layout gets the number as `page.num`.

Any other key on a group or a page is kept as it is and handed to the layout in `extras`, so a site can carry details of its own: the `tone: teal` above is `group.extras['tone']`.

## watch

A list of folders. Every markdown file in them must be a page in the manifest, and every image in them must be shown by a guide; `rake docs:check` reports the ones that aren't. Without `watch`, a guide nobody listed goes unnoticed.

## redirects

A mapping of old path to new path, for a URL the site no longer has:

```yaml
redirects:
  /guides/setup/: /guides/getting-started/
  /guides/old-name/: /guides/new-name/#a-heading
```

Each one writes a page at the old path that sends the browser to the new one. The new path must be a page or a file the site writes, and the old one must not be; [The checks](/guides/checks.md#redirect) lists what is reported when they are wrong.

## outputs

| Key         | Value         | Default | What it does                                                                     |
| ----------- | ------------- | ------- | -------------------------------------------------------------------------------- |
| `llms_full` | true or false | false   | Also writes `/llms-full.txt`, every guide's markdown copy in one file.           |

## checks

| Key              | Value          | Default | What it does                                      |
| ---------------- | -------------- | ------- | ------------------------------------------------- |
| `image_limit_kb` | a whole number | 300     | The largest an image a guide shows may be, in KB. |

## When the manifest is wrong

A manifest that can't be read stops the build before anything is written. Every problem in it is reported at once, as a `manifest` problem on the line it is on:

| Message                                                                   | What it means                                                                                         |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| was not found                                                             | There is no file at the manifest's path.                                                              |
| the manifest is empty                                                     | The file has no YAML in it.                                                                           |
| the manifest is not valid YAML                                            | The YAML parser's own message follows.                                                                |
| the manifest holds only text, numbers, true or false, lists and mappings | A date, a `:symbol`, a YAML tag or an alias. Quote a date or a symbol to make it text.                |
| … must be a mapping                                                       | The manifest, `site`, `outputs`, `checks`, a group or a page is not a mapping.                       |
| … is missing `key`                                                        | A required key is missing, or has no value.                                                           |
| … has an unknown key `key`                                                | A key the manifest, `site`, `outputs` or `checks` doesn't take. The hint lists the ones it does.     |
| `key` must be …                                                           | A value of the wrong kind, such as a list where text belongs.                                         |
| slug `slug` is not URL-safe                                               | A slug with a capital, a space, a leading `/` or another character outside the allowed ones.         |
| duplicate slug `slug`, first used on line n                               | Two pages share a slug.                                                                               |
| duplicate source `source`, first used on line n                           | Two pages share a guide.                                                                              |
