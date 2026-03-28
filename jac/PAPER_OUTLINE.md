# Data-Spatial Product Quality Analysis: Applying Object-Spatial Programming to E-Commerce Catalog Auditing

**Authors:** Vatsal Shah, Jason Mars
**Affiliation:** University of Michigan

---

## Abstract (~200 words)

E-commerce product listings are the primary interface between merchants and consumers, yet catalog quality remains a persistent challenge. Inaccurate descriptions, missing sizing information, and misleading imagery drive return rates as high as 30% in some product categories, costing U.S. retailers over $800 billion annually. Existing catalog quality tools rely on flat rule-based validators or isolated LLM calls, lacking the ability to reason about cross-product patterns, brand-level trends, and the topological relationships inherent in product catalogs.

We present **amplify-audit**, the first application of Object-Spatial Programming (OSP) to e-commerce catalog quality analysis. Our approach models product catalogs as typed property graphs — with products, brands, categories, and evidence as nodes connected by semantically typed edges — and deploys mobile computational agents (walkers) that traverse this topology to perform multi-hop quality analysis. We introduce a novel **Meaning-Typed Quality Assessment** framework where LLM-powered analysis functions derive their specifications from type signatures rather than handcrafted prompts.

Our evaluation on [N] product listings across [M] Shopify and Amazon brands demonstrates that graph-aware scoring improves issue detection precision by [X]% over flat analysis, and that the walker-based architecture enables [Y]x faster batch analysis through implicit parallelism. The tool is open-source and available at [URL].

---

## 1. Introduction (~1.5 pages)

### 1.1 The Product Listing Quality Problem
- $800B+ in annual U.S. e-commerce returns (NRF 2024)
- 20-30% of online apparel purchases returned (vs 8% in-store)
- Top return drivers: sizing (52%), description mismatch (22%), quality (15%)
- "Information asymmetry" between what the listing promises and what the buyer receives
- **Key insight**: Most return-driving issues are *fixable* through better product descriptions — this is a content problem, not a logistics problem

### 1.2 Limitations of Current Approaches
- **Rule-based validators** (Google Merchant, Amazon IDQ): Check field completeness but miss semantic issues
- **LLM analyzers** (GPT wrappers): Analyze listings in isolation, cannot reason about brand patterns or category norms
- **PIM systems** (Salsify, Akeneo): Focus on data management, not quality optimization
- **No tool models the inherent graph structure** of product catalogs (products ↔ brands ↔ categories ↔ evidence)

### 1.3 Our Approach: Data-Spatial Analysis
- Model catalogs as typed property graphs
- Send computation to the data (walkers) instead of pulling data to computation
- Use the graph topology to inform scoring (brand norms, category patterns)
- Leverage Meaning-Typed Programming for type-safe AI analysis

### 1.4 Contributions
1. **DSPQA Framework**: First application of Object-Spatial Programming to e-commerce catalog quality, with formal definitions of the quality analysis graph and walker semantics
2. **Graph-Aware Scoring Model**: Composite scoring function that incorporates information-theoretic metrics (Shannon entropy for reason concentration) and graph neighborhood context
3. **Meaning-Typed Quality Assessment**: Demonstration of how Jac's `by llm()` mechanism enables type-safe LLM analysis with structured output validation
4. **Open-Source Implementation**: Production-quality tool with 7 Jac modules, 6 specialized walkers, and comprehensive test suite

---

## 2. Background and Motivation (~2 pages)

### 2.1 Object-Spatial Programming
- Overview of OSP paradigm (cite Jac/Jaseci papers)
- Five archetypes: obj, node, edge, walker, class
- The "computation moves to data" inversion
- Walker entry/exit abilities as event-driven computation
- Comparison with traditional OOP/FP approaches (Table 1)

### 2.2 Meaning-Typed Programming
- `by llm()` as a language primitive (cite MTP paper)
- Function signatures as LLM specifications
- Type validation of LLM output
- Semantic strings (`sem`) for disambiguation

### 2.3 E-Commerce Product Knowledge Graphs
- Amazon AutoKnow (Dong et al., 2020)
- Walmart Retail Graph
- KDD 2021 Product Knowledge Graph tutorial
- Billion-scale e-commerce knowledge graphs (Alibaba, JD.com)
- **Gap**: These model product data but not quality analysis

### 2.4 Listing Quality in Practice
- Amazon Item Data Quality (IDQ) score
- Walmart Content Quality Score
- Jungle Scout Listing Quality Score
- Google Merchant feed validation
- **Gap**: All are closed-source, proprietary, and flat (no graph reasoning)

---

## 3. Approach: Data-Spatial Product Quality Analysis (~3 pages)

### 3.1 Graph Schema

**Definition 1 (Product Quality Graph).** A product quality graph G = (N, E) where:
- N = N_P ∪ N_B ∪ N_C ∪ N_R ∪ N_I ∪ N_X
  - N_P: Product nodes (listing content + computed scores)
  - N_B: Brand nodes (vendor aggregates)
  - N_C: Category nodes (category norms)
  - N_R: ReturnEvidence nodes (customer return reasons)
  - N_I: IssueNode (detected quality issues)
  - N_X: RecommendationNode (proposed PDP fixes)
- E = E_bb ∪ E_ic ∪ E_hr ∪ E_hi ∪ E_hx ∪ E_st
  - E_bb: BelongsToBrand (product → brand)
  - E_ic: InCategory (product → category)
  - E_hr: HasReturn (product → evidence)
  - E_hi: HasIssue (product → issue)
  - E_hx: HasRecommendation (product → recommendation)
  - E_st: SimilarTo (product ↔ product)

**Figure 1**: Visual diagram of the graph topology

### 3.2 Walker Architecture

**Definition 2 (Analysis Walker).** A walker W = (S, A, T) where:
- S: walker state (accumulated data fields)
- A: set of entry/exit abilities (triggered by node types)
- T: traversal strategy (which edges to follow)

Six specialized walkers (Table 2):

| Walker | Input Nodes | Output | Traversal |
|--------|------------|--------|-----------|
| QualityAnalyzer | Product | quality_score, issues | root → Product |
| ReturnAnalyzer | Product, ReturnEvidence | sku_health, risk_level | root → Product → Evidence |
| RecommendationWalker | Product (scored) | recommendations | root → Product |
| AiEnricher | Product (page data) | ai_insight | root → Product (filtered) |
| BrandAggregator | Brand, Product | brand metrics | root → Brand → Product |
| AuditReporter | All | audit reports | root → all nodes |

### 3.3 Composite Scoring Model

**Definition 3 (SKU Health Score).** For product p with return data:

```
S(p) = w_r · R̂(p) + w_t · T̂(p) + w_k · K̂(p) + w_c · Ĉ(p)
```

Where:
- R̂(p) = min(R(p) · 100, 100) — normalized return rate
- T̂(p) = min(T(p) · 100, 100) — normalized ticket rate
- K̂(p) = min(K(p) · 10, 100) — keyword signal density
- Ĉ(p) = (1 - H_norm(p)) · 100 — reason concentration

And weights w_r=0.40, w_t=0.20, w_k=0.25, w_c=0.15 (empirically tuned).

**Shannon Entropy for Reason Concentration:**

```
H(X) = -Σ p_i · log₂(p_i)
H_norm = H(X) / log₂(|X|)
C(p) = 1 - H_norm
```

Intuition: A product where 90% of returns cite "runs small" (low entropy) has a clear, actionable signal. A product with uniformly distributed reasons (high entropy) has no dominant fixable issue.

### 3.4 Rule-Based Quality Score

**Definition 4 (Listing Quality Score).** For product p:

```
Q(p) = max(0, min(100, 100 - 20·E(p) - 10·W(p) - 3·I(p)))
```

Where E, W, I are counts of errors, warnings, and info-level issues respectively, detected by pattern matching across title, description, images, tags, price, and vendor attributes.

### 3.5 Meaning-Typed AI Analysis

The AI enrichment walker uses Jac's `by llm()` mechanism:

```jac
def analyze_product_listing(
    title: str, description: str, price: str, brand: str,
    image_count: int, tag_count: int, variant_count: int, platform: str
) -> AiInsight by llm(temperature=0.3);
```

The compiler generates an LLM prompt from:
1. Function name → semantic intent
2. Parameter names/types → input schema
3. Return type (AiInsight) → output schema
4. `sem` strings → disambiguation constraints

**Score Blending:** Final score = 0.3 · Q_rule(p) + 0.7 · Q_ai(p)

### 3.6 Graph-Aware Brand Analysis

The BrandAggregator walker demonstrates multi-hop reasoning:

```
root → Brand("Nike") → [Product₁, Product₂, ..., Product_n]
```

By traversing brand → product edges, we compute:
- Brand-level average quality
- Cross-product issue patterns (e.g., "Nike products consistently lack sizing info")
- Category-relative performance

This is impossible in flat analysis tools.

---

## 4. Implementation (~1.5 pages)

### 4.1 System Architecture
- 7 Jac modules, ~800 lines of Jac code
- Compiles to Python bytecode via Jac compiler
- Configurable via jac.toml (model selection, temperature, etc.)
- TypeScript companion library for web integration

**Table 3: Module Structure**

| Module | Lines | Description |
|--------|-------|-------------|
| types.jac | ~170 | Graph schema: 6 node types, 6 edge types, 8 objects, 6 enums |
| scoring.jac | ~120 | Information-theoretic scoring: entropy, composite, confidence |
| classifier.jac | ~160 | Dual-mode classifier: 98 keywords + LLM fallback |
| analyzer.jac | ~140 | Rule-based quality analysis: 15+ heuristic checks |
| ai_analyzer.jac | ~100 | Meaning-typed LLM analysis: 4 by-llm functions |
| walkers.jac | ~320 | 6 specialized walkers for graph traversal |
| main.jac | ~180 | Graph builder, orchestration, entry point |
| tests.jac | ~130 | 18+ test cases covering all modules |

### 4.2 Walker Execution Model
- Graph construction: O(n) for n products
- Quality analysis: O(n) — one visit per product
- Return analysis: O(n · r) — n products, r average returns
- Brand aggregation: O(b · p̄) — b brands, p̄ avg products per brand
- AI enrichment: O(min(n, k)) — capped at k products (default 20)

### 4.3 Dual Classification System
- Keyword classifier: 98 terms across 5 categories, O(|text| · 98)
- LLM classifier: `by llm()` with IssueType enum return, automatic type validation
- Hybrid mode: LLM for ≤50 reasons, keyword fallback for larger batches

### 4.4 TypeScript Interop
- The Jac implementation runs alongside the existing TypeScript npm package
- Products fetched via TypeScript (cheerio scraping) are passed to Jac for analysis
- Results returned as JSON-serializable dicts

---

## 5. Evaluation (~2 pages)

### 5.1 Experimental Setup
- Dataset: [N] product listings from [M] Shopify stores and Amazon
- Categories: Apparel, Electronics, Home & Kitchen, Beauty
- Return data: Synthetic return reasons based on published return rate statistics
- Baselines:
  - Rule-only: TypeScript analyzer (no graph, no LLM)
  - LLM-only: Direct Claude API calls per product (no graph)
  - DSPQA: Full Jac implementation with graph + walkers + LLM

### 5.2 Quality Detection Accuracy (Table 4)
- Precision/Recall/F1 for issue detection across categories
- Ground truth: Manual annotation of [sample_size] listings
- Hypothesis: Graph-aware analysis (with brand context) improves precision

### 5.3 Brand-Level Pattern Detection (Table 5)
- Can the system detect brand-wide issues (e.g., "all Nike products lack sizing")?
- Comparison: flat analysis (per-product) vs. BrandAggregator walker
- Metric: Pattern detection recall at brand level

### 5.4 Scoring Correlation (Figure 2)
- Correlation between DSPQA scores and actual return rates
- Hypothesis: Composite score (with entropy) correlates better than rule-only

### 5.5 Performance and Scalability (Table 6)
- Wall-clock time for 10, 50, 100, 500, 1000 products
- Breakdown: graph construction, walker execution, LLM calls
- Comparison: flat TypeScript analysis vs. Jac walker-based

### 5.6 Developer Experience (Table 7)
- Lines of code comparison: TypeScript vs. Jac
- Number of explicit data access patterns vs. implicit (walker traversal)
- Qualitative: separation of concerns (data in nodes, logic in walkers)

---

## 6. Related Work (~1.5 pages)

### 6.1 Product Knowledge Graphs
- AutoKnow (Amazon, Dong et al. 2020): automatic product knowledge graph construction
- AliCoCo (Alibaba): large-scale e-commerce concept graph
- Product Knowledge Graph tutorial (KDD 2021)
- **Distinction**: These model product data, not quality analysis pipelines

### 6.2 NLP for E-Commerce
- BERT/GPT for product description generation (arXiv 2024)
- PRAISE: LLM-driven structured insights for product descriptions (arXiv 2025)
- LLMs in e-commerce: comparative analysis (ScienceDirect 2024)
- **Distinction**: These generate content; we analyze and score existing content

### 6.3 Data Quality in E-Commerce
- Google Merchant Feed Validation
- Great Expectations, Soda Core (general data quality)
- Walmart Content Quality Score, Amazon IDQ
- **Distinction**: These are rule-based validators; we combine rules + graph + LLM

### 6.4 Programming Language Paradigms
- Object-Spatial Programming (Jac/Jaseci)
- Meaning-Typed Programming (MTP, arXiv 2024)
- Compiler-driven cache coherence (Mars et al., our reference paper)
- Agent-based modeling (NetLogo, Mesa)
- **Distinction**: We apply OSP to a new domain (e-commerce quality)

---

## 7. Discussion (~1 page)

### 7.1 Why Graphs for Product Quality?
- Product catalogs ARE graphs (products ↔ brands ↔ categories)
- Quality issues propagate through relationships (brand-wide patterns)
- The walker model naturally expresses "scan all products for X"
- Separation of data (nodes) and analysis (walkers) enables extensibility

### 7.2 Meaning-Typed vs. Prompt-Engineered Analysis
- MTP advantages: type safety, composability, testability
- No brittle prompt strings; the compiler generates prompts from types
- MockLLM enables deterministic testing

### 7.3 Limitations
- Graph construction requires product data ingestion (web scraping is the bottleneck)
- LLM analysis adds latency and cost
- Keyword classifier has inherent recall limits
- Graph persistence not leveraged in current implementation

### 7.4 Future Work
- Persistent product graphs with `jac start` (server mode)
- Temporal analysis: track quality changes over time
- Cross-merchant benchmarking via shared category norms
- Image analysis via multimodal `by llm()` (already supported in Jac)
- Integration with Shopify/Amazon APIs for automated PDP updates

---

## 8. Conclusion (~0.5 pages)

We presented amplify-audit, the first application of Object-Spatial Programming to e-commerce product quality analysis. By modeling catalogs as typed property graphs and deploying specialized walkers for multi-hop analysis, our approach enables graph-aware quality scoring that captures brand-level patterns and cross-product relationships invisible to flat analysis tools.

Our key insight is that the walker-based computational model — where analysis agents traverse data topology rather than pulling data to stationary functions — naturally maps to catalog quality workflows where analysts need to "scan products across a brand for common issues." Jac's Meaning-Typed Programming further simplifies AI integration by eliminating prompt engineering in favor of type-driven specifications.

The tool is open-source, works across Shopify and Amazon, and can be extended with new walkers for domain-specific analysis without modifying existing code — demonstrating the extensibility benefits of the OSP paradigm's separation of data and computation.

---

## References

1. National Retail Federation. "Consumer Returns in the Retail Industry 2024."
2. Mars, J. et al. "Jac: A Language for Object-Spatial Programming." [Jaseci paper]
3. Mars, J. et al. "Meaning-Typed Programming." arXiv:2405.08965, 2024.
4. Mars, J. et al. "Compiler-Driven Cache Coherence for Full-Stack Applications via Cross-Boundary Static Analysis." [Reference paper]
5. Dong, X. et al. "AutoKnow: Self-Driving Knowledge Collection for Products." KDD 2020.
6. Amazon. "Item Data Quality (IDQ) Score." Seller Central Documentation.
7. Walmart. "Content Quality Score." Marketplace Documentation.
8. Teikametrics. "Understanding Listing Quality Scores." 2024.
9. Shannon, C. "A Mathematical Theory of Communication." 1948.
10. Various. "Investigating LLM Applications in E-Commerce." arXiv:2408.12779, 2024.
11. Various. "PRAISE: Enhancing Product Descriptions with LLM-Driven Structured Insights." arXiv:2506.17314, 2025.
12. WisePIM. "Product Validation Scoring Framework." 2024.
