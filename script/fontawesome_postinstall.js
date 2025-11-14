#!/usr/bin/env node

/**
 * Sync Font Awesome assets into Propshaft-friendly locations and ensure the
 * main stylesheet imports the package CSS. This mirrors the expectations from
 * `bin/check-fontawesome` and keeps Docker builds reproducible.
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
  vendorCss: path.join(projectRoot, 'app', 'assets', 'vendor', 'fontawesome', 'css', 'all.min.css'),
  vendorWebfonts: path.join(projectRoot, 'app', 'assets', 'vendor', 'fontawesome', 'webfonts'),
  appWebfonts: path.join(projectRoot, 'app', 'assets', 'webfonts'),
  publicWebfonts: path.join(projectRoot, 'public', 'webfonts'),
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

function syncWebfonts() {
  copyDirContents(paths.sourceWebfonts, paths.vendorWebfonts)
  copyDirContents(paths.sourceWebfonts, paths.appWebfonts)
  copyDirContents(paths.sourceWebfonts, paths.publicWebfonts)
}

function syncCss() {
  ensureDir(path.dirname(paths.vendorCss))
  fs.copyFileSync(paths.sourceCss, paths.vendorCss)

  if (!fs.existsSync(paths.applicationCss)) return

  const importLine = "@import '@fortawesome/fontawesome-free/css/all.min.css';"
  const css = fs.readFileSync(paths.applicationCss, 'utf8')
  if (!css.includes(importLine)) {
    const updated = `${importLine}\n\n${css}`
    fs.writeFileSync(paths.applicationCss, updated)
  }
}

try {
  syncWebfonts()
  syncCss()
  console.log('[fontawesome] Assets synced.')
} catch (error) {
  console.error('[fontawesome] Failed to sync assets:', error)
  process.exit(1)
}
