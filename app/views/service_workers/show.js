self.addEventListener("push", (event) => {
  const payload = event.data ? event.data.json() : {}
  event.waitUntil(self.registration.showNotification(payload.title || "Rental Scout", {
    body: payload.body || "",
    tag: payload.tag,
    data: { url: payload.url || "/" }
  }))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const targetUrl = new URL(event.notification.data?.url || "/", self.location.origin).href
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      const existingClient = windowClients.find((client) => client.url === targetUrl)
      return existingClient ? existingClient.focus() : clients.openWindow(targetUrl)
    })
  )
})
