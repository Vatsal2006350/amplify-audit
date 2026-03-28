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
- **Rule-based validators** (Google Merchant, Amazon IDQ, Walmart CQS): Check field completeness but miss semantic issues — e.g., a listing can score 100% on completeness while having a misleading size chart
- **LLM analyzers** (GPT wrappers): Analyze listings in isolation, cannot reason about brand patterns or category norms
- **PIM systems** (Salsify, Akeneo, Pimcore): Focus on data management, not quality optimization
- **No open-source product listing linter exists**: After extensive survey, no dedicated open-source tool checks product titles, descriptions, images, pricing, and metadata for quality and SEO compliance — a clear ecosystem gap
- **No tool models the inherent graph structure** of product catalogs (products ↔ brands ↔ categories ↔ evidence)
- **No unified framework connects listing quality to return rates**: Papers study return prediction OR listing quality in isolation; connecting "bad listing feature X causes return reason Y" is largely unexplored

### 1.3 Our Approach: Data-Spatial Analysis
- Model catalogs as typed property graphs
- Send computation to the data (walkers) instead of pulling data to computation
- Use the graph topology to inform scoring (brand norms, category patterns)
- Leverage Meaning-Typed Programming for type-safe AI analysis

### 1.4 Contributions
1. **DSPQA Framework**: First application of Object-Spatial Programming to e-commerce catalog quality, with formal definitions of the quality analysis graph and walker semantics
2. **Graph-Aware Scoring Model**: Composite scoring function that incorporates information-theoretic metrics (Shannon entropy for reason concentration) and graph neighborhood context — connecting listing quality signals to return rate prediction
3. **Meaning-Typed Quality Assessment**: Demonstration of how Jac's `by llm()` mechanism enables type-safe LLM analysis with structured output validation, eliminating prompt engineering
4. **Hybrid NLP + Rule-Based Quality Scoring**: Systematic comparison and combination of rule-based checks (structural completeness) with LLM-based semantic assessment — showing NLP catches issues rules miss (misleading descriptions) while rules catch issues NLP misses (missing GTIN, wrong image count)
5. **Open-Source Implementation**: First dedicated open-source product listing linter — 8 Jac modules, 6 specialized walkers, and comprehensive test suite

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
- Amazon AutoKnow (Dong et al., KDD 2020): Self-driving knowledge collection — auto product type, attribute values, error correction
- Walmart Retail Graph: Bipartite graph (products ↔ entities) powering semantic search and recommendations
- Billion-scale Pre-trained E-commerce Product Knowledge Graph Model (IEEE 2021): Pre-trained embeddings for billion-scale product graphs
- KDD 2021 Product Knowledge Graph tutorial (Amazon Product Graph Team)
- AliCoCo (Alibaba): Large-scale e-commerce concept graph
- **Gap**: These model product data structure but not quality analysis pipelines — no graph reasons about *why* a listing is bad

### 2.4 Listing Quality in Practice
- Amazon Item Data Quality (IDQ) score: 0-100, silently impacts search rankings, "Frequently Bought Together" placement, Lightning Deal eligibility
- Walmart Content Quality Score: 0-100 across content, discoverability, offer, ratings/reviews; higher scores rank favorably
- Jungle Scout LQS: 1-10 evaluating title length, keyword richness, bullet points, description, photo count/resolution
- Google Merchant feed validation: XML schema checks, structured data validators
- Academic frameworks evaluate: completeness, accuracy, consistency, validity, uniqueness, compliance (WisePIM 2024)
- **Gap**: All are closed-source, proprietary, and flat (no graph reasoning). No open-source equivalent exists

### 2.5 Return Rate Prediction and NLP for E-Commerce
- Urbanke et al. (2015): Mahalanobis feature extraction for return prediction on 1.14M purchases
- HyperGo (2024): CNN-LSTM hybrid achieving 97.67% accuracy for return prediction
- ACL ECNLP Workshop (2024): First comprehensive study predicting return *reasons* across multiple domains
- QLeBERT (Ullah et al., 2023): Combines quality-related lexicon, N-grams, BERT, and BiLSTM for quality classification
- PRAISE (2025): LLM-driven structured insights for addressing incomplete/inaccurate seller descriptions on Amazon
- ModICT (2024): Multimodal in-context tuning combining images + marketing keywords for product descriptions
- **Gap**: These study returns OR listing quality in isolation — no framework connects listing features to return causes

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

## 6. Related Work (~2 pages)

### 6.1 Product Knowledge Graphs
- AutoKnow (Amazon, Dong et al., KDD 2020): automatic product knowledge graph construction from taxonomy, user logs, and catalog data
- Walmart Retail Graph: bipartite graph with products and related entities powering semantic search and recommendations
- Billion-scale Pre-trained E-commerce Product KG Model (IEEE 2021): pre-trained embeddings for billion-scale product graphs, tested on classification, deduplication, and recommendation
- AliCoCo (Alibaba): large-scale e-commerce concept graph
- KDD 2021 Tutorial: "All You Need to Know to Build a Product Knowledge Graph" (Amazon Product Graph Team)
- KDD 2020 Workshop on Knowledge Graphs & E-Commerce (Walmart, Amazon, Home Depot)
- **Distinction**: These model product data structure, not quality analysis pipelines. We model quality signals (issues, evidence, recommendations) as first-class graph citizens

### 6.2 NLP for E-Commerce
- QLeBERT (Ullah et al., 2023): quality-related lexicon + BERT + BiLSTM for product quality classification
- PRAISE (arXiv 2025): LLM-driven structured insights for incomplete/inaccurate seller descriptions on Amazon
- ModICT (2024): multimodal in-context tuning combining images + marketing keywords; +3.3% Rouge-L, +9.4% diversity
- Investigating LLM Applications in E-Commerce (arXiv 2024): finds fine-tuning smaller models often outperforms few-shot with large LLMs
- Automated Product Description Generation via Vision-Language Models (Stanford CS231N, 2024): compares CLIP-GPT2, OFA, BLIP-2
- "Unveiling Dual Quality in Product Reviews" (2025): SetFit + sentence-transformers for quality inconsistencies; 1,957-review dataset
- "A Critical Assessment of Consumer Reviews" (2022): uses Shannon's Entropy Theory for review quality metrics
- **Distinction**: These generate or classify content; we analyze and score existing listings with graph-aware context and produce actionable fixes

### 6.3 Return Rate Prediction
- Urbanke et al. (2015): Mahalanobis feature extraction for return prediction on 1.14M purchases from German retailer
- HyperGo Framework (2024): CNN-LSTM hybrid achieving 97.67% accuracy for return prediction
- "Predicting Returns Even Before Purchase in Fashion E-Commerce" (2019): hybrid dual-model (DNN); A/B test on 100K users showed 3% return reduction
- "Learning Reasons for Product Returns on E-Commerce" (ACL ECNLP Workshop, 2024): first comprehensive study predicting return *reasons* across multiple domains
- "Forecasting E-Commerce Consumer Returns" (2024): systematic review of 25 publications; identifies product reviews/sentiment as promising predictors
- **Distinction**: These predict returns from purchase/behavioral data; we identify *fixable listing content* that drives returns

### 6.4 Data Quality Tools and Frameworks
- Amazon IDQ Score: 0-100, impacts search rankings and Lightning Deal eligibility
- Walmart Content Quality Score: 0-100, evaluates content, discoverability, offer, ratings/reviews
- Google Merchant feed validation: XML schema checks
- Great Expectations, Soda Core: general-purpose data quality frameworks (adaptable but not e-commerce-specific)
- Spectral (Stoplight): JSON/YAML linter with custom rulesets
- Open-source PIMs: Pimcore, Akeneo, AtroPIM — data management, not quality scoring
- **Distinction**: Platform tools are closed-source and rule-based only; general frameworks lack e-commerce domain knowledge; no open-source listing linter exists. We combine rules + graph + LLM in an open-source tool

### 6.5 Programming Language Paradigms
- Object-Spatial Programming (Jac/Jaseci, arXiv 2023): computation travels to data via walkers traversing node/edge graphs
- "The Case for a Wholistic Serverless Programming Paradigm" (2022): graph-native programming for reasoning about data
- Meaning-Typed Programming (MTP, arXiv 2024): `by llm()` as language primitive; developers complete tasks 3.2x faster with 45% fewer LOC
- LLM-Based Multi-Agent Systems (IEEE ICEBE 2025): LLM-powered agents simulating consumer decisions
- Agentic LLMs in Supply Chain (Int. J. Production Research, 2025): autonomous consensus-seeking agents
- Agent-based modeling (NetLogo, Mesa)
- **Distinction**: We apply OSP + MTP to a new domain (e-commerce quality) and demonstrate that the walker/graph model naturally expresses catalog quality workflows

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

### 7.3 Industry Context: The Build-vs-Buy Landscape
- Major brands (Nike, Adidas, Warby Parker, Allbirds) invest heavily in product data infrastructure but build internal, proprietary solutions
- Nike acquired Datalogue, Zodiac, Select for unified product/customer data; RFID across all footwear/apparel
- Adidas moved to microservices/micro-frontends, piloted GitHub Copilot across 500 engineers (20-25% efficiency gains)
- Warby Parker uses 168 technologies with custom "Point of Everything" headless commerce platform
- 91% of IT decision-makers believe they need to improve data quality (Syncari 2024)
- SMBs lack the engineering resources of these brands — an open-source listing linter fills a real gap
- Enterprise PIM market (Inriver, Pimcore, Akeneo) focuses on data management, not quality optimization

### 7.4 Limitations
- Graph construction requires product data ingestion (web scraping is the bottleneck)
- LLM analysis adds latency (~2-5s per product) and cost (~$0.01 per product via Claude)
- Keyword classifier has inherent recall limits (98 keywords across 5 categories)
- Graph persistence not leveraged in current implementation (in-memory only)
- Evaluation uses synthetic return reasons based on published statistics, not real merchant data

### 7.5 Future Work
- Persistent product graphs with `jac start` (server mode) for incremental analysis
- Temporal analysis: track quality changes over time, measure fix impact
- Cross-merchant benchmarking via shared category norms
- Image analysis via multimodal `by llm()` (already supported in Jac) — detecting misleading product photos
- Integration with Shopify/Amazon APIs for automated PDP updates (close the loop)
- Pre-purchase return prediction: use listing quality signals to predict return rates before products go live
- Multi-agent extension: leverage Jac's walker architecture for specialized agents (pricing, inventory, competitive) as demonstrated in the companion Amplify platform

---

### 7.6 Why This Work Is Novel (Positioning Statement)

The research gap is clear across four dimensions:

1. **No open-source product listing linter exists.** Major brands build internal solutions; SMBs rely on expensive SaaS tools or platform-native checks.
2. **No unified framework connects listing quality to return rates.** Papers study return prediction OR listing quality in isolation. Connecting "bad listing feature X causes return reason Y" via graph topology is unexplored.
3. **Multi-agent and graph-based approaches are validated in adjacent domains** (supply chain, financial trading, general knowledge graphs) but have not been applied to product listing auditing.
4. **The NLP vs. rule-based comparison for listing quality is undocumented.** Platforms use rule-based scoring; academic research focuses on NLP for reviews/descriptions. No paper systematically compares and combines both for holistic listing quality assessment.

---

## 8. Conclusion (~0.5 pages)

We presented amplify-audit, the first application of Object-Spatial Programming to e-commerce product quality analysis. By modeling catalogs as typed property graphs and deploying specialized walkers for multi-hop analysis, our approach enables graph-aware quality scoring that captures brand-level patterns and cross-product relationships invisible to flat analysis tools.

Our key insight is that the walker-based computational model — where analysis agents traverse data topology rather than pulling data to stationary functions — naturally maps to catalog quality workflows where analysts need to "scan products across a brand for common issues." Jac's Meaning-Typed Programming further simplifies AI integration by eliminating prompt engineering in favor of type-driven specifications.

The tool is open-source, works across Shopify and Amazon, and can be extended with new walkers for domain-specific analysis without modifying existing code — demonstrating the extensibility benefits of the OSP paradigm's separation of data and computation.

---

## References

### Core Framework
1. Mars, J. et al. "The Jaseci Programming Paradigm and Runtime Stack." arXiv:2305.09864, 2023.
2. Mars, J. et al. "Meaning-Typed Programming." arXiv:2405.08965, 2024.
3. Mars, J. et al. "The Case for a Wholistic Serverless Programming Paradigm and Full Stack Automation for AI and Beyond." 2022.
4. Mars, J. et al. "Compiler-Driven Cache Coherence for Full-Stack Applications via Cross-Boundary Static Analysis." [Reference paper]

### E-Commerce Returns and Industry
5. National Retail Federation. "Consumer Returns in the Retail Industry 2024."
6. Shannon, C. "A Mathematical Theory of Communication." Bell System Technical Journal, 1948.

### Product Knowledge Graphs
7. Dong, X. et al. "AutoKnow: Self-Driving Knowledge Collection for Products of Thousands of Types." KDD 2020.
8. Walmart Global Tech. "Retail Graph: Walmart's Product Knowledge Graph." 2021.
9. "Billion-scale Pre-trained E-commerce Product Knowledge Graph Model." IEEE, 2021. arXiv:2105.00388.
10. "All You Need to Know to Build a Product Knowledge Graph." KDD 2021 Tutorial.
11. "KDD 2020 Workshop on Knowledge Graphs and E-Commerce." USC ISI.

### NLP for E-Commerce
12. Ullah, I. et al. "QLeBERT: Assessing Product Quality in E-Commerce." 2023.
13. "PRAISE: Enhancing Product Descriptions with LLM-Driven Structured Insights." arXiv:2506.17314, 2025.
14. "ModICT: Multimodal In-Context Tuning for Product Description Generation." arXiv:2402.13587, 2024.
15. "Investigating LLM Applications in E-Commerce." arXiv:2408.12779, 2024.
16. "Automated Product Description Generation via Vision-Language Models." Stanford CS231N, 2024.
17. "Unveiling Dual Quality in Product Reviews: An NLP-Based Approach." 2025.
18. "A Critical Assessment of Consumer Reviews: A Hybrid NLP-Based Methodology." 2022.

### Return Rate Prediction
19. Urbanke, P. et al. "Predicting Product Returns in E-Commerce: The Contribution of Mahalanobis Feature Extraction." 2015.
20. "HyperGo Framework." CNN-LSTM hybrid for return prediction. 2024.
21. "Predicting Returns Even Before Purchase in Fashion E-Commerce." arXiv:1906.12128, 2019.
22. "Learning Reasons for Product Returns on E-Commerce." ACL ECNLP Workshop, 2024.
23. "Forecasting E-Commerce Consumer Returns: A Systematic Literature Review." Springer, 2024.
24. "Return Management: A Machine Learning Approach." 2024.

### Listing Quality Scoring
25. Amazon. "Item Data Quality (IDQ) Score." Seller Central Documentation.
26. Walmart. "Content Quality Score." Marketplace Documentation.
27. Teikametrics. "Understanding Listing Quality Scores." 2024.
28. WisePIM. "Product Validation Scoring Framework." 2024.

### Multi-Agent Systems
29. "LLM-Based Multi-Agent System for Simulating and Analyzing Marketing and Consumer Behavior." IEEE ICEBE, 2025. arXiv:2510.18155.
30. "Agentic LLMs in the Supply Chain." International Journal of Production Research, 2025.
31. "A Survey on LLM-based Multi-Agent Systems." arXiv:2412.17481, 2024.

### E-Commerce SEO
32. "AI's Revolutionary Role in SEO." Springer, 2024.
33. "Implementing LLMs to Enhance Catalog Accuracy in Retail." 2024.
