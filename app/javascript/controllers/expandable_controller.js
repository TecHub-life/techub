import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['collapsed', 'expanded']

  connect() {
    this.collapse()
  }

  expand() {
    this.collapsedTarget.classList.add('hidden')
    this.expandedTarget.classList.remove('hidden')
  }

  collapse() {
    this.collapsedTarget.classList.remove('hidden')
    this.expandedTarget.classList.add('hidden')
  }
}
