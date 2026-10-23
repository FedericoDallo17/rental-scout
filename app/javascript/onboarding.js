const initializeOnboarding = () => {
  const form = document.querySelector("form[data-onboarding]")
  if (!form || form.dataset.initialized) return
  form.dataset.initialized = "true"
  const panels = [...form.querySelectorAll("[data-onboarding-panel]")]
  const progress = [...form.querySelectorAll("[data-onboarding-progress]")]
  const next = form.querySelector("[data-onboarding-next]")
  const back = form.querySelector("[data-onboarding-back]")
  const submit = form.querySelector("[data-onboarding-submit]")
  const summary = document.querySelector("[data-onboarding-summary]")
  const field = (name) => form.elements.namedItem(`search_preference[${name}]`)
  const selectedText = (name) => field(name).selectedOptions[0].textContent
  let current = Number(form.dataset.step || 0)

  const updateSummary = () => {
    const zones = [...form.querySelectorAll("[data-onboarding-zone] input:checked")]
      .map((input) => input.closest("label").textContent.trim())
    const zoneSummary = summary.querySelector("[data-onboarding-summary-zones]")
    zoneSummary.textContent = zones.join(", ") || zoneSummary.dataset.empty
    summary.querySelector("[data-onboarding-summary-operation]").textContent = selectedText("operation_type")
    summary.querySelector("[data-onboarding-summary-bedrooms]").textContent = selectedText("min_bedrooms")
    const budget = summary.querySelector("[data-onboarding-summary-budget]")
    const currency = field("price_currency").value
    const min = field("min_price").value
    const max = field("max_price").value
    const number = (value) => Number(value).toLocaleString(document.documentElement.lang)
    const range = min && max ? `${number(min)} – ${number(max)}` : max ? `≤ ${number(max)}` : min ? `≥ ${number(min)}` : null
    budget.textContent = range ? `${currency} ${range}` : budget.dataset.empty
    if (range && form.querySelector("input[type='checkbox'][name='search_preference[include_expenses]']").checked) {
      budget.textContent += ` · ${budget.dataset.expenses}`
    }
  }

  const show = (index, focus = true) => {
    current = Math.max(0, Math.min(panels.length - 1, index))
    form.dataset.step = String(current)
    panels.forEach((panel, i) => { panel.hidden = i !== current })
    progress.forEach((item, i) => {
      if (i === current) item.setAttribute("aria-current", "step")
      else item.removeAttribute("aria-current")
      item.classList.toggle("is-complete", i < current)
    })
    next.hidden = current === panels.length - 1
    back.hidden = current === 0
    submit.hidden = current !== panels.length - 1
    if (focus) panels[current].querySelector("h2").focus()
  }

  const validPanel = () => [...panels[current].querySelectorAll("input, select")]
    .every((input) => input.reportValidity())

  next.addEventListener("click", () => { if (validPanel()) show(current + 1) })
  back.addEventListener("click", () => show(current - 1))
  // Enter advances the active step rather than saving an unfinished search.
  form.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && event.target.matches("input:not([type='submit'])") && current < panels.length - 1) {
      event.preventDefault()
      if (validPanel()) show(current + 1)
    }
  })
  // Reveal native validation errors even when the invalid field is in another step.
  form.addEventListener("invalid", (event) => {
    const panel = event.target.closest("[data-onboarding-panel]")
    if (panel) {
      const details = event.target.closest("details")
      if (details) details.open = true
      show(panels.indexOf(panel), false)
    }
  }, true)
  form.addEventListener("input", updateSummary)
  form.addEventListener("change", updateSummary)

  const normalize = (value) => value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim()
  form.querySelector("[data-onboarding-zone-filter]").hidden = false
  const query = form.querySelector("[data-onboarding-zone-query]")
  const filterZones = () => {
    const labels = [...form.querySelectorAll("[data-onboarding-zone]")]
    labels.forEach((label) => { label.hidden = !normalize(label.textContent).includes(normalize(query.value)) })
    form.querySelector("[data-onboarding-no-zones]").hidden = labels.some((label) => !label.hidden)
  }
  query.addEventListener("input", filterZones)
  filterZones()
  updateSummary()
  // On a failed server save, show every field so all errors can be corrected.
  if (form.querySelector("[data-onboarding-errors]")) {
    panels.forEach((panel) => { panel.hidden = false })
    submit.hidden = false
    form.querySelector("[data-onboarding-errors]").focus()
  } else {
    show(current, false)
  }
}

document.addEventListener("turbo:load", initializeOnboarding)
document.addEventListener("turbo:before-cache", () => {
  const form = document.querySelector("form[data-onboarding]")
  if (form) delete form.dataset.initialized
})
