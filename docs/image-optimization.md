## Image Optimization Policy

This document defines how we generate and optimize images in TecHub and how to troubleshoot
failures.

### Defaults

- Optimizer: libvips via the `image_processing` gem (fast, low memory)
- Fallback: ImageMagick 7 `magick` CLI; if unavailable, `convert` (IM6)
- Upload destination: determined by `ACTIVE_STORAGE_SERVICE` (`:local` in dev/test, `:do_spaces` in
  production)

### Build Guarantees

- Dockerfile builds and installs ImageMagick 7 from source and verifies `magick -version` during
  build.
- The image also includes `libvips`.

### Runtime Configuration

- Force vips: set `IMAGE_OPT_VIPS=1` (default in Dockerfile)
- Force ImageMagick: unset `IMAGE_OPT_VIPS` or set to `0`
- Override CLI explicitly: `IM_CLI=magick` or `IM_CLI=convert`

### Code Path

- `Images::OptimizeService` tries vips first when `IMAGE_OPT_VIPS` is truthy; on error falls back to
  ImageMagick.
- When using ImageMagick, the service picks `magick` if present, otherwise `convert`.

### Troubleshooting

1. Check logs for structured events:
   - `image_optimize_started`, `image_optimize_failed`, `vips_optimize_failed`
2. Verify binaries inside the job container:
   - `magick -version` or `convert -version`
   - `identify -list format | head -n 50`
3. Manual reproduce inside the job container:
   - PNG:
     `magick /rails/public/generated/<login>/avatar-1x1.png -strip -define png:compression-level=9 /rails/public/generated/<login>/avatar-1x1.png`
   - JPG:
     `magick /rails/public/generated/<login>/og.jpg -strip -interlace Plane -quality 85 /rails/public/generated/<login>/og.jpg`
4. Permissions/size checks:
   - Ensure file exists and meets `IMAGE_OPT_BG_THRESHOLD` (default 300KB) when background
     optimizing

### Rationale

- libvips is significantly faster and more memory efficient for typical web image transforms.
- IM7 is installed to ensure consistent CLI (`magick`) and wide codec support; we still allow
  `convert` fallback.

### Version Pinning

- We install IM7 from upstream source during build for consistency. If you need a specific version,
  pin the tarball URL in the Dockerfile and re-build.

### Upgrading

- Bump ImageMagick source URL in the Dockerfile.
- Rebuild and deploy; verify with `magick -version` in the running container.

### Security & Stability Notes

- Avoid processing untrusted images with exotic codecs without necessity. Our builds include common
  codecs (jpeg, png, webp, heif, jp2, tiff).
- Vips failures are logged and fall back to IM for safety.
