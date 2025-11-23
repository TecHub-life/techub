# Pin npm packages by running ./bin/importmap

pin "application"
pin "techub_console"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "chart.js" # @4.5.1
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "ahoy.js" # @0.4.4
