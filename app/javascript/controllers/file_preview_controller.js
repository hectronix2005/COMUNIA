import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "dropzone", "filename"]

  connect() {
    this.dropzoneTarget.addEventListener("dragover", this.dragover.bind(this))
    this.dropzoneTarget.addEventListener("dragleave", this.dragleave.bind(this))
    this.dropzoneTarget.addEventListener("drop", this.drop.bind(this))
  }

  disconnect() {
    this.dropzoneTarget.removeEventListener("dragover", this.dragover.bind(this))
    this.dropzoneTarget.removeEventListener("dragleave", this.dragleave.bind(this))
    this.dropzoneTarget.removeEventListener("drop", this.drop.bind(this))
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("dragover")
  }

  dragleave(event) {
    this.dropzoneTarget.classList.remove("dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dragover")
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.showPreview(files[0])
    }
  }

  changed() {
    const file = this.inputTarget.files[0]
    if (file) this.showPreview(file)
  }

  showPreview(file) {
    if (file.size > 5 * 1024 * 1024) {
      alert("El archivo no debe superar 5MB")
      this.inputTarget.value = ""
      return
    }

    if (!["image/jpeg", "image/png", "application/pdf"].includes(file.type)) {
      alert("Solo se aceptan archivos JPG, PNG o PDF")
      this.inputTarget.value = ""
      return
    }

    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = `${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`
    }

    this.previewTarget.innerHTML = ""
    this.previewTarget.style.display = "block"
    this.dropzoneTarget.classList.add("has-file")

    if (file.type.startsWith("image/")) {
      const img = document.createElement("img")
      img.src = URL.createObjectURL(file)
      img.className = "img-fluid rounded shadow-sm"
      img.style.maxHeight = "300px"
      img.onload = () => URL.revokeObjectURL(img.src)
      this.previewTarget.appendChild(img)
    } else {
      const div = document.createElement("div")
      div.className = "d-flex align-items-center text-muted"
      div.innerHTML = `<i class="bi bi-file-earmark-pdf fs-1 me-3 text-danger"></i><div><strong>${file.name}</strong><br><small>${(file.size / 1024 / 1024).toFixed(2)} MB</small></div>`
      this.previewTarget.appendChild(div)
    }
  }
}
