import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['tab', 'panel']
  static values = { default: String }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener('keydown', this.handleKeydown)

    const fromQuery = new URLSearchParams(window.location.search).get('tab')
    const fallback =
      this.defaultValue ||
      this.tabTargets[0]?.dataset.tabsId ||
      this.tabTargets[0]?.dataset.tabName ||
      this.tabTargets[0]?.dataset.id
    this.selectById(fromQuery || fallback, { focus: false, replace: true })
  }

  disconnect() {
    this.element.removeEventListener('keydown', this.handleKeydown)
  }

  select(event) {
    const id = this.tabIdFor(event.currentTarget)
    this.selectById(id)
  }

  change(event) {
    this.select(event)
  }

  selectById(id, { focus = true, replace = false } = {}) {
    if (!id) return

    this.tabTargets.forEach((tab) => {
      const active = this.tabIdFor(tab) === id
      tab.setAttribute('aria-selected', String(active))
      if (active) {
        tab.dataset.active = 'true'
      } else {
        delete tab.dataset.active
      }
      tab.tabIndex = active ? 0 : -1
      tab.classList.toggle('bg-white', active)
      tab.classList.toggle('text-slate-900', active)
      tab.classList.toggle('dark:bg-slate-800', active)
      tab.classList.toggle('dark:text-slate-100', active)
      tab.classList.toggle('text-slate-500', !active)
      tab.classList.toggle('dark:text-slate-400', !active)
      if (active && focus) tab.focus()
    })

    this.panelTargets.forEach((panel) => {
      const active = this.panelIdFor(panel) === id
      panel.classList.toggle('hidden', !active)
      panel.setAttribute('aria-hidden', String(!active))
      panel.tabIndex = active ? 0 : -1
    })

    this.updateUrl(id, replace)
  }

  handleKeydown(event) {
    if (!['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(event.key)) return
    event.preventDefault()

    const currentIndex = this.tabTargets.findIndex((tab) => {
      return tab.getAttribute('aria-selected') === 'true'
    })
    if (currentIndex === -1) return

    let nextIndex = currentIndex
    if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % this.tabTargets.length
    if (event.key === 'ArrowLeft')
      nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
    if (event.key === 'Home') nextIndex = 0
    if (event.key === 'End') nextIndex = this.tabTargets.length - 1

    const nextTab = this.tabTargets[nextIndex]
    this.selectById(this.tabIdFor(nextTab))
  }

  updateUrl(id, replace) {
    const url = new URL(window.location)
    url.searchParams.set('tab', id)
    if (replace) {
      window.history.replaceState({}, '', url)
    } else {
      window.history.pushState({}, '', url)
    }
  }

  tabIdFor(element) {
    return element?.dataset?.tabsId || element?.dataset?.tabName || element?.dataset?.id || null
  }

  panelIdFor(element) {
    return element?.dataset?.tabsId || element?.dataset?.tabPanel || element?.dataset?.id || null
  }
}
