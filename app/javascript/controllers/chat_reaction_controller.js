import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker"]
  static values = { id: Number }

  showPicker(e) {
    e.stopPropagation()
    const picker = this.pickerTarget
    picker.style.display = picker.style.display === "none" ? "flex" : "none"
    // Auto-close on outside click
    if (picker.style.display === "flex") {
      setTimeout(() => {
        const close = (ev) => {
          if (!picker.contains(ev.target)) {
            picker.style.display = "none"
            document.removeEventListener("click", close)
          }
        }
        document.addEventListener("click", close)
      }, 0)
    }
  }

  react(e) {
    const emoji = e.currentTarget.dataset.emoji
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch("/chat/reaccionar", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "X-CSRF-Token": csrfToken },
      body: `id=${this.idValue}&emoji=${encodeURIComponent(emoji)}`
    }).catch(() => {})
    this.pickerTarget.style.display = "none"
  }
}
