import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    login: String,
    status: String
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
    // Start with a simulated progress animation
    this.simulateProgress()
    
    // Poll the server every 3 seconds
    this.pollInterval = setInterval(() => {
      this.checkStatus()
    }, 3000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }

  simulateProgress() {
    let progress = 0
    const progressBar = document.getElementById('progress-bar')
    const progressPercent = document.getElementById('progress-percent')
    const progressMessage = document.getElementById('progress-message')
    
    const messages = [
      'Generating your AI images...',
      'Creating avatar variants...',
      'Synthesizing card data...',
      'Capturing screenshots...',
      'Almost done...'
    ]
    
    let messageIndex = 0
    
    this.progressInterval = setInterval(() => {
      // Slow down as we approach 90%
      if (progress < 30) {
        progress += 2
      } else if (progress < 60) {
        progress += 1
      } else if (progress < 85) {
        progress += 0.5
      } else {
        progress += 0.2
      }
      
      // Cap at 90% until we get real completion
      progress = Math.min(progress, 90)
      
      if (progressBar && progressPercent) {
        progressBar.style.width = `${progress}%`
        progressPercent.textContent = `${Math.round(progress)}%`
      }
      
      // Update message every 15%
      const newMessageIndex = Math.floor(progress / 20)
      if (newMessageIndex !== messageIndex && newMessageIndex < messages.length) {
        messageIndex = newMessageIndex
        if (progressMessage) {
          progressMessage.textContent = messages[messageIndex]
        }
      }
    }, 500)
  }

  async checkStatus() {
    try {
      const response = await fetch(`/profiles/${this.loginValue}.json`, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) return
      
      const data = await response.json()
      const newStatus = data.profile?.last_pipeline_status
      
      if (newStatus && newStatus !== 'queued') {
        this.stopPolling()
        this.updateStatus(newStatus)
      }
    } catch (error) {
      console.error('Failed to check pipeline status:', error)
    }
  }

  updateStatus(newStatus) {
    const progressBar = document.getElementById('progress-bar')
    const progressPercent = document.getElementById('progress-percent')
    const progressMessage = document.getElementById('progress-message')
    
    if (newStatus === 'success') {
      // Complete the progress bar
      if (progressBar && progressPercent) {
        progressBar.style.width = '100%'
        progressPercent.textContent = '100%'
      }
      if (progressMessage) {
        progressMessage.textContent = 'Complete! Reloading...'
      }
      
      // Reload the page after a short delay to show completion
      setTimeout(() => {
        window.location.reload()
      }, 1500)
    } else if (newStatus === 'failure') {
      // Show error state
      if (progressBar) {
        progressBar.classList.remove('from-indigo-500', 'to-purple-600')
        progressBar.classList.add('bg-red-500')
      }
      if (progressMessage) {
        progressMessage.textContent = 'Generation failed. Reloading...'
      }
      
      // Reload to show error message
      setTimeout(() => {
        window.location.reload()
      }, 2000)
    }
  }
}
