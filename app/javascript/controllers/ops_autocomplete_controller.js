import { Controller } from '@hotwired/stimulus'

// Simple autocomplete for /ops admin forms.
// Configure with data-ops-autocomplete-endpoint-value, returning [{ login }].
export default class extends Controller {
  static targets = ['input', 'results']
  static values = { endpoint: String }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)
    const q = this.inputTarget.value.trim()
    if (q.length < 1) return this.hide()
    this.timeout = setTimeout(() => this.fetch(q), 120)
  }

  async fetch(q) {
    try {
      const url = `${this.endpointValue}?q=${encodeURIComponent(q)}`
      const resp = await fetch(url, { headers: { Accept: 'application/json' } })
      if (!resp.ok) return this.hide()
      const data = await resp.json()
      const items = Array.isArray(data) ? data : []
      this.show(items)
    } catch (_) {
      this.hide()
    }
  }

  show(items) {
    if (!items.length) return this.hide()
    this.resultsTarget.innerHTML = items
      .map(
        (r) =>
          `<div class="px-3 py-1.5 text-sm cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700" data-action="click->ops-autocomplete#pick" data-value="${r.login}">@${r.login}</div>`
      )
      .join('')
    this.resultsTarget.classList.remove('hidden')
  }

  pick(e) {
    this.inputTarget.value = e.currentTarget.dataset.value
    this.hide()
  }

  hide() {
    this.resultsTarget.classList.add('hidden')
    this.resultsTarget.innerHTML = ''
  }
}
