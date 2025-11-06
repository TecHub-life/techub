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
    const count = this._hiddenCountValue()
    document.dispatchEvent(
      new CustomEvent('techub:hidden:toggle', { detail: { visible: this.hiddenVisible } })
    )
    if (this.hiddenVisible) {
      sendAnalytics('hidden_items_revealed', { hidden_count: count })
    }
    if (count === 0) {
      this._celebrateNoSecrets()
    } else {
      const state = this.hiddenVisible ? 'revealed' : 'hidden'
      console.info(`Hidden items ${state}: ${count} secret${count === 1 ? '' : 's'} loaded.`)
    }
    return this.hiddenVisible
  },
  hiddenCount() {
    const count = this._hiddenCountValue()
    if (count === 0) {
      this._celebrateNoSecrets()
    } else {
      console.info(`Hidden items: ${count}`)
    }
    return count
  },
  _hiddenCountValue() {
    return parseInt(hiddenHost()?.dataset?.hiddenItemsHiddenCountValue || '0', 10) || 0
  },
  _celebrateNoSecrets() {
    console.log(
      '%cNO SECRETS (YET) • TEC HUB',
      'background: #0f172a; color: #38bdf8; padding: 4px 8px; border-radius: 4px; font-weight: bold;'
    )
    console.log(
      "You've unlocked the console even without hidden items. Add a hidden link in settings to turn this into a scavenger hunt."
    )
    console.log('Tip: toggle the “Hidden” checkbox + share a secret code to guide visitors.')
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
