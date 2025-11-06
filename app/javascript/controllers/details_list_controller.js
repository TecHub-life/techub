import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['item']

  expandAll(event) {
    event.preventDefault()
    this.itemTargets.forEach((details) => {
      details.open = true
    })
  }

  collapseAll(event) {
    event.preventDefault()
    this.itemTargets.forEach((details) => {
      details.open = false
    })
  }
}
