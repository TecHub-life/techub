# Art Assets

Locations (committed):

- Pre-made avatars: `app/assets/images/avatars-1x1/` (1024×1024)
- Supporting art: `app/assets/images/supporting-art-1x1/` (1024×1024)

Recommended additional folders (if migrating old content):

- Spirit animals: `app/assets/images/spirit-animals-1x1/`
- Archetypes: `app/assets/images/archetypes-1x1/`

Migration notes:

- Previously-generated AI art lived in object storage and/or a non-committed local directory.
- To make assets available in all environments without AI calls, move them into the repository under
  the folders above.
- If your source is a DigitalOcean Space or S3 bucket, sync locally first (outside of the app
  runtime), then copy into the target folders and commit.

Example local sync workflow:

1. Use your preferred S3 tool to fetch objects to a local folder, e.g.
   `~/Downloads/techub-art/spirit-animals/`.
2. Copy into the repo:
   - `cp ~/Downloads/techub-art/spirit-animals/*.png app/assets/images/spirit-animals-1x1/`
   - `cp ~/Downloads/techub-art/archetypes/*.png app/assets/images/archetypes-1x1/`

3. Commit and deploy. The Rails asset pipeline will package these for the app.

Notes:

- We taped off AI image generation; these assets serve as selectable options in profile settings.
- AI text generation remains enabled; image generation can be re-enabled later via env flags.
