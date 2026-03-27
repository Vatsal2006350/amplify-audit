<div align="center">

# amplify-audit

**Audit any product listing in 30 seconds.**

Quality scores. Return risk analysis. Improvement recommendations. One command.

[![npm version](https://img.shields.io/npm/v/amplify-audit.svg)](https://www.npmjs.com/package/amplify-audit)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/node-%3E%3D18-brightgreen.svg)](https://nodejs.org/)

```
npx amplify-audit https://your-store.myshopify.com/products/any-product
```

</div>

---

## What it does

Paste any product URL. Get back:

- **Quality Score** (0-100) — title length, description completeness, missing sizing info, image count, SEO signals
- **Return Risk Analysis** — classifies return reasons across 5 categories using 98 semantic keywords
- **Improvement Recommendations** — specific before/after copy changes with rationale
- **SKU Health Score** — composite metric using Shannon entropy, fixability scoring, and confidence intervals

Works with **Shopify**, **Amazon**, and any product page with structured data (JSON-LD, Open Graph).

No API key. No account. No setup.

## Quick start

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners
```

```
⟳ Fetching product data...
⟳ Running quality analysis...

Men's Tree Runner - Jet Black (White Sole)
Platform: shopify

Quality Score: 64/100  NEEDS WORK

─── Issues Found ───
  ▲ Title could be longer (42 chars). Optimal is 50-80 characters for SEO.
  ▲ Description could be more detailed (242 chars). Target 300-1000 characters.
  ▲ No sizing or fit information found. This is the #1 driver of returns.
  ○ No material/fabric information detected. Adding materials improves buyer confidence.
  ○ No care instructions found. Consider adding washing/maintenance info.

✓ Audit complete.
```

## With return data

Have return reasons? Feed them in for a full return risk analysis:

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners \
  --returns ./returns.json
```

Where `returns.json` is:

```json
{
  "reasons": ["too small", "runs small", "fit issue", "wrong size", "color different"],
  "orderCount": 150,
  "returnCount": 35,
  "ticketCount": 8
}
```

```
─── Return Risk Analysis ───
  Risk Level: HIGH
  Primary Issue: sizing
  Fixable by PDP: Yes

  too small                ███░░░░░░░░░░░░░░░░░ 14%
  runs small               ███░░░░░░░░░░░░░░░░░ 14%
  fit issue                ███░░░░░░░░░░░░░░░░░ 14%
  wrong size               ███░░░░░░░░░░░░░░░░░ 14%
  too tight                ███░░░░░░░░░░░░░░░░░ 14%

  SKU Health Score: 25.4/100
  Confidence: 90%

─── Recommendations ───
  title
    - Men's Tree Runner - Jet Black (White Sole)
    + Men's Tree Runner - Jet Black (White Sole) (Runs Small — Consider Sizing Up)
    Set expectations at the top of the listing to reduce fit-related returns.
```

## Use as a library

```bash
npm install amplify-audit
```

```typescript
import { audit } from 'amplify-audit'

// Audit by URL
const report = await audit({
  url: 'https://mystore.myshopify.com/products/blue-sweater'
})

console.log(report.qualityScore)     // 64
console.log(report.issues)           // [{ type: 'warning', category: 'title', message: '...' }]
console.log(report.recommendations)  // [{ field: 'title', before: '...', after: '...' }]

// Audit with return data
const report = await audit({
  url: 'https://amazon.com/dp/B09V3KXJPB',
  returns: {
    reasons: ['too small', 'runs small', 'color different'],
    orderCount: 200,
    returnCount: 40,
  },
})

console.log(report.returnRisk)       // { score: 'HIGH', primaryIssueType: 'sizing', ... }
console.log(report.skuHealthScore)   // 25.4
```

### Individual modules

Use any module standalone:

```typescript
// Score listing quality (no network calls)
import { analyzeListingQuality } from 'amplify-audit'

const { qualityScore, issues } = analyzeListingQuality({
  title: 'Blue Wool Sweater',
  description: 'Hand-knit, 100% wool...',
  tags: ['clothing', 'blue'],
  images: ['https://...'],
})

// Classify return reasons
import { classifyReasons, getPrimaryIssueType } from 'amplify-audit'

const scores = classifyReasons(['too small', 'runs small', 'tight fit'])
const primary = getPrimaryIssueType(scores) // 'sizing'

// SKU health scoring (Shannon entropy + fixability)
import { computeFixabilityScore, computeReasonConcentration } from 'amplify-audit'

const concentration = computeReasonConcentration({ 'runs small': 8, 'other': 2 })
// 0.72 — high concentration = clear signal

const score = computeFixabilityScore(0.23, 0.05, 6, { 'runs small': 8, 'other': 2 })
// 25.4 — composite fixability score
```

## CI/CD quality gate

Fail your pipeline when listing quality drops below a threshold:

```bash
npx amplify-audit https://your-store.com/products/sku-123 --min-score 70 --json
```

Exits with code 1 if the score is below `--min-score`. Use `--json` for machine-readable output.

```yaml
# GitHub Actions example
- name: Audit listing quality
  run: npx amplify-audit ${{ env.PRODUCT_URL }} --min-score 70
```

## CLI reference

```
Usage: amplify-audit [url] [options]

Arguments:
  url                    Product URL to audit (Shopify, Amazon, or any product page)

Options:
  --product <path>       Path to product JSON file (instead of URL)
  --returns <path>       Path to returns JSON file
  --json                 Output as JSON
  --min-score <n>        Exit code 1 if quality score is below threshold
  -V, --version          Output version number
  -h, --help             Display help
```

## What's under the hood

This tool extracts production algorithms from [Amplify](https://use-amplify.com), an AI operations platform for e-commerce teams.

| Module | What it does | Dependencies |
|--------|-------------|-------------|
| **Listing Analyzer** | Title length, description completeness, missing sizing/material/care info, image count, tag validation | None |
| **Return Classifier** | 98 semantic keywords across 5 categories: sizing, quality, description mismatch, color mismatch, missing info | None |
| **SKU Scorer** | Weighted composite (return rate 40%, ticket rate 20%, keyword signals 25%, reason concentration 15%) using Shannon entropy | None |
| **Recommender** | Deterministic fix templates by issue type with before/after diffs | None |
| **Fetcher** | Shopify product JSON, Amazon scraper, JSON-LD/Open Graph fallback | cheerio |

### Scoring algorithm

```
fixability_score = (
  return_rate × 40% +
  ticket_rate × 20% +
  keyword_signals × 25% +
  reason_concentration × 15%     ← Shannon entropy, inverted
)
```

**Reason concentration** uses Shannon entropy to detect whether returns are driven by one specific issue (high concentration = clear fix) vs random noise (low concentration = unclear):

```
entropy = -Σ(p × log₂(p))  for each reason
concentration = 1 - (entropy / max_entropy)
```

If 80% of returns say "runs small", concentration ≈ 0.97 — strong signal that a sizing note will reduce returns.

## Supported platforms

| Platform | Method | What's fetched |
|----------|--------|---------------|
| **Shopify** | Product JSON API (`/products/{handle}.json`) | Title, description, tags, images, variants, vendor, price |
| **Amazon** | HTML scraping (cheerio) | Title, description, bullet points, images, price, brand |
| **Any site** | JSON-LD / Open Graph fallback | Title, description, image, brand, price |

## Contributing

```bash
git clone https://github.com/Vatsal2006350/amplify-audit.git
cd amplify-audit
npm install
npm run build
node dist/cli.js https://allbirds.com/products/mens-tree-runners
```

PRs welcome. If you're adding a new platform fetcher or scoring signal, include test cases.

## About

Built by [Amplify](https://use-amplify.com) — the AI operations manager for e-commerce teams. Amplify automates listings, compliance, and catalog management across every marketplace.

**amplify-audit** is the free, open-source analysis layer. The full Amplify platform adds:

- Continuous monitoring across all SKUs
- Auto-apply fixes to Shopify, Amazon, and 9+ marketplaces
- Multi-agent AI system (diagnosis, research, listing, pricing, inventory)
- Impact measurement (pre/post return rate tracking)

## License

MIT
