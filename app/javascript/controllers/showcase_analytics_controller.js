import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    event: String,
    itemId: Number,
    kind: String,
    hidden: { type: Boolean, default: false },
    pinned: { type: Boolean, default: false },
    style: String,
    surface: String,
    profile: String,
  }

  track(event) {
    if (this.element.tagName === 'A') {
      // let navigation continue asynchronously
      this.dispatchEvent(event)
    }
    this.sendPayload()
  }

  dispatchEvent(event) {
    // placeholder for future hooks
  }

  sendPayload() {
    const endpoint = this.analyticsEndpoint
    if (!endpoint || !this.eventValue) return

    const payload = {
      event: this.eventValue,
      profile: this.profileValue,
      item_id: this.itemIdValue,
      kind: this.kindValue,
      hidden: this.hiddenValue,
      pinned: this.pinnedValue,
      style: this.styleValue,
      surface: this.surfaceValue,
    }

    const body = JSON.stringify(payload)
    const headers = { 'Content-Type': 'application/json', 'X-CSRF-Token': this.csrfToken }

    if (navigator.sendBeacon) {
      const blob = new Blob([body], { type: 'application/json' })
      navigator.sendBeacon(endpoint, blob)
    } else {
      fetch(endpoint, { method: 'POST', headers, body })
    }
  }

  get analyticsEndpoint() {
    const host = document.querySelector('[data-controller~="hidden-items"]')
    return host?.dataset?.hiddenItemsAnalyticsEndpointValue
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta?.getAttribute('content') || ''
  }
}
