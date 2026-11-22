# SatPulse Workbench on the web

This repository deploys the browser version of SatPulse Workbench to
<https://workbench.satpulse.net/>. The Workbench runs entirely in the browser:
the SatPulse Go code is compiled to WebAssembly, and it talks to the receiver
through Web Serial, so it needs Chrome or Edge.

The source is in [jclark/satpulse](https://github.com/jclark/satpulse). This
repository holds only the deployment: a GitHub Actions workflow that builds
the Workbench from a pinned source commit and publishes it with GitHub Pages.
No build output is stored in Git.

## Staging and production

The site serves two builds:

- production, at <https://workbench.satpulse.net/>
- staging, at <https://workbench.satpulse.net/staging/>, for testing a build
  before it goes into production

[`deploy.json`](deploy.json) records the source commit, Go version and output
digest of each build, and the workflow keeps it up to date. Its other fields
name the source repository and branch, the Go and Node versions for new
builds, and the source CI workflows that must have passed before a commit can
be staged.

Run the Deploy workflow from the Actions tab, or with
`gh workflow run deploy.yml -f action=ACTION`, where ACTION is one of:

- `stage`: stage the head of the source branch, provided the required CI
  workflows passed on it
- `promote`: put the staged build into production
- `redeploy`: rebuild the site from `deploy.json` as it is

To roll back, revert the commit that recorded the promotion. A push that
changes `deploy.json` also redeploys.

## How it works

Each build is published in a directory named for its source commit, and the
production and staging pages are copies of that build's `index.html` with a
`<base>` element pointing into the directory. The page URLs stay the same,
while each build's files have their own URLs, so a browser never combines
cached files from different builds.

Every run publishes the whole site, rebuilding both builds from their pinned
commits. The build is reproducible, and a build whose digest is
already recorded must reproduce it exactly: production serves the same bytes
that were tested in staging.
