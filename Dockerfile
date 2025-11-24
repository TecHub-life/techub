# (syntax directive removed to avoid pulling docker/dockerfile frontend from Docker Hub)
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t techub .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name techub techub

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

ARG BASE_IMAGE=ghcr.io/techub-life/techub-base:latest
FROM ${BASE_IMAGE} AS base

# Rails app lives here
WORKDIR /rails

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install Node dependencies required for runtime screenshots (Puppeteer)
COPY package.json package-lock.json ./
COPY script ./script
RUN npm install --omit=optional --no-audit --no-fund && npm cache clean --force

# Copy application code
COPY . .

# Ensure Font Awesome assets are copied into app assets before precompile
RUN npm run postinstall

# Assert Font Awesome assets exist and provide guidance if not
RUN ./bin/check-fontawesome

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets for production without requiring secret RAILS_MASTER_KEY
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
