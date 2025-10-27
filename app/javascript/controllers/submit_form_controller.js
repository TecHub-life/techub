import { Controller } from '@hotwired/stimulus'

// Handles visual feedback for form submission with loading state
export default class extends Controller {
  static targets = ['button', 'text', 'spinner']

  connect() {
    this.element.addEventListener('turbo:submit-start', this.handleSubmit.bind(this))
    this.element.addEventListener('turbo:submit-end', this.handleComplete.bind(this))
  }

  handleSubmit() {
    // Disable button and show loading state
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
    }
    if (this.hasTextTarget) {
      this.originalText = this.textTarget.textContent
      this.textTarget.textContent = 'Submitting...'
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden')
    }
  }

  handleComplete() {
    // Re-enable button and restore text (in case of error)
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = false
    }
    if (this.hasTextTarget && this.originalText) {
      this.textTarget.textContent = this.originalText
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
  }
}
