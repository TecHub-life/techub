const hiddenHost = () => document.querySelector('[data-controller~="hidden-items"]')

const analyticsEndpoint = () => hiddenHost()?.dataset?.hiddenItemsAnalyticsEndpointValue
const profileLogin = () => hiddenHost()?.dataset?.hiddenItemsProfileValue

const csrfToken = () =>
  document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''

function sendAnalytics(eventName, properties = {}) {
  const endpoint = analyticsEndpoint()
  if (!endpoint || !eventName) return

  const payload = JSON.stringify({ event: eventName, ...properties })
  const headers = { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken() }

  if (navigator.sendBeacon) {
    const blob = new Blob([payload], { type: 'application/json' })
    navigator.sendBeacon(endpoint, blob)
  } else {
    fetch(endpoint, { method: 'POST', headers, body: payload })
  }
}

const techub = {
  hiddenVisible: false,
  revealHidden() {
    this.hiddenVisible = !this.hiddenVisible
    document.dispatchEvent(
      new CustomEvent('techub:hidden:toggle', { detail: { visible: this.hiddenVisible } })
    )
    if (this.hiddenVisible) {
      sendAnalytics('hidden_items_revealed', { hidden_count: this.hiddenCount() })
    }
    return this.hiddenVisible
  },
  hiddenCount() {
    const count = parseInt(hiddenHost()?.dataset?.hiddenItemsHiddenCountValue || '0', 10)
    console.info(`Hidden items: ${count}`)
    return count
  },
  iddqd() {
    console.log(
      '%c🧠 TEC HUB // INVINCIBLE MODE ENABLED',
      'background: #1e1b4b; color: #facc15; padding: 4px; border-radius: 4px;'
    )
    console.log(
      "Nice find, clever human. You've unlocked hidden bits. Keep exploring — there's always more under the surface."
    )
    document.dispatchEvent(new CustomEvent('techub:iddqd'))
    sendAnalytics('iddqd_triggered', { profile: profileLogin() })
    return true
  },
}

Object.defineProperty(window, 'techub', {
  value: techub,
  configurable: false,
  writable: false,
})
