#!/usr/bin/env node

/**
 * Sync Font Awesome assets into Propshaft-friendly locations.
 * Simplified Strategy:
 * 1. Webfonts -> app/assets/webfonts
 * 2. CSS -> app/assets/stylesheets/fontawesome.css
 *    - Served at /assets/fontawesome.css
 *    - Relative path `../webfonts/` resolves to /assets/webfonts/ (Correct)
 */

const fs = require('fs')
const path = require('path')

const projectRoot = path.resolve(__dirname, '..')
const fontawesomeRoot = path.join(projectRoot, 'node_modules', '@fortawesome', 'fontawesome-free')

if (!fs.existsSync(fontawesomeRoot)) {
  console.warn('[fontawesome] Skipping postinstall: package is not installed.')
  process.exit(0)
}

const paths = {
  sourceWebfonts: path.join(fontawesomeRoot, 'webfonts'),
  sourceCss: path.join(fontawesomeRoot, 'css', 'all.min.css'),
  
  // Target locations
  appWebfonts: path.join(projectRoot, 'app', 'assets', 'webfonts'),
  appStylesheet: path.join(projectRoot, 'app', 'assets', 'stylesheets', 'fontawesome.css'),
  
  applicationCss: path.join(projectRoot, 'app', 'assets', 'stylesheets', 'application.css'),
}

function ensureDir(directory) {
  fs.mkdirSync(directory, { recursive: true })
}

function copyDirContents(sourceDir, targetDir) {
  ensureDir(targetDir)
  for (const entry of fs.readdirSync(sourceDir)) {
    const sourcePath = path.join(sourceDir, entry)
    const targetPath = path.join(targetDir, entry)
    const stat = fs.statSync(sourcePath)
    if (stat.isDirectory()) {
      copyDirContents(sourcePath, targetPath)
    } else if (stat.isFile()) {
      fs.copyFileSync(sourcePath, targetPath)
    }
  }
}

function syncAssets() {
  // 1. Sync webfonts
  console.log(`[fontawesome] Copying webfonts to ${paths.appWebfonts}`)
  copyDirContents(paths.sourceWebfonts, paths.appWebfonts)
  
  // 2. Sync CSS
  console.log(`[fontawesome] Copying CSS to ${paths.appStylesheet}`)
  // Ensure parent dir exists (app/assets/stylesheets)
  ensureDir(path.dirname(paths.appStylesheet))
  fs.copyFileSync(paths.sourceCss, paths.appStylesheet)
}

function updateApplicationCss() {
  if (!fs.existsSync(paths.applicationCss)) return

  // New import path
  const importLine = "@import 'fontawesome.css';"
  
  // Old variants to clean up
  const oldImports = [
    "@import 'fontawesome/css/all.min.css';",
    "@import '@fortawesome/fontawesome-free/css/all.min.css';",
    "@import url('https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css');",
    "@import 'fontawesome/all.min.css';",
    "@import 'fontawesome/all.css';"
  ]
  
  let css = fs.readFileSync(paths.applicationCss, 'utf8')
  
  // Remove old lines
  for (const line of oldImports) {
    if (css.includes(line)) {
      css = css.replace(line, '').trim()
    }
  }

  // Add new line if missing
  if (!css.includes(importLine)) {
    const updated = `${importLine}\n\n${css}`
    fs.writeFileSync(paths.applicationCss, updated)
  } else {
    fs.writeFileSync(paths.applicationCss, css)
  }
}

try {
  syncAssets()
  updateApplicationCss()
  console.log('[fontawesome] Assets synced locally.')
} catch (error) {
  console.error('[fontawesome] Failed to sync assets:', error)
  process.exit(1)
}
