# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::Images do
  def image(src, alt: 'Flow', line: 3) = Bearings::Document::Image.new(src:, alt:, line:)

  def page(*images)
    Bearings::Site::Page.new(
      title: '',
      slug: 'start',
      description: nil,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: '/guides/start/',
      markdown_url: '/guides/start.md',
      canonical_url: nil,
      source_path: 'docs/START.md',
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title: '', headings: [], links: [], code_blocks: [], code_spans: [], images:, diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def site(*images)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages: [page(*images)]
    )
  end

  def check(*shown, images: { 'docs/flow.png' => 'png' }, watched: [], limit_kb: 300)
    Bearings::Checks::Images.call(site: site(*shown), images:, watched:, limit_kb:)
  end

  def kb(count) = 'x' * (count * 1024)

  describe '.call' do
    it 'passes an image that is present, described and small enough' do
      assert_empty check(image('flow.png'))
    end

    it 'reports an image with empty alt text' do
      undescribed = Bearings::Problem.new(
        check: 'image',
        level: :error,
        file: 'docs/START.md',
        line: 3,
        message: 'shows an image with no alt text',
        hint: 'describe the image in its alt text; it is all an agent or a screen reader gets'
      )

      assert_equal [undescribed], check(image('flow.png', alt: ''))
    end

    it 'reports an image whose alt text is only whitespace' do
      assert_equal ['shows an image with no alt text'], check(image('flow.png', alt: ' ')).map(&:message)
    end

    it 'leaves the alt text of a <source> to the <img> beside it' do
      assert_empty check(image('flow.png', alt: nil))
    end

    it 'reports an <img> with no alt text once for all the URLs in its src and srcset' do
      assert_equal ['shows an image with no alt text'],
                   check(image('flow.png', alt: ''), image('flow.png', alt: '')).map(&:message)
    end

    it 'reports an image whose file does not exist' do
      missing = Bearings::Problem.new(
        check: 'image',
        level: :error,
        file: 'docs/START.md',
        line: 3,
        message: 'shows `images/gone.png`, which was not found',
        hint: 'add the image at docs/images/gone.png, or fix the path'
      )

      assert_equal [missing], check(image('images/gone.png'))
    end

    it 'leaves an image that is not a repo path alone' do
      assert_empty check(image('data:image/png;base64,iVBORw0KGgo='))
    end

    it 'reports an image larger than the limit' do
      oversized = Bearings::Problem.new(
        check: 'image',
        level: :error,
        file: 'docs/START.md',
        line: 3,
        message: 'shows `flow.png`, which is 301 KB, over the 300 KB limit',
        hint: 'shrink or compress the image; guides may ship inside a gem, where every image adds to the download'
      )

      assert_equal [oversized], check(image('flow.png'), images: { 'docs/flow.png' => "#{kb(300)}x" })
    end

    it 'passes an image exactly at the limit' do
      assert_empty check(image('flow.png'), images: { 'docs/flow.png' => kb(300) })
    end

    it 'reports an image larger than a custom limit' do
      assert_equal ['shows `flow.png`, which is 2 KB, over the 1 KB limit'],
                   check(image('flow.png'), images: { 'docs/flow.png' => kb(2) }, limit_kb: 1).map(&:message)
    end

    it 'passes an image under a custom limit the default would reject' do
      assert_empty check(image('flow.png'), images: { 'docs/flow.png' => kb(400) }, limit_kb: 500)
    end

    it 'warns about an image loaded from another site' do
      remote = Bearings::Problem.new(
        check: 'image',
        level: :warning,
        file: 'docs/START.md',
        line: 3,
        message: 'loads `https://cdn.example/flow.png` from another site',
        hint: 'add the image to the repo and point at it by a relative path; ' \
              'a remote image breaks offline and in the gem'
      )

      assert_equal [remote], check(image('https://cdn.example/flow.png'))
    end

    it 'warns about an image loaded by a protocol-relative URL' do
      assert_equal [:warning], check(image('//cdn.example/flow.png')).map(&:level)
    end

    it 'reports an image in a watched folder that no guide shows' do
      unused = Bearings::Problem.new(
        check: 'image',
        level: :error,
        file: 'docs/old.png',
        line: 1,
        message: 'is in a watched folder but no guide shows it',
        hint: 'show it in a guide, or delete it'
      )

      assert_equal [unused], check(image('flow.png'), watched: ['docs/flow.png', 'docs/old.png'])
    end

    it 'reports an unused image whose extension is upper case' do
      assert_equal ['docs/OLD.PNG'], check(image('flow.png'), watched: ['docs/OLD.PNG']).map(&:file)
    end

    it 'ignores a watched file that is not an image' do
      assert_empty check(image('flow.png'), watched: ['docs/START.md'])
    end
  end
end
