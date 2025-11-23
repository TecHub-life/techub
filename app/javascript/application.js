// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import '@hotwired/turbo-rails'
import 'controllers'
import 'techub_console'
import ahoy from 'ahoy.js'

// Configure Ahoy
// ahoy.apiPath = "/ahoy/events" // Default is fine
// ahoy.visitParams = { ... } // Default is fine
window.ahoy = ahoy // Make available globally if needed
