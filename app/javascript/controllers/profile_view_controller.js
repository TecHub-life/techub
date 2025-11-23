import { Controller } from '@hotwired/stimulus'
import ahoy from 'ahoy.js'

export default class extends Controller {
  static values = { login: String }

  connect() {
    // Track client-side to ensure cached pages are counted
    ahoy.track('Viewed Profile', { login: this.loginValue })
  }
}
