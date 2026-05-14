import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "badge", "frame"]

  connect() {
    this.open = false
    this.requestPermission()
    this.subscribeToPush()

    // Close panel on outside click
    this._outsideClick = (e) => {
      if (this.open && !this.element.contains(e.target)) this.closePanel()
    }
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  togglePanel(e) {
    e.preventDefault()
    e.stopPropagation()
    this.open = !this.open
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("show", this.open)
    }
    // Load notifications when opening
    if (this.open && this.hasFrameTarget) {
      this.frameTarget.src = "/notificaciones"
    }
  }

  closePanel() {
    this.open = false
    if (this.hasPanelTarget) this.panelTarget.classList.remove("show")
  }

  markRead(e) {
    const id = e.currentTarget.dataset.notificationId
    if (!id) return
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(`/notificaciones/${id}/leer`, {
      method: "PATCH",
      headers: { "X-CSRF-Token": csrfToken, "Accept": "text/vnd.turbo-stream.html" }
    })
  }

  async requestPermission() {
    if (!("Notification" in window)) return
    if (Notification.permission === "default") {
      // Wait a few seconds before prompting
      setTimeout(() => { Notification.requestPermission() }, 3000)
    }
  }

  async subscribeToPush() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) return
    if (Notification.permission !== "granted") return

    try {
      const reg = await navigator.serviceWorker.ready
      let sub = await reg.pushManager.getSubscription()

      if (!sub) {
        const vapidKey = document.querySelector('meta[name="vapid-public-key"]')?.content
        if (!vapidKey) return

        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: this.urlBase64ToUint8Array(vapidKey)
        })
      }

      const json = sub.toJSON()
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      await fetch("/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          endpoint: json.endpoint,
          p256dh: json.keys.p256dh,
          auth: json.keys.auth
        })
      })
    } catch (err) {
      console.warn("Push subscription failed:", err)
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - base64String.length % 4) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = atob(base64)
    const outputArray = new Uint8Array(rawData.length)
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i)
    }
    return outputArray
  }
}
