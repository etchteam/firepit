require "application_system_test_case"

class LinkPasteTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
    join_room rooms(:designers)
  end

  test "pasting a URL over selected text creates a link" do
    fill_in_rich_text_area "Write a message", with: "Click here for more info"
    paste_into_editor("Write a message", text: "https://example.com", selection: [0, 10])
    assert page.find(:rich_textarea, "Write a message").has_css?("a[href='https://example.com']")
  end

  test "pasting a URL without a selection does not create a link" do
    fill_in_rich_text_area "Write a message", with: "Hello"
    paste_into_editor("Write a message", text: "https://example.com", selection: [5, 5])
    assert page.find(:rich_textarea, "Write a message").has_no_css?("a")
  end

  test "pasting a URL with embedded line breaks creates a link with the line breaks removed" do
    fill_in_rich_text_area "Write a message", with: "Click here for more info"
    paste_into_editor("Write a message", text: "https://app.frontapp.com/inboxes/teammates/\n10381066/inbox/all/56924074506", selection: [0, 10])
    assert page.find(:rich_textarea, "Write a message").has_css?("a[href='https://app.frontapp.com/inboxes/teammates/10381066/inbox/all/56924074506']")
  end

  test "pasting non-URL text over selected text does not create a link" do
    fill_in_rich_text_area "Write a message", with: "Click here for more info"
    paste_into_editor("Write a message", text: "just some text", selection: [0, 10])
    assert page.find(:rich_textarea, "Write a message").has_no_css?("a")
  end

    test "pasting an incomplete URL over selected text does not create a link" do
    fill_in_rich_text_area "Write a message", with: "Click here for more info"
    paste_into_editor("Write a message", text: "www.google", selection: [0, 10])
    assert page.find(:rich_textarea, "Write a message").has_no_css?("a")
  end

  test "pasting a hyperlink copied directly from a browser creates a link from the HTML href" do
    fill_in_rich_text_area "Write a message", with: "Click here for more info"
    paste_into_editor("Write a message", text: "Inbox", selection: [0, 10],
      html: "<a href='https://app.frontapp.com/inboxes/teammates/10381066/inbox/all/56924074506'>Inbox</a>")
    assert page.find(:rich_textarea, "Write a message").has_css?("a[href='https://app.frontapp.com/inboxes/teammates/10381066/inbox/all/56924074506']")
  end

  private

  def paste_into_editor(label, text:, selection:, html: nil)
    formats = { "text/plain" => text, "text/html" => html.to_s }
    page.find(:rich_textarea, label).execute_script(<<~JS, formats.to_json, *selection)
      const [ formatsJson, start, end_ ] = arguments
      const formats = JSON.parse(formatsJson)
      this.editor.setSelectedRange([ start, end_ ])
      const event = new Event("paste", { bubbles: true, cancelable: true })
      Object.defineProperty(event, "clipboardData", { value: { getData: (type) => formats[type] ?? "" } })
      this.dispatchEvent(event)
    JS
  end
end
