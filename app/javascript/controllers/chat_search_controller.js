import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "input", "results", "toggleBtn"]
  static values = { canal: String, con: Number }

  #debounceTimer = null

  toggle() {
    const vis = this.overlayTarget.style.display === "none"
    this.overlayTarget.style.display = vis ? "flex" : "none"
    if (vis) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
      this.resultsTarget.innerHTML = ""
    }
  }

  search() {
    clearTimeout(this.#debounceTimer)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) { this.resultsTarget.innerHTML = ""; return }

    this.#debounceTimer = setTimeout(async () => {
      const params = new URLSearchParams({ q, canal: this.canalValue })
      if (this.conValue) params.set("con", this.conValue)
      try {
        const resp = await fetch(`/chat/buscar?${params}`)
        this.resultsTarget.innerHTML = await resp.text()
      } catch (e) { console.warn(e) }
    }, 300)
  }

  scrollTo(e) {
    e.preventDefault()
    const id = e.currentTarget.dataset.msgId
    const el = document.getElementById(id)
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "center" })
      el.style.background = "#fef9c3"
      setTimeout(() => { el.style.background = ""; }, 2000)
    }
    this.overlayTarget.style.display = "none"
  }
}
