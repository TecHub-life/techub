#!/usr/bin/env node
// Simple Puppeteer screenshot helper
// Usage: node script/screenshot.js --url http://127.0.0.1:3000/cards/loftwah/og --out /path/to/out.png --width 1200 --height 630 --wait 500

const args = require('node:util').parseArgs({
  options: {
    url: { type: 'string', required: true },
    out: { type: 'string', required: true },
    width: { type: 'string', default: '1200' },
    height: { type: 'string', default: '630' },
    wait: { type: 'string', default: '500' },
  },
})

async function main() {
  const { url, out, width, height, wait } = args.values
  const w = parseInt(width, 10)
  const h = parseInt(height, 10)
  const delay = parseInt(wait, 10)

  let puppeteer
  try {
    puppeteer = require('puppeteer')
  } catch (_e) {
    console.error('Puppeteer is not installed. Run: npm i --save-dev puppeteer')
    process.exit(2)
  }

  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  })
  try {
    const page = await browser.newPage()
    await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 })
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 60_000 })
    if (delay > 0) await new Promise((r) => setTimeout(r, delay))
    await page.screenshot({ path: out, type: 'png' })
    console.log(`Saved screenshot: ${out}`)
  } finally {
    await browser.close()
  }
}

main().catch((e) => {
  console.error(e.stack || e.message || String(e))
  process.exit(1)
})
