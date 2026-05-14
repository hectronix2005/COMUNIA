import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle(e) {
    e.preventDefault()
    const vis = this.panelTarget.style.display === "none"
    this.panelTarget.style.display = vis ? "flex" : "none"
    if (vis) {
      setTimeout(() => {
        const close = (ev) => {
          if (!this.element.contains(ev.target)) {
            this.panelTarget.style.display = "none"
            document.removeEventListener("click", close)
          }
        }
        document.addEventListener("click", close)
      }, 0)
    }
  }

  insert(e) {
    const emoji = e.currentTarget.dataset.emoji
    const input = document.getElementById("chat-input")
    if (input) {
      const start = input.selectionStart
      input.value = input.value.substring(0, start) + emoji + input.value.substring(input.selectionEnd)
      input.selectionStart = input.selectionEnd = start + emoji.length
      input.focus()
      input.dispatchEvent(new Event("input"))
    }
    this.panelTarget.style.display = "none"
  }
}
