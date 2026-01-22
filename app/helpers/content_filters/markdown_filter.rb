class ContentFilters::MarkdownFilter < ActionText::Content::Filter
  # Markdown pattern detection
  # NOTE: Underscore-based emphasis (__bold__ and _italic_) is intentionally not supported
  # to avoid false positives with code identifiers like __init__ and my_variable_name
  MARKDOWN_PATTERNS = [
    /\*\*[^*]+\*\*/,                    # Bold: **text**
    /\*[^*]+\*/,                        # Italic: *text*
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

  def self.has_markdown?(text)
    MARKDOWN_PATTERNS.any? { |pattern| text.match?(pattern) }
  end

  def applicable?
    has_markdown? && !has_attachments?
  end

  def apply
    # Convert markdown to HTML using Redcarpet
    markdown_html = self.class.markdown_renderer.render(plain_text_content)

    # Replace the entire fragment with the rendered markdown
    fragment.update do |source|
      source.inner_html = markdown_html
    end
  end

  private
    def has_markdown?
      self.class.has_markdown?(plain_text_content)
    end

    def has_attachments?
      # Skip markdown rendering if ActionText attachments are present
      # to avoid destroying them when we replace inner_html
      fragment.find_all("action-text-attachment").any?
    end

    def plain_text_content
      fragment.to_plain_text
    end

    def self.markdown_renderer
      @markdown_renderer ||= Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(
          filter_html: true,           # Strip HTML tags for security
          safe_links_only: true,       # Block javascript: and data: URLs
          no_styles: true,              # Remove inline styles
          link_attributes: { target: "_blank", rel: "noopener noreferrer" }
        ),
        autolink: true,                           # Convert plain URLs to links
        disable_indented_code_blocks: true,       # Disable 4-space indented code blocks
        fenced_code_blocks: true,                 # Allow ``` code blocks
        footnotes: false,                         # Footnotes not needed in chat
        highlight: false,                         # Syntax highlighting handled separately
        quote: true,                              # Enable blockquotes with >
        no_intra_emphasis: true,                  # Prevent emphasis_within_words
        space_after_headers: true,                # Require space after # for headers
        strikethrough: true,                      # Enable ~~strikethrough~~
        tables: false,                            # Tables not supported in chat UI
        underline: false                          # Underline not supported
      )
    end
end
