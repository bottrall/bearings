# bearings

A themeless docs engine: plain markdown guides in, a checked static site and llms.txt out.

You write the guides as plain markdown that reads the same on GitHub, list them in one manifest, and write the layout that gives the site its look. bearings builds the pages, a markdown copy of each, `llms.txt`, a search index and a sitemap, and checks every link, anchor, code example, constant name, image and diagram in them. If the check passes, the site is correct.

## Installation

Add the gem to your `Gemfile`:

```ruby
gem 'bearings'
```

Requires Ruby 3.3 or later.

## Usage

Add two lines to your `Rakefile`:

```ruby
require 'bearings/rake'
Bearings::Rake.install
```

Then `bundle exec rake docs` builds the site into `_site/`, and `bundle exec rake docs:check` builds and checks it.

## Guides

The guides are at [bearings.bottrall.dev](https://bearings.bottrall.dev), built by bearings from the markdown in this repo's `docs/` folder. Start with [Getting started](docs/GETTING_STARTED.md).

[CONTRIBUTING.md](CONTRIBUTING.md) explains the setup and the `bin/` scripts. Released under the [MIT License](LICENSE).
