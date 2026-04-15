import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { message: String, type: { type: String, default: "warning" } }

  confirm(event) {
    event.preventDefault()
    event.stopPropagation()

    const form = this.element.closest("form") || this.element
    const message = this.messageValue || "¿Esta seguro?"

    const iconMap = { warning: "bi-exclamation-triangle", danger: "bi-x-circle", success: "bi-check-circle" }
    const colorMap = { warning: "#D4A017", danger: "#C0392B", success: "#1B7A4A" }
    const icon = iconMap[this.typeValue] || iconMap.warning
    const color = colorMap[this.typeValue] || colorMap.warning

    const modalHTML = `
      <div class="modal fade" id="confirmModal" tabindex="-1">
        <div class="modal-dialog modal-dialog-centered modal-sm">
          <div class="modal-content border-0 shadow">
            <div class="modal-body text-center p-4">
              <i class="bi ${icon}" style="font-size: 3rem; color: ${color};"></i>
              <p class="mt-3 mb-0">${message}</p>
            </div>
            <div class="modal-footer border-0 justify-content-center pb-4 pt-0">
              <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancelar</button>
              <button type="button" class="btn btn-${this.typeValue === "danger" ? "danger" : "primary"}" id="confirmBtn">Confirmar</button>
            </div>
          </div>
        </div>
      </div>`

    document.body.insertAdjacentHTML("beforeend", modalHTML)
    const modalEl = document.getElementById("confirmModal")
    const modal = new bootstrap.Modal(modalEl)

    document.getElementById("confirmBtn").addEventListener("click", () => {
      modal.hide()
      if (form.tagName === "FORM") {
        form.submit()
      } else if (form.tagName === "A") {
        window.location = form.href
      }
    })

    modalEl.addEventListener("hidden.bs.modal", () => modalEl.remove())
    modal.show()
  }
}
