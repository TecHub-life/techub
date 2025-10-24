import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['tab', 'panel']
  static values = {
    default: { type: String, default: 'profile' },
    scrollToTop: { type: Boolean, default: true },
  }

  connect() {
    console.log('Tabs controller connected, default tab:', this.defaultValue)
    console.log('Found tab targets:', this.tabTargets.length)
    console.log('Found panel targets:', this.panelTargets.length)

    // Check URL for tab parameter
    const urlParams = new URLSearchParams(window.location.search)
    const tabFromUrl = urlParams.get('tab')
    const initialTab = tabFromUrl || this.defaultValue

    console.log('Initial tab from URL or default:', initialTab)
    this.showTab(initialTab)
  }

  change(event) {
    const tabName = event.currentTarget.dataset.tabName
    console.log('Tab clicked:', tabName)
    this.showTab(tabName)

    // Update URL with tab parameter
    const url = new URL(window.location)
    url.searchParams.set('tab', tabName)
    window.history.pushState({}, '', url)

    // Only scroll to top if scrollToTop is true (default behavior)
    if (this.scrollToTopValue) {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  showTab(tabName) {
    // Update tab buttons
    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.tabName === tabName
      if (isActive) {
        tab.classList.remove(
          'text-slate-500',
          'dark:text-slate-400',
          'hover:bg-slate-100',
          'dark:hover:bg-slate-800'
        )
        tab.classList.add(
          'bg-indigo-100',
          'text-indigo-700',
          'dark:bg-indigo-900/30',
          'dark:text-indigo-300'
        )
      } else {
        tab.classList.remove(
          'bg-indigo-100',
          'text-indigo-700',
          'dark:bg-indigo-900/30',
          'dark:text-indigo-300'
        )
        tab.classList.add(
          'text-slate-500',
          'dark:text-slate-400',
          'hover:bg-slate-100',
          'dark:hover:bg-slate-800'
        )
      }
    })

    // Update panels
    this.panelTargets.forEach((panel) => {
      const isActive = panel.dataset.tabPanel === tabName
      if (isActive) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }
}
