<p align="center">
  <h1 align="center">amplify-audit</h1>
  <p align="center">
    <strong>The open-source product listing linter.</strong>
    <br />
    Like ESLint, but for e-commerce. Find bad listings. Fix copy. Reduce returns.
  </p>
  <p align="center">
    <a href="#quick-start">Quick Start</a> &middot;
    <a href="#what-it-catches">What It Catches</a> &middot;
    <a href="#how-it-works">How It Works</a> &middot;
    <a href="https://github.com/Vatsal2006350/amplify-audit">GitHub</a>
  </p>
</p>

---

> U.S. e-commerce returns hit **$800B+ in 2024**. The #1 driver? Bad product listings — missing sizing info, vague descriptions, misleading photos. Most of these are fixable with better copy. amplify-audit finds the issues and tells you exactly what to change.

---

## Highlights

- **15+ quality checks** across title, description, images, sizing, SEO, price, and trust signals
- **4 platforms** — Shopify, Amazon, Best Buy, and any site with JSON-LD/OpenGraph
- **Graph-aware analysis** — detects brand-wide patterns invisible to flat tools ("all Nike products lack sizing info")
- **Entropy-based return scoring** — novel metric using Shannon entropy to measure if a product's returns have a fixable root cause
- **AI-powered deep analysis** — optional LLM enrichment via type-safe `by llm()` (no prompt engineering)
- **Actionable fixes** — generates before/after PDP diffs you can apply directly
- **Multiple interfaces** — CLI, REST API, JSON/CSV/Markdown export
- **Zero config** — works out of the box, AI features opt-in

## Quick Start

```bash
# Install
pip install -r requirements.txt

# Audit a single product
AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run main.jac

# Audit an entire Shopify store
AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --max 50
```

That's it. No API keys needed for the core analysis.

<details>
<summary><strong>More examples</strong></summary>

```bash
# Export as JSON
AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --json -o report.json

# Export as CSV (open in Excel/Sheets)
AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --csv -o report.csv

# Export as Markdown report
AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --markdown -o report.md

# Enable AI deep analysis (requires API key)
export ANTHROPIC_API_KEY=sk-ant-...
AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run main.jac --ai

# Filter by score threshold
AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --min-score 50
```

AI enrichment is optional. If the `jac-byllm` plugin is not available in your environment, run without `--ai` and core analysis still works.

</details>

## What It Catches

```
$ jac run main.jac https://example-store.com/products/womens-running-shoes

  Women's Running Shoes
  ──────────────────────────────────────────────
  Quality Score:  42/100
  SKU Health:     67.3 (MEDIUM risk)
  SEO Score:      38/100

  ERRORS
    ✗ description    Description is too short (87 chars). Target 300-1000 characters.
    ✗ images         Only 2 image(s). Aim for 4+ with lifestyle and detail shots.

  WARNINGS
    ⚠ sizing         No sizing or fit information found. #1 driver of returns.
    ⚠ title          Title could be longer (28 chars). Optimal is 50-80 for SEO.
    ⚠ tags           No tags/categories found. Tags improve discoverability.

  INFO
    ℹ material       No material/fabric information detected.
    ℹ care           No care instructions found.

  RETURN RISK
    Primary issue:   SIZING (82% of returns)
    Concentration:   0.74 (high — clear fixable signal)
    Fixable by PDP:  Yes

  RECOMMENDED FIXES
    1. title → "Women's Running Shoes (Runs Small — Consider Sizing Up)"
       Rationale: Set expectations at top of listing to reduce fit-related returns.

    2. description → Add: "Fit note: This style runs slightly small. If you're
       between sizes or prefer extra room, consider sizing up."
       Rationale: Adds concrete fit guidance shoppers can act on before purchasing.
```

The key insight: this product has a **0.74 reason concentration** — meaning returns are heavily clustered around one fixable cause. A single description change could meaningfully reduce the 25% return rate.

## How It Works

amplify-audit models your catalog as a **typed property graph** and sends analysis agents (walkers) through it:

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

**8 specialized walkers** traverse this graph in sequence:

| Walker | What It Does |
|--------|-------------|
| `QualityAnalyzer` | 15+ rule-based checks on title, description, images, tags, price |
| `ReturnAnalyzer` | Classifies return reasons, computes entropy-based SKU health score |
| `RecommendationWalker` | Generates before/after PDP fix diffs based on detected issues |
| `SEOAnalyzer` | SEO scoring: title keywords, description density, URL slug quality |
| `AiEnricher` | Optional LLM-powered deep analysis via `by llm()` |
| `BrandAggregator` | Cross-product brand-level metrics (requires multiple products) |
| `TrendAnalyzer` | Catalog-wide pattern detection: co-occurrence, hotspots, distribution |
| `AuditReporter` | Collects everything into a structured audit report |

Each walker reads state written by previous walkers and writes new state. Adding a new analysis capability means adding a new walker file — **zero changes to existing code**.

## Scoring

### Listing Quality Score

```
Q(p) = max(0, min(100,  100 - 20·errors - 10·warnings - 3·infos))
```

15+ heuristic checks across 7 categories: title (length, caps, separators), description (length, sizing keywords, material, care), images (count), tags (count), price, vendor.

### SKU Health Score (Fixability)

```
S(p) = 0.40·R̂(p) + 0.20·T̂(p) + 0.25·K̂(p) + 0.15·Ĉ(p)
```

| Component | What It Measures |
|-----------|-----------------|
| `R̂(p)` | Normalized return rate |
| `T̂(p)` | Normalized support ticket rate |
| `K̂(p)` | Keyword signal density (matches across 98 issue keywords) |
| `Ĉ(p)` | **Reason concentration** — `1 - H_norm(p)` via Shannon entropy |

### The Entropy Metric

The reason concentration `C(p)` is what makes this tool different from everything else:

```
H(X)     = -Σ pᵢ · log₂(pᵢ)       ← Shannon entropy of return reasons
H_norm   = H(X) / log₂(|X|)        ← Normalized to [0, 1]
C(p)     = 1 - H_norm               ← Concentration: 0 = uniform, 1 = single cause
```

| Scenario | C(p) | Meaning |
|----------|------|---------|
| 90% of returns say "runs small" | 0.93 | One clear, fixable cause |
| 60/20/10/10 split across 4 reasons | 0.32 | Moderate — one dominant cause |
| 20% each across 5 reason types | 0.00 | No dominant cause — PDP fix won't help |

**Why it matters:** A product with 30% return rate and C(p) = 0.93 is a slam dunk for a PDP fix. A product with 30% return rate and C(p) = 0.05 has systemic issues no description change will solve. This distinction is the difference between wasting time and actually reducing returns.

### Hybrid Score Blending (with AI)

When `--ai` is enabled:

```
Q_final(p) = 0.30 · Q_rule(p) + 0.70 · Q_ai(p)
```

Rules catch structural issues (missing fields, bad formatting). The LLM catches semantic issues (misleading descriptions, vague sizing language). Neither alone is sufficient.

## AI Integration: Meaning-Typed Programming

amplify-audit uses [Jac's](https://www.jac-lang.org/) `by llm()` — type signatures as LLM specs instead of prompt strings:

```jac
def analyze_product_listing(
    title: str, description: str, price: str, brand: str,
    image_count: int, tag_count: int, variant_count: int, platform: str
) -> AiInsight by llm(temperature=0.3);

sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";
sem AiInsight.summary = "One-sentence summary of the single most important finding";
```

The Jac compiler generates the prompt from the function signature + `sem` annotations. No brittle prompt strings. Type-safe output validation. Testable with mock backends.

This extends to return reason classification:

```jac
def classify_reason_llm(reason: str) -> IssueType by llm(temperature=0.0);
```

The keyword classifier (98 terms, 5 categories) handles the common cases. The LLM handles ambiguity: "way too snug around the chest" → SIZING, even though it contains no sizing keywords.

## REST API

```bash
jac start api.jac --port 8002
```

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/walker/health` | GET | Health check |
| `/walker/audit_product` | POST | Audit a single product URL |
| `/walker/audit_catalog` | POST | Audit an entire store |
| `/walker/get_brands` | POST | Brand-level aggregate metrics |
| `/walker/get_trends` | POST | Cross-product trend analysis |
| `/walker/export_report` | POST | Export as JSON, CSV, or Markdown |

```bash
curl -X POST http://localhost:8002/walker/audit_product \
  -H "Content-Type: application/json" \
  -d '{"url": "https://allbirds.com/products/mens-tree-runners"}'
```

Auto-generated Swagger docs at `http://localhost:8002/docs`.

## Supported Platforms

| Platform | Single Product | Store Catalog | Method |
|----------|:-:|:-:|--------|
| Shopify | ✓ | ✓ | `.json` API |
| Amazon | ✓ | — | HTML scraping + JSON-LD |
| Best Buy | ✓ | — | JSON-LD + fallback |
| Generic | ✓ | — | JSON-LD + OpenGraph |

## Configuration

```toml
# jac.toml
[project]
name = "amplify-audit"
version = "0.3.0"
entry = "main.jac"

[server]
port = 8002

[plugins.byllm.model]
default_model = "claude-sonnet-4-6"  # any LiteLLM-supported model

[plugins.byllm.call_params]
temperature = 0.3
max_tokens = 1024
```

| Variable | Required | Description |
|----------|:--------:|-------------|
| `ANTHROPIC_API_KEY` | Only for `--ai` | Enables LLM-powered deep analysis and semantic classification |

## Architecture

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
<summary><strong>Module breakdown (14 files, ~3,000 lines)</strong></summary>

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

## Why This Exists

Every major e-commerce platform has an internal listing quality score — Amazon's IDQ, Walmart's CQS, Jungle Scout's LQS. They're all **closed-source, platform-specific, and flat**.

"Flat" means they analyze each product in isolation. They can't see that all 10 of your Nike products are missing size charts, or that your sizing-related returns are concentrated enough to fix with a single description change.

amplify-audit is:

1. **Open-source** — the first dedicated product listing linter. No existing open-source tool does this.
2. **Graph-aware** — models your catalog as a typed property graph, enabling brand-level and catalog-level pattern detection.
3. **Connected to returns** — doesn't just score listings, but connects listing quality signals to return outcomes via the entropy-based fixability metric.
4. **Cross-platform** — works on Shopify, Amazon, Best Buy, and any site with structured data.

### What it does NOT do

- It does not predict return rates from behavioral data (purchase history, customer profiles). It identifies fixable listing content.
- It does not manage product data (that's what PIMs like Salsify and Akeneo do). It audits and scores it.
- It does not automatically apply fixes. It generates before/after diffs for human review (or for integration with Shopify's Admin API).

## Built With

- [Jac](https://www.jac-lang.org/) — Object-Spatial Programming language
- [jaclang](https://pypi.org/project/jaclang/) — Jac compiler and runtime
- [jac-byllm](https://pypi.org/project/jac-byllm/) — Meaning-Typed Programming plugin for LLM integration

## Testing

```bash
jac test tests.jac
```

18+ test cases covering:
- Scoring functions (entropy, composite, confidence, quality)
- Keyword classification across all 5 issue categories
- Rule-based analysis (title, description, images, tags)
- Walker execution and graph traversal

## Contributing

Contributions welcome. The walker architecture makes it straightforward to add new analysis capabilities:

1. Define any new node/edge types in `types.jac`
2. Create a new walker in its own `.jac` file
3. Add the walker to the pipeline in `main.jac`

No need to modify existing walkers or analysis code.

## License

MIT
