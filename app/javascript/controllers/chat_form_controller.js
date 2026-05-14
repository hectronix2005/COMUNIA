import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  #typingTimeout = null

  async submit(event) {
    event.preventDefault()
    const input = this.inputTarget
    const contenido = input.value.trim()
    if (!contenido) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      await fetch(this.element.action, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": csrfToken
        },
        body: `contenido=${encodeURIComponent(contenido)}`
      })
      input.value = ""
      input.style.height = "auto"
      input.focus()
    } catch (err) {
      console.warn("Chat send error:", err)
    }
  }

  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  autoResize() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 120) + "px"
  }

  sendTyping() {
    if (this.#typingTimeout) return
    const stream = this.element.dataset.stream
    if (!stream) return
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/chat/typing", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrfToken },
      body: `stream=${encodeURIComponent(stream)}`
    }).catch(() => {})
    this.#typingTimeout = setTimeout(() => { this.#typingTimeout = null }, 3000)
  }
}
