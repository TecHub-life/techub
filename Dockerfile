# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t techub .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name techub techub

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.3.0
# Pin ImageMagick version for reproducible builds (update as needed)
ARG IMAGEMAGICK_VERSION=7.1.1-32
ARG IMAGEMAGICK_SHA256
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
ARG IMAGEMAGICK_VERSION
ARG IMAGEMAGICK_SHA256

# Rails app lives here
WORKDIR /rails

# Install base packages (include build tools so dev gems can compile in compose)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips sqlite3 ca-certificates \
      nodejs npm chromium \
      # IM7 build deps and image format libraries
      build-essential pkg-config \
      libjpeg-dev libpng-dev libtiff-dev libwebp-dev \
      libheif-dev libopenjp2-7-dev liblcms2-dev libfreetype6-dev \
      libxml2-dev libfontconfig1-dev \
      fonts-noto fonts-noto-color-emoji fonts-liberation \
      git && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    # Build and install ImageMagick 7 from source to guarantee `magick` CLI
    set -eux; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "https://github.com/ImageMagick/ImageMagick/archive/refs/tags/${IMAGEMAGICK_VERSION}.tar.gz" -o "$tmpdir/ImageMagick.tar.gz"; \
    if [ -n "${IMAGEMAGICK_SHA256}" ]; then echo "${IMAGEMAGICK_SHA256}  $tmpdir/ImageMagick.tar.gz" | sha256sum -c -; fi; \
    tar -xzf "$tmpdir/ImageMagick.tar.gz" -C "$tmpdir"; \
    cd "$tmpdir"/ImageMagick-${IMAGEMAGICK_VERSION}; \
    ./configure --disable-docs; \
    make -j"$(nproc)"; \
    make install; \
    ldconfig; \
    # Smoke test: perform a tiny convert to ensure runtime works
    magick -version >/dev/null 2>&1; \
    magick -size 1x1 xc:white /tmp/im7-ok.png; \
    test -s /tmp/im7-ok.png; \
    cd /; rm -rf "$tmpdir"

# Set production environment
ENV RAILS_ENV="production" \
    NODE_ENV="production" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="1" \
    PUPPETEER_EXECUTABLE_PATH="/usr/bin/chromium" \
    IMAGE_OPT_VIPS="1" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install Node dependencies required for runtime screenshots (Puppeteer)
COPY package.json package-lock.json ./
RUN npm install --omit=optional --no-audit --no-fund && npm cache clean --force

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Create non-root user early so we can copy with correct ownership
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Copy built artifacts: gems, application, with proper ownership
COPY --from=build --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=rails:rails /rails /rails

# Ensure runtime directories exist and are owned
RUN mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
