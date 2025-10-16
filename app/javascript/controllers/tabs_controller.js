import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['tab', 'panel']
  static values = {
    default: { type: String, default: 'profile' }
  }

  connect() {
    this.showTab(this.defaultValue)
  }

  change(event) {
    const tabName = event.currentTarget.dataset.tabName
    this.showTab(tabName)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  showTab(tabName) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabName === tabName
      if (isActive) {
        tab.classList.remove('border-transparent', 'text-slate-500', 'dark:text-slate-400')
        tab.classList.add('border-indigo-500', 'text-indigo-600', 'dark:border-indigo-400', 'dark:text-indigo-400')
      } else {
        tab.classList.remove('border-indigo-500', 'text-indigo-600', 'dark:border-indigo-400', 'dark:text-indigo-400')
        tab.classList.add('border-transparent', 'text-slate-500', 'dark:text-slate-400')
      }
    })

    // Update panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tabPanel === tabName
      if (isActive) {
        panel.classList.remove('hidden')
      } else {
        panel.classList.add('hidden')
      }
    })
  }
}
