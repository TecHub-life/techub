import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'curl',
    'fetch',
    'copyNotice',
    'tryPanel',
    'form',
    'status',
    'response',
    'pathInput',
    'queryInput',
    'toggleIcon',
  ]

  static values = {
    baseUrl: String,
    path: String,
    verb: String,
  }

  connect() {
    this.copyTimeout = null
  }

  disconnect() {
    if (this.copyTimeout) {
      clearTimeout(this.copyTimeout)
      this.copyTimeout = null
    }
  }

  copyCurl() {
    this.copyFromTarget(this.hasCurlTarget ? this.curlTarget : null)
  }

  copyFetch() {
    this.copyFromTarget(this.hasFetchTarget ? this.fetchTarget : null)
  }

  toggleTry(event) {
    if (!this.hasTryPanelTarget) return
    const willOpen = this.tryPanelTarget.classList.contains('hidden')
    this.tryPanelTarget.classList.toggle('hidden', !willOpen)
    if (event?.currentTarget) {
      event.currentTarget.setAttribute('aria-expanded', willOpen ? 'true' : 'false')
    }
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle('rotate-180', willOpen)
    }
    if (willOpen) {
      this.showStatus('Ready', false)
    } else {
      this.showStatus('', false)
    }
  }

  send(event) {
    event.preventDefault()
    const { url, missing } = this.buildUrl()
    if (missing.length > 0) {
      this.showStatus(`Fill ${missing.join(', ')}`, true)
      if (this.hasResponseTarget) {
        this.responseTarget.classList.add('hidden')
        this.responseTarget.textContent = ''
      }
      return
    }
    if (!url) {
      this.showStatus('Missing endpoint URL', true)
      return
    }
    this.showStatus('Sending...', false)
    fetch(url, {
      method: (this.verbValue || 'GET').toUpperCase(),
      headers: {
        Accept: 'application/json',
      },
    })
      .then(async (response) => {
        const text = await response.text()
        let body = text
        try {
          const json = JSON.parse(text)
          body = JSON.stringify(json, null, 2)
        } catch (error) {
          if (!text) {
            body = '(empty response)'
          }
        }
        this.showStatus(`HTTP ${response.status} ${response.statusText}`, !response.ok)
        if (this.hasResponseTarget) {
          this.responseTarget.textContent = body
          this.responseTarget.classList.remove('hidden')
        }
      })
      .catch((error) => {
        this.showStatus(error.message || 'Request failed', true)
        if (this.hasResponseTarget) {
          this.responseTarget.textContent = ''
          this.responseTarget.classList.add('hidden')
        }
      })
  }

  copyFromTarget(target) {
    const text = target?.textContent?.trim()
    if (!text) return
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard
        .writeText(text)
        .then(() => this.showCopyNotice('Copied!'))
        .catch(() => this.fallbackCopy(text))
    } else {
      this.fallbackCopy(text)
    }
  }

  fallbackCopy(text) {
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.setAttribute('readonly', '')
    textarea.style.position = 'fixed'
    textarea.style.top = '-9999px'
    document.body.appendChild(textarea)
    textarea.select()
    try {
      const ok = document.execCommand('copy')
      this.showCopyNotice(ok ? 'Copied!' : 'Copy failed', !ok)
    } catch (error) {
      this.showCopyNotice('Copy failed', true)
    }
    document.body.removeChild(textarea)
  }

  showCopyNotice(message, isError = false) {
    if (!this.hasCopyNoticeTarget) return
    this.copyNoticeTarget.textContent = message
    this.copyNoticeTarget.classList.remove('hidden', 'text-emerald-600', 'text-rose-500')
    this.copyNoticeTarget.classList.add(isError ? 'text-rose-500' : 'text-emerald-600')
    if (this.copyTimeout) {
      clearTimeout(this.copyTimeout)
    }
    this.copyTimeout = setTimeout(() => {
      this.copyNoticeTarget.classList.add('hidden')
    }, 2000)
  }

  buildUrl() {
    let path = this.pathValue || ''
    const missing = []
    this.pathInputTargets.forEach((input) => {
      const name = input.name
      const value = (input.value || '').trim()
      if (!value) missing.push(name)
      const safe = encodeURIComponent(value)
      const placeholder = new RegExp(`\\{${name}\\}`, 'g')
      path = path.replace(placeholder, safe)
    })
    const params = new URLSearchParams()
    this.queryInputTargets.forEach((input) => {
      const value = (input.value || '').trim()
      if (value === '') return
      params.append(input.name, value)
    })
    const base = (this.baseUrlValue || '').replace(/\/$/, '')
    const query = params.toString()
    const url = `${base}${path}${query ? `?${query}` : ''}`
    return { url, missing }
  }

  showStatus(message, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove(
      'text-emerald-600',
      'text-rose-500',
      'text-slate-500',
      'dark:text-emerald-300',
      'dark:text-rose-300',
      'dark:text-slate-400'
    )
    if (!message) {
      this.statusTarget.classList.add('text-slate-500', 'dark:text-slate-400')
      return
    }
    if (isError) {
      this.statusTarget.classList.add('text-rose-500', 'dark:text-rose-300')
    } else {
      this.statusTarget.classList.add('text-emerald-600', 'dark:text-emerald-300')
    }
  }
}
