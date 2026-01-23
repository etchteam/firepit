require "test_helper"

class ContentFiltersTest < ActionView::TestCase
  test "entire message contains an unfurled URL" do
    text = "https://basecamp.com/"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_basecamp(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_not_equal message.body.body.to_html, filtered.to_html
    assert_match /<div><action-text-attachment/, filtered.to_html
  end

  test "message includes additional text besides an unfurled URL" do
    text = "Hello https://basecamp.com/"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_basecamp(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_equal message.body.body.to_html, filtered.to_html
    assert_match %r{<div>Hello https://basecamp\.com/<action-text-attachment}, filtered.to_html
  end

  test "unfurled tweet without any image" do
    text = "<div>https://twitter.com/37signals/status/1750290547908952568<action-text-attachment content-type=\"application/vnd.actiontext.opengraph-embed\" url=\"https://pbs.twimg.com/profile_images/1671940407633010689/9P5gi6LF_200x200.jpg\" href=\"https://twitter.com/37signals/status/1750290547908952568\" filename=\"37signals (@37signals)\" caption=\"We're back up on all apps, everyone. Really sorry for the disruption to your day.\" content=\"<actiontext-opengraph-embed>\n      <div class=&quot;og-embed&quot;>\n        <div class=&quot;og-embed__content&quot;>\n          <div class=&quot;og-embed__title&quot;>37signals (@37signals)</div>\n          <div class=&quot;og-embed__description&quot;>We're back up on all apps, everyone. Really sorry for the disruption to your day.</div>\n        </div>\n        <div class=&quot;og-embed__image&quot;>\n          <img src=&quot;https://pbs.twimg.com/profile_images/1671940407633010689/9P5gi6LF_200x200.jpg&quot; class=&quot;image&quot; alt=&quot;&quot; />\n        </div>\n      </div>\n    </actiontext-opengraph-embed>\"></action-text-attachment></div>"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_basecamp(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::StyleUnfurledTwitterAvatars.apply(message.body.body)
    assert_match %r{<div class="cf-twitter-avatar">}, filtered.to_html
  end

  test "unfurled tweet containing an image" do
    text = "<div>https://twitter.com/dhh/status/1748445489648050505<action-text-attachment content-type=\"application/vnd.actiontext.opengraph-embed\" url=\"https://pbs.twimg.com/media/GEO5l04bsAA9f6H.jpg\" href=\"https://twitter.com/dhh/status/1748445489648050505\" filename=\"DHH (@dhh)\" caption=\"We pay homage to the glorious MIT License with the ONCE license. May all our future legalese be as succinct!\" content=\"<actiontext-opengraph-embed>\n      <div class=&quot;og-embed&quot;>\n        <div class=&quot;og-embed__content&quot;>\n          <div class=&quot;og-embed__title&quot;>DHH (@dhh)</div>\n          <div class=&quot;og-embed__description&quot;>We pay homage to the glorious MIT License with the ONCE license. May all our future legalese be as succinct!</div>\n        </div>\n        <div class=&quot;og-embed__image&quot;>\n          <img src=&quot;https://pbs.twimg.com/media/GEO5l04bsAA9f6H.jpg&quot; class=&quot;image&quot; alt=&quot;&quot; />\n        </div>\n      </div>\n    </actiontext-opengraph-embed>\"></action-text-attachment></div>"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_basecamp(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::StyleUnfurledTwitterAvatars.apply(message.body.body)
    assert_no_match %r{<div class="cf-twitter-avatar">}, filtered.to_html
  end

  test "entire message contains an unfurled URL from x.com but unfurls to twitter.com" do
    text = "https://x.com/dhh/status/1752476663303323939"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_twitter(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_not_equal message.body.body.to_html, filtered.to_html
    assert_match /<div><action-text-attachment/, filtered.to_html
  end

  test "entire message contains an unfurled URL from x.com with query params" do
    text = "https://x.com/dhh/status/1752476663303323939?s=20"
    message = Message.create! room: rooms(:pets), body: unfurled_message_body_for_twitter(text), client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_not_equal message.body.body.to_html, filtered.to_html
    assert_match /<div><action-text-attachment/, filtered.to_html
  end

  test "message contains a forbidden tag" do
    exploit_image_tag = 'Hello <img src="https://ssecurityrise.com/tests/billionlaughs-cache.svg">World'
    message = Message.create! room: rooms(:pets), body: exploit_image_tag, client_message_id: "0015", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_equal "Hello World", filtered.to_html
  end

  test "message with a mention attachment" do
    message = Message.create! room: rooms(:pets), body: "<div>Hey #{mention_attachment_for(:david)}</div>", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    expected = /<action-text-attachment sgid="#{users(:david).attachable_sgid}" content-type="application\/vnd\.campfire\.mention" content="(.*?)"><\/action-text-attachment>/m

    assert_match expected, filtered.to_html
  end

  # Markdown filter tests

  test "markdown filter is not applicable to plain text without markdown" do
    refute_markdown_applicable "Just plain text here"
  end

  test "markdown filter is applicable when markdown patterns are detected" do
    assert_markdown_applicable "This has **bold** text"
  end

  test "has_markdown? class method detects markdown patterns" do
    assert ContentFilters::MarkdownFilter.has_markdown?("This is **bold**")
    assert ContentFilters::MarkdownFilter.has_markdown?("This is *italic*")
    assert ContentFilters::MarkdownFilter.has_markdown?("This has `code`")
    assert ContentFilters::MarkdownFilter.has_markdown?("[link](url)")
    assert ContentFilters::MarkdownFilter.has_markdown?("# Header")

    refute ContentFilters::MarkdownFilter.has_markdown?("Just plain text")
    refute ContentFilters::MarkdownFilter.has_markdown?("Email: user@example.com")
    refute ContentFilters::MarkdownFilter.has_markdown?("Python __init__ method")
    refute ContentFilters::MarkdownFilter.has_markdown?("Use my_variable_name")
  end

  # Tests for MARKDOWN_PATTERNS (in order of pattern definition)

  test "renders bold text with double asterisks" do
    assert_markdown_rendered "This is **bold** text", /<strong>bold<\/strong>/
  end

  test "renders italic text with single asterisks" do
    assert_markdown_rendered "This is *italic* text", /<em>italic<\/em>/
  end

  test "renders inline code with backticks" do
    assert_markdown_rendered "Use the `print()` function", /<code>print\(\)<\/code>/
  end

  test "renders code blocks with triple backticks" do
    code_block = "```\ndef hello():\n    print('world')\n```"
    filtered = apply_text_filters(code_block)
    assert_match /<code>/, filtered.to_html
    assert_match /def hello/, filtered.to_html
  end

  test "does not detect indented code blocks as markdown" do
    # 4-space indentation doesn't trigger markdown detection (good - avoids false positives)
    indented = "Here is code:\n\n    def hello():\n        print('world')"
    # Should not be detected as markdown since no explicit markdown patterns
    refute_markdown_applicable indented
  end

  test "renders headers" do
    filtered = apply_text_filters("# Heading 1\n## Heading 2")
    assert_match /<h1>Heading 1<\/h1>/, filtered.to_html
    assert_match /<h2>Heading 2<\/h2>/, filtered.to_html
  end

  test "renders unordered lists with asterisks" do
    filtered = apply_text_filters("* Item 1\n* Item 2\n* Item 3")
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
  end

  test "renders unordered lists with hyphens" do
    filtered = apply_text_filters("- Item 1\n- Item 2\n- Item 3")
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
  end

  test "renders ordered lists" do
    filtered = apply_text_filters("1. First\n2. Second\n3. Third")
    assert_match /<ol>/, filtered.to_html
    assert_match /<li>First<\/li>/, filtered.to_html
  end

  test "renders markdown links" do
    filtered = apply_text_filters("Check out [Basecamp](https://basecamp.com)")
    assert_match /<a href="https:\/\/basecamp\.com".*?>Basecamp<\/a>/, filtered.to_html
    assert_match /target="_blank"/, filtered.to_html
    assert_match /rel="noopener noreferrer"/, filtered.to_html
  end

  test "renders strikethrough text" do
    assert_markdown_rendered "This is ~~deleted~~ text", /<del>deleted<\/del>/
  end

  test "renders blockquotes" do
    filtered = apply_text_filters("> This is a quote")
    assert_match /<blockquote>/, filtered.to_html
    assert_match /This is a quote/, filtered.to_html
  end

  test "renders horizontal rules" do
    assert_markdown_rendered "Before\n\n---\n\nAfter", /<hr/
  end

  # Combinations, edge cases and false positives

  test "mixed markdown and plain URLs are both rendered" do
    filtered = apply_text_filters("Visit **our site** at https://example.com")
    assert_match /<strong>our site<\/strong>/, filtered.to_html
    # Redcarpet's autolink should handle the plain URL
    assert_match /<a href="https:\/\/example\.com"/, filtered.to_html
  end

  test "combines markdown bold with code" do
    filtered = apply_text_filters("Use **bold** and `code` together")
    assert_match /<strong>bold<\/strong>/, filtered.to_html
    assert_match /<code>code<\/code>/, filtered.to_html
  end

  test "markdown takes precedence over auto_link for URLs" do
    filtered = apply_text_filters("Visit **https://example.com** now")
    # Should have markdown rendering, not auto_link
    assert_match /<strong>/, filtered.to_html
  end

  test "single line starting with asterisk does not trigger list detection" do
    # Single lines starting with "* " DON'T trigger markdown (avoids false positives)
    refute_markdown_applicable "* walks into room", "Single lines starting with '* ' should not trigger markdown detection"
  end

  test "single line starting with hyphen does not trigger list detection" do
    # Single lines starting with "- " DON'T trigger markdown (avoids false positives)
    refute_markdown_applicable "- Not sure about that", "Single lines starting with '- ' should not trigger markdown detection"
  end

  test "multiple list items trigger markdown detection" do
    # Multiple list items (2+) DO trigger markdown detection
    assert_markdown_applicable "* Item 1\n* Item 2", "Multiple list items should trigger markdown detection"
  end

  test "list with text before it triggers markdown detection" do
    assert_markdown_applicable "Hello\n* Item 1\n* Item 2", "List with text before should trigger markdown detection"
  end

  test "list with text after it triggers markdown detection" do
    assert_markdown_applicable "* Item 1\n* Item 2\nGoodbye", "List with text after should trigger markdown detection"
  end

  test "list with text before and after triggers markdown detection" do
    assert_markdown_applicable "Hello\n* Item 1\n* Item 2\nGoodbye", "List with text before and after should trigger markdown detection"
  end

  test "renders list with text before it correctly" do
    filtered = apply_text_filters("Hello\n- Item 1\n- Item 2")
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
    assert_match /<li>Item 2<\/li>/, filtered.to_html
    assert_match /Hello/, filtered.to_html
  end

  test "renders list with text after it correctly" do
    filtered = apply_text_filters("- Item 1\n- Item 2\nGoodbye")
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
    assert_match /<li>Item 2<\/li>/, filtered.to_html
    assert_match /Goodbye/, filtered.to_html
  end

  test "renders list with text before and after correctly" do
    filtered = apply_text_filters("Hello\n- Item 1\n- Item 2\nGoodbye")
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
    assert_match /<li>Item 2<\/li>/, filtered.to_html
    assert_match /Hello/, filtered.to_html
    assert_match /Goodbye/, filtered.to_html
  end

  # Newline preservation tests

  test "preserves single newlines with markdown" do
    filtered = apply_text_filters("Line 1 with **bold**\nLine 2 normal")
    # Should have a <br> tag to preserve the line break
    assert_match /<br>/, filtered.to_html
    assert_match /<strong>bold<\/strong>/, filtered.to_html
  end

  test "preserves multiple single newlines with markdown" do
    filtered = apply_text_filters("Line 1 with **bold**\nLine 2 with *italic*\nLine 3 normal")
    # Should have <br> tags for line breaks
    assert_match /<strong>bold<\/strong><br>/, filtered.to_html
    assert_match /<em>italic<\/em><br>/, filtered.to_html
  end

  test "converts double newlines to paragraph breaks" do
    filtered = apply_text_filters("Paragraph 1 with **bold**\n\nParagraph 2 normal")
    # Should have separate paragraphs
    assert_match /<\/p>\s*<p>/, filtered.to_html
    assert_match /<strong>bold<\/strong>/, filtered.to_html
  end

  # Escaping markdown syntax
  test "escape markdown with backticks for literal characters" do
    filtered = apply_text_filters("Use `**bold**` for bold text")
    # The **bold** inside backticks should be rendered as code, not as bold
    assert_match /<code>\*\*bold\*\*<\/code>/, filtered.to_html
    refute_match /<strong>bold<\/strong>/, filtered.to_html
  end

  test "backslash escaping works for markdown characters" do
    # Backslash escaping DOES work - backslashes prevent markdown rendering
    filtered = apply_text_filters("This is \\*\\*not bold\\*\\*")
    refute_match /<strong>/, filtered.to_html
    assert_match /\*\*not bold\*\*/, filtered.to_html
    refute_match /\\/, filtered.to_html, "Backslashes should be removed from output"
  end

  test "preserves ActionText attachments with markdown" do
    # When attachments are present, markdown is NOT rendered to avoid destroying attachments
    body = "<div>Check **this** #{mention_attachment_for(:david)}</div>"
    message = Message.create! room: rooms(:pets), body: body, creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)

    # Markdown should NOT be rendered when attachments are present
    refute_match /<strong>this<\/strong>/, filtered.to_html
    # But attachment should be preserved
    assert_match /action-text-attachment/, filtered.to_html
    assert_match /#{users(:david).attachable_sgid}/, filtered.to_html
    # Markdown syntax remains as-is
    assert_match /\*\*this\*\*/, filtered.to_html
  end

  # Security tests
  test "prevents XSS attacks with script tags" do
    filtered = apply_text_filters("**bold** <script>alert('xss')</script>")
    refute_match /<script>/i, filtered.to_html
    assert_match /<strong>bold<\/strong>/, filtered.to_html
  end

  test "prevents XSS attacks with javascript: URLs in markdown links" do
    filtered = apply_text_filters("[Click me](javascript:alert('xss'))")
    # Redcarpet's safe_links_only doesn't render javascript: URLs as links,
    # but leaves the raw markdown text in the output
    # This is acceptable - the link won't be clickable
    assert_match /\[Click me\]\(javascript:/, filtered.to_html
    # Importantly, it should NOT render as an actual <a> tag
    refute_match /<a href="javascript:/, filtered.to_html
  end

  test "prevents XSS attacks with HTML event handlers" do
    filtered = apply_text_filters("**bold** <img src=x onerror=alert('xss')>")
    refute_match /onerror/, filtered.to_html
    refute_match /<img/, filtered.to_html
  end

  test "prevents style injection" do
    filtered = apply_text_filters("**bold** <div style='background:red'>styled</div>")
    # SanitizeTags filter should remove the style attribute and potentially the div
    refute_match /style=/, filtered.to_html
  end

  private
    # Helper methods to reduce test duplication
    def create_test_message(body, client_id: nil)
      Message.create! room: rooms(:pets), body: body, client_message_id: client_id || next_client_id, creator: users(:jason)
    end

    def apply_text_filters(body)
      message = create_test_message(body)
      ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    end

    def assert_markdown_rendered(body, expected_pattern, message = nil)
      filtered = apply_text_filters(body)
      assert_match expected_pattern, filtered.to_html, message
    end

    def refute_markdown_rendered(body, unexpected_pattern, message = nil)
      filtered = apply_text_filters(body)
      refute_match unexpected_pattern, filtered.to_html, message
    end

    def assert_markdown_applicable(body, message = nil)
      test_message = create_test_message(body)
      filter = ContentFilters::MarkdownFilter.new(test_message.body.body)
      assert filter.applicable?, message || "Expected markdown to be detected in: #{body}"
    end

    def refute_markdown_applicable(body, message = nil)
      test_message = create_test_message(body)
      filter = ContentFilters::MarkdownFilter.new(test_message.body.body)
      refute filter.applicable?, message || "Expected markdown NOT to be detected in: #{body}"
    end

    def next_client_id
      @client_id_counter ||= 1000
      @client_id_counter += 1
      @client_id_counter.to_s.rjust(4, "0")
    end

    def unfurled_message_body_for_basecamp(text)
      "<div>#{text}#{unfurled_link_trix_attachment_for_basecamp}</div>"
    end

    def unfurled_link_trix_attachment_for_basecamp
      <<~BASECAMP
      <action-text-attachment content-type=\"application/vnd.actiontext.opengraph-embed\" url=\"https://basecamp.com/assets/general/opengraph.png\" href=\"https://basecamp.com/\" filename=\"Project management software, online collaboration\" caption=\"Trusted by millions, Basecamp puts everything you need to get work done in one place. It’s the calm, organized way to manage projects, work with clients, and communicate company-wide.\" content=\"<actiontext-opengraph-embed>\n      <div class=&quot;og-embed&quot;>\n        <div class=&quot;og-embed__content&quot;>\n          <div class=&quot;og-embed__title&quot;>Project management software, online collaboration</div>\n          <div class=&quot;og-embed__description&quot;>Trusted by millions, Basecamp puts everything you need to get work done in one place. It’s the calm, organized way to manage projects, work with clients, and communicate company-wide.</div>\n        </div>\n        <div class=&quot;og-embed__image&quot;>\n          <img src=&quot;https://basecamp.com/assets/general/opengraph.png&quot; class=&quot;image&quot; alt=&quot;&quot; />\n        </div>\n      </div>\n    </actiontext-opengraph-embed>\"></action-text-attachment>
      BASECAMP
    end

    def unfurled_message_body_for_twitter(text)
      "<div>#{text}#{unfurled_link_trix_attachment_for_twitter}</div>"
    end

    def unfurled_link_trix_attachment_for_twitter
      <<~TWEET
      <action-text-attachment content-type=\"application/vnd.actiontext.opengraph-embed\" url=\"https://pbs.twimg.com/ext_tw_video_thumb/1752476502791503873/pu/img/WEAqUgarUxWjPNHD.jpg\" href=\"https://twitter.com/dhh/status/1752476663303323939\" filename=\"DHH (@dhh)\" caption=\"We're playing with adding easy extension points to ONCE/Campfire. Here's one experiment for allowing any type of CSS to be easily added.\" content=\"&lt;actiontext-opengraph-embed&gt;\n      &lt;div class=&quot;og-embed&quot;&gt;\n        &lt;div class=&quot;og-embed__content&quot;&gt;\n          &lt;div class=&quot;og-embed__title&quot;&gt;DHH (@dhh)&lt;/div&gt;\n          &lt;div class=&quot;og-embed__description&quot;&gt;We're playing with adding easy extension points to ONCE/Campfire. Here's one experiment for allowing any type of CSS to be easily added.&lt;/div&gt;\n        &lt;/div&gt;\n        &lt;div class=&quot;og-embed__image&quot;&gt;\n          &lt;img src=&quot;https://pbs.twimg.com/ext_tw_video_thumb/1752476502791503873/pu/img/WEAqUgarUxWjPNHD.jpg&quot; class=&quot;image&quot; alt=&quot;&quot; /&gt;\n        &lt;/div&gt;\n      &lt;/div&gt;\n    &lt;/actiontext-opengraph-embed&gt;\"><figure class=\"attachment attachment--content attachment--og\">\n  \n    <div class=\"og-embed gap\">\n      <div class=\"og-embed__content\">\n        <div class=\"og-embed__title\">\n          <a href=\"https://twitter.com/dhh/status/1752476663303323939\">DHH (@dhh)</a>\n        </div>\n        <div class=\"og-embed__description\">We're playing with adding easy extension points to ONCE/Campfire. Here's one experiment for allowing any type of CSS to be easily added.</div>\n      </div>\n        <div class=\"og-embed__image\">\n          <img src=\"https://pbs.twimg.com/ext_tw_video_thumb/1752476502791503873/pu/img/WEAqUgarUxWjPNHD.jpg\" class=\"image center\" alt=\"\">\n        </div>\n    </div>\n  \n</figure></action-text-attachment>
      TWEET
    end
end
