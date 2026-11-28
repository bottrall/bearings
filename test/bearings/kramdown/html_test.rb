# frozen_string_literal: true

require 'test_helper'

describe Bearings::Kramdown::Html do
  def lexer(token)
    Class.new(Rouge::RegexLexer) { state(:root) { rule(/.+/m, token) } }
  end

  def class_name = lexer(Rouge::Token::Tokens::Name::Class)

  def html(markdown, lexers)
    Bearings::Kramdown::Html.convert(Kramdown::Document.new(markdown, input: 'GFM').root, lexers:).first
  end

  describe '#highlight_code' do
    it 'leaves a block with no language plain' do
      assert_equal "<pre><code>x\n</code></pre>\n", html("```\nx\n```\n", 'plaintext' => class_name)
    end

    it 'highlights a block with the lexer the mapping names for its language' do
      assert_includes html("```ruby\nx\n```\n", 'ruby' => class_name), %(<span class="nc">x\n</span>)
    end

    it 'highlights a block whose language Rouge reads as a mapped one' do
      assert_includes html("```rb\nx\n```\n", 'ruby' => class_name), %(<span class="nc">x\n</span>)
    end

    it 'highlights a block in a language Rouge does not know when the mapping names it' do
      assert_includes html("```rbs\nx\n```\n", 'rbs' => class_name), %(<span class="nc">x\n</span>)
    end

    it 'reads a language Rouge does not know without the options after a ?' do
      assert_includes html("```rbs?x=1\nx\n```\n", 'rbs' => class_name), %(<span class="nc">x\n</span>)
    end

    it 'highlights a block in a language the mapping leaves out with the lexer registered with Rouge for it' do
      Class.new(lexer(Rouge::Token::Tokens::Keyword)) { tag 'bearings-html-test' }

      assert_includes html("```bearings-html-test\nx\n```\n", {}), %(<span class="k">x\n</span>)
    end

    it "keeps Rouge's markup around a block the mapping highlights" do
      assert_match(
        /\A<div class="language-ruby highlighter-rouge"><div class="highlight"><pre class="highlight"><code>/,
        html("```ruby\nx\n```\n", 'ruby' => class_name)
      )
    end

    it "highlights a code span with the lexer the mapping names for its language, outside Rouge's block markup" do
      assert_equal %(<p><code class="language-ruby highlighter-rouge"><span class="nc">x</span></code></p>\n),
                   html("`x`{:.language-ruby}\n", 'ruby' => class_name)
    end

    it "leaves Rouge's own lexer registered for a language the mapping overrides" do
      html("```ruby\nx\n```\n", 'ruby' => class_name)

      assert_equal Rouge::Lexers::Ruby, Rouge::Lexer.find('ruby')
    end
  end
end
