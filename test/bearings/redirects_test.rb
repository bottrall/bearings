# frozen_string_literal: true

require 'test_helper'

describe Bearings::Redirects do
  def site
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages: [page]
    )
  end

  def page
    Bearings::Site::Page.new(
      title: 'Start',
      slug: 'start',
      description: nil,
      group_label: 'Start here',
      featured: false,
      num: '01',
      url: '/guides/start/',
      markdown_url: '/guides/start.md',
      canonical_url: nil,
      source_path: 'docs/START.md',
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: nil,
      extras: {}
    )
  end

  def redirect(from, to, line = 4)
    Bearings::Manifest::Redirect.new(from:, to:, line:)
  end

  def html(to = '/guides/start/', url: nil)
    Bearings::Redirects.files([redirect('/old/', to)], url).first.content
  end

  def problems(*redirects, paths: [])
    Bearings::Redirects.problems(redirects, site, paths:, file: 'docs-site/manifest.yml')
  end

  def problem(message, hint, line = 4)
    Bearings::Problem.new(check: 'redirect', level: :error, file: 'docs-site/manifest.yml', line:, message:, hint:)
  end

  describe '.files' do
    it 'writes each stub to index.html under its old path' do
      assert_equal %w[old/index.html api/v1/index.html],
                   Bearings::Redirects.files([redirect('/old/', '/'), redirect('/api/v1/', '/')], nil).map(&:path)
    end

    it 'writes an old path with no trailing slash to the same file' do
      assert_equal ['old/index.html'], Bearings::Redirects.files([redirect('/old', '/')], nil).map(&:path)
    end

    it 'gives the new path under the site URL as the canonical link' do
      assert_includes html(url: 'https://bearings.example/'), '<link rel="canonical" href="https://bearings.example/guides/start/">'
    end

    it 'gives the new path as the canonical link when the site has no URL' do
      assert_includes html, '<link rel="canonical" href="/guides/start/">'
    end

    it 'refreshes to the new path' do
      assert_includes html, '<meta http-equiv="refresh" content="0; url=/guides/start/">'
    end

    it 'links to the new path in the body' do
      assert_includes html, '<a href="/guides/start/">/guides/start/</a>'
    end

    it 'escapes the new path' do
      assert_includes html('/search/?q=a&b="c"'), '<a href="/search/?q=a&amp;b=&quot;c&quot;">'
    end
  end

  describe '.problems' do
    it 'reports an old path that is a page of the site' do
      assert_equal(
        [problem(
          'redirect from `/guides/start` would replace a page of the site',
          'remove the redirect; only a URL the site no longer has needs one'
        )],
        problems(redirect('/guides/start', '/llms.txt'), paths: ['llms.txt'])
      )
    end

    it 'reports an old path that is a file the site writes' do
      assert_equal ['redirect from `/` would replace a page of the site'],
                   problems(redirect('/', '/guides/start/'), paths: ['index.html']).map(&:message)
    end

    it 'reports a new path that is another redirect, and not as missing' do
      assert_equal(
        [problem('redirect from `/older/` points to `/old/`, another redirect', 'point it at `/guides/start/`', 5)],
        problems(redirect('/old/', '/guides/start/'), redirect('/older/', '/old/', 5))
      )
    end

    it 'reports a new path that is not a page or file in the site' do
      assert_equal(
        [problem(
          'redirect from `/old/` points to `/gone/`, which is not a page or file in the site',
          'point it at a page URL such as `/guides/<slug>/`, or at a file the site writes'
        )],
        problems(redirect('/old/', '/gone/'))
      )
    end

    it 'accepts a new path that is a page of the site' do
      assert_empty problems(redirect('/old/', '/guides/start/'))
    end

    it 'accepts a new path to a page with a fragment' do
      assert_empty problems(redirect('/old/', '/guides/start/#install'))
    end

    it 'accepts a new path that is a file the site writes' do
      assert_empty problems(redirect('/old/', '/guides/start.md'), paths: ['guides/start.md'])
    end

    it 'accepts a new folder path whose index.html the site writes' do
      assert_empty problems(redirect('/old/', '/api/'), paths: ['api/index.html'])
    end
  end
end
