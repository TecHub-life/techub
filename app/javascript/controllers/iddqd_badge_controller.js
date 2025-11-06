import { Controller } from '@hotwired/stimulus'

// Toggles the Doom easter-egg badge when the correct query param is present.
export default class extends Controller {
  static targets = ['badge']
  static values = {
    code: String,
    param: { type: String, default: 'iddqd' }
  }

  connect () {
    this.revealIfUnlocked()
  }

  revealIfUnlocked () {
    const code = this.codeValue || '42069'
    const paramName = this.paramValue || 'iddqd'

    if (!code || !paramName) return

    const searchParams = new URLSearchParams(window.location.search)
    const queryMatch = searchParams.get(paramName)

    if (queryMatch === code) {
      this.persistUnlock(code)
      this.showBadge()
      return
    }

    if (this.storedCode === code) {
      this.showBadge()
    }
  }

  showBadge () {
    if (!this.hasBadgeTarget) return
    this.badgeTarget.classList.remove('hidden')
  }

  persistUnlock (code) {
    try {
      window.localStorage.setItem(this.storageKey, code)
    } catch (error) {
      // Ignore storage issues (private browsing, etc.).
    }
  }

  get storedCode () {
    try {
      return window.localStorage.getItem(this.storageKey)
    } catch (error) {
      return null
    }
  }

  get storageKey () {
    return `techub-${this.paramValue || 'iddqd'}-unlock`
  }
}
