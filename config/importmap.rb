# Pin npm packages by running ./bin/importmap

pin "application"
pin "techub_console"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "ahoy.js" # @0.4.4

# Chart.js and dependencies (Local Vendored)
pin "chart.js", to: "chart.js.js" # Vendored from https://ga.jspm.io/npm:chart.js@4.4.1/dist/chart.js
pin "@kurkle/color", to: "@kurkle--color.js" # Vendored from https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js
