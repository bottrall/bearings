# Getting started

Install the gem and point it at your guides. See [the manifest](MANIFEST.md#groups) for the full list.

## Install

```ruby
gem 'bearings', '~> 0.1'
```

Then run `bundle install`.

## Configure the `manifest` & guides

| Key       | What it does                          |
| --------- | ------------------------------------- |
| `groups`  | the [reading order](ORDER.md)         |
| `title`   | the site's name, shown on every page  |

> [!NOTE]
> Every guide starts with a `# ` title line.

![The build pipeline](images/pipeline.png)

```mermaid
graph LR
  guides --> site
```

```json
{ "title": "Docs" }
```

## Install

Read more at <https://example.com/docs>.
