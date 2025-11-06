import { Controller } from '@hotwired/stimulus'

// Adds loading/success/failure affordances to Turbo-driven form submissions.
export default class extends Controller {
  static targets = ['button', 'text', 'spinner']
  static values = {
    defaultText: String,
  }

  connect() {
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleComplete = this.handleComplete.bind(this)

    this.element.addEventListener('turbo:submit-start', this.handleSubmit)
    this.element.addEventListener('turbo:submit-end', this.handleComplete)

    if (!this.defaultTextValue && this.hasTextTarget) {
      this.defaultTextValue = this.textTarget.textContent
    }
  }

  disconnect() {
    this.element.removeEventListener('turbo:submit-start', this.handleSubmit)
    this.element.removeEventListener('turbo:submit-end', this.handleComplete)
  }

  handleSubmit() {
    if (this.hasButtonTarget) {
      this.buttonTarget.disabled = true
      this.buttonTarget.setAttribute('aria-busy', 'true')
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden')
    }

    if (this.hasTextTarget) {
      this.textTarget.textContent = 'Submitting…'
    }
  }

  handleComplete(event) {
    const success = Boolean(event.detail?.success)

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }

    if (this.hasTextTarget) {
      this.textTarget.textContent = success ? 'Submitted' : 'Try again'
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.removeAttribute('aria-busy')
      setTimeout(() => {
        this.buttonTarget.disabled = false
        if (this.hasTextTarget) {
          this.textTarget.textContent = this.defaultTextValue || 'Submit'
        }
      }, success ? 800 : 1400)
    }
  }
}
