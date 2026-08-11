// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"

const urlBase64ToUint8Array = (value) => {
  const padding = "=".repeat((4 - value.length % 4) % 4)
  const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
}

const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content

const saveSubscription = async (settings, subscription) => {
  const response = await fetch(settings.dataset.createUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), "Accept": "application/json" },
    body: JSON.stringify({ subscription: subscription.toJSON() })
  })
  if (!response.ok) throw new Error("Could not save push subscription")
}

const removeSubscription = async (settings, subscription) => {
  const response = await fetch(settings.dataset.destroyUrl, {
    method: "DELETE",
    headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken(), "Accept": "application/json" },
    body: JSON.stringify({ endpoint: subscription.endpoint })
  })
  if (!response.ok && response.status !== 404) throw new Error("Could not remove push subscription")
  await subscription.unsubscribe()
}

const initializeWebPushSettings = async () => {
  const settings = document.querySelector("[data-web-push-settings]")
  if (!settings || settings.dataset.initialized === "true") return
  settings.dataset.initialized = "true"

  const button = settings.querySelector("[data-web-push-toggle]")
  const status = settings.querySelector("[data-web-push-status]")
  if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
    button.disabled = true
    status.textContent = settings.dataset.unsupportedLabel
    return
  }

  const registration = await navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
  let subscription = await registration.pushManager.getSubscription()

  const render = () => {
    button.textContent = subscription ? settings.dataset.disableLabel : settings.dataset.enableLabel
    status.textContent = subscription ? settings.dataset.enabledLabel : ""
  }
  render()

  button.addEventListener("click", async () => {
    button.disabled = true
    try {
      if (subscription) {
        await removeSubscription(settings, subscription)
        subscription = null
      } else {
        const permission = await Notification.requestPermission()
        if (permission !== "granted") {
          status.textContent = settings.dataset.deniedLabel
          return
        }
        const newSubscription = await registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(settings.dataset.vapidPublicKey)
        })
        try {
          await saveSubscription(settings, newSubscription)
          subscription = newSubscription
        } catch (error) {
          await newSubscription.unsubscribe()
          throw error
        }
      }
      render()
    } catch (error) {
      console.error(error)
      status.textContent = settings.dataset.errorLabel
    } finally {
      button.disabled = false
    }
  })
}

document.addEventListener("turbo:load", () => initializeWebPushSettings().catch(console.error))
