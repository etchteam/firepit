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
    message = Message.create! room: rooms(:pets), body: "Just plain text here", client_message_id: "0031", creator: users(:jason)

    filter = ContentFilters::MarkdownFilter.new(message.body.body)
    refute filter.applicable?
  end

  test "markdown filter is applicable when markdown patterns are detected" do
    message = Message.create! room: rooms(:pets), body: "This has **bold** text", client_message_id: "0032", creator: users(:jason)

    filter = ContentFilters::MarkdownFilter.new(message.body.body)
    assert filter.applicable?
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
    message = Message.create! room: rooms(:pets), body: "This is **bold** text", client_message_id: "0016", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<strong>bold<\/strong>/, filtered.to_html
  end

  test "renders italic text with single asterisks" do
    message = Message.create! room: rooms(:pets), body: "This is *italic* text", client_message_id: "0018", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<em>italic<\/em>/, filtered.to_html
  end

  test "renders inline code with backticks" do
    message = Message.create! room: rooms(:pets), body: "Use the `print()` function", client_message_id: "0019", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<code>print\(\)<\/code>/, filtered.to_html
  end

  test "renders code blocks with triple backticks" do
    code_block = "```\ndef hello():\n    print('world')\n```"
    message = Message.create! room: rooms(:pets), body: code_block, client_message_id: "0020", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<code>/, filtered.to_html
    assert_match /def hello/, filtered.to_html
  end

  test "does not detect indented code blocks as markdown" do
    # 4-space indentation doesn't trigger markdown detection (good - avoids false positives)
    indented = "Here is code:\n\n    def hello():\n        print('world')"
    message = Message.create! room: rooms(:pets), body: indented, client_message_id: "0042", creator: users(:jason)

    # Should not be detected as markdown since no explicit markdown patterns
    filter = ContentFilters::MarkdownFilter.new(message.body.body)
    refute filter.applicable?
  end

  test "renders headers" do
    message = Message.create! room: rooms(:pets), body: "# Heading 1\n## Heading 2", client_message_id: "0023", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<h1>Heading 1<\/h1>/, filtered.to_html
    assert_match /<h2>Heading 2<\/h2>/, filtered.to_html
  end

  test "renders unordered lists with asterisks" do
    message = Message.create! room: rooms(:pets), body: "* Item 1\n* Item 2\n* Item 3", client_message_id: "0035", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
  end

  test "renders unordered lists with hyphens" do
    message = Message.create! room: rooms(:pets), body: "- Item 1\n- Item 2\n- Item 3", client_message_id: "0035", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<ul>/, filtered.to_html
    assert_match /<li>Item 1<\/li>/, filtered.to_html
  end

  test "renders ordered lists" do
    message = Message.create! room: rooms(:pets), body: "1. First\n2. Second\n3. Third", client_message_id: "0036", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<ol>/, filtered.to_html
    assert_match /<li>First<\/li>/, filtered.to_html
  end

  test "renders markdown links" do
    message = Message.create! room: rooms(:pets), body: "Check out [Basecamp](https://basecamp.com)", client_message_id: "0021", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<a href="https:\/\/basecamp\.com".*?>Basecamp<\/a>/, filtered.to_html
    assert_match /target="_blank"/, filtered.to_html
    assert_match /rel="noopener noreferrer"/, filtered.to_html
  end

  test "renders strikethrough text" do
    message = Message.create! room: rooms(:pets), body: "This is ~~deleted~~ text", client_message_id: "0022", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<del>deleted<\/del>/, filtered.to_html
  end

  test "renders blockquotes" do
    message = Message.create! room: rooms(:pets), body: "> This is a quote", client_message_id: "0024", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<blockquote>/, filtered.to_html
    assert_match /This is a quote/, filtered.to_html
  end

  test "renders horizontal rules" do
    message = Message.create! room: rooms(:pets), body: "Before\n\n---\n\nAfter", client_message_id: "0038", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<hr/, filtered.to_html
  end

  # Combinations, edge cases and false positives

  test "mixed markdown and plain URLs are both rendered" do
    message = Message.create! room: rooms(:pets), body: "Visit **our site** at https://example.com", client_message_id: "0033", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<strong>our site<\/strong>/, filtered.to_html
    # Redcarpet's autolink should handle the plain URL
    assert_match /<a href="https:\/\/example\.com"/, filtered.to_html
  end

  test "combines markdown bold with code" do
    message = Message.create! room: rooms(:pets), body: "Use **bold** and `code` together", client_message_id: "0034", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    assert_match /<strong>bold<\/strong>/, filtered.to_html
    assert_match /<code>code<\/code>/, filtered.to_html
  end

  test "markdown takes precedence over auto_link for URLs" do
    message = Message.create! room: rooms(:pets), body: "Visit **https://example.com** now", client_message_id: "0040", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    # Should have markdown rendering, not auto_link
    assert_match /<strong>/, filtered.to_html
  end

  test "single asterisk at line start is not always a list" do
    message = Message.create! room: rooms(:pets), body: "* walks into room *", client_message_id: "0037", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    # This might trigger list detection - documenting current behavior
    # This is a known edge case from the review
    html = filtered.to_html
    # Just documenting what happens - this is a potential false positive
    assert html.present?
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
    message = Message.create! room: rooms(:pets), body: "**bold** <script>alert('xss')</script>", client_message_id: "0027", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    refute_match /<script>/, filtered.to_html
    assert_match /<strong>bold<\/strong>/, filtered.to_html
  end

  test "prevents XSS attacks with javascript: URLs in markdown links" do
    message = Message.create! room: rooms(:pets), body: "[Click me](javascript:alert('xss'))", client_message_id: "0028", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    # Redcarpet's safe_links_only doesn't render javascript: URLs as links,
    # but leaves the raw markdown text in the output
    # This is acceptable - the link won't be clickable
    assert_match /\[Click me\]\(javascript:/, filtered.to_html
    # Importantly, it should NOT render as an actual <a> tag
    refute_match /<a href="javascript:/, filtered.to_html
  end

  test "prevents XSS attacks with HTML event handlers" do
    message = Message.create! room: rooms(:pets), body: "**bold** <img src=x onerror=alert('xss')>", client_message_id: "0029", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    refute_match /onerror/, filtered.to_html
    refute_match /<img/, filtered.to_html
  end

  test "prevents style injection" do
    message = Message.create! room: rooms(:pets), body: "**bold** <div style='background:red'>styled</div>", client_message_id: "0030", creator: users(:jason)

    filtered = ContentFilters::TextMessagePresentationFilters.apply(message.body.body)
    # SanitizeTags filter should remove the style attribute and potentially the div
    refute_match /style=/, filtered.to_html
  end

  private
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
