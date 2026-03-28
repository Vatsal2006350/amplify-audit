# amplify-audit (Jac)

**The first open-source product listing linter.** Powered by [Object-Spatial Programming](https://www.jac-lang.org/).

Analyze e-commerce product listings for quality issues, SEO optimization, return risk, and generate actionable PDP fixes — using a graph-based architecture where analysis agents (walkers) traverse your product catalog topology.

## Why Graphs?

Product catalogs ARE graphs: products belong to brands, brands span categories, returns cite reasons that cluster into fixable issues. Flat analysis tools can't see cross-product patterns like "Nike products consistently lack sizing info."

amplify-audit models your catalog as a **typed property graph** and sends computation to the data:

```
root
 ├── Brand("Nike")
 │    ├──[BelongsToBrand]── Product("Air Max 90")
 │    │                      ├──[HasReturn]── ReturnEvidence("runs small", count=8)
 │    │                      ├──[HasIssue]── IssueNode(SIZING, fixable=True)
 │    │                      └──[HasRecommendation]── RecommendationNode(...)
 │    └──[BelongsToBrand]── Product("Air Force 1")
 └── Category("Sneakers")
```

## Quick Start

### Prerequisites

```bash
pip install jaclang jac-byllm requests
```

### Audit a Product (CLI)

```bash
# Audit a single product
jac run main.jac https://allbirds.com/products/mens-tree-runners

# Audit with JSON output
jac run main.jac https://allbirds.com/products/mens-tree-runners --json

# Audit an entire Shopify store
jac run main.jac https://allbirds.com --store --max 50

# Export to file
jac run main.jac https://allbirds.com --store --json -o report.json
jac run main.jac https://allbirds.com --store --csv -o report.csv
jac run main.jac https://allbirds.com --store --markdown -o report.md

# Enable AI-powered deep analysis (requires ANTHROPIC_API_KEY)
export ANTHROPIC_API_KEY=sk-ant-...
jac run main.jac https://allbirds.com/products/mens-tree-runners --ai
```

### Start the API Server

```bash
jac start api.jac --port 8002
```

Then:

```bash
# Audit a product
curl -X POST http://localhost:8002/walker/audit_product \
  -H "Content-Type: application/json" \
  -d '{"url": "https://allbirds.com/products/mens-tree-runners"}'

# Audit a store
curl -X POST http://localhost:8002/walker/audit_catalog \
  -H "Content-Type: application/json" \
  -d '{"url": "https://allbirds.com", "max_products": 20}'

# Health check
curl http://localhost:8002/walker/health

# Export data
curl -X POST http://localhost:8002/walker/export_report \
  -H "Content-Type: application/json" \
  -d '{"format": "csv"}'
```

API docs at `http://localhost:8002/docs` (Swagger UI).

### Run Tests

```bash
jac test tests.jac
```

## Architecture

### Modules

| Module | Lines | Description |
|--------|-------|-------------|
| `types.jac` | ~195 | Graph schema: 6 node types, 6 edge types, 8 objects, 6 enums |
| `scoring.jac` | ~150 | Shannon entropy, composite scoring, confidence |
| `classifier.jac` | ~200 | 98-keyword classifier + `by llm()` semantic fallback |
| `analyzer.jac` | ~170 | Rule-based quality analysis: 15+ heuristic checks |
| `ai_analyzer.jac` | ~125 | Meaning-Typed LLM analysis: 4 `by llm()` functions |
| `seo_analyzer.jac` | ~250 | SEO-specific analysis: title, description, URL, keywords |
| `recommender.jac` | ~145 | Deterministic PDP fix templates by issue type |
| `fetcher.jac` | ~270 | Multi-platform product fetching (Shopify, Amazon, generic) |
| `trend_analyzer.jac` | ~230 | Cross-product pattern detection and trend analysis |
| `export.jac` | ~220 | Report export: JSON, CSV, Markdown |
| `walkers.jac` | ~485 | 6 core analysis walkers |
| `api.jac` | ~190 | REST API endpoints via walker-as-API |
| `main.jac` | ~450 | CLI entry point with argument parsing |
| `tests.jac` | ~195 | 18+ test cases |

### Walkers (Analysis Agents)

| Walker | What It Does | Traversal |
|--------|-------------|-----------|
| `QualityAnalyzer` | Rule-based listing quality checks | root → Product |
| `ReturnAnalyzer` | Classifies return reasons, computes SKU health | root → Product → Evidence |
| `RecommendationWalker` | Generates PDP fix recommendations | root → Product |
| `AiEnricher` | LLM-powered deep analysis via `by llm()` | root → Product (filtered) |
| `BrandAggregator` | Cross-product brand-level metrics | root → Brand → Product |
| `SEOAnalyzer` | SEO quality scoring (title, URL, keywords) | root → Product |
| `TrendAnalyzer` | Cross-catalog pattern detection | root → all nodes |
| `AuditReporter` | Collects full audit reports from graph | root → all nodes |

### The Technical Moat

**1. Graph-Aware Scoring** — No other tool models product quality as a graph. The `BrandAggregator` walker detects brand-wide patterns by traversing `Brand → Product` edges. Flat tools analyze products in isolation.

**2. Entropy-Based Fixability** — Shannon entropy measures return reason concentration:
```
C(p) = 1 - H_norm(p)
```
A product where 90% of returns say "runs small" (high concentration) = clear, fixable signal. Uniformly distributed reasons = no actionable fix. This metric is novel — no existing tool or paper computes it.

**3. Meaning-Typed Programming** — LLM analysis uses type signatures instead of prompt engineering:
```jac
def analyze_product_listing(
    title: str, description: str, price: str, brand: str,
    image_count: int, tag_count: int, variant_count: int, platform: str
) -> AiInsight by llm(temperature=0.3);
```
The Jac compiler generates the prompt from the function signature + `sem` strings. Type-safe, testable, no brittle prompts.

**4. Hybrid Scoring** — 30% rule-based + 70% AI for quality scores. Rules catch structural issues (missing fields, bad formatting); LLM catches semantic issues (misleading descriptions, vague sizing). Neither alone is sufficient.

## Scoring Model

### SKU Health Score

```
S(p) = 0.40 * R(p) + 0.20 * T(p) + 0.25 * K(p) + 0.15 * C(p)
```

Where:
- `R(p)` = normalized return rate
- `T(p)` = normalized ticket rate
- `K(p)` = keyword signal density
- `C(p)` = reason concentration (1 - normalized Shannon entropy)

### Listing Quality Score

```
Q(p) = max(0, min(100, 100 - 20*errors - 10*warnings - 3*infos))
```

Checks: title (length, caps, separators), description (length, sizing, material, care), images, tags, price, vendor.

### SEO Score

Weighted composite: title SEO (35%) + description keywords (30%) + URL slug (15%) + images (10%) + tags (10%).

## Configuration

Edit `jac.toml`:

```toml
[project]
name = "amplify-audit"
version = "0.3.0"
entry = "main.jac"

[server]
port = 8002

[plugins.byllm.model]
default_model = "claude-sonnet-4-6"  # or any LiteLLM-supported model

[plugins.byllm.call_params]
temperature = 0.3
max_tokens = 1024
```

Environment variables:
- `ANTHROPIC_API_KEY` — Required for AI-powered analysis (`--ai` flag)

## Supported Platforms

| Platform | Single Product | Store Catalog | Method |
|----------|---------------|---------------|--------|
| Shopify | Yes | Yes | `.json` API |
| Amazon | Yes | No | HTML scraping + JSON-LD |
| Best Buy | Yes | No | JSON-LD + fallback |
| Generic | Yes | No | JSON-LD + OpenGraph |

## Comparison: TypeScript vs Jac

| Feature | TypeScript (npm) | Jac (OSP) |
|---------|-----------------|-----------|
| Quality Analysis | Per-product functions | Graph-walking walkers |
| Brand Patterns | Not possible | BrandAggregator walker |
| SEO Analysis | Not included | SEOAnalyzer walker |
| Trend Detection | Not included | TrendAnalyzer walker |
| LLM Integration | Manual API calls | `by llm()` type-safe |
| API Server | Express/manual | `jac start` (automatic) |
| Graph Persistence | None | Built-in (SQLite) |
| Export Formats | JSON only | JSON, CSV, Markdown |
| Extensibility | Add functions | Add walkers (no existing code changes) |

## License

MIT
