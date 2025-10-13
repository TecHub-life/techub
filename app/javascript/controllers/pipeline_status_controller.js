import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    login: String,
    status: String,
  }

  connect() {
    if (this.statusValue === 'queued') {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.checkStatus()
    }, 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(`/profiles/${this.loginValue}/status.json`, {
        headers: { Accept: 'application/json' },
      })
      if (!response.ok) return
      const data = await response.json()
      const state = data?.status
      if (!state) return

      if (state === 'queued' || state === 'running') return

      this.stopPolling()
      this.updateStatus(state)
    } catch (error) {
      console.error('Failed to check pipeline status:', error)
    }
  }

  updateStatus(state) {
    const statusText = document.getElementById('status-text')
    const container = document.getElementById('pipeline-status-container')

    if (state === 'success') {
      if (statusText) statusText.textContent = 'Success'
      if (container)
        container.classList.remove('bg-yellow-50', 'border-yellow-200', 'text-yellow-800')
      setTimeout(() => {
        window.location.reload()
      }, 800)
    } else if (state === 'failure') {
      if (statusText) statusText.textContent = 'Failure'
      setTimeout(() => {
        window.location.reload()
      }, 1200)
    }
  }
}
