import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  async submit(event) {
    event.preventDefault()
    const contenido = this.inputTarget.value.trim()
    if (!contenido) return

    const form = this.element
    const url  = form.action
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token
        },
        body: new URLSearchParams({ contenido })
      })
      this.inputTarget.value = ""
      this.inputTarget.focus()
    } catch (e) {
      console.error("Error enviando mensaje:", e)
    }
  }
}
