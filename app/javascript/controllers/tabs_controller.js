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
    this.showTab(this.defaultValue)
  }

  change(event) {
    const tabName = event.currentTarget.dataset.tabName
    console.log('Tab clicked:', tabName)
    this.showTab(tabName)
    // Only scroll to top if scrollToTop is true (default behavior)
    if (this.scrollToTopValue) {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  showTab(tabName) {
    console.log('🚨 SHOWTAB CALLED with:', tabName)
    console.log('Available tab targets:', this.tabTargets.map(t => t.dataset.tabName))
    console.log('Available panel targets:', this.panelTargets.map(p => p.dataset.tabPanel))
    
    // Update tab buttons
    this.tabTargets.forEach((tab) => {
      const isActive = tab.dataset.tabName === tabName
      console.log('Tab:', tab.dataset.tabName, 'isActive:', isActive)
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
      console.log('Panel:', panel.dataset.tabPanel, 'isActive:', isActive, 'current class:', panel.className)
      if (isActive) {
        panel.classList.remove('hidden')
        console.log('✅ SHOWING panel:', panel.dataset.tabPanel)
      } else {
        panel.classList.add('hidden')
        console.log('❌ HIDING panel:', panel.dataset.tabPanel)
      }
    })
  }
}
