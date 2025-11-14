#!/usr/bin/env node
// Simple Puppeteer screenshot helper with resilient navigation + debug artifacts
// Usage: node script/screenshot.js \
//   --url http://127.0.0.1:3000/cards/loftwah/og \
//   --out /path/to/out.jpg --width 1200 --height 630 --wait 500 --type jpeg --quality 85 \
//   [--gotoTimeout 60000] [--waitUntil networkidle0|networkidle2|domcontentloaded] \
//   [--debug 1] [--debugDir /path/to/debug]

const args = require('node:util').parseArgs({
  options: {
    url: { type: 'string', required: true },
    out: { type: 'string', required: true },
    width: { type: 'string', default: '1200' },
    height: { type: 'string', default: '630' },
    wait: { type: 'string', default: '500' },
    type: { type: 'string', default: 'jpeg' }, // 'png' or 'jpeg'
    quality: { type: 'string', default: '85' }, // 1..100 (jpeg only)
    gotoTimeout: { type: 'string', default: '60000' },
    waitUntil: { type: 'string', default: 'networkidle0' }, // networkidle0|networkidle2|domcontentloaded
    debug: { type: 'string', default: '0' },
    debugDir: { type: 'string', default: '' },
  },
})

async function main() {
  const { url, out, width, height, wait, type, quality, gotoTimeout, waitUntil, debug, debugDir } =
    args.values
  const w = parseInt(width, 10)
  const h = parseInt(height, 10)
  const delay = parseInt(wait, 10)
  const q = parseInt(quality, 10)
  const navTimeout = Math.max(1000, parseInt(gotoTimeout, 10) || 60000)
  const waitMode = (waitUntil || 'networkidle0').toLowerCase()
  const wantDebug = debug === '1' || debug === 'true'
  const debugPath = (debugDir || '').trim()

  const fs = require('node:fs')
  const path = require('node:path')
  const ensureDir = (p) => {
    if (!p) return
    try {
      fs.mkdirSync(p, { recursive: true })
    } catch (_) {}
  }
  if (wantDebug && debugPath) ensureDir(debugPath)

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
    const events = { console: [], pageerror: [], failedRequests: [] }
    page.on('console', (msg) => {
      try {
        events.console.push({ type: msg.type(), text: msg.text() })
      } catch (_) {}
    })
    page.on('pageerror', (err) => {
      try {
        events.pageerror.push({ message: err.message })
      } catch (_) {}
    })
    page.on('requestfailed', (req) => {
      try {
        events.failedRequests.push({ url: req.url(), method: req.method(), failure: req.failure() })
      } catch (_) {}
    })

    await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 })
    // Be explicit about timeouts
    page.setDefaultNavigationTimeout(navTimeout)
    page.setDefaultTimeout(Math.max(navTimeout, 60_000))

    const navAttempts = []
    const attemptNav = async (mode, timeout) => {
      const started = Date.now()
      await page.goto(url, { waitUntil: mode, timeout })
      // Fonts readiness can lag; wait a tad if available
      try {
        await page.evaluate(async () => {
          if (document.fonts && document.fonts.ready) {
            await Promise.race([document.fonts.ready, new Promise((r) => setTimeout(r, 2000))])
          }
        })
      } catch (_) {}
      const duration = Date.now() - started
      navAttempts.push({ waitUntil: mode, timeout, duration_ms: duration })
    }

    let navigated = false
    try {
      await attemptNav(waitMode, navTimeout)
      navigated = true
    } catch (e1) {
      // Fallback to a more permissive mode on timeout or generic nav errors
      const fallbackMode =
        waitMode === 'networkidle0'
          ? 'domcontentloaded'
          : waitMode === 'networkidle2'
            ? 'domcontentloaded'
            : 'networkidle2'
      try {
        await attemptNav(fallbackMode, Math.max(navTimeout, 90_000))
        navigated = true
      } catch (e2) {
        // Persist debug artifacts if requested
        if (wantDebug && debugPath) {
          try {
            fs.writeFileSync(path.join(debugPath, 'console.json'), JSON.stringify(events, null, 2))
          } catch (_) {}
          try {
            fs.writeFileSync(
              path.join(debugPath, 'error.txt'),
              String(e2 && (e2.stack || e2.message || e2))
            )
          } catch (_) {}
          try {
            const html = await page.content()
            fs.writeFileSync(path.join(debugPath, 'page.html'), html)
          } catch (_) {}
        }
        const payload = {
          event: 'screenshot_failed',
          url,
          out,
          width: w,
          height: h,
          wait_ms: delay,
          type,
          quality: q,
          navAttempts,
          error: String(e2 && (e2.message || e2)),
          debugDir: wantDebug ? debugPath : undefined,
        }
        console.error(JSON.stringify(payload))
        throw e2
      }
    }

    if (!navigated) throw new Error('Navigation did not complete')
    if (delay > 0) await new Promise((r) => setTimeout(r, delay))
    const opts = { path: out, type: type === 'png' ? 'png' : 'jpeg' }
    if (opts.type === 'jpeg' && Number.isFinite(q)) opts.quality = q
    await page.screenshot(opts)
    const result = {
      event: 'screenshot_saved',
      url,
      out,
      width: w,
      height: h,
      wait_ms: delay,
      type: opts.type,
      quality: opts.quality,
      nav: navAttempts[navAttempts.length - 1],
    }
    console.log(JSON.stringify(result))
  } finally {
    await browser.close()
  }
}

main().catch((e) => {
  console.error(e.stack || e.message || String(e))
  process.exit(1)
})
