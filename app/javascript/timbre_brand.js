// Approved D2 motion: a rigid door opens outward about its left hinge, the
// lettering passes through the opening, then the original SVG paths are restored.
const duration = 3300
const activeScenes = new Set()
const svgNamespace = "http://www.w3.org/2000/svg"
let sceneId = 0
const ease = (t) => t * t * (3 - 2 * t)

const doorAngle = (time) => {
  if (time <= 495 || time >= 3102) return 0
  if (time < 1254) return 100 * ease((time - 495) / 759)
  if (time <= 2300) return 100
  return 100 * (1 - ease((time - 2300) / 802))
}

function initializeScene(root) {
  if (root.dataset.initialized || !Element.prototype.animate) return
  const art = root.querySelector(".timbre-motion__art")
  const originalMarkup = art.innerHTML
  const replay = root.querySelector("[data-timbre-replay]")
  const manual = root.dataset.timbreTrigger === "manual"
  const reduced = matchMedia("(prefers-reduced-motion: reduce)")
  const part = (name) => art.querySelector(`[data-part="${name}"]`)
  const leaf = part("leaf")
  const composition = part("composition")
  const tail = part("tail")
  const paths = [...leaf.querySelectorAll("path")].map((node) => {
    const original = node.getAttribute("d")
    const contours = original.split(/(?=M)/).filter((d) => d.trim()).map((d) => {
      const guide = document.createElementNS(svgNamespace, "path")
      guide.setAttribute("d", d)
      const length = guide.getTotalLength()
      const count = Math.max(8, Math.ceil(length / 0.6))
      return Array.from({ length: count }, (_, i) => {
        const point = guide.getPointAtLength(length * i / count)
        return { x: point.x, y: point.y }
      })
    })
    return { node, original, contours }
  })

  const slab = document.createElementNS(svgNamespace, "path")
  slab.setAttribute("fill", "currentColor")
  slab.setAttribute("opacity", "0")
  const definitions = document.createElementNS(svgNamespace, "defs")
  const gatewayId = `timbre-door-gateway-${++sceneId}`
  definitions.innerHTML = `<clipPath id="${gatewayId}" clipPathUnits="userSpaceOnUse"><rect x="12" y="0" width="528" height="132"/></clipPath>`
  const gateway = document.createElementNS(svgNamespace, "g")
  gateway.setAttribute("clip-path", `url(#${gatewayId})`)
  composition.insertBefore(gateway, tail)
  gateway.append(tail)
  composition.prepend(definitions)
  composition.append(slab, leaf, part("button"), part("waves"))

  let animations = []
  let frame = 0
  const projectDoor = (angle) => {
    root.dataset.doorAngle = angle.toFixed(3)
    if (angle < 0.00001) {
      paths.forEach(({ node, original }) => node.setAttribute("d", original))
      slab.setAttribute("opacity", "0")
      slab.removeAttribute("d")
      return
    }
    const a = angle * Math.PI / 180
    const c = Math.cos(a), s = Math.sin(a)
    const project = (x, y, z = 0) => {
      const rx = x * c - z * s, rz = x * s + z * c, w = 1 - rz / 260
      return [rx / w, 60 + (y - 60) / w].map((n) => n.toFixed(4)).join(" ")
    }
    paths.forEach(({ node, contours }) => {
      node.setAttribute("d", contours.map((points) =>
        `M${points.map(({ x, y }) => project(x, y)).join("L")}Z`).join(" "))
    })
    const edge = [[72, 36, 0], [72, 120, 0], [72, 120, -2.4], [72, 36, -2.4]]
    slab.setAttribute("d", `M${edge.map((p) => project(...p)).join("L")}Z`)
    slab.setAttribute("opacity", (s * 0.55).toFixed(4))
  }
  const finish = () => {
    cancelAnimationFrame(frame)
    animations.forEach((animation) => animation.cancel())
    animations = []
    projectDoor(0)
    root.dataset.scene = "done"
  }
  const track = () => {
    const time = Math.min(duration, Number(animations[0]?.currentTime) || 0)
    projectDoor(doorAngle(time))
    if (time < duration && animations[0]?.playState === "running") frame = requestAnimationFrame(track)
  }
  const play = () => {
    finish()
    if (reduced.matches) {
      root.dispatchEvent(new CustomEvent("timbre:finished"))
      return
    }
    const animate = (name, frames) => part(name).animate(frames, { duration, fill: "both", easing: "linear" })
    animations = [
      animate("composition", [
        { offset: 0, transform: `translateX(${manual ? 199 : 176}px)` },
        { offset: 0.15, transform: `translateX(${manual ? 199 : 176}px)`, easing: "cubic-bezier(.22,.7,.2,1)" },
        { offset: 0.64, transform: "none" }, { offset: 1, transform: "none" }
      ]),
      animate("tail", [
        { offset: 0, opacity: 1, transform: "translateX(-496px)" },
        { offset: 0.36, opacity: 1, transform: "translateX(-496px)", easing: "cubic-bezier(.3,.05,.2,1)" },
        { offset: 0.68, opacity: 1, transform: "none" }, { offset: 1, opacity: 1, transform: "none" }
      ]),
      animate("button", [
        { offset: 0, transform: "none" }, { offset: 0.05, transform: "translate(9.6px,1.6px) scale(.9)" },
        { offset: 0.13, transform: "none" }, { offset: 1, transform: "none" }
      ]),
      animate("waves", [
        { offset: 0, opacity: 0, transform: "translate(9.6px,1.6px) scale(.9)" },
        { offset: 0.035, opacity: 0.65, transform: "none" },
        { offset: 0.18, opacity: 0, transform: "translate(-48px,-8px) scale(1.5)" },
        { offset: 1, opacity: 0, transform: "translate(-48px,-8px) scale(1.5)" }
      ])
    ]
    animations[0].onfinish = () => {
      finish()
      root.dispatchEvent(new CustomEvent("timbre:finished"))
    }
    root.dataset.scene = "playing"
    frame = requestAnimationFrame(track)
  }
  const motionPreferenceChanged = () => {
    const wasPlaying = root.dataset.scene === "playing"
    finish()
    if (replay) replay.hidden = reduced.matches
    if (manual && !wasPlaying) root.dataset.scene = "idle"
    if (wasPlaying) root.dispatchEvent(new CustomEvent("timbre:finished"))
  }
  const onPageHide = () => finish()
  const dispose = () => {
    finish()
    replay?.removeEventListener("click", play)
    root.removeEventListener("timbre:play", play)
    reduced.removeEventListener("change", motionPreferenceChanged)
    window.removeEventListener("pagehide", onPageHide)
    art.innerHTML = originalMarkup
    if (replay) replay.hidden = true
    delete root.dataset.initialized
    delete root.dataset.scene
    delete root.dataset.doorAngle
  }
  root.dataset.initialized = "true"
  replay?.addEventListener("click", play)
  root.addEventListener("timbre:play", play)
  reduced.addEventListener("change", motionPreferenceChanged)
  window.addEventListener("pagehide", onPageHide)
  activeScenes.add(dispose)
  motionPreferenceChanged()
  // Play on every visit. Forms remain usable throughout; no sound.
  if (!manual && !reduced.matches) play()
}

document.addEventListener("turbo:load", () => {
  document.querySelectorAll("[data-timbre-motion]").forEach(initializeScene)
})
document.addEventListener("turbo:before-cache", () => {
  activeScenes.forEach((dispose) => dispose())
  activeScenes.clear()
})
