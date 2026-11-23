# frozen_string_literal: true

Bearings::Document = Data.define(:title, :headings, :links, :code_blocks, :code_spans, :images, :diagrams, :body)
Bearings::Document::Heading = Data.define(:level, :id, :line)
Bearings::Document::Link = Data.define(:href, :line)
Bearings::Document::CodeBlock = Data.define(:language, :code, :line)
Bearings::Document::CodeSpan = Data.define(:code, :line)
Bearings::Document::Image = Data.define(:src, :alt, :line)
Bearings::Document::Diagram = Data.define(:code, :line)
