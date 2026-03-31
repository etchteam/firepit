import { Controller } from "@hotwired/stimulus"

const URL_PATTERN = /^(?:[a-z0-9]+:\/\/[^\s]+|www\.[^\s.]+\.[^\s]+)$/

export default class LinkPasteController extends Controller {
  connect() {
    this._boundHandle = this.handle.bind(this)
    this.element.addEventListener("paste", this._boundHandle, true)
  }

  disconnect() {
    this.element.removeEventListener("paste", this._boundHandle, true)
  }

  handle(event) {
    const editor = this.element.editor
    if (!editor) return

    const [ start, end ] = editor.getSelectedRange()
    if (start === end) return

    const url = this.#getClipboardUrl(event.clipboardData)
    if (!url || !URL_PATTERN.test(url)) return

    event.preventDefault()
    event.stopPropagation()
    editor.activateAttribute("href", url)
  }

  #getClipboardUrl(clipboardData) {
    // When a hyperlink is copied with Cmd+C the URL lives in text/html as an href,
    // while text/plain contains the anchor's display text (not the URL itself).
    const html = clipboardData?.getData("text/html")
    if (html) {
      const doc = new DOMParser().parseFromString(html, "text/html")
      const anchors = doc.querySelectorAll("a[href]")
      if (anchors.length === 1) return anchors[0].href
    }

    return clipboardData?.getData("text/plain")?.trim().replaceAll(/[\r\n]+/g, "")
  }
}
