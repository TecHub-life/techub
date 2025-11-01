import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = [
    'challengerHp',
    'opponentHp',
    'challengerHpBar',
    'opponentHpBar',
    'challengerHpText',
    'opponentHpText',
    'logEntry',
  ]

  static values = {
    battleLog: Array,
    challengerMaxHp: Number,
    opponentMaxHp: Number,
  }

  connect() {
    console.log('Battle Animator connected!', this.battleLogValue)
    this.currentTurn = 0
    this.isPlaying = false
    this.speed = 800 // milliseconds per turn (slightly faster default)
    this.challengerCurrentHp = 100
    this.opponentCurrentHp = 100

    // Hide all log entries initially
    this.logEntryTargets.forEach((entry) => {
      entry.classList.add('hidden', 'opacity-0')
    })

    // Auto-start the battle animation
    setTimeout(() => this.play(), 500)
  }

  play() {
    if (this.isPlaying) return

    this.isPlaying = true
    this.animateBattle()
  }

  pause() {
    this.isPlaying = false
  }

  async animateBattle() {
    while (this.isPlaying && this.currentTurn < this.battleLogValue.length) {
      const entry = this.battleLogValue[this.currentTurn]

      // Show current log entry with animation
      if (this.logEntryTargets[this.currentTurn]) {
        const logElement = this.logEntryTargets[this.currentTurn]
        logElement.classList.remove('hidden')

        // Trigger animation
        await this.sleep(50)
        logElement.classList.remove('opacity-0')
        logElement.classList.add('animate-slide-in')

        // Scroll into view
        logElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }

      // Handle different event types
      switch (entry.type) {
        case 'attack':
          await this.animateAttack(entry)
          break
        case 'knockout':
          await this.animateKnockout(entry)
          break
        case 'type_advantage':
          await this.animateTypeAdvantage()
          break
      }

      this.currentTurn++
      await this.sleep(this.speed)
    }

    // Battle finished
    if (this.currentTurn >= this.battleLogValue.length) {
      this.pause()
    }
  }

  async animateAttack(entry) {
    const isChallenger = entry.attacker === this.element.dataset.challengerLogin
    const target = isChallenger ? 'opponent' : 'challenger'
    const newHp = entry.defender_hp

    // Flash the attacker
    const attackerCard = isChallenger
      ? this.element.querySelector('.challenger-card')
      : this.element.querySelector('.opponent-card')

    if (attackerCard) {
      attackerCard.classList.add('animate-attack-flash')
      await this.sleep(300)
      attackerCard.classList.remove('animate-attack-flash')
    }

    // Update HP with animation
    await this.updateHpBar(target, newHp)

    // Flash damage on defender
    const defenderCard = isChallenger
      ? this.element.querySelector('.opponent-card')
      : this.element.querySelector('.challenger-card')

    if (defenderCard) {
      defenderCard.classList.add('animate-damage-shake')
      await this.sleep(500)
      defenderCard.classList.remove('animate-damage-shake')
    }
  }

  async animateKnockout(entry) {
    const loserCard = entry.message.includes(this.element.dataset.challengerLogin)
      ? this.element.querySelector('.challenger-card')
      : this.element.querySelector('.opponent-card')

    if (loserCard) {
      loserCard.classList.add('animate-knockout')
      await this.sleep(1000)
    }
  }

  async animateTypeAdvantage() {
    // Flash both cards
    const cards = this.element.querySelectorAll('.challenger-card, .opponent-card')
    cards.forEach((card) => card.classList.add('animate-pulse'))
    await this.sleep(500)
    cards.forEach((card) => card.classList.remove('animate-pulse'))
  }

  async updateHpBar(target, newHp) {
    const hpBar = target === 'challenger' ? this.challengerHpBarTarget : this.opponentHpBarTarget
    const hpText = target === 'challenger' ? this.challengerHpTextTarget : this.opponentHpTextTarget
    const currentHp = target === 'challenger' ? this.challengerCurrentHp : this.opponentCurrentHp

    // Animate HP drain
    const steps = 20
    const hpDiff = currentHp - newHp
    const stepSize = hpDiff / steps

    for (let i = 0; i < steps; i++) {
      const intermediateHp = currentHp - stepSize * (i + 1)
      hpBar.style.width = `${Math.max(0, intermediateHp)}%`
      hpText.textContent = Math.round(Math.max(0, intermediateHp))

      // Change color based on HP
      this.updateHpColor(hpBar, intermediateHp)

      await this.sleep(20)
    }

    // Set final value
    hpBar.style.width = `${Math.max(0, newHp)}%`
    hpText.textContent = Math.round(Math.max(0, newHp))
    this.updateHpColor(hpBar, newHp)

    // Update stored HP
    if (target === 'challenger') {
      this.challengerCurrentHp = newHp
    } else {
      this.opponentCurrentHp = newHp
    }
  }

  updateHpColor(hpBar, hp) {
    // Remove existing color classes
    hpBar.classList.remove('bg-emerald-500', 'bg-yellow-500', 'bg-orange-500', 'bg-red-500')

    // Add color based on HP percentage
    if (hp > 60) {
      hpBar.classList.add('bg-emerald-500')
    } else if (hp > 40) {
      hpBar.classList.add('bg-yellow-500')
    } else if (hp > 20) {
      hpBar.classList.add('bg-orange-500')
    } else {
      hpBar.classList.add('bg-red-500')
    }
  }

  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms))
  }
}
