# Developer Integration Guide

This guide helps engineering teams wire `amplify-audit` into local dev, CI, and application code with minimal setup.

## 1) Local developer workflow

```bash
npm install
npm run audit -- https://allbirds.com/products/mens-tree-runners
```

Use JSON output for machine-friendly logs:

```bash
npm run audit:json -- https://allbirds.com/products/mens-tree-runners
```

Use sample returns data:

```bash
npm run audit -- https://allbirds.com/products/mens-tree-runners --returns examples/devs/returns.sample.json
```

## 2) Programmatic usage in Node services

Install and import:

```bash
npm install amplify-audit
```

```js
import { audit } from 'amplify-audit'

const report = await audit({ url: 'https://your-store.com/products/sku-123' })
if (report.qualityScore < 70) {
  // Block publish, create Jira ticket, or notify Slack.
}
```

Reference runnable example in this repository:

- `examples/devs/library-usage.mjs`

## 3) CI quality gate (GitHub Actions)

Use the CLI as a PR gate:

```yaml
name: listing-quality-gate
on:
  pull_request:
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npx amplify-audit "${{ vars.PRODUCT_URL }}" --min-score 70 --json
```

`amplify-audit` exits with code 1 when score is below `--min-score`, so your workflow fails automatically.

## 4) Suggested team conventions

- Keep minimum quality threshold in one place (e.g. `70`).
- Store representative return reasons in version-controlled fixtures.
- Run listing audits in PR checks for content templates and merchandising changes.
- Persist JSON output as CI artifact for historical trend tracking.
