import puppeteer from 'puppeteer'
;(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  })

  const page = await browser.newPage()
  await page.setUserAgent(
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
  )
  await page.setExtraHTTPHeaders({ 'Accept-Language': 'en-AU,en;q=0.9' })
  await page.setViewport({ width: 1366, height: 900 })

  await page.goto('https://x.com/loftwah', { waitUntil: 'networkidle2', timeout: 60_000 })

  // Nuke signup/login overlays and sticky bars so header is interactable
  await page.evaluate(() => {
    const kill = (n) => n && n.parentElement && n.parentElement.removeChild(n)
    // Bottom banner / dialogs / regions that match CTA text
    document.querySelectorAll('div[role="dialog"], div[role="region"]').forEach((el) => {
      const t = (el.innerText || '').toLowerCase()
      if (
        t.includes('don’t miss') ||
        t.includes("don't miss") ||
        t.includes('sign up') ||
        t.includes('log in')
      ) {
        kill(el)
      }
    })
    // Cookie/consent bars sometimes use fixed position
    document.querySelectorAll('div[style*="position: fixed"]').forEach((el) => {
      const t = (el.innerText || '').toLowerCase()
      if (t.includes('sign up') || t.includes('log in') || t.includes('cookie')) kill(el)
    })
  })

  // Give React time to hydrate profile header
  await page.waitForSelector('div[data-testid="UserName"]', { timeout: 15000 }).catch(() => {})
  await new Promise((r) => setTimeout(r, 1200))

  // Light scroll to trigger image lazy-load
  for (let i = 0; i < 2; i++) {
    await page.evaluate(() => window.scrollBy(0, window.innerHeight * 0.7))
    await new Promise((r) => setTimeout(r, 700))
  }
  await page.evaluate(() => window.scrollTo(0, 0))
  await new Promise((r) => setTimeout(r, 500))

  const result = await page.evaluate(() => {
    const txt = (sel, root = document) => root.querySelector(sel)?.innerText?.trim() || null
    const allTxt = (sel, root = document) =>
      Array.from(root.querySelectorAll(sel))
        .map((n) => n.innerText?.trim())
        .filter(Boolean)

    // Helpers for image src/srcset
    const imgUrl = (el) => {
      if (!el) return null
      const s = el.getAttribute('srcset')
      if (s) {
        // choose highest-res candidate
        const parts = s
          .split(',')
          .map((p) => p.trim().split(' ')[0])
          .filter(Boolean)
        return parts[parts.length - 1] || el.getAttribute('src')
      }
      return el.getAttribute('src')
    }

    // ---- Parse header (robust to slight A/B changes)
    const userNameBlock = document.querySelector('div[data-testid="UserName"]')
    let displayName = null,
      handle = null
    if (userNameBlock) {
      const lines = (userNameBlock.innerText || '')
        .split('\n')
        .map((s) => s.trim())
        .filter(Boolean)
      displayName = lines[0] || null
      const m = (userNameBlock.innerText || '').match(/@\w+/)
      handle = m ? m[0] : null
    }

    const bio = txt('div[data-testid="UserDescription"]')
    const headerItems =
      document.querySelector('div[data-testid="UserProfileHeader_Items"]') || document

    const headerSpans = allTxt('div[data-testid="UserProfileHeader_Items"] span')
    const joined = headerSpans.find((t) => /^Joined\s/i.test(t)) || null
    const location =
      headerSpans.find((t) => !/^Joined\s/i.test(t) && !/^https?:\/\//i.test(t)) || null

    const websites = Array.from(headerItems.querySelectorAll('a[href^="http"]'))
      .map((a) => a.getAttribute('href'))
      .filter(Boolean)

    const followers =
      document.querySelector('a[href$="/followers"] span span')?.textContent?.trim() || null
    const following =
      document.querySelector('a[href$="/following"] span span')?.textContent?.trim() || null

    // Avatar & banner images (prefer direct pbs links)
    const avatarEl =
      document.querySelector('img[src*="pbs.twimg.com/profile_images"]') ||
      document.querySelector('img[srcset*="pbs.twimg.com/profile_images"]')
    const avatarUrl = imgUrl(avatarEl)

    let bannerUrl = null
    const bannerImg =
      document.querySelector('img[src*="pbs.twimg.com/profile_banners"]') ||
      document.querySelector('img[srcset*="pbs.twimg.com/profile_banners"]')
    if (bannerImg) bannerUrl = imgUrl(bannerImg)
    if (!bannerUrl) {
      const bg = Array.from(document.querySelectorAll('[style*="background-image"]')).find((el) =>
        /pbs\.twimg\.com\/profile_banners/.test(el.getAttribute('style') || '')
      )
      if (bg) {
        const m = (bg.getAttribute('style') || '').match(/url\(["']?(.*?)["']?\)/i)
        if (m) bannerUrl = m[1]
      }
    }

    // Posts (optional)
    const posts = Array.from(document.querySelectorAll("article div[data-testid='tweetText']"))
      .slice(0, 10)
      .map((n) => n.innerText.trim())
      .filter(Boolean)

    // ---- Derive size variants
    const deriveAvatar = (url) => {
      if (!url) return null
      // /profile_images/:id/:hash(_suffix)?.ext
      const m = url.match(
        /^(https:\/\/pbs\.twimg\.com\/profile_images\/[^/]+\/)([^._/]+)(?:_([^./]+))?(\.[a-z0-9]+)$/i
      )
      if (!m) return { original: url }
      const [, base, hash, _suf, ext] = m
      const mk = (v) => `${base}${hash}${v ? '_' + v : ''}${ext}`
      return {
        original: mk(''),
        '400x400': mk('400x400'),
        normal: mk('normal'),
        bigger: mk('bigger'),
        mini: mk('mini'),
      }
    }

    const deriveBanner = (url) => {
      if (!url) return null
      // /profile_banners/:userId/:bannerId(/size?)?
      const m = url.match(
        /^(https:\/\/pbs\.twimg\.com\/profile_banners\/[^/]+\/[^/]+)(?:\/([^/]+))?\/?$/i
      )
      if (!m) return { original: url }
      const [, base] = m
      const mk = (size) => (size ? `${base}/${size}` : `${base}`)
      return {
        original: mk(''),
        '1500x500': mk('1500x500'),
        '600x200': mk('600x200'),
        '300x100': mk('300x100'),
      }
    }

    return {
      displayName,
      handle,
      bio,
      location,
      joined,
      websites,
      following,
      followers,
      avatar: { url: avatarUrl, variants: deriveAvatar(avatarUrl) },
      banner: { url: bannerUrl, variants: deriveBanner(bannerUrl) },
      postsCount: posts.length,
      posts,
    }
  })

  // stdout: JSON for machines
  console.log(JSON.stringify(result, null, 2))

  await browser.close()
})()
