import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'results']
  static values = { 
    field: String,
    endpoint: { type: String, default: '/directory/autocomplete' }
  }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 1) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => this.fetch(query), 100)
  }

  async fetch(query) {
    const response = await fetch(
      `${this.endpointValue}?field=${this.fieldValue}&q=${encodeURIComponent(query)}`
    )
    const data = await response.json()
    this.show(data.results)
  }

  show(results) {
    if (!results.length) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = results
      .map(
        (r) =>
          `<div class="px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer text-sm font-medium text-slate-700 dark:text-slate-200 border-b border-slate-200 dark:border-slate-600 last:border-0 transition-colors" data-action="click->autocomplete#select" data-value="${r.value}">${r.label}</div>`
      )
      .join('')
    this.resultsTarget.classList.remove('hidden')
  }

  select(e) {
    this.inputTarget.value = e.currentTarget.dataset.value
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
  }

  clickOutside(e) {
    if (!this.element.contains(e.target)) {
      this.hideResults()
    }
  }
}
