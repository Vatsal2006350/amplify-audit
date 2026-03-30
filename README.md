<p align="center">
  <h1 align="center">amplify-audit</h1>
  <p align="center">
    <strong>The open-source product listing linter.</strong>
    <br />
    Like ESLint, but for e-commerce. Find bad listings. Fix copy. Reduce returns.
  </p>
  <p align="center">
    <a href="https://www.npmjs.com/package/amplify-audit"><img src="https://img.shields.io/npm/v/amplify-audit.svg" alt="npm version" /></a>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" /></a>
    <a href="https://nodejs.org/"><img src="https://img.shields.io/badge/node-%3E%3D18-brightgreen.svg" alt="Node.js" /></a>
    <a href="https://www.jac-lang.org/"><img src="https://img.shields.io/badge/jac-OSP-blue.svg" alt="Jac" /></a>
  </p>
  <p align="center">
    <a href="#quick-start">Quick Start</a> &middot;
    <a href="#what-it-catches">What It Catches</a> &middot;
    <a href="#the-scoring-model">Scoring</a> &middot;
    <a href="#jac-version-graph-aware-analysis">Graph-Aware Analysis</a> &middot;
    <a href="#rest-api">API</a>
  </p>
</p>

---

> U.S. e-commerce returns hit **$800B+ in 2024**. The #1 driver? Bad product listings. Missing sizing info, vague descriptions, misleading photos. Most of these are fixable with better copy. amplify-audit finds the problems and tells you exactly what to change.

---

## 30-Second Overview

- **What is this?** `amplify-audit` is an open-source linter for product pages (PDPs).
- **Why this matters:** Better listing quality reduces avoidable returns and support tickets.
- **How to run it:** `npx amplify-audit <product-url>`
- **What you get:** A quality score, prioritized issues, and concrete listing fixes.

## Golden Demo (Real Run)

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners
```

```text
Fetching product data...
Running quality analysis...

Men's Tree Runner - Jet Black (White Sole)
Platform: shopify
https://allbirds.com/products/mens-tree-runners

Quality Score: 64/100  NEEDS WORK

--- Issues Found ---
  ▲ Title could be longer (42 chars). Optimal is 50-80 characters for SEO.
  ▲ Description could be more detailed (242 chars). Target 300-1000 characters.
  ▲ No sizing or fit information found. This is the #1 driver of returns.
  ○ No material/fabric information detected. Adding materials improves buyer confidence.
  ○ No care instructions found. Consider adding washing/maintenance info.

Audit complete.
```

## Highlights

- **15+ quality checks** across title, description, images, sizing, SEO, price, and trust signals
- **98-keyword return classifier** covering 5 issue categories, with optional LLM semantic fallback
- **Entropy-based fixability scoring**, a novel metric that uses Shannon entropy to measure whether a product's returns have a single fixable root cause
- **4 platforms** supported: Shopify, Amazon, Best Buy, and any site with JSON-LD / OpenGraph
- **Graph-aware analysis** in the Jac version, detecting brand-wide patterns that flat tools can't see
- **Actionable fixes** with before/after PDP diffs you can apply directly
- **Two interfaces**: an npm package (TypeScript) and a Jac version (graph-based, CLI + REST API)
- **Zero config**. Works out of the box. No API keys needed for core analysis

## Quick Start

### npm (TypeScript)

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners
```

Or for local development in this repo:

```bash
npm install
npm run audit -- https://allbirds.com/products/mens-tree-runners
```

### Jac (Graph-Aware)

```bash
pip install -r jac/requirements.txt
AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run jac/main.jac
```

No API keys needed. AI features are opt-in (pass `--ai` with `ANTHROPIC_API_KEY` set).

## Developer Integration

If you are adopting this in a team workflow (services, PR checks, CI gates), use:

- `docs/developer-integration.md` for copy-paste local + CI setup
- `examples/devs/library-usage.mjs` for programmatic Node usage
- `examples/devs/returns.sample.json` for realistic returns fixture data

Helpful scripts in this repository:

```bash
npm run audit -- <product-url>
npm run audit:json -- <product-url>
npm run example:library
```

## What It Catches

```
$ npx amplify-audit https://example-store.com/products/womens-running-shoes

  Women's Running Shoes
  Platform: shopify

  Quality Score: 42/100  NEEDS WORK

  Issues Found
  ✗ description    Description is too short (87 chars). Target 300-1000.
  ✗ images         Only 2 image(s). Aim for 4+ with lifestyle and detail shots.
  ▲ sizing         No sizing or fit info found. #1 driver of returns.
  ▲ title          Title could be longer (28 chars). Optimal is 50-80 for SEO.
  ▲ tags           No tags/categories found. Tags improve discoverability.
  ○ material       No material/fabric information detected.
  ○ care           No care instructions found.

  Return Risk Analysis
  Risk Level: MEDIUM
  Primary Issue: SIZING (82% of returns)
  Reason Concentration: 0.74 (high, clear fixable signal)
  Fixable by PDP: Yes

  Recommended Fixes
  1. title → "Women's Running Shoes (Runs Small, Consider Sizing Up)"
     Set expectations at top of listing to reduce fit-related returns.

  2. description → Add: "Fit note: This style runs slightly small.
     If you're between sizes, consider sizing up."
     Adds concrete fit guidance shoppers can act on before purchasing.
```

The important thing here: this product has a **0.74 reason concentration**. Returns are heavily clustered around one fixable cause. A single description change could meaningfully reduce the return rate.

## The Scoring Model

### Listing Quality Score

```
Q(p) = max(0, min(100,  100 - 20·errors - 10·warnings - 3·infos))
```

15+ heuristic checks covering title (length, caps, separators), description (length, sizing keywords, material, care instructions), images (count), tags, price, and vendor.

### SKU Health Score (Fixability)

```
S(p) = 0.40·R̂(p) + 0.20·T̂(p) + 0.25·K̂(p) + 0.15·Ĉ(p)
```

| Component | What It Measures |
|-----------|-----------------|
| `R̂(p)` | Normalized return rate |
| `T̂(p)` | Normalized support ticket rate |
| `K̂(p)` | Keyword signal density (98 terms across 5 categories) |
| `Ĉ(p)` | **Reason concentration** via Shannon entropy (see below) |

### The Entropy Metric

This is the thing that makes amplify-audit different from everything else out there. The reason concentration `C(p)` tells you whether a product's returns point to one fixable cause or are just noise:

```
H(X)     = -Σ pᵢ · log₂(pᵢ)       ← Shannon entropy of return reasons
H_norm   = H(X) / log₂(|X|)        ← Normalized to [0, 1]
C(p)     = 1 - H_norm               ← 0 = uniform noise, 1 = single cause
```

| Scenario | C(p) | What It Means |
|----------|------|---------------|
| 90% of returns say "runs small" | **0.93** | One clear, fixable cause. Add a sizing note. |
| 60/20/10/10 split across 4 reasons | **0.32** | One dominant cause with some noise |
| 20% each across 5 reason types | **0.00** | No dominant cause. A PDP fix won't help. |

If a product has a 30% return rate and C(p) = 0.93, that's a slam dunk for a PDP fix. If it has a 30% return rate and C(p) = 0.05, the problems are systemic and no description change will solve them. That distinction is the whole point.

## With Return Data

If you have return reasons, feed them in for the full analysis:

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners \
  --returns ./returns.json
```

```json
{
  "reasons": ["too small", "runs small", "fit issue", "wrong size", "color different"],
  "orderCount": 150,
  "returnCount": 35,
  "ticketCount": 8
}
```

## Use as a Library

```bash
npm install amplify-audit
```

```typescript
import { audit } from 'amplify-audit'

const report = await audit({
  url: 'https://mystore.myshopify.com/products/blue-sweater'
})

console.log(report.qualityScore)     // 64
console.log(report.issues)           // [{ type: 'warning', category: 'title', ... }]
console.log(report.recommendations)  // [{ field: 'title', before: '...', after: '...' }]
```

<details>
<summary><strong>Individual modules</strong></summary>

```typescript
import { analyzeListingQuality } from 'amplify-audit'

const { qualityScore, issues } = analyzeListingQuality({
  title: 'Blue Wool Sweater',
  description: 'Hand-knit, 100% wool...',
  tags: ['clothing', 'blue'],
  images: ['https://...'],
})

import { classifyReasons, getPrimaryIssueType } from 'amplify-audit'

const scores = classifyReasons(['too small', 'runs small', 'tight fit'])
const primary = getPrimaryIssueType(scores) // 'sizing'

import { computeFixabilityScore, computeReasonConcentration } from 'amplify-audit'

const concentration = computeReasonConcentration({ 'runs small': 8, 'other': 2 })
// 0.72 = high concentration = clear signal
```

</details>

## CI/CD Quality Gate

You can fail your pipeline when listing quality drops below a threshold:

```bash
npx amplify-audit https://your-store.com/products/sku-123 --min-score 70 --json
```

Exits with code 1 if the score is below `--min-score`.

Ready-to-use workflow is included at:

- `.github/workflows/listing-quality-gate.yml`

```yaml
# GitHub Actions
- name: Audit listing quality
  run: npx amplify-audit ${{ env.PRODUCT_URL }} --min-score 70
```

---

## Jac Version: Graph-Aware Analysis

The `jac/` directory contains a full rewrite in [Jac](https://www.jac-lang.org/), a language built around Object-Spatial Programming. The idea is simple: data lives on a graph, and computation moves through it.

This makes it possible to do analysis that flat tools literally cannot do.

### Why Graphs?

Product catalogs are graphs. Products belong to brands, brands span categories, returns cite reasons that cluster into fixable issues. amplify-audit models your catalog as a **typed property graph**:

```
root
 ├── Brand("Nike")
 │    ├──[BelongsToBrand]── Product("Air Max 90")
 │    │                      ├──[HasReturn]── ReturnEvidence("runs small", count=8)
 │    │                      ├──[HasIssue]── IssueNode(SIZING, fixable=True)
 │    │                      └──[HasRecommendation]── RecommendationNode(...)
 │    └──[BelongsToBrand]── Product("Air Force 1")
 └── Brand("Allbirds")
      └──[BelongsToBrand]── Product("Tree Runners")
```

Then it sends **8 specialized walkers** (analysis agents) through the graph:

| Walker | What It Does |
|--------|-------------|
| `QualityAnalyzer` | 15+ rule-based checks on title, description, images, tags, price |
| `ReturnAnalyzer` | Classifies return reasons, computes entropy-based SKU health |
| `RecommendationWalker` | Generates before/after PDP fix diffs |
| `SEOAnalyzer` | SEO scoring for title keywords, description density, URL slug |
| `AiEnricher` | Optional LLM-powered deep analysis via `by llm()` |
| `BrandAggregator` | Cross-product brand-level metrics |
| `TrendAnalyzer` | Catalog-wide pattern detection, co-occurrence, hotspots |
| `AuditReporter` | Collects everything into a structured report |

### What the graph enables

**Brand-level patterns:** "Nike products consistently have sizing issues (8/10 products). Average quality score: 62.3."

**Issue co-occurrence:** "Products with sizing issues also tend to have image issues (found together on 12 products)."

**Fixability hotspots:** "Sizing is the highest-impact fix across your catalog. 34 products fixable by PDP changes."

Flat tools analyze each product in isolation and can't see any of this.

### Jac Quick Start

```bash
pip install -r jac/requirements.txt

# Single product
AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run jac/main.jac

# Entire store (up to 50 products)
AMPLIFY_AUDIT_URL=https://allbirds.com jac run jac/main.jac --store --max 50

# With AI enrichment
export ANTHROPIC_API_KEY=sk-ant-...
AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run jac/main.jac --ai

# Export
AMPLIFY_AUDIT_URL=https://allbirds.com jac run jac/main.jac --store --json -o report.json
AMPLIFY_AUDIT_URL=https://allbirds.com jac run jac/main.jac --store --csv -o report.csv
AMPLIFY_AUDIT_URL=https://allbirds.com jac run jac/main.jac --store --markdown -o report.md
```

### Meaning-Typed Programming (No Prompt Engineering)

The Jac version uses type signatures as LLM specs instead of prompt strings:

```jac
def analyze_product_listing(
    title: str, description: str, price: str, brand: str,
    image_count: int, tag_count: int, variant_count: int, platform: str
) -> AiInsight by llm(temperature=0.3);

sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";
```

The compiler generates the prompt from the function signature and `sem` annotations. Type-safe output. Testable with mock backends. No brittle prompt strings.

### REST API

```bash
jac start jac/api.jac --port 8002
```

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/walker/health` | GET | Health check |
| `/walker/audit_product` | POST | Audit a single product URL |
| `/walker/audit_catalog` | POST | Audit an entire store |
| `/walker/get_brands` | POST | Brand-level metrics |
| `/walker/get_trends` | POST | Cross-product trends |
| `/walker/export_report` | POST | Export as JSON/CSV/Markdown |

Swagger docs at `http://localhost:8002/docs`.

### Jac Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              Product Quality Graph           │
                    │                                             │
  URL / Store ──→   │  Product ──→ Brand ──→ Category             │
  fetch & build     │    │                                        │
                    │    ├──→ ReturnEvidence                      │
                    │    ├──→ IssueNode                           │
                    │    └──→ RecommendationNode                  │
                    └────────────────┬────────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────────┐
              │                      │                          │
              ▼                      ▼                          ▼
     QualityAnalyzer         ReturnAnalyzer            BrandAggregator
     SEOAnalyzer             RecommendationWalker      TrendAnalyzer
     AiEnricher              AuditReporter
              │                      │                          │
              └──────────────────────┼──────────────────────────┘
                                     │
                                     ▼
                            JSON / CSV / Markdown
```

<details>
<summary><strong>Module breakdown (14 files, ~3,000 lines of Jac)</strong></summary>

| Module | Lines | Description |
|--------|------:|-------------|
| `types.jac` | 195 | Graph schema: 6 node types, 6 edge types, 8 objects, 6 enums |
| `scoring.jac` | 153 | Shannon entropy, composite scoring, confidence |
| `classifier.jac` | 201 | 98-keyword classifier + `by llm()` semantic fallback |
| `analyzer.jac` | 173 | Rule-based quality analysis, 15+ heuristic checks |
| `ai_analyzer.jac` | 127 | Meaning-Typed LLM analysis, 4 `by llm()` functions |
| `recommender.jac` | 147 | Deterministic PDP fix templates by issue type |
| `seo_analyzer.jac` | 250 | SEO scoring for title, description, URL, images, tags |
| `fetcher.jac` | 270 | Multi-platform product fetching |
| `walkers.jac` | 491 | 6 core analysis walkers |
| `trend_analyzer.jac` | 266 | Cross-product pattern detection |
| `export.jac` | 220 | Report export in JSON, CSV, Markdown |
| `api.jac` | 190 | REST API via walker-as-API |
| `main.jac` | 450 | CLI entry point |
| `tests.jac` | 195 | 18+ test cases |

</details>

---

## Supported Platforms

| Platform | Single Product | Store Catalog | Method |
|----------|:-:|:-:|--------|
| Shopify | ✓ | ✓ | `.json` API |
| Amazon | ✓ | - | HTML scraping + JSON-LD |
| Best Buy | ✓ | - | JSON-LD + fallback |
| Generic | ✓ | - | JSON-LD + OpenGraph |

## What This Doesn't Do

- **Predict returns from behavioral data** (customer history, purchase patterns). It looks at listing content, not buyer behavior.
- **Manage product data.** That's what PIMs like Salsify and Akeneo do. This audits and scores listings.
- **Auto-apply fixes.** It generates before/after diffs for human review. The full [Amplify](https://use-amplify.com) platform handles automated Shopify writes.

## Configuration

### npm

```
amplify-audit [url] [options]

Options:
  --returns <path>       Path to returns JSON file
  --json                 Output as JSON
  --min-score <n>        Exit with code 1 if quality score is below threshold
  -V, --version          Version
  -h, --help             Help
```

### Jac

```toml
# jac/jac.toml
[project]
name = "amplify-audit"
version = "0.3.0"

[plugins.byllm.model]
default_model = "claude-sonnet-4-6"  # any LiteLLM-supported model

[plugins.byllm.call_params]
temperature = 0.3
```

| Variable | Required | Description |
|----------|:--------:|-------------|
| `ANTHROPIC_API_KEY` | Only for `--ai` | Enables LLM-powered analysis and semantic classification |

## Testing

```bash
# TypeScript
npm test

# Jac
jac test jac/tests.jac
```

## Contributing

PRs welcome. The Jac walker architecture makes it straightforward to add new analysis:

1. Define new node/edge types in `jac/types.jac`
2. Create a new walker in its own `.jac` file
3. Add the walker to the pipeline in `jac/main.jac`

No need to modify existing walkers or analysis code.

For the TypeScript version, add modules in `src/` and include test cases.

## About

Built by [Amplify](https://use-amplify.com). amplify-audit is the free, open-source analysis engine. The full platform adds continuous monitoring, auto-apply to Shopify, multi-agent AI, and impact measurement.

## License

MIT
