class ContentFilters::MarkdownFilter < ActionText::Content::Filter
  MARKDOWN_PATTERNS = [
    /\*\*[^*]+\*\*/,                    # Bold: **text**
    /__[^_]+__/,                        # Bold alt: __text__
    /\*[^*]+\*/,                        # Italic: *text*
    /_[^_]+_/,                          # Italic alt: _text_
    /`[^`]+`/,                          # Inline code: `code`
    /```[\s\S]+?```/,                   # Code blocks: ```code```
    /^[#]{1,6}\s/m,                     # Header levels 1-6: # Header
    /^\*\s/m,                           # Unordered lists: * item
    /^-\s/m,                            # Unordered lists alt: - item
    /^\d+\.\s/m,                        # Ordered lists: 1. item
    /\[.+?\]\(.+?\)/,                   # Links: [text](url)
    /~~.+?~~/,                          # Strikethrough: ~~text~~
    /^>\s/m,                            # Blockquotes: > quote
    /^---+$/m                           # Horizontal rule: ---
  ].freeze

  def applicable?
    has_markdown?
  end

  def apply
    # Convert markdown to HTML using Redcarpet
    markdown_html = markdown_renderer.render(plain_text_content)

    # Replace the entire fragment with the rendered markdown
    fragment.update do |source|
      source.inner_html = markdown_html
    end
  end

  private
    def has_markdown?
      content = plain_text_content
      MARKDOWN_PATTERNS.any? { |pattern| content.match?(pattern) }
    end

    def plain_text_content
      fragment.to_plain_text
    end

    def markdown_renderer
      @markdown_renderer ||= Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(
          filter_html: true,
          safe_links_only: true,
          no_styles: true,
          link_attributes: { target: "_blank", rel: "noopener noreferrer" }
        ),
        autolink: true,
        disable_indented_code_blocks: false,
        fenced_code_blocks: true,
        footnotes: false,
        highlight: false,
        quote: true,
        no_intra_emphasis: true,
        space_after_headers: true,
        strikethrough: true,
        tables: true,
        underline: false
      )
    end
end
