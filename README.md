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
    <a href="#api">API</a>
  </p>
</p>

---

> U.S. e-commerce returns hit **$800B+ in 2024**. The #1 driver? Bad product listings — missing sizing info, vague descriptions, misleading photos. Most of these are fixable with better copy. amplify-audit finds the issues and tells you exactly what to change.

---

## Highlights

- **15+ quality checks** across title, description, images, sizing, SEO, price, and trust signals
- **98-keyword return classifier** across 5 issue categories with optional LLM semantic fallback
- **Entropy-based fixability scoring** — novel metric using Shannon entropy to measure if a product's returns have a fixable root cause
- **4 platforms** — Shopify, Amazon, Best Buy, and any site with JSON-LD / OpenGraph
- **Graph-aware analysis** — Jac version detects brand-wide patterns invisible to flat tools
- **Actionable fixes** — generates before/after PDP diffs you can apply directly
- **Two interfaces** — npm package (TypeScript) and Jac version (graph-based, with CLI + REST API)
- **Zero config** — works out of the box, no API keys for core analysis

## Quick Start

### npm (TypeScript)

```bash
npx amplify-audit https://allbirds.com/products/mens-tree-runners
```

### Jac (Graph-Aware)

```bash
pip install jaclang jac-byllm requests
jac run jac/main.jac https://allbirds.com/products/mens-tree-runners
```

No API keys needed. AI features are opt-in (`--ai` flag with `ANTHROPIC_API_KEY`).

## What It Catches

```
$ npx amplify-audit https://example-store.com/products/womens-running-shoes

  Women's Running Shoes
  Platform: shopify

  Quality Score: 42/100  NEEDS WORK

  ─── Issues Found ───
  ✗ description    Description is too short (87 chars). Target 300-1000.
  ✗ images         Only 2 image(s). Aim for 4+ with lifestyle and detail shots.
  ▲ sizing         No sizing or fit info found. #1 driver of returns.
  ▲ title          Title could be longer (28 chars). Optimal is 50-80 for SEO.
  ▲ tags           No tags/categories found. Tags improve discoverability.
  ○ material       No material/fabric information detected.
  ○ care           No care instructions found.

  ─── Return Risk Analysis ───
  Risk Level: MEDIUM
  Primary Issue: SIZING (82% of returns)
  Reason Concentration: 0.74 (high — clear fixable signal)
  Fixable by PDP: Yes

  ─── Recommended Fixes ───
  1. title → "Women's Running Shoes (Runs Small — Consider Sizing Up)"
     Set expectations at top of listing to reduce fit-related returns.

  2. description → Add: "Fit note: This style runs slightly small.
     If you're between sizes, consider sizing up."
     Adds concrete fit guidance shoppers can act on before purchasing.
```

The key insight: this product has a **0.74 reason concentration** — returns are heavily clustered around one fixable cause. A single description change could meaningfully reduce the return rate.

## The Scoring Model

### Listing Quality Score

```
Q(p) = max(0, min(100,  100 - 20·errors - 10·warnings - 3·infos))
```

15+ heuristic checks across title (length, caps, separators), description (length, sizing keywords, material, care instructions), images (count), tags, price, and vendor.

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

This is what makes amplify-audit different. The reason concentration `C(p)` measures whether a product's returns point to a single fixable cause:

```
H(X)     = -Σ pᵢ · log₂(pᵢ)       ← Shannon entropy of return reasons
H_norm   = H(X) / log₂(|X|)        ← Normalized to [0, 1]
C(p)     = 1 - H_norm               ← 0 = uniform noise, 1 = single cause
```

| Scenario | C(p) | What It Means |
|----------|------|---------------|
| 90% of returns say "runs small" | **0.93** | One clear, fixable cause — add a sizing note |
| 60/20/10/10 split across 4 reasons | **0.32** | One dominant cause, some noise |
| 20% each across 5 reason types | **0.00** | No dominant cause — PDP fix won't help |

A product with 30% return rate and C(p) = 0.93 is a slam dunk for a PDP fix. A product with 30% return rate and C(p) = 0.05 has systemic issues no description change will solve.

## With Return Data

Have return reasons? Feed them in for the full analysis:

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
// 0.72 — high concentration = clear signal
```

</details>

## CI/CD Quality Gate

Fail your pipeline when listing quality drops below a threshold:

```bash
npx amplify-audit https://your-store.com/products/sku-123 --min-score 70 --json
```

Exits with code 1 if the score is below `--min-score`.

```yaml
# GitHub Actions
- name: Audit listing quality
  run: npx amplify-audit ${{ env.PRODUCT_URL }} --min-score 70
```

---

## Jac Version: Graph-Aware Analysis

The `jac/` directory contains a full rewrite using [Object-Spatial Programming](https://www.jac-lang.org/) — a paradigm where **data lives on a graph and computation moves through it**.

This unlocks analysis that flat tools literally cannot do.

### Why Graphs?

Product catalogs ARE graphs: products belong to brands, brands span categories, returns cite reasons that cluster into fixable issues. amplify-audit models your catalog as a **typed property graph**:

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

Then sends **8 specialized walkers** (analysis agents) through the graph:

| Walker | What It Does |
|--------|-------------|
| `QualityAnalyzer` | 15+ rule-based checks on title, description, images, tags, price |
| `ReturnAnalyzer` | Classifies return reasons, computes entropy-based SKU health |
| `RecommendationWalker` | Generates before/after PDP fix diffs |
| `SEOAnalyzer` | SEO scoring: title keywords, description density, URL slug |
| `AiEnricher` | Optional LLM-powered deep analysis via `by llm()` |
| `BrandAggregator` | Cross-product brand-level metrics |
| `TrendAnalyzer` | Catalog-wide pattern detection: co-occurrence, hotspots |
| `AuditReporter` | Collects everything into a structured report |

### What the graph enables

**Brand-level patterns:** "Nike products consistently have sizing issues (8/10 products). Average quality score: 62.3."

**Issue co-occurrence:** "Products with sizing issues also tend to have image issues (found together on 12 products)."

**Fixability hotspots:** "Sizing issues are the highest-impact fix across your catalog — 34 products fixable by PDP changes."

Flat tools analyze each product in isolation. They can't see any of this.

### Jac Quick Start

```bash
pip install jaclang jac-byllm requests

# Single product
jac run jac/main.jac https://allbirds.com/products/mens-tree-runners

# Entire store (up to 50 products)
jac run jac/main.jac https://allbirds.com --store --max 50

# With AI enrichment
export ANTHROPIC_API_KEY=sk-ant-...
jac run jac/main.jac https://allbirds.com/products/mens-tree-runners --ai

# Export
jac run jac/main.jac https://allbirds.com --store --json -o report.json
jac run jac/main.jac https://allbirds.com --store --csv -o report.csv
jac run jac/main.jac https://allbirds.com --store --markdown -o report.md
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

The compiler generates the prompt from the function signature + `sem` annotations. Type-safe output. Testable with mock backends. No brittle prompts.

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
| `analyzer.jac` | 173 | Rule-based quality analysis: 15+ heuristic checks |
| `ai_analyzer.jac` | 127 | Meaning-Typed LLM analysis: 4 `by llm()` functions |
| `recommender.jac` | 147 | Deterministic PDP fix templates by issue type |
| `seo_analyzer.jac` | 250 | SEO scoring: title, description, URL, images, tags |
| `fetcher.jac` | 270 | Multi-platform product fetching |
| `walkers.jac` | 491 | 6 core analysis walkers |
| `trend_analyzer.jac` | 266 | Cross-product pattern detection |
| `export.jac` | 220 | Report export: JSON, CSV, Markdown |
| `api.jac` | 190 | REST API via walker-as-API |
| `main.jac` | 450 | CLI entry point |
| `tests.jac` | 195 | 18+ test cases |

</details>

---

## Supported Platforms

| Platform | Single Product | Store Catalog | Method |
|----------|:-:|:-:|--------|
| Shopify | ✓ | ✓ | `.json` API |
| Amazon | ✓ | — | HTML scraping + JSON-LD |
| Best Buy | ✓ | — | JSON-LD + fallback |
| Generic | ✓ | — | JSON-LD + OpenGraph |

## What It Does NOT Do

- **Predict returns from behavioral data** (customer history, purchase patterns). It identifies fixable listing content.
- **Manage product data** (that's what PIMs like Salsify and Akeneo do). It audits and scores it.
- **Auto-apply fixes.** It generates before/after diffs for human review. (The full [Amplify](https://use-amplify.com) platform adds automated Shopify writes.)

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

PRs welcome. The Jac walker architecture makes it easy to add new analysis:

1. Define new node/edge types in `jac/types.jac`
2. Create a new walker in its own `.jac` file
3. Add the walker to the pipeline in `jac/main.jac`

No need to modify existing walkers.

For the TypeScript version: add modules in `src/`, include test cases.

## About

Built by [Amplify](https://use-amplify.com) — AI operations for e-commerce teams. amplify-audit is the free, open-source analysis engine. The full platform adds continuous monitoring, auto-apply to Shopify, multi-agent AI, and impact measurement.

## License

MIT
