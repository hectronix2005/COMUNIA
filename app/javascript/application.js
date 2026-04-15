// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

// Initialize Bootstrap popovers on page load and Turbo navigation
function initPopovers() {
  const Popover = window.bootstrap?.Popover
  if (!Popover) return
  document.querySelectorAll('[data-bs-toggle="popover"]').forEach(el => {
    Popover.getOrCreateInstance(el, { sanitize: false })
  })
}

document.addEventListener("turbo:load", initPopovers)
document.addEventListener("DOMContentLoaded", initPopovers)
