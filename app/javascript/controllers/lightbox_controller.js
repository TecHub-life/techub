import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="lightbox"
export default class extends Controller {
  static targets = ['modal', 'image', 'title', 'counter', 'prevBtn', 'nextBtn']
  static values = {
    images: Array,
    currentIndex: Number,
  }

  connect() {
    console.log('Lightbox controller connected')
    this.currentIndexValue = 0
    this.bindKeyboardEvents()
  }

  disconnect() {
    this.unbindKeyboardEvents()
  }

  bindKeyboardEvents() {
    this.keydownHandler = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.keydownHandler)
  }

  unbindKeyboardEvents() {
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler)
    }
  }

  handleKeydown(event) {
    if (!this.isOpen()) return

    switch (event.key) {
      case 'Escape':
        this.close()
        break
      case 'ArrowLeft':
        this.previous()
        break
      case 'ArrowRight':
        this.next()
        break
    }
  }

  open(event) {
    const imageUrl = event.currentTarget.dataset.imageUrl
    const imageLabel = event.currentTarget.dataset.imageLabel
    const imageType = event.currentTarget.dataset.imageType || 'image'

    console.log('Opening lightbox:', imageUrl, imageLabel, imageType)

    // Find the image in our images array
    const imageIndex = this.imagesValue.findIndex((img) => img.url === imageUrl)
    if (imageIndex === -1) {
      console.error('Image not found in images array')
      return
    }

    this.currentIndexValue = imageIndex
    this.updateDisplay()
    this.modalTarget.style.display = 'flex'
    this.modalTarget.classList.remove('opacity-0')
    this.modalTarget.classList.add('opacity-100')
    document.body.style.overflow = 'hidden'
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    this.modalTarget.classList.remove('opacity-100')
    this.modalTarget.classList.add('opacity-0')

    setTimeout(() => {
      this.modalTarget.style.display = 'none'
      document.body.style.overflow = ''
    }, 200)
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  previous() {
    if (this.imagesValue.length <= 1) return

    this.currentIndexValue =
      this.currentIndexValue === 0 ? this.imagesValue.length - 1 : this.currentIndexValue - 1

    this.updateDisplay()
  }

  next() {
    if (this.imagesValue.length <= 1) return

    this.currentIndexValue = (this.currentIndexValue + 1) % this.imagesValue.length
    this.updateDisplay()
  }

  updateDisplay() {
    const currentImage = this.imagesValue[this.currentIndexValue]
    if (!currentImage) return

    this.imageTarget.src = currentImage.url
    this.imageTarget.alt = currentImage.label
    this.titleTarget.textContent = currentImage.label
    this.counterTarget.textContent = `${this.currentIndexValue + 1} of ${this.imagesValue.length}`

    // Show/hide navigation buttons
    const showNav = this.imagesValue.length > 1
    this.prevBtnTarget.style.display = showNav ? 'block' : 'none'
    this.nextBtnTarget.style.display = showNav ? 'block' : 'none'
  }

  isOpen() {
    return this.modalTarget.style.display === 'flex'
  }
}
