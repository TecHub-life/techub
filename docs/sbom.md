### SBOM usage

**Location**

- The SBOM file is expected at:
  - `/home/loftwah/gits/techub/tmp/sbom-techub-image.cdx.json/sbom-techub-image.cdx.json`
- `tmp/` is ignored by git, so large files here will not be committed.

**Quick start**

- Ensure `jq` is installed (Ubuntu/Debian):
  ```bash
  sudo apt-get update && sudo apt-get install -y jq
  ```
- Put the SBOM at the location above and run:
  ```bash
  bin/sbom count
  ```

**All-in-one report**

- To run a comprehensive, non-interactive report similar to CI:
  ```bash
  bin/sbom-ci
  ```
  This prints: top-level keys, component count, first 10 components, several common queries
  (limited), gzip + count from gzip, NDJSON export preview, and an NDJSON split.

**Summary report (Markdown)**

- Generate a human-readable Markdown summary with counts, ecosystems, licenses, unknown versions,
  and optional license policy gates:

  ```bash
  # writes to docs/pipeline-artifacts/sbom-summary.md by default
  bin/sbom-summary

  # fail if disallowed licenses are found (exit code 3)
  bin/sbom-summary --disallow GPL-3.0-only,GPL-2.0-only,GPL-3.0-or-later,GPL-2.0-or-later

  # customize output path and sample sizes
  bin/sbom-summary --out docs/pipeline-artifacts/sbom-summary.md \
                   --unknown-limit 100 \
                   --top-licenses 20 \
                   --top-ecosystems 20
  ```

- The summary includes:
  - Image metadata (name, version, purl)
  - Total components
  - Component types (e.g., `file`, `library`)
  - Ecosystems by `purl` (npm, deb, gem, etc.)
  - Top licenses
  - Unknown-version components (first N)
  - Optional policy gate with counts and first 20 offenders per disallowed license

**CI usage**

- Example step that writes an artifact and enforces a license policy:

  ```bash
  set -e
  bin/sbom-summary --out docs/pipeline-artifacts/sbom-summary.md \
                   --disallow GPL-3.0-only,GPL-2.0-only,GPL-3.0-or-later,GPL-2.0-or-later
  ```

  - If violations are found the script exits with status 3 and prints the counts plus a short
    offender list. The Markdown report is still written for inspection.

**Commands**

- `bin/sbom keys` — show top-level JSON keys in a pager
- `bin/sbom count` — count components
- `bin/sbom list [N]` — list first N components (name, version, purl)
- `bin/sbom find REGEX [LIMIT]` — case-insensitive regex search by component name; optional LIMIT
  avoids page truncation issues
- `bin/sbom compress` — create a gzipped SBOM alongside the original
- `bin/sbom count_gz` — count components from the gzipped SBOM
- `bin/sbom ndjson` — export components to `tmp/components.ndjson`
- `bin/sbom split [LINES]` — split NDJSON into chunks (default 5000 lines)

**Examples**

```bash
bin/sbom keys
bin/sbom count
bin/sbom list 200
bin/sbom find rails 20
bin/sbom compress && bin/sbom count_gz
bin/sbom ndjson && bin/sbom split 10000
bin/sbom-summary --out docs/pipeline-artifacts/sbom-summary.md --disallow GPL-3.0-only,GPL-2.0-only
```

**Why this is useful**

- **Vulnerability scanning input**: SBOM feeds scanners (e.g., Grype/OSV) to find CVEs by exact
  package/version.
- **License compliance**: Inventory of licenses; enforce policies via the summary script’s
  `--disallow` gate.
- **Drift detection**: Diff SBOMs between builds to catch new/removed/changed dependencies.
- **Incident response**: Exact dependency inventory to triage quickly when a new CVE lands.
- **Provenance/compliance**: Store SBOMs and the generated summary as pipeline artifacts for audits.

**Notes**

- Avoid opening the SBOM in GUI editors; use the commands above.
- Many `file`-type components are OS/runtime files from the base image (not application libraries).
- For ad-hoc exploration, you can also run:
  ```bash
  jq -C '.' '/home/loftwah/gits/techub/tmp/sbom-techub-image.cdx.json/sbom-techub-image.cdx.json' | less -R
  ```
