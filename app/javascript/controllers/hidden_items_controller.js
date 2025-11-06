import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    hiddenCount: Number,
    analyticsEndpoint: String,
  }

  connect() {
    this.visible = false
    this.toggleHandler = this.toggleFromEvent.bind(this)
    this.iddqdHandler = this.runIddqdGlow.bind(this)
    document.addEventListener('techub:hidden:toggle', this.toggleHandler)
    document.addEventListener('techub:iddqd', this.iddqdHandler)
  }

  disconnect() {
    document.removeEventListener('techub:hidden:toggle', this.toggleHandler)
    document.removeEventListener('techub:iddqd', this.iddqdHandler)
  }

  toggleFromEvent(event) {
    this.visible = Boolean(event?.detail?.visible)
    this.updateHiddenItems()
  }

  updateHiddenItems() {
    const items = this.element.querySelectorAll('[data-hidden-item]')
    items.forEach((el) => {
      el.classList.toggle('hidden', !this.visible)
      el.setAttribute('aria-hidden', String(!this.visible))
    })
  }

  runIddqdGlow() {
    this.element.classList.add(
      'ring-4',
      'ring-amber-400/60',
      'shadow-[0_0_35px_rgba(251,191,36,0.5)]'
    )
    setTimeout(() => {
      this.element.classList.remove(
        'ring-4',
        'ring-amber-400/60',
        'shadow-[0_0_35px_rgba(251,191,36,0.5)]'
      )
    }, 2000)
  }
}
