import { Controller } from '@hotwired/stimulus'

const STORAGE_KEY = 'techub-theme'

export default class extends Controller {
  static targets = ['button', 'icon']

  connect() {
    this.applyPreferredTheme()
  }

  toggle() {
    const current = document.documentElement.classList.contains('dark') ? 'dark' : 'light'
    const next = current === 'dark' ? 'light' : 'dark'
    this.setTheme(next)
  }

  applyPreferredTheme() {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored) {
      this.setTheme(stored, { persist: false })
      return
    }

    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    this.setTheme(prefersDark ? 'dark' : 'light', { persist: false })
  }

  setTheme(theme, { persist = true } = {}) {
    document.documentElement.classList.toggle('dark', theme === 'dark')
    document.documentElement.dataset.theme = theme
    if (persist) {
      window.localStorage.setItem(STORAGE_KEY, theme)
    }
    window.dispatchEvent(new CustomEvent('techub:theme-change', { detail: { theme } }))
    this.updateIcon(theme)
  }

  updateIcon(theme) {
    if (!this.hasIconTarget) return
    this.iconTarget.textContent = theme === 'dark' ? '🌞' : '🌚'
  }
}
