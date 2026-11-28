# frozen_string_literal: true

require 'test_helper'

describe Bearings::Kramdown::WithLexers do
  describe '#document' do
    it 'highlights the code blocks with its lexers' do
      lexer = Class.new(Rouge::RegexLexer) { state(:root) { rule(/.+/m, Rouge::Token::Tokens::Name::Class) } }
      markdown = Bearings::Kramdown::WithLexers.new(lexers: { 'ruby' => lexer })

      assert_includes markdown.document("# Title\n\n```ruby\nx\n```\n").body, %(<span class="nc">x\n</span>)
    end
  end
end
