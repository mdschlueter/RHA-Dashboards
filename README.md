Interactive mapping dashboards for the Respiratory Health Association in Chicago.

## Repository structure

- **`asthma_app/`** — visualizes the effectiveness of Illinois's state-wide
  asthma program (student return-to-class rates) across Chicago
  neighborhoods, Illinois counties, congressional districts, and Cook County
  House/Senate districts. See `asthma_app/README.md`.
- **`vaping_app/`** — visualizes youth vaping-prevention program attendance
  by Chicago neighborhood. See `vaping_app/README.md`.
- **`.github/workflows/update-asthma-dashboard.yml`** — automatically
  reprocesses and redeploys the asthma dashboard to shinyapps.io whenever
  `asthma_app/school_level_linked_incs_251008.csv` (or the preprocessing
  script) changes on `main`. This is the intended way to hand off data
  updates to someone without R/RStudio installed: they replace the CSV
  through GitHub's web UI and commit.

### One-time setup for the automated deploy
The workflow needs three **repository secrets** (Settings → Secrets and
variables → Actions → New repository secret) pulled from your shinyapps.io
account (Account → Tokens → Show):
- `SHINYAPPS_ACCOUNT` — your shinyapps.io account name
- `SHINYAPPS_TOKEN`
- `SHINYAPPS_SECRET`

These are credentials — add them directly in the GitHub UI (or via
`gh secret set NAME`), never commit them to a file.

## History note
This repo was split out from an earlier, messier repo
(`RHA-Interactive-Mapping-Project`) that accumulated several superseded
drafts of both visualizations. Only the current, working code and data for
each app is here, with fresh git history.
