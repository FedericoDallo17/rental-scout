// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "timbre_brand"
import "onboarding"

// Native disclosures remain usable without JavaScript. Start compact on phones,
// and restore desktop controls when crossing the responsive breakpoint.
const phoneLayout = window.matchMedia("(max-width: 720px)")
const updateResponsiveDisclosures = () => {
  document.querySelectorAll("[data-responsive-disclosure]").forEach((disclosure) => {
    disclosure.open = !phoneLayout.matches
  })
}
phoneLayout.addEventListener("change", updateResponsiveDisclosures)
document.addEventListener("turbo:load", updateResponsiveDisclosures)
document.addEventListener("click", (event) => {
  if (!phoneLayout.matches) return
  const menu = document.querySelector(".app-account-menu[open]")
  if (menu && !menu.contains(event.target)) menu.open = false
})
document.addEventListener("keydown", (event) => {
  if (!phoneLayout.matches || event.key !== "Escape") return
  const menu = document.querySelector(".app-account-menu[open]")
  if (menu) {
    menu.open = false
    menu.querySelector("summary").focus()
  }
})

const urlBase64ToUint8Array = (value) => {
  const padding = "=".repeat((4 - value.length % 4) % 4)
  const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))
}

const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.content

const currentDeviceGuide = () => {
  const userAgent = navigator.userAgent || ""
  const platform = navigator.userAgentData?.platform || navigator.platform || ""
  const isTouchIpad = platform === "MacIntel" && navigator.maxTouchPoints > 1

  if (/iPhone|iPad|iPod/i.test(userAgent) || isTouchIpad) return "ios"
  if (/Android/i.test(userAgent)) return "android"
  if (/Windows|Win32|Win64/i.test(`${userAgent} ${platform}`)) return "windows"
  if (/Macintosh|MacIntel|MacPPC|Mac68K/i.test(`${userAgent} ${platform}`)) return "mac"
}

const openCurrentDeviceGuide = (settings) => {
  const device = currentDeviceGuide()
  if (!device) return

  const guide = settings.querySelector(`[data-device-guide='${device}']`)
  if (guide) {
    guide.open = true
    guide.dataset.detected = "true"
  }
}

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
  openCurrentDeviceGuide(settings)
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

let disposeTourEntrance = () => {}
let disposeTourHash = () => {}

const initializeTourEntrance = (tour) => {
  const entrance = document.querySelector("[data-tour-entrance]")
  const header = document.querySelector("[data-tour-header]")
  const scene = entrance?.querySelector("[data-timbre-motion]")
  if (!scene || location.hash.startsWith("#tour-") || tour.dataset.entered === "true") return

  const enter = entrance.querySelector("[data-tour-enter]")
  const skip = entrance.querySelector("[data-tour-skip]")
  const hint = entrance.querySelector("[data-tour-entrance-hint]")
  const reduced = matchMedia("(prefers-reduced-motion: reduce)")
  let leaving = false
  let exitAnimation
  let fallback
  entrance.hidden = false
  tour.hidden = true
  header.hidden = true

  const reveal = (focus = true) => {
    clearTimeout(fallback)
    exitAnimation?.cancel()
    entrance.hidden = true
    tour.hidden = false
    header.hidden = false
    tour.dataset.entered = "true"
    if (focus) tour.querySelector("[data-tour-panel]:not([hidden])").focus({ preventScroll: true })
  }
  const leave = () => {
    if (leaving) return
    leaving = true
    clearTimeout(fallback)
    if (reduced.matches || !entrance.animate) return reveal()
    exitAnimation = entrance.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 380, fill: "forwards" })
    exitAnimation.onfinish = () => reveal()
  }
  const open = () => {
    if (enter.disabled) return
    enter.disabled = true
    entrance.dataset.opening = "true"
    hint.textContent = hint.dataset.openingLabel
    // Always keep a route in, including browsers without Web Animations.
    fallback = setTimeout(leave, 3900)
    if (reduced.matches || !scene.dataset.initialized) leave()
    else scene.dispatchEvent(new CustomEvent("timbre:play"))
  }
  const followChapter = () => {
    if ([...tour.querySelectorAll("[data-tour-panel]")].some((panel) => `#${panel.id}` === location.hash)) leave()
  }
  enter.addEventListener("click", open)
  skip.addEventListener("click", leave)
  scene.addEventListener("timbre:finished", leave)
  window.addEventListener("hashchange", followChapter)
  disposeTourEntrance = () => {
    reveal(false)
    enter.removeEventListener("click", open)
    skip.removeEventListener("click", leave)
    scene.removeEventListener("timbre:finished", leave)
    window.removeEventListener("hashchange", followChapter)
    disposeTourEntrance = () => {}
  }
}

const initializePortfolioTour = () => {
  const tour = document.querySelector("[data-portfolio-tour]")
  if (!tour || tour.dataset.initialized === "true") return
  tour.dataset.initialized = "true"
  const panels = [...tour.querySelectorAll("[data-tour-panel]")]
  const links = [...tour.querySelectorAll("[data-tour-step]")]
  const back = tour.querySelector("[data-tour-back]")
  const next = tour.querySelector("[data-tour-next]")
  const nextLabel = next.textContent
  const progress = tour.querySelector("[data-tour-progress]")
  let current = Math.max(0, panels.findIndex((panel) => `#${panel.id}` === location.hash))

  const show = (index, focus = true) => {
    current = index
    panels.forEach((panel, i) => { panel.hidden = i !== current })
    links.forEach((link, i) => {
      if (i === current) link.setAttribute("aria-current", "step")
      else link.removeAttribute("aria-current")
    })
    back.disabled = current === 0
    next.textContent = current === panels.length - 1 ? next.dataset.finishLabel : nextLabel
    progress.textContent = progress.dataset.template.replace("{current}", current + 1)
    if (focus) {
      history.replaceState(null, "", `#${panels[current].id}`)
      panels[current].focus({ preventScroll: true })
      panels[current].scrollIntoView({ block: "nearest" })
    }
  }
  const followHash = () => {
    const index = panels.findIndex((panel) => `#${panel.id}` === location.hash)
    if (index >= 0) show(index)
  }
  window.addEventListener("hashchange", followHash)
  disposeTourHash = () => window.removeEventListener("hashchange", followHash)
  links.forEach((link, i) => link.addEventListener("click", (event) => {
    event.preventDefault()
    show(i)
  }))
  back.addEventListener("click", () => show(Math.max(0, current - 1)))
  next.addEventListener("click", () => {
    if (current === panels.length - 1) {
      budget.value = budget.defaultValue
      filter()
      tour.querySelectorAll("[data-tour-favorite]").forEach((button) => {
        button.setAttribute("aria-pressed", "false")
        button.textContent = button.dataset.saveLabel
      })
      tour.querySelectorAll("[data-tour-tracking]").forEach((select) => { select.selectedIndex = 0 })
      tour.querySelector("[data-tour-tracking-feedback]").textContent = ""
      tour.querySelector("[data-tour-notification]").hidden = true
    }
    show((current + 1) % panels.length)
  })
  tour.querySelector("[data-tour-navigation]").hidden = false
  show(current, false)

  const budget = tour.querySelector("[data-tour-budget]")
  const count = tour.querySelector("[data-tour-match-count]")
  const filter = () => {
    const cards = [...tour.querySelectorAll('[data-filterable="true"]')]
    cards.forEach((card) => { card.hidden = Number(card.dataset.price) > Number(budget.value) })
    const matches = cards.filter((card) => !card.hidden).length
    count.textContent = count.dataset.template.replace("{count}", matches)
    tour.querySelector("[data-tour-budget-value]").textContent = `UYU ${Number(budget.value).toLocaleString(document.documentElement.lang)}`
    tour.querySelector("[data-tour-empty]").hidden = matches > 0
  }
  budget.addEventListener("input", filter)
  filter()
  tour.querySelectorAll("[data-tour-favorite]").forEach((button) => {
    button.addEventListener("click", () => {
      const saved = button.getAttribute("aria-pressed") !== "true"
      button.setAttribute("aria-pressed", String(saved))
      button.textContent = saved ? button.dataset.savedLabel : button.dataset.saveLabel
    })
  })
  tour.querySelectorAll("[data-tour-tracking]").forEach((select) => {
    select.addEventListener("change", () => {
      const feedback = tour.querySelector("[data-tour-tracking-feedback]")
      feedback.textContent = feedback.dataset.template.replace("{status}", select.value)
    })
  })
  tour.querySelector("[data-tour-alert]").addEventListener("click", () => {
    tour.querySelector("[data-tour-notification]").hidden = false
  })
  initializeTourEntrance(tour)
}

document.addEventListener("turbo:load", initializePortfolioTour)
// Turbo restores cached HTML without its event listeners; rebuild the tour on return.
document.addEventListener("turbo:before-cache", () => {
  disposeTourEntrance()
  disposeTourHash()
  const tour = document.querySelector("[data-portfolio-tour]")
  if (tour) delete tour.dataset.initialized
})
