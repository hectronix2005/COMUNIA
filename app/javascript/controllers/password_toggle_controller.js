import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "icon"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"
    this.iconTarget.className = isPassword ? "bi bi-eye-slash" : "bi bi-eye"
  }
}
