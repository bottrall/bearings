# frozen_string_literal: true

require 'kramdown/converter/syntax_highlighter/rouge'

# A highlighter registered under another name would put that name in place of highlighter-rouge in a block's class.
# rubocop:disable-next Bottrall/NoInheritance -- kramdown picks a block's lexer only in its converter's highlight_code
class Bearings::Kramdown::Html < Kramdown::Converter::Html
  ROUGE = ::Kramdown::Converter::SyntaxHighlighter::Rouge #: singleton(::Kramdown::Converter::SyntaxHighlighter::Rouge)

  # @rbs text: String
  # @rbs lang: String?
  # @rbs type: Symbol
  # @rbs opts: Hash[Symbol, untyped]
  # @rbs return: String?
  def highlight_code(text, lang, type, opts = {})
    lexer = lang && lexer(lang, text)
    return super unless lexer

    ROUGE::HTMLLegacy.new({ css_class: 'highlight', **ROUGE.options(self, type) }).format(lexer.lex(text))
  end

  private

  # @rbs lang: String
  # @rbs text: String
  # @rbs return: ::Rouge::Lexer?
  def lexer(lang, text)
    found, lexer_options = ::Rouge::Lexer.lookup_fancy(lang, text)
    lexers = options.fetch(:lexers) #: Bearings::Kramdown::lexers
    lexers[found&.tag || lang.partition('?').first]&.new(lexer_options)
  end
end
