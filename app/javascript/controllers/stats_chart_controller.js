import { Controller } from '@hotwired/stimulus'
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js'

// Register only what we need to keep bundle size reasonable (though importmap loads it all mostly)
Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler
)

export default class extends Controller {
  static values = {
    labels: Array,
    data: Array,
    label: String,
    color: { type: String, default: '#6366f1' }, // Indigo-500
  }

  connect() {
    this.element.style.height = '300px'
    this.element.style.width = '100%'

    const ctx = this.element.getContext('2d')

    // Create gradient
    const gradient = ctx.createLinearGradient(0, 0, 0, 300)
    gradient.addColorStop(0, this.hexToRgba(this.colorValue, 0.5))
    gradient.addColorStop(1, this.hexToRgba(this.colorValue, 0.0))

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            label: this.labelValue,
            data: this.dataValue,
            borderColor: this.colorValue,
            backgroundColor: gradient,
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
            fill: true,
            tension: 0.3, // smooth curves
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            backgroundColor: '#1e293b',
            titleColor: '#f8fafc',
            bodyColor: '#f8fafc',
            borderColor: '#334155',
            borderWidth: 1,
          },
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false,
        },
        scales: {
          x: {
            grid: {
              display: false,
              drawBorder: false,
            },
            ticks: {
              color: '#94a3b8',
            },
          },
          y: {
            grid: {
              color: '#334155',
              borderDash: [5, 5],
              drawBorder: false,
            },
            ticks: {
              color: '#94a3b8',
            },
            beginAtZero: false,
          },
        },
      },
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  hexToRgba(hex, alpha) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }
}
