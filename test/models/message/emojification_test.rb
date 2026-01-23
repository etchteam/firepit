require "test_helper"

class Message::EmojificationTest < ActiveSupport::TestCase
  test "converts shortcode to emoji on create" do
    message = rooms(:designers).messages.create!(
      body: "I :heart: this!",
      client_message_id: "emoji-create",
      creator: users(:david)
    )

    assert_includes message.body.body.to_html, "\u2764"
    assert_not_includes message.body.body.to_html, ":heart:"
  end

  test "converts shortcode to emoji on update" do
    message = rooms(:designers).messages.create!(
      body: "Hello world",
      client_message_id: "emoji-update",
      creator: users(:david)
    )

    message.update!(body: "Hello :wave:")

    assert_includes message.body.body.to_html, "\u{1F44B}"
    assert_not_includes message.body.body.to_html, ":wave:"
  end

  test "preserves unknown shortcodes" do
    message = rooms(:designers).messages.create!(
      body: "This is :notarealcode: right?",
      client_message_id: "emoji-unknown",
      creator: users(:david)
    )

    assert_includes message.body.body.to_html, ":notarealcode:"
  end

  test "converts multiple occurrences of same shortcode" do
    message = rooms(:designers).messages.create!(
      body: ":heart: and :heart: and :heart:",
      client_message_id: "emoji-multiple",
      creator: users(:david)
    )

    assert_equal 3, message.body.body.to_html.scan("\u2764").count
    assert_not_includes message.body.body.to_html, ":heart:"
  end

  test "case insensitive matching" do
    message = rooms(:designers).messages.create!(
      body: ":HEART: and :Heart: and :heart:",
      client_message_id: "emoji-case",
      creator: users(:david)
    )

    assert_equal 3, message.body.body.to_html.scan("\u2764").count
    assert_not_includes message.body.body.to_html, ":HEART:"
    assert_not_includes message.body.body.to_html, ":Heart:"
    assert_not_includes message.body.body.to_html, ":heart:"
  end

  test "converts shortcodes within HTML content" do
    message = rooms(:designers).messages.create!(
      body: "<div>Check this :thumbsup:</div>",
      client_message_id: "emoji-html",
      creator: users(:david)
    )

    assert_includes message.body.body.to_html, "\u{1F44D}"
    assert_not_includes message.body.body.to_html, ":thumbsup:"
  end

  test "converts multiple different shortcodes" do
    message = rooms(:designers).messages.create!(
      body: ":heart: :thumbsup: :100:",
      client_message_id: "emoji-different",
      creator: users(:david)
    )

    assert_includes message.body.body.to_html, "\u2764"
    assert_includes message.body.body.to_html, "\u{1F44D}"
    assert_includes message.body.body.to_html, "\u{1F4AF}"
  end
end
