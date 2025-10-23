# Pipeline Verification Guide

This guide captures the repeatable steps we used to validate the TecHub profile pipeline locally and
in the production (Docker/Kamal) environment. The examples assume the `loftwah` profile, but any
login can be substituted.

## 1. Local (development) verification

1. **Start the Rails server** so screenshot captures can hit real views:

   ```bash
   bundle exec rails server -p 3000 -b 127.0.0.1
   ```

   Leave the server running in the background while you verify the stages or pipeline.

2. **Run every stage and capture snapshots:**

   ```bash
   bundle exec rake "profiles:verify:stages[loftwah]"
   ```

   - Artifacts land under `tmp/pipeline_verification/<timestamp>/`.
   - Each stage directory contains:
     - `before.json` / `after.json` snapshots of the pipeline context.
     - `result.json` with the raw `ServiceResult`.
     - `captures/` with any images created during that stage.
     - Aggregated `trace.json` at the root.

3. **Run the full pipeline and copy its outputs:**

   ```bash
   bundle exec rake "profiles:verify:pipeline[loftwah]"
   ```

   - Results go to `tmp/pipeline_runs/<timestamp>/`.
   - `pipeline_result.json` includes the success/failure payload, trace, optimisations, and card id.
   - `captures/` contains the final screenshots.

4. **Stop the local server** once verification is complete.

## 2. Production parity via Docker Compose

1. **Build the latest worker image** (after changing code or tasks):

   ```bash
   docker compose build worker
   ```

2. **Start the web container** so Chrome in the worker can hit `http://web`:

   ```bash
   docker compose up -d web
   ```

3. **Run stage-by-stage verification** with host-mounted artifacts:

   ```bash
   mkdir -p tmp/prod_stage
   RAILS_MASTER_KEY=$(cat config/master.key) \
     docker compose run --rm \
       -v "$(pwd)/tmp/prod_stage:/artifacts" \
       worker bundle exec rake "profiles:verify:stages[loftwah,/artifacts,http://web]"
   ```

   - Snapshots are copied to `tmp/prod_stage/` with the same structure as the local run.

4. **Run the full pipeline** and copy its outputs:

   ```bash
   mkdir -p tmp/prod_pipeline
   RAILS_MASTER_KEY=$(cat config/master.key) \
     docker compose run --rm \
       -v "$(pwd)/tmp/prod_pipeline:/artifacts" \
       worker bundle exec rake "profiles:verify:pipeline[loftwah,/artifacts,http://web]"
   ```

   - The result JSON and screenshots are written to `tmp/prod_pipeline/`.

5. **Shut everything down** when finished:
   ```bash
   docker compose down
   ```

## 3. Interpreting the artifacts

- `trace.json` records every stage event (started/completed, timing, and payload hints).
- `before.json`/`after.json` snapshots show attribute-level changes for the context.
- `captures/` folders duplicate the exact files generated during screenshots.
- `pipeline_result.json` mirrors the return value and metadata from
  `Profiles::GeneratePipelineService`.

### Checked-in reference artifacts

For quick inspection without rerunning the pipeline, the repository includes complete dumps of a
recent verification run for the `loftwah` profile that was captured inside the Docker/Kamal worker
image:

- `docs/pipeline-artifacts/stage/` – stage-by-stage snapshots, traces, and captures.
- `docs/pipeline-artifacts/pipeline/` – end-to-end pipeline output plus copied screenshots.

Each directory mirrors exactly what the commands above produce (all JSON payloads and generated
images) so you can trace how data flows between stages without leaving the repo.

The combination of local and Docker runs ensures the pipeline behaves the same on developer machines
and in the production container image. Update this document if new stages are added or additional
hosts/environments need to be covered.
