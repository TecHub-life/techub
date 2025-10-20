import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['tab', 'panel']
  static values = {
    default: { type: String, default: 'profile' },
    scrollToTop: { type: Boolean, default: true }
  }

  connect() {
    this.showTab(this.defaultValue)
  }

  change(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.showTab(tabName)
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
        tab.classList.remove('text-slate-500', 'dark:text-slate-400', 'hover:bg-slate-100', 'dark:hover:bg-slate-800')
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
        tab.classList.add('text-slate-500', 'dark:text-slate-400', 'hover:bg-slate-100', 'dark:hover:bg-slate-800')
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
