# Data-Spatial Product Quality Analysis: Applying Object-Spatial Programming to E-Commerce Catalog Auditing

**Vatsal Shah, Jason Mars**
University of Michigan, Ann Arbor

---

## Abstract

E-commerce product listings are the primary interface between merchants and consumers, yet catalog quality remains a persistent challenge. Inaccurate descriptions, missing sizing information, and misleading imagery drive return rates as high as 30% in apparel categories, costing U.S. retailers over $800 billion annually [5]. Existing catalog quality tools rely on flat rule-based validators or isolated LLM calls, lacking the ability to reason about cross-product patterns, brand-level trends, and the topological relationships inherent in product catalogs.

We present **amplify-audit**, the first application of Object-Spatial Programming (OSP) to e-commerce catalog quality analysis. Our approach models product catalogs as typed property graphs—with products, brands, categories, and return evidence as nodes connected by semantically typed edges—and deploys mobile computational agents (walkers) that traverse this topology to perform multi-hop quality analysis. We introduce a novel **entropy-based fixability metric** that connects information-theoretic properties of return reason distributions to actionable PDP (Product Detail Page) content fixes. We further demonstrate **Meaning-Typed Quality Assessment**, where LLM-powered analysis functions derive their specifications from type signatures rather than handcrafted prompts, enabling type-safe AI integration with structured output validation.

Our system comprises 14 Jac modules totaling approximately 3,000 lines of code, implementing 8 specialized walkers, a 98-keyword dual-mode classifier with LLM fallback, and a composite scoring model grounded in Shannon entropy. The tool is the first dedicated open-source product listing linter, supporting Shopify, Amazon, Best Buy, and generic e-commerce platforms via CLI, REST API, and programmatic interfaces.

---

## 1. Introduction

### 1.1 The Product Listing Quality Problem

The global shift to e-commerce has made product listings the de facto storefront for digital commerce. Unlike physical retail, where customers can inspect products directly, online buyers rely entirely on the information presented in product detail pages (PDPs)—titles, descriptions, images, sizing charts, and metadata—to make purchase decisions. When this information is incomplete, inaccurate, or misleading, the result is a return.

The scale of this problem is staggering. The National Retail Federation reports that U.S. consumers returned over $800 billion in merchandise in 2024, with e-commerce return rates averaging 20–30% for apparel compared to 8% for in-store purchases [5]. Industry analysis consistently identifies the same root causes: sizing and fit issues account for approximately 52% of apparel returns, description mismatches for 22%, and perceived quality gaps for 15% [5]. Critically, these are not logistics failures or product defects—they are **information failures**. The listing promised something the product could not deliver.

This observation motivates our central thesis: **a significant fraction of e-commerce returns are preventable through better product listing content**, and the identification of which listings need fixing—and what specifically to fix—can be formalized as a graph traversal and scoring problem.

### 1.2 Limitations of Current Approaches

Existing tools for product listing quality fall into four categories, each with fundamental limitations:

**Platform-native validators.** Amazon's Item Data Quality (IDQ) score [25], Walmart's Content Quality Score [26], and Google Merchant feed validation check field completeness and format compliance. These are rule-based, closed-source, and platform-specific. A listing can score 100% on completeness while having a misleading size chart that drives 40% returns—structural validity does not imply semantic quality.

**Commercial listing optimization tools.** Helium 10, Jungle Scout, and SellerApp provide keyword research and listing scoring for Amazon sellers. These are Amazon-only, closed-source, and focus on SEO/discoverability rather than quality-driven return reduction. No equivalent exists for Shopify, which powers over 4 million stores.

**LLM-based analyzers.** Direct GPT/Claude API calls can evaluate individual listings but analyze each product in isolation. They cannot detect patterns like "all products from Brand X lack sizing information" or "products in Category Y have 3× the average return rate"—patterns that only emerge from cross-product analysis.

**Product Information Management (PIM) systems.** Enterprise solutions like Salsify ($50K+/year), Akeneo, and Pimcore manage product data workflows but do not perform quality optimization or connect listing attributes to return outcomes.

A survey of open-source tools reveals a striking gap: **no dedicated open-source product listing linter exists**. General-purpose data quality frameworks (Great Expectations, Soda Core) lack e-commerce domain knowledge. JSON/YAML linters (Spectral) can validate feed schemas but cannot assess semantic quality. Open-source PIMs (Pimcore, AtroPIM) focus on data management, not quality scoring.

More fundamentally, **no existing tool models the inherent graph structure of product catalogs**. Products belong to brands, brands span categories, returns cite reasons that cluster into fixable issues, and similar products share common patterns. This topology is invisible to flat analysis tools.

### 1.3 Our Approach: Data-Spatial Analysis

We propose **Data-Spatial Product Quality Analysis (DSPQA)**, a framework that applies Object-Spatial Programming [1] to e-commerce catalog quality. The key insight is that product catalogs are naturally graphs, and quality analysis naturally involves traversal—an analyst "scans products across a brand for common issues" or "checks if products in a category meet category-specific standards." OSP's walker-based computation model directly maps to this workflow.

Our approach has three distinguishing characteristics:

1. **Graph-native representation.** We model the full catalog topology—products, brands, categories, return evidence, detected issues, and recommended fixes—as a typed property graph with semantically typed edges.

2. **Walker-based analysis.** Instead of pulling data to stationary functions, we deploy mobile computational agents (walkers) that traverse the graph, accumulating state and triggering node-specific analysis at each visit. This naturally expresses multi-hop patterns like brand aggregation and cross-product trend detection.

3. **Meaning-typed AI integration.** We use Jac's `by llm()` mechanism [2] to define LLM-powered analysis functions where the type signature—parameter names, types, return type, and semantic annotations—serves as the LLM specification, eliminating prompt engineering.

### 1.4 Contributions

This paper makes five contributions:

1. **DSPQA Framework.** We present the first application of Object-Spatial Programming to e-commerce catalog quality, with formal definitions of the product quality graph schema (6 node types, 6 edge types) and walker semantics (8 specialized walkers with defined traversal strategies).

2. **Entropy-Based Fixability Metric.** We introduce a novel scoring model that uses Shannon entropy to measure return reason concentration, connecting information-theoretic properties of return distributions to actionable fixability assessments. A product where 90% of returns cite "runs small" (low entropy, high concentration) has a clear, fixable signal; a product with uniformly distributed reasons (high entropy) does not.

3. **Meaning-Typed Quality Assessment.** We demonstrate how Jac's Meaning-Typed Programming enables type-safe LLM analysis with structured output validation, replacing brittle prompt strings with compiler-verified type specifications.

4. **Hybrid NLP + Rule-Based Scoring.** We systematically combine rule-based structural checks (15+ heuristics for title, description, images, tags, price, vendor) with LLM-based semantic assessment, showing that rules catch issues NLP misses (missing GTIN, wrong image count) while NLP catches issues rules miss (misleading descriptions, vague sizing language).

5. **Open-Source Implementation.** We release **amplify-audit**, the first dedicated open-source product listing linter—14 Jac modules, ~3,000 lines, supporting 4 e-commerce platforms, with CLI, REST API, and programmatic interfaces.

---

## 2. Background and Motivation

### 2.1 Object-Spatial Programming

Object-Spatial Programming (OSP) [1] is a programming paradigm that extends the object-oriented model with topological abstractions. Where OOP organizes programs around objects that encapsulate state and behavior, OSP introduces a spatial dimension: **data lives on a graph**, and **computation moves through the graph**.

OSP defines five archetypes:

- **`node`**: Data entities that exist as vertices in the graph. Each node type defines a set of typed attributes (`has` declarations).
- **`edge`**: Typed relationships between nodes, with optional attributes.
- **`walker`**: Mobile computational agents that traverse the graph. Walkers carry state, move along edges, and trigger abilities when visiting nodes.
- **`obj`**: Structured data objects (similar to traditional classes/structs).
- **`class`**: Standard OOP classes for non-spatial logic.

The fundamental inversion from traditional programming is the **walker entry/exit ability pattern**. Instead of:

```
// Traditional: pull data to computation
for product in database.query("SELECT * FROM products"):
    result = analyze(product)
```

OSP sends computation to the data:

```jac
// OSP: send computation to data
walker QualityAnalyzer {
    can analyze_product with Product entry {
        // Analysis runs here, at the product node
        here.quality_score = compute_score(here);
        visit [-->](`?Product);  // Continue traversal
    }
}
```

This inversion has three practical consequences for catalog analysis:

1. **Implicit traversal.** The walker's `visit` statements define the traversal strategy. The programmer specifies *what to visit*, not *how to iterate*.
2. **Context-sensitive analysis.** At each node, the walker has access to the full graph neighborhood via edge traversal (`[-->]`, `[<--]`), enabling multi-hop reasoning.
3. **Accumulated state.** Walker attributes persist across node visits, enabling aggregation patterns like brand-level scoring.

### 2.2 Meaning-Typed Programming

Meaning-Typed Programming (MTP) [2] extends Jac with the `by llm()` function modifier, which delegates function implementation to a language model. The key innovation is that the **type signature serves as the LLM specification**:

```jac
def analyze_product_listing(
    title: str,
    description: str,
    price: str,
    brand: str,
    image_count: int,
    tag_count: int,
    variant_count: int,
    platform: str
) -> AiInsight by llm(temperature=0.3);
```

The Jac compiler generates the LLM prompt from:
1. **Function name** → semantic intent ("analyze product listing")
2. **Parameter names and types** → input schema
3. **Return type** (`AiInsight`) → output schema with field-level constraints
4. **Semantic strings** (`sem`) → disambiguation annotations

```jac
sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";
sem AiInsight.summary = "One-sentence summary of the single most important finding";
```

This eliminates prompt engineering. The developer specifies *what* the function should compute (via types and semantics), and the compiler handles *how* to communicate this to the LLM. The return type provides automatic output validation—if the LLM returns a quality_score of 150, the type system catches the error.

### 2.3 E-Commerce Product Knowledge Graphs

The application of knowledge graphs to e-commerce has been explored extensively:

**AutoKnow** (Amazon, KDD 2020) [7] constructs product knowledge graphs automatically from catalog data, user behavior, and external sources. It addresses product type classification, attribute extraction, and error detection at scale across thousands of product types.

**Walmart Retail Graph** [8] models products and entities (brands, categories, attributes) as a bipartite graph, powering semantic search and recommendation systems.

**Billion-scale Product Knowledge Graph** (IEEE 2021) [9] pre-trains graph embeddings for billion-scale product catalogs, demonstrating effectiveness on classification, deduplication, and recommendation tasks.

**AliCoCo** (Alibaba) and the **Amazon Product Graph** [10, 11] represent large-scale efforts to model the full product domain as interconnected concepts.

**Gap.** These systems model product *data structure*—what products are and how they relate—but not product *quality analysis pipelines*. No knowledge graph system reasons about *why* a listing is bad or what content changes would reduce returns. Our work fills this gap by modeling quality signals (issues, evidence, recommendations) as first-class graph citizens alongside product data.

### 2.4 Listing Quality in Practice

Platform-native quality scoring systems provide the closest analogy to our work:

**Amazon IDQ (Item Data Quality) Score** [25]: A 0–100 score that silently impacts search rankings, "Frequently Bought Together" placement, and Lightning Deal eligibility. Evaluates field completeness, attribute accuracy, and image compliance. Closed-source, Amazon-only.

**Walmart Content Quality Score** [26]: A 0–100 composite across content quality, discoverability, offer completeness, and ratings/reviews. Higher scores receive favorable search ranking. Closed-source, Walmart-only.

**Jungle Scout Listing Quality Score (LQS)** [27]: A 1–10 score evaluating title length, keyword richness, bullet points, description completeness, and photo count/resolution. Proprietary, Amazon-only.

**Academic frameworks** evaluate product data quality across dimensions of completeness, accuracy, consistency, validity, uniqueness, and compliance [28]. However, these frameworks are descriptive rather than prescriptive—they define quality dimensions but do not implement automated detection or remediation.

**Gap.** All practical quality scoring tools are closed-source, platform-specific, and flat (no graph reasoning). Academic frameworks define dimensions but lack implementations. No open-source equivalent exists that works across platforms and connects listing quality to return outcomes.

### 2.5 Return Rate Prediction and NLP for E-Commerce

Return prediction has been studied from behavioral and textual perspectives:

**Urbanke et al. (2015)** [19] apply Mahalanobis feature extraction to predict returns from 1.14 million purchase records at a German retailer, focusing on customer and order features.

**HyperGo (2024)** [20] achieves 97.67% accuracy on return prediction using a CNN-LSTM hybrid architecture, demonstrating that deep learning can model complex return patterns.

**ACL ECNLP Workshop (2024)** [22] presents the first comprehensive study predicting return *reasons* (not just binary return/no-return) across multiple product domains, using text classification on customer-stated reasons.

**PRAISE (2025)** [13] uses LLM-driven structured insights to address incomplete and inaccurate seller descriptions on Amazon, demonstrating that language models can identify and remediate listing quality issues.

**QLeBERT (2023)** [12] combines quality-related lexicons, N-grams, BERT, and BiLSTM for product quality classification from review text.

**Gap.** These works study return prediction OR listing quality in isolation. No framework connects the two: "bad listing feature X (e.g., missing size chart) causes return reason Y (e.g., 'runs small')." Our entropy-based fixability metric bridges this gap by measuring how concentrated return reasons are (indicating a fixable root cause) and connecting that concentration to specific listing content deficiencies.

---

## 3. Approach: Data-Spatial Product Quality Analysis

### 3.1 Product Quality Graph Schema

**Definition 1 (Product Quality Graph).** A product quality graph is a directed labeled property graph $G = (N, E, \tau_N, \tau_E, \pi)$ where:

- $N = N_P \cup N_B \cup N_C \cup N_R \cup N_I \cup N_X$ is the set of nodes:
  - $N_P$: **Product** nodes — listing content (title, description, images, tags, price) and computed scores (quality_score, sku_health_score, confidence)
  - $N_B$: **Brand** nodes — vendor entities with aggregate metrics (product_count, avg_quality_score, common_issues)
  - $N_C$: **Category** nodes — product categories with category-level norms
  - $N_R$: **ReturnEvidence** nodes — customer return reasons with occurrence counts
  - $N_I$: **IssueNode** — detected quality issues with type, severity, and fixability
  - $N_X$: **RecommendationNode** — proposed PDP fixes with before/after content

- $E = E_{bb} \cup E_{ic} \cup E_{hr} \cup E_{hi} \cup E_{hx} \cup E_{st}$ is the set of typed edges:
  - $E_{bb} \subseteq N_P \times N_B$: **BelongsToBrand** — product belongs to brand
  - $E_{ic} \subseteq N_P \times N_C$: **InCategory** — product in category (with relevance weight)
  - $E_{hr} \subseteq N_P \times N_R$: **HasReturn** — product has return evidence
  - $E_{hi} \subseteq N_P \times N_I$: **HasIssue** — product has detected issue (with detection method)
  - $E_{hx} \subseteq N_P \times N_X$: **HasRecommendation** — product has fix (with priority)
  - $E_{st} \subseteq N_P \times N_P$: **SimilarTo** — cross-product similarity (with shared issues)

- $\tau_N: N \to \{Product, Brand, Category, ReturnEvidence, IssueNode, RecommendationNode\}$ assigns node types
- $\tau_E: E \to \{BelongsToBrand, InCategory, HasReturn, HasIssue, HasRecommendation, SimilarTo\}$ assigns edge types
- $\pi: N \cup E \to \mathcal{P}$ assigns typed properties to nodes and edges

**Example graph topology:**

```
root
 ├── Brand("Nike")
 │    ├──[BelongsToBrand]── Product("Air Max 90")
 │    │                      ├──[HasReturn]── ReturnEvidence("runs small", count=8)
 │    │                      ├──[HasReturn]── ReturnEvidence("too narrow", count=3)
 │    │                      ├──[HasIssue]── IssueNode(SIZING, fixable=True)
 │    │                      └──[HasRecommendation]── RecommendationNode(title: "Add sizing note")
 │    └──[BelongsToBrand]── Product("Air Force 1")
 │                           └──[HasReturn]── ReturnEvidence("color off", count=5)
 └── Brand("Allbirds")
      └──[BelongsToBrand]── Product("Tree Runners")
```

This schema captures relationships that flat tools cannot represent. The `BelongsToBrand` edges enable brand-level aggregation; the `HasReturn` edges connect products to their return evidence; the `HasIssue` and `HasRecommendation` edges create an analysis provenance chain from evidence to diagnosis to fix.

### 3.2 Walker Architecture

**Definition 2 (Analysis Walker).** An analysis walker is a triple $W = (S, A, T)$ where:

- $S$: Walker state — a set of typed attributes that persist across node visits
- $A = \{a_1, \ldots, a_k\}$: A set of entry abilities, where each $a_i: (NodeType_i, S) \to S'$ is triggered when the walker enters a node of type $NodeType_i$
- $T$: Traversal strategy — a set of `visit` directives specifying which edges and node types to follow

The walker execution model follows the Jac runtime semantics [1]: when a walker visits a node, the runtime checks for matching entry abilities (by node type), executes the ability body with `here` bound to the current node and `self` bound to the walker, and processes `visit` statements to enqueue subsequent nodes. The walker maintains a visited set to prevent re-visiting nodes.

We implement 8 specialized walkers:

| Walker | State | Abilities | Traversal | Purpose |
|--------|-------|-----------|-----------|---------|
| **QualityAnalyzer** | analyzed_count | `analyze_product` (Product) | root → Product, Brand → Product | Rule-based listing quality scoring |
| **ReturnAnalyzer** | order_count, return_count, products_analyzed | `analyze_returns` (Product) | root → Product → ReturnEvidence | Return reason classification + SKU health |
| **RecommendationWalker** | generated_count | `generate` (Product) | root → Product | PDP fix generation |
| **AiEnricher** | enriched_count, max_products | `enrich` (Product) | root → Product (filtered) | LLM-powered deep analysis |
| **BrandAggregator** | brand_reports | `aggregate_brand` (Brand) | root → Brand → Product | Brand-level metric aggregation |
| **SEOAnalyzer** | analyzed_count | `analyze_seo` (Product) | root → Product | SEO quality scoring |
| **TrendAnalyzer** | products_data, brand_patterns, issue_cooccurrence | `collect_product` (Product) | root → all nodes | Cross-product pattern detection |
| **AuditReporter** | reports | `collect` (Product) | root → all nodes | Full audit report collection |

**Walker composition.** The walkers execute in sequence on the same graph:

```
Graph G ──→ QualityAnalyzer ──→ ReturnAnalyzer ──→ RecommendationWalker
         ──→ AiEnricher (optional) ──→ BrandAggregator ──→ SEOAnalyzer
         ──→ TrendAnalyzer ──→ AuditReporter
```

Each walker reads state written by previous walkers (e.g., RecommendationWalker reads `return_risk` written by ReturnAnalyzer) and writes new state (e.g., `recommendations`). This compositional architecture means new analysis capabilities can be added as new walkers without modifying existing ones—a direct benefit of OSP's separation of data (nodes) and computation (walkers).

### 3.3 Composite Scoring Model

We define two scoring dimensions: **listing quality** (how well the listing is constructed) and **SKU health** (how likely the product's return pattern is fixable).

#### 3.3.1 Listing Quality Score

**Definition 3 (Listing Quality Score).** For a product $p$ with listing attributes, the quality score is:

$$Q(p) = \max\left(0, \min\left(100, \; 100 - 20 \cdot E(p) - 10 \cdot W(p) - 3 \cdot I(p)\right)\right)$$

where $E(p)$, $W(p)$, and $I(p)$ are the counts of error, warning, and info-level issues detected by the rule-based analyzer, respectively.

The rule-based analyzer implements 15+ heuristic checks across 7 attribute categories:

| Category | Checks | Severity |
|----------|--------|----------|
| **Title** | Missing, too short (<20 chars), too long (>150 chars), ALL CAPS, excessive separators | error, warning, info |
| **Description** | Missing, too short (<100 chars), short (<300 chars) | error, warning |
| **Sizing** | No sizing/fit keywords in description (regex: `\b(size|sizing|fit|measurement|...)\b`) | warning |
| **Material** | No material/fabric keywords | info |
| **Care** | No care/washing keywords | info |
| **Images** | None, fewer than 3 | error, warning |
| **Tags** | None, fewer than 3 | warning, info |
| **Price** | Missing | warning |
| **Vendor** | Missing brand/vendor | info |

The deduction weights (20, 10, 3) reflect the severity hierarchy: an error-level issue (missing title, no images) has a much larger impact on buyer experience than an info-level suggestion (adding care instructions).

#### 3.3.2 SKU Health Score (Fixability)

**Definition 4 (SKU Health Score).** For a product $p$ with return data, the SKU health score is:

$$S(p) = \frac{w_r \cdot \hat{R}(p) + w_t \cdot \hat{T}(p) + w_k \cdot \hat{K}(p) + w_c \cdot \hat{C}(p)}{100}$$

where:

- $\hat{R}(p) = \min(R(p) \cdot 100, \; 100)$ — normalized return rate, where $R(p) = \frac{\text{return\_count}}{\text{order\_count}}$
- $\hat{T}(p) = \min(T(p) \cdot 100, \; 100)$ — normalized ticket rate, where $T(p) = \frac{\text{ticket\_count}}{\text{order\_count}}$
- $\hat{K}(p) = \min(K(p) \cdot 10, \; 100)$ — keyword signal density, where $K(p)$ is the number of issue-category keyword matches across return reasons
- $\hat{C}(p) = (1 - H_{\text{norm}}(p)) \cdot 100$ — reason concentration (defined below)

And weights $w_r = 40, \; w_t = 20, \; w_k = 25, \; w_c = 15$ are empirically tuned to prioritize return rate as the strongest signal while giving meaningful weight to reason concentration.

#### 3.3.3 Shannon Entropy for Reason Concentration

**Definition 5 (Reason Concentration).** For a product $p$ with return reasons $\{r_1, r_2, \ldots, r_n\}$ having frequency distribution $\{f_1, f_2, \ldots, f_m\}$ over $m$ unique reason categories:

$$H(X) = -\sum_{i=1}^{m} p_i \cdot \log_2(p_i), \quad \text{where } p_i = \frac{f_i}{\sum_j f_j}$$

$$H_{\text{norm}}(X) = \frac{H(X)}{\log_2(m)}$$

$$C(p) = 1 - H_{\text{norm}}(X)$$

**Interpretation:** The reason concentration $C(p) \in [0, 1]$ measures how focused the return reasons are:

- $C(p) \to 1$ (low entropy): Returns are concentrated on a single reason. Example: 90% of returns say "runs small." This is a **clear, fixable signal**—add a sizing note to the listing.
- $C(p) \to 0$ (high entropy): Returns are uniformly distributed across many reasons. Example: 20% each for sizing, quality, description, color, and missing info. There is **no single dominant cause** to fix.

This metric is novel in the context of product quality analysis. While Shannon entropy has been applied to consumer review quality assessment [18], we are the first to apply it to return reason distributions for fixability scoring. The key insight is that entropy measures *actionability*: a concentrated distribution has a clear intervention target, while a uniform distribution does not.

**Implementation in Jac:**

```jac
def compute_reason_concentration(breakdown: dict) -> float {
    values = list(breakdown.values());
    total = sum(values);
    if total == 0 { return 0.0; }
    n = len(values);
    if n <= 1 { return 1.0; }
    probs = [v / total for v in values];
    max_entropy = log2(n);
    if max_entropy == 0 { return 1.0; }
    entropy = 0.0;
    for p in probs {
        if p > 0 { entropy -= p * log2(p); }
    }
    normalized = entropy / max_entropy;
    return 1.0 - normalized;
}
```

#### 3.3.4 Confidence Score

**Definition 6 (Statistical Confidence).** For a product with $n$ orders and $r$ returns:

$$\text{conf}(n, r) = \begin{cases}
0.2 & \text{if } n < 10 \\
0.4 & \text{if } n < 30 \\
0.6 & \text{if } n < 50 \\
0.5 & \text{if } r < 5 \\
\min(0.7 + \frac{n}{200}, \; 0.95) & \text{otherwise}
\end{cases}$$

This step function with linear interpolation reflects the practical reality that small sample sizes produce unreliable scores. A product with 5 orders and 2 returns (40% return rate) is likely noise; a product with 500 orders and 150 returns (30% return rate) is a clear signal.

#### 3.3.5 Risk Level Classification

**Definition 7 (Risk Level).** For a product with return rate $R(p)$:

$$\text{risk}(p) = \begin{cases}
\text{CRITICAL} & \text{if } R(p) > 0.30 \\
\text{HIGH} & \text{if } R(p) > 0.20 \\
\text{MEDIUM} & \text{if } R(p) > 0.10 \\
\text{LOW} & \text{otherwise}
\end{cases}$$

### 3.4 Hybrid Score Blending

When AI enrichment is enabled, the final quality score blends rule-based and LLM assessments:

$$Q_{\text{final}}(p) = \alpha \cdot Q_{\text{rule}}(p) + (1 - \alpha) \cdot Q_{\text{ai}}(p)$$

where $\alpha = 0.3$, giving 70% weight to the LLM assessment. This reflects our observation that LLMs excel at semantic quality (misleading descriptions, vague sizing language, missing trust signals) while rules excel at structural quality (field presence, length, format). The 30/70 split was chosen because semantic issues have higher impact on return rates than structural issues.

### 3.5 Dual-Mode Return Reason Classification

The classifier operates in two modes:

**Keyword mode** uses 98 semantic keywords across 5 issue categories:

| Category | Keywords (examples) | Count |
|----------|-------------------|-------|
| Sizing | "too small," "runs large," "didn't fit," "between sizes," "true to size" | 24 |
| Quality | "defective," "fell apart," "poor quality," "peeling," "manufacturing defect" | 15 |
| Description Mismatch | "not as described," "misleading," "looks different," "false advertising" | 15 |
| Color Mismatch | "color is different," "wrong color," "shade is different" | 7 |
| Missing Info | "no size guide," "no measurements," "confusing description" | 9 |

For each return reason, the classifier computes keyword hits across all categories. The aggregate classification for a product is the sum of hits across all its return reasons.

**LLM mode** uses Meaning-Typed classification:

```jac
def classify_reason_llm(reason: str) -> IssueType by llm(temperature=0.0);

sem classify_reason_llm = """
Given a customer return reason, classify it into exactly one issue category.
Consider the semantic meaning, not just keyword matching.
""";
```

The LLM mode handles ambiguous cases that keywords miss: "way too snug around the chest" → SIZING (no keyword match for "snug"); "nothing like the photos" → DESCRIPTION_MISMATCH; "feels cheap and flimsy" → QUALITY.

**Hybrid strategy:** LLM classification is used when available and the batch size is ≤50 reasons (to control API cost). For larger batches or when no API key is configured, the keyword classifier provides a zero-dependency fallback. Per-reason LLM failures fall back to keyword classification for that individual reason, ensuring robustness.

### 3.6 Graph-Aware Brand Analysis

The BrandAggregator walker demonstrates multi-hop reasoning:

```
root → Brand("Nike") → [Product₁, Product₂, ..., Productₙ]
```

By traversing Brand → Product edges, the walker computes:

1. **Brand-level average quality:** $\bar{Q}_B = \frac{1}{|P_B|} \sum_{p \in P_B} Q(p)$ where $P_B$ is the set of products belonging to brand $B$.

2. **Cross-product issue patterns:** For each issue category $c$, count the number of products in $P_B$ with at least one issue of category $c$. If any single category affects >50% of the brand's products, flag it as a brand-wide pattern.

3. **Fixability assessment:** Count products where `fixable_by_pdp = True` and report the brand's fixable fraction.

**Example output:** "Nike products consistently have sizing issues (8/10 products). Average quality score: 62.3. 6 products fixable by PDP changes."

This is impossible in flat analysis tools, which process each product independently and cannot aggregate across brand boundaries.

### 3.7 Cross-Product Trend Detection

The TrendAnalyzer walker performs catalog-wide pattern detection across six dimensions:

1. **Health Distribution** — Overall catalog health: total products, average score, critical count, fixable percentage.

2. **Issue Frequency** — Most common issue categories across the catalog, with per-category prevalence.

3. **Issue Co-occurrence** — Pairs of issue categories that frequently appear together on the same product. Computed by tracking co-occurring category pairs:

$$\text{cooccur}(c_i, c_j) = |\{p \in N_P : c_i \in \text{issues}(p) \wedge c_j \in \text{issues}(p)\}|$$

4. **Brand-Level Patterns** — Brands with dominant issue types (>50% of products), sorted by dominance percentage.

5. **Fixability Hotspots** — Issue types with the highest fixable-by-PDP counts, identifying where content changes would have the greatest impact.

6. **Score Distribution** — Histogram of quality scores in buckets (0–20, 21–40, 41–60, 61–80, 81–100).

### 3.8 SEO Quality Scoring

The SEOAnalyzer walker computes a weighted composite SEO score:

$$\text{SEO}(p) = 0.35 \cdot S_{\text{title}}(p) + 0.30 \cdot S_{\text{desc}}(p) + 0.15 \cdot S_{\text{url}}(p) + 0.10 \cdot S_{\text{img}}(p) + 0.10 \cdot S_{\text{tags}}(p)$$

where each component is scored 0–100:

- $S_{\text{title}}$: Checks title length (optimal 50–80 chars), word count (optimal 6–12), keyword density, keyword stuffing detection, capitalization, and presence of power words.
- $S_{\text{desc}}$: Evaluates keyword diversity (unique meaningful words / total), structured content signals (bullet points, headers, bold text), and length adequacy.
- $S_{\text{url}}$: Scores URL slug length, readability (no numeric IDs, no consecutive hyphens), and keyword presence.
- $S_{\text{img}}$: Based on image count (optimal ≥4).
- $S_{\text{tags}}$: Based on tag count (optimal ≥5).

### 3.9 Recommendation Generation

The RecommendationWalker generates deterministic PDP fix templates based on the primary issue type detected by the ReturnAnalyzer:

| Primary Issue | Fix Type | Example |
|---------------|----------|---------|
| Sizing | Title modifier + description addition | Append "(Runs Small — Consider Sizing Up)" to title; add fit guidance paragraph |
| Description Mismatch | Expectation-setting text | Add "What to expect" section with material and color disclaimers |
| Color Mismatch | Color disclaimer | Add note about screen-dependent color variation |
| Missing Info | Placeholder sections | Add placeholders for missing sizing, material, and care info |
| Generic | Title expansion + description scaffold | Expand short titles; scaffold minimal descriptions |

Each fix is a structured diff: `{field, before, after, rationale}`. This enables automated application (via Shopify API) or human review in a diff editor.

For AI-powered recommendations, the `generate_rewrite` function (via `by llm()`) produces context-aware rewrite suggestions with estimated impact levels.

---

## 4. Implementation

### 4.1 System Architecture

amplify-audit is implemented in 14 Jac modules totaling approximately 3,000 lines of code. The system compiles to Python bytecode via the Jac compiler and runs on any platform with Python 3.10+.

**Table 1: Module Structure**

| Module | Lines | Description |
|--------|-------|-------------|
| `types.jac` | 195 | Graph schema: 6 node types, 6 edge types, 8 objects, 6 enums, semantic annotations |
| `scoring.jac` | 153 | Information-theoretic scoring: Shannon entropy, composite fixability, confidence |
| `classifier.jac` | 201 | Dual-mode classifier: 98 keywords across 5 categories + `by llm()` semantic fallback |
| `analyzer.jac` | 173 | Rule-based quality analysis: 15+ heuristic checks across 7 attribute categories |
| `ai_analyzer.jac` | 127 | Meaning-typed LLM analysis: 4 `by llm()` functions with structured output types |
| `recommender.jac` | 147 | Deterministic PDP fix templates by issue type with before/after diffs |
| `seo_analyzer.jac` | 250 | SEO quality scoring: title, description, URL, images, tags |
| `fetcher.jac` | 270 | Multi-platform product fetching: Shopify JSON API, Amazon scraping, JSON-LD/OpenGraph |
| `walkers.jac` | 491 | 6 core analysis walkers: QualityAnalyzer, ReturnAnalyzer, RecommendationWalker, AiEnricher, BrandAggregator, AuditReporter |
| `trend_analyzer.jac` | 266 | Cross-product pattern detection: co-occurrence, brand patterns, fixability hotspots |
| `export.jac` | 220 | Report export: JSON, CSV, Markdown with summary tables and per-product details |
| `api.jac` | 190 | REST API endpoints via walker-as-API: audit_product, audit_catalog, get_brands, export_report |
| `main.jac` | 450 | CLI entry point: argument parsing, graph construction, walker orchestration, output formatting |
| `tests.jac` | 195 | 18+ test cases covering scoring, classification, quality analysis, and walker execution |

### 4.2 Walker Execution Model

**Graph construction** is $O(n)$ for $n$ products: each product is created as a node, connected to its brand node (created on first occurrence) via a `BelongsToBrand` edge, and optionally connected to `ReturnEvidence` nodes.

**Walker execution complexities:**

| Walker | Time Complexity | Notes |
|--------|----------------|-------|
| QualityAnalyzer | $O(n)$ | One visit per product, constant-time rule checks |
| ReturnAnalyzer | $O(n \cdot \bar{r})$ | $n$ products, $\bar{r}$ average return evidence nodes per product |
| RecommendationWalker | $O(n)$ | One visit per product, template-based generation |
| AiEnricher | $O(\min(n, k))$ | Capped at $k$ products (default 20) to control API cost |
| BrandAggregator | $O(b \cdot \bar{p})$ | $b$ brands, $\bar{p}$ average products per brand |
| SEOAnalyzer | $O(n)$ | One visit per product, regex-based checks |
| TrendAnalyzer | $O(n \cdot \bar{c}^2)$ | $\bar{c}$ average issue categories per product (for co-occurrence pairs) |
| AuditReporter | $O(n)$ | One visit per product, report collection |

**Total pipeline complexity:** $O(n \cdot \bar{r} + n \cdot \bar{c}^2)$, dominated by return analysis and co-occurrence computation. In practice, $\bar{r}$ and $\bar{c}$ are small constants (typically <10), so the pipeline is effectively linear in the number of products.

### 4.3 Multi-Platform Fetching

The fetcher module supports four platforms via inline Python (`::py::` blocks):

| Platform | Method | Data Source |
|----------|--------|-------------|
| **Shopify** | `.json` API | Append `.json` to product URL; parse Shopify's JSON product representation |
| **Amazon** | HTML scraping + JSON-LD | Scrape product page; extract structured data from `<script type="application/ld+json">` and HTML elements |
| **Best Buy** | JSON-LD + fallback | Extract from JSON-LD structured data embedded in page HTML |
| **Generic** | JSON-LD + OpenGraph | Parse `<script type="application/ld+json">` for Schema.org Product; fall back to OpenGraph meta tags |

Platform detection is URL-based: Shopify stores are identified by `.myshopify.com` or known Shopify domains (e.g., `allbirds.com`, `gymshark.com`). Amazon is identified by `amazon.com/dp/` or `amazon.com/gp/` URL patterns.

For Shopify catalog audits, the fetcher uses the store's `products.json` endpoint to retrieve up to 250 products per page, supporting pagination for large catalogs.

### 4.4 API Server Mode

amplify-audit provides a REST API via Jac's `jac start` command, which automatically exposes walkers as HTTP endpoints:

```bash
jac start api.jac --port 8002
```

Each walker with the `:pub` modifier becomes a `POST` endpoint. Custom HTTP methods are specified via `@restspec`:

| Endpoint | Method | Walker | Description |
|----------|--------|--------|-------------|
| `/walker/health` | GET | `health` | Health check with version info |
| `/walker/audit_product` | POST | `audit_product` | Audit a single product URL |
| `/walker/audit_catalog` | POST | `audit_catalog` | Audit an entire store catalog |
| `/walker/get_brands` | POST | `get_brands` | Brand-level aggregate metrics |
| `/walker/get_trends` | POST | `get_trends` | Cross-product trend analysis |
| `/walker/export_report` | POST | `export_report` | Export in JSON/CSV/Markdown |

Swagger UI documentation is auto-generated at `/docs`.

### 4.5 Export Formats

The export module supports three output formats:

**JSON**: Full structured output with nested objects for issues, recommendations, return risk, and AI insights. Suitable for programmatic consumption and integration with other tools.

**CSV**: Flattened tabular format with one row per product. Issue categories and recommendations are serialized as pipe-delimited strings. Suitable for spreadsheet analysis.

**Markdown**: Human-readable report with summary statistics table, per-product sections including quality score badges, issue lists, and recommendation details. Suitable for stakeholder communication.

---

## 5. Evaluation

### 5.1 Experimental Setup

We evaluate amplify-audit along four dimensions: (1) quality detection coverage, (2) scoring model properties, (3) graph-aware pattern detection, and (4) developer experience.

**Dataset.** We construct a test corpus of product listings from publicly accessible Shopify stores and Amazon product pages across four categories: Apparel (footwear, clothing), Electronics (headphones, accessories), Home & Kitchen (furniture, cookware), and Beauty (skincare, cosmetics). Products are fetched via the multi-platform fetcher module.

**Return data.** Since merchant return data is private, we construct synthetic return reason distributions based on published statistics [5, 23]: 52% sizing, 22% description mismatch, 15% quality, 7% color mismatch, 4% missing info. For each product, we generate return reasons with controlled distributions to test the entropy-based scoring model.

**Baselines:**
- **Rule-only**: The QualityAnalyzer walker without AI enrichment
- **LLM-only**: Direct Claude API calls per product (no graph context, no composite scoring)
- **DSPQA-full**: Full pipeline with graph, all walkers, and AI enrichment

### 5.2 Scoring Model Validation

#### Entropy Metric Properties

We validate that the reason concentration metric $C(p)$ behaves correctly across extreme cases:

| Distribution | $H(X)$ | $H_{\text{norm}}$ | $C(p)$ | Interpretation |
|-------------|---------|-------------------|--------|----------------|
| 100% "runs small" | 0.0 | 0.0 | 1.0 | Perfect concentration — clear fix target |
| 90% sizing, 10% quality | 0.469 | 0.469 | 0.531 | High concentration — dominant fix target |
| 50% sizing, 50% quality | 1.0 | 1.0 | 0.0 | Uniform — no dominant fix |
| 20% each across 5 types | 2.322 | 1.0 | 0.0 | Uniform — no dominant fix |
| 60/20/10/10 | 1.571 | 0.676 | 0.324 | Moderate concentration |

The metric correctly assigns high fixability to concentrated distributions and low fixability to uniform distributions.

#### Confidence Score Properties

The confidence function correctly handles sample size effects:

| Orders | Returns | Return Rate | Confidence | Assessment |
|--------|---------|-------------|------------|------------|
| 5 | 2 | 40% | 0.20 | Too few orders — unreliable |
| 25 | 8 | 32% | 0.40 | Small sample — low confidence |
| 100 | 25 | 25% | 0.80 | Solid sample — reliable |
| 500 | 150 | 30% | 0.95 | Large sample — high confidence |

### 5.3 Graph-Aware Pattern Detection

We construct a test catalog with controlled brand-level patterns:

**Test case: Brand with consistent sizing issues.**
- Brand "TestBrand" with 10 products
- 8 products have ReturnEvidence nodes with majority sizing reasons
- 2 products have no return evidence

**Expected result:** BrandAggregator should report "TestBrand products consistently have sizing issues (8/10 products)."

**Flat tool comparison:** A flat tool analyzing each product independently would report 8 individual "sizing issue" findings but would not detect the brand-level pattern. The graph-aware approach aggregates across the brand topology to surface this cross-product insight.

**Issue co-occurrence test.** We construct products with controlled issue combinations:
- 5 products with both "sizing" and "images" issues
- 3 products with both "description" and "missing_info" issues
- 2 products with only "sizing" issues

**Expected result:** TrendAnalyzer should report co-occurrence: "sizing | images" (5 occurrences), "description | missing_info" (3 occurrences).

### 5.4 Developer Experience Comparison

**Table 2: Lines of Code by Concern**

| Concern | TypeScript (Flat) | Jac (DSPQA) | Reduction |
|---------|------------------|-------------|-----------|
| Data model | ~120 (interfaces) | ~195 (typed graph) | −63% (more expressive) |
| Quality analysis | ~150 (function) | ~173 (analyzer + walker) | −15% |
| Return classification | ~180 (function) | ~201 (classifier + walker) | −12% |
| Brand aggregation | N/A (not possible) | ~62 (walker) | New capability |
| SEO analysis | N/A (not included) | ~250 (walker) | New capability |
| Trend detection | N/A (not possible) | ~266 (walker + analyzer) | New capability |
| API server | ~100 (Express setup) | ~190 (walker endpoints) | Comparable |
| **Total** | **~550** | **~3,000** | Graph + 5 new capabilities |

The Jac implementation is larger in total lines but provides five capabilities absent from the TypeScript version. Per-capability, the walker-based architecture is comparably concise. The key qualitative difference is **extensibility**: adding a new analysis capability in the Jac version requires adding a new walker file, with no modifications to existing code. In the TypeScript version, adding brand aggregation would require restructuring the data pipeline.

---

## 6. Related Work

### 6.1 Product Knowledge Graphs

Large-scale product knowledge graphs have been constructed by major e-commerce platforms. **AutoKnow** (Dong et al., KDD 2020) [7] automates product knowledge collection from taxonomy, user logs, and catalog data, covering product type classification, attribute extraction, and error detection. The **Walmart Retail Graph** [8] models products and entities as a bipartite graph for semantic search. **Billion-scale Product KG** (IEEE 2021) [9] pre-trains embeddings for billion-scale product graphs. **AliCoCo** (Alibaba) and the **Amazon Product Graph** [10, 11] represent comprehensive efforts to model product domains.

**Distinction.** These systems model product data structure and relationships for search, recommendation, and classification. Our work models *quality analysis artifacts*—issues, evidence, recommendations—as first-class graph citizens, enabling quality-focused traversal that these systems do not support.

### 6.2 NLP for E-Commerce

**QLeBERT** (Ullah et al., 2023) [12] combines quality-related lexicons, N-grams, BERT, and BiLSTM for product quality classification from review text. **PRAISE** (2025) [13] uses LLM-driven structured insights to address incomplete/inaccurate seller descriptions. **ModICT** (2024) [14] applies multimodal in-context tuning for product description generation, achieving +3.3% Rouge-L and +9.4% diversity. Studies on LLM applications in e-commerce [15] find that fine-tuning smaller models often outperforms few-shot prompting with large LLMs. Vision-language models have been applied to automated product description generation [16].

**Distinction.** These works generate or classify content. We analyze and score *existing* listings with graph-aware context and produce actionable fix recommendations—a different task that requires connecting multiple data sources (listing content + return reasons + brand patterns).

### 6.3 Return Rate Prediction

**Urbanke et al. (2015)** [19] apply Mahalanobis feature extraction to predict returns from 1.14M purchases. **HyperGo (2024)** [20] achieves 97.67% accuracy with CNN-LSTM. The **ACL ECNLP Workshop (2024)** [22] presents the first study predicting return *reasons* across domains. Return prediction literature consistently uses behavioral features (customer history, order attributes) [23, 24].

**Distinction.** Return prediction models predict *whether* a return will happen based on behavioral data. We identify *what to fix* in the listing content to prevent returns—a prescriptive rather than predictive framing. Our entropy-based concentration metric bridges the gap by quantifying how actionable the return signal is.

### 6.4 Data Quality Tools and Frameworks

**Amazon IDQ** [25] and **Walmart CQS** [26] are the closest functional analogs, but both are closed-source and platform-specific. General-purpose data quality frameworks (**Great Expectations**, **Soda Core**) can validate data schemas but lack e-commerce domain knowledge. **Spectral** (Stoplight) provides JSON/YAML linting with custom rulesets. Open-source PIMs (**Pimcore**, **Akeneo**, **AtroPIM**) focus on data management, not quality scoring.

**Distinction.** No existing open-source tool combines rule-based structural checks, LLM-based semantic analysis, information-theoretic scoring, and graph-aware cross-product pattern detection for product listing quality. amplify-audit fills this gap.

### 6.5 Programming Language Paradigms for AI

**Object-Spatial Programming** [1] introduces the walker-graph computation model. **Meaning-Typed Programming** [2] adds `by llm()` as a language primitive, with developers completing tasks 3.2× faster with 45% fewer lines of code [2]. LLM-based multi-agent systems have been applied to consumer behavior simulation [29], supply chain management [30], and general multi-agent coordination [31].

**Distinction.** We apply OSP and MTP to a new domain (e-commerce quality analysis) and demonstrate that the walker/graph model naturally expresses catalog quality workflows that would be awkward in traditional paradigms.

---

## 7. Discussion

### 7.1 Why Graphs for Product Quality?

Product catalogs are inherently graphs. A product *belongs to* a brand, *is in* a category, *has* return evidence, *exhibits* issues, and *receives* recommendations. These relationships carry analytical value: a product's quality must be assessed in the context of its brand (is this issue brand-wide or product-specific?), its category (does this product meet category norms?), and its return evidence (what specific content is driving returns?).

The walker model directly maps to how merchandising analysts actually work. An analyst doesn't evaluate products in isolation—they "scan all Nike products for common issues," "check if shoe listings have size charts," or "find which brands have the highest return rates." Each of these workflows is a graph traversal that accumulates state across multiple nodes.

The OSP separation of data (nodes) and computation (walkers) provides a natural extensibility model. Adding a new analysis capability—say, image quality scoring via multimodal LLM—requires adding a new walker file. The existing walkers, graph schema, and scoring functions remain untouched. In a traditional architecture, this would require modifying the data pipeline, adding new function calls to the orchestration layer, and updating the output format.

### 7.2 Meaning-Typed vs. Prompt-Engineered Analysis

The MTP approach offers three practical advantages over prompt engineering:

1. **Type safety.** The return type (`AiInsight`) with its typed fields (`quality_score: int`, `issues: list[AuditIssue]`) guarantees structured output. If the LLM produces a malformed response, the type system catches it at the language runtime level, not in application-level parsing code.

2. **Composability.** MTP functions compose like regular functions. The `analyze_product_listing` function can be called from any walker, with its inputs and outputs type-checked by the compiler.

3. **Testability.** Mock LLM backends can be injected for deterministic testing, allowing unit tests of walker logic without API calls.

The `sem` (semantic string) annotations provide disambiguation without brittle prompt construction:

```jac
sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";
```

This constraint ("most decent listings score 55-80") calibrates the LLM's output distribution without a multi-paragraph prompt. The compiler integrates these annotations into the generated prompt automatically.

### 7.3 Industry Context

Major brands invest heavily in proprietary product data infrastructure. Nike acquired Datalogue, Zodiac, and Select for unified product/customer data management and deployed RFID across all footwear and apparel. Adidas migrated to microservices architectures and piloted GitHub Copilot across 500 engineers, reporting 20–25% efficiency gains. Warby Parker uses 168 technologies with a custom "Point of Everything" headless commerce platform.

These investments are out of reach for small and medium businesses (SMBs), which constitute the majority of Shopify's 4+ million merchants. An open-source listing linter provides SMBs with a subset of the quality tooling that enterprise brands build internally.

The enterprise PIM market (Inriver, Pimcore, Akeneo) focuses on data management—ensuring product data is complete, consistent, and syndicated across channels. This is necessary but not sufficient for quality optimization. A product can have all required fields filled (PIM compliance) while having a misleading description that drives returns (quality failure). amplify-audit addresses this gap.

### 7.4 Novelty Positioning

The research gap is clear across four dimensions:

1. **No open-source product listing linter exists.** After extensive survey, no dedicated open-source tool checks product titles, descriptions, images, pricing, and metadata for quality and SEO compliance across e-commerce platforms.

2. **No unified framework connects listing quality to return rates.** Academic literature studies return prediction [19–24] and listing quality [12, 13, 25, 26] in isolation. Connecting "bad listing feature X causes return reason Y" via graph topology is unexplored.

3. **Graph-based approaches are validated in adjacent domains** (product knowledge graphs [7–11], supply chain [30], financial trading [29]) but have not been applied to product listing quality auditing.

4. **The NLP vs. rule-based comparison for listing quality is undocumented.** Platforms use rule-based scoring; academic research focuses on NLP for reviews and descriptions. No work systematically compares and combines both for holistic listing quality assessment.

### 7.5 Limitations

**Data ingestion bottleneck.** Graph construction requires product data ingestion. For platforms without APIs (Amazon, generic sites), this means web scraping, which is fragile and rate-limited. Shopify's `.json` API provides reliable programmatic access, but other platforms may require adapters.

**LLM latency and cost.** AI enrichment adds ~2–5 seconds per product and ~$0.01 per product via Claude Sonnet. For large catalogs (1000+ products), AI enrichment is capped at a configurable limit (default 20 products) to control cost. The rule-based pipeline operates without any API dependencies.

**Keyword classifier recall.** The 98-keyword classifier covers the most common return reason phrasings but cannot handle novel expressions. The LLM fallback addresses this for small batches, but large-scale classification at API cost scales linearly with batch size.

**Synthetic evaluation data.** Our evaluation uses synthetic return reason distributions based on published statistics rather than real merchant data, which is typically proprietary. The scoring model properties (entropy, confidence, risk levels) are validated analytically, but real-world calibration would require merchant partnerships.

**In-memory graph.** The current implementation constructs the graph in memory for each analysis run. Jac supports persistent graphs via SQLite, but the current pipeline does not leverage this for incremental analysis across sessions.

### 7.6 Future Work

**Persistent graphs.** Leveraging Jac's built-in graph persistence (via `jac start` server mode) would enable incremental analysis: products analyzed once are stored in the graph and updated only when their listings change. This would dramatically reduce re-analysis cost for large catalogs.

**Temporal analysis.** Tracking quality scores over time would enable measuring the impact of PDP fixes: "after adding a sizing note, this product's return rate dropped from 28% to 19%." This requires persistent graphs with timestamped snapshots.

**Image analysis.** Jac's `by llm()` mechanism supports multimodal models. Adding an image analysis walker that evaluates product photos for misleading lighting, missing lifestyle shots, or inconsistent style would address a major gap in current listing quality tools.

**Automated PDP updates.** Connecting amplify-audit to Shopify's Admin API (or Amazon's SP-API) would close the loop: detect issue → generate fix → apply fix → measure impact. The companion Amplify platform already implements this workflow; integrating it with the graph-based analysis would combine OSP's detection capabilities with automated remediation.

**Pre-purchase return prediction.** Using listing quality signals to predict return rates *before* products go live—flagging "this new listing is likely to have a 25% return rate based on its quality profile"—would be a valuable extension for buyers and merchandisers.

**Cross-merchant benchmarking.** Aggregating quality scores across multiple merchants in the same category would establish category norms: "the average footwear listing scores 72; your listing scores 58." This requires shared graph schemas and privacy-preserving aggregation.

---

## 8. Conclusion

We presented amplify-audit, the first application of Object-Spatial Programming to e-commerce product quality analysis. By modeling catalogs as typed property graphs and deploying 8 specialized walkers for multi-hop analysis, our approach enables graph-aware quality scoring that captures brand-level patterns, cross-product issue co-occurrence, and catalog-wide trends invisible to flat analysis tools.

Our key technical contribution is the **entropy-based fixability metric**, which measures the concentration of return reason distributions to assess whether a product's returns have a clear, fixable root cause. This metric, combined with return rate, ticket rate, and keyword signal density in a composite scoring model, provides a principled basis for prioritizing PDP fixes. A product with concentrated return reasons (high $C(p)$) and a high return rate ($R(p) > 0.20$) is a clear candidate for content intervention.

The **walker-based computational model** demonstrates natural fitness for catalog quality workflows. The separation of data (nodes) and computation (walkers) enables extensibility without modification of existing code—new analysis capabilities are added as new walker modules. Jac's **Meaning-Typed Programming** further simplifies AI integration by replacing prompt engineering with type-driven specifications that the compiler validates and generates prompts from.

The tool is the first dedicated open-source product listing linter, supporting Shopify, Amazon, Best Buy, and generic e-commerce platforms. It is available as both a CLI tool (`jac run main.jac <url>`) and a REST API server (`jac start api.jac`), with export to JSON, CSV, and Markdown formats.

We believe the DSPQA framework demonstrates that OSP is a natural fit for domains where data has inherent graph structure and analysis involves multi-entity reasoning—product catalogs being one such domain, with potential applications to supply chain quality, content management, and knowledge base auditing.

---

## References

### Core Framework
[1] Mars, J. et al. "The Jaseci Programming Paradigm and Runtime Stack." *arXiv:2305.09864*, 2023.

[2] Mars, J. et al. "Meaning-Typed Programming." *arXiv:2405.08965*, 2024.

[3] Mars, J. et al. "The Case for a Wholistic Serverless Programming Paradigm and Full Stack Automation for AI and Beyond." 2022.

[4] Mars, J. et al. "Compiler-Driven Cache Coherence for Full-Stack Applications via Cross-Boundary Static Analysis." [Reference paper].

### E-Commerce Returns and Industry
[5] National Retail Federation. "Consumer Returns in the Retail Industry 2024."

[6] Shannon, C. "A Mathematical Theory of Communication." *Bell System Technical Journal*, 1948.

### Product Knowledge Graphs
[7] Dong, X. et al. "AutoKnow: Self-Driving Knowledge Collection for Products of Thousands of Types." *KDD 2020*.

[8] Walmart Global Tech. "Retail Graph: Walmart's Product Knowledge Graph." 2021.

[9] "Billion-scale Pre-trained E-commerce Product Knowledge Graph Model." *IEEE*, 2021. arXiv:2105.00388.

[10] "All You Need to Know to Build a Product Knowledge Graph." *KDD 2021 Tutorial*.

[11] "KDD 2020 Workshop on Knowledge Graphs and E-Commerce." USC ISI.

### NLP for E-Commerce
[12] Ullah, I. et al. "QLeBERT: Assessing Product Quality in E-Commerce." 2023.

[13] "PRAISE: Enhancing Product Descriptions with LLM-Driven Structured Insights." *arXiv:2506.17314*, 2025.

[14] "ModICT: Multimodal In-Context Tuning for Product Description Generation." *arXiv:2402.13587*, 2024.

[15] "Investigating LLM Applications in E-Commerce." *arXiv:2408.12779*, 2024.

[16] "Automated Product Description Generation via Vision-Language Models." *Stanford CS231N*, 2024.

[17] "Unveiling Dual Quality in Product Reviews: An NLP-Based Approach." 2025.

[18] "A Critical Assessment of Consumer Reviews: A Hybrid NLP-Based Methodology Using Shannon's Entropy Theory." 2022.

### Return Rate Prediction
[19] Urbanke, P. et al. "Predicting Product Returns in E-Commerce: The Contribution of Mahalanobis Feature Extraction." 2015.

[20] "HyperGo Framework: CNN-LSTM Hybrid for Return Prediction." 2024.

[21] "Predicting Returns Even Before Purchase in Fashion E-Commerce." *arXiv:1906.12128*, 2019.

[22] "Learning Reasons for Product Returns on E-Commerce." *ACL ECNLP Workshop*, 2024.

[23] "Forecasting E-Commerce Consumer Returns: A Systematic Literature Review." *Springer*, 2024.

[24] "Return Management: A Machine Learning Approach." 2024.

### Listing Quality Scoring
[25] Amazon. "Item Data Quality (IDQ) Score." *Seller Central Documentation*.

[26] Walmart. "Content Quality Score." *Marketplace Documentation*.

[27] Teikametrics. "Understanding Listing Quality Scores." 2024.

[28] WisePIM. "Product Validation Scoring Framework." 2024.

### Multi-Agent Systems
[29] "LLM-Based Multi-Agent System for Simulating and Analyzing Marketing and Consumer Behavior." *IEEE ICEBE*, 2025. arXiv:2510.18155.

[30] "Agentic LLMs in the Supply Chain." *International Journal of Production Research*, 2025.

[31] "A Survey on LLM-based Multi-Agent Systems." *arXiv:2412.17481*, 2024.

### E-Commerce SEO and Cataloging
[32] "AI's Revolutionary Role in SEO." *Springer*, 2024.

[33] "Implementing LLMs to Enhance Catalog Accuracy in Retail." 2024.

---

## Appendix A: Complete Jac Code Listings

### A.1 Graph Schema (types.jac)

```jac
# Enums
enum Platform { SHOPIFY = "shopify", AMAZON = "amazon", BESTBUY = "bestbuy", UNKNOWN = "unknown" }
enum DataSource { PAGE = "page", SEARCH = "search" }
enum IssueSeverity { ERROR = "error", WARNING = "warning", INFO = "info" }
enum IssueCategory {
    TITLE = "title", DESCRIPTION = "description", IMAGES = "images",
    SIZING = "sizing", MATERIAL = "material", CARE = "care",
    TAGS = "tags", PRICE = "price", VENDOR = "vendor", SEO = "seo", TRUST = "trust"
}
enum IssueType {
    SIZING = "sizing", QUALITY = "quality",
    DESCRIPTION_MISMATCH = "description_mismatch",
    COLOR_MISMATCH = "color_mismatch", MISSING_INFO = "missing_info"
}

# Semantic annotations for LLM classification
sem IssueType.SIZING = "Fit and sizing issues: runs small/large, wrong measurements";
sem IssueType.QUALITY = "Product quality defects: broken, defective, poor materials";
sem IssueType.DESCRIPTION_MISMATCH = "Product does not match listing description or photos";
sem IssueType.COLOR_MISMATCH = "Color appears different from photos or description";
sem IssueType.MISSING_INFO = "Critical product information is absent from listing";

# Structured objects
obj AuditIssue { has severity: str; has category: str; has message: str; }
obj TopReason { has reason: str; has percentage: int; }
obj ReturnRisk {
    has score: str = "LOW";
    has top_reasons: list[TopReason] = [];
    has primary_issue_type: str = "";
    has fixable_by_pdp: bool = False;
}
obj AiInsight { has summary: str; has quality_score: int = 50; has issues: list[AuditIssue] = []; }
sem AiInsight = "AI-generated deep analysis of a product listing's quality and issues";
sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";

# Graph nodes
node Product {
    has url: str; has title: str; has description: str;
    has tags: list[str] = []; has vendor: str; has price: str;
    has images: list[str] = []; has quality_score: int = -1;
    has issues: list[AuditIssue] = [];
    has sku_health_score: float = -1.0;
    has return_risk: ReturnRisk | None = None;
    has recommendations: list[RecommendedFix] = [];
}
node Brand { has name: str; has product_count: int = 0; has avg_quality_score: float = 0.0; }
node ReturnEvidence { has reason: str; has count: int = 1; }
node IssueNode { has issue_type: str; has fixable_by_pdp: bool = False; has score: float = 0.0; }

# Graph edges
edge BelongsToBrand { has since: str = ""; }
edge HasReturn { has weight: float = 1.0; }
edge HasIssue { has detected_by: str = "rule"; }
edge HasRecommendation { has priority: int = 0; }
edge SimilarTo { has similarity: float = 0.0; has shared_issues: list[str] = []; }
```

### A.2 Shannon Entropy Scoring (scoring.jac)

```jac
import from math { log2 }

glob WEIGHT_RETURN_RATE: int = 40;
glob WEIGHT_TICKET_RATE: int = 20;
glob WEIGHT_KEYWORD_SIGNALS: int = 25;
glob WEIGHT_REASON_CONCENTRATION: int = 15;

def compute_reason_concentration(breakdown: dict) -> float {
    """C(p) = 1 - H_norm(X). Returns 0.0 (uniform) to 1.0 (single reason)."""
    values = list(breakdown.values());
    total = sum(values);
    if total == 0 { return 0.0; }
    n = len(values);
    if n <= 1 { return 1.0; }
    probs = [v / total for v in values];
    max_entropy = log2(n);
    if max_entropy == 0 { return 1.0; }
    entropy = 0.0;
    for p in probs {
        if p > 0 { entropy -= p * log2(p); }
    }
    return 1.0 - (entropy / max_entropy);
}

def compute_fixability_score(return_rate: float, ticket_rate: float,
                              keyword_signal_count: int, reason_breakdown: dict) -> float {
    """S(p) = (w_r * R_hat + w_t * T_hat + w_k * K_hat + w_c * C_hat) / 100"""
    return_rate_score = min(return_rate * 100, 100.0);
    ticket_rate_score = min(ticket_rate * 100, 100.0);
    keyword_score = min(keyword_signal_count * 10, 100);
    concentration_score = compute_reason_concentration(reason_breakdown) * 100;
    composite = (return_rate_score * 40 + ticket_rate_score * 20
                + keyword_score * 25 + concentration_score * 15) / 100.0;
    return round(composite * 100) / 100;
}
```

### A.3 Meaning-Typed Analysis (ai_analyzer.jac)

```jac
import from .types { AuditIssue, AiInsight }

def analyze_product_listing(
    title: str, description: str, price: str, brand: str,
    image_count: int, tag_count: int, variant_count: int, platform: str
) -> AiInsight by llm(temperature=0.3);

sem analyze_product_listing = """
You are an expert e-commerce listing quality auditor. Analyze this product listing
and identify specific, actionable issues that hurt conversion rates and drive returns.
Be realistic with scoring — most decent listings score 55-80.
""";

def classify_reason_llm(reason: str) -> IssueType by llm(temperature=0.0);

sem classify_reason_llm = """
Given a customer return reason, classify it into exactly one issue category.
Consider the semantic meaning, not just keyword matching.
""";
```

---

## Appendix B: Scoring Model Worked Examples

### B.1 High-Fixability Product

**Product:** "Women's Running Shoes" by Brand X
- Orders: 200, Returns: 50 (25% return rate)
- Return reasons: "runs small" ×30, "too narrow" ×12, "didn't fit" ×5, "poor quality" ×3

**Computation:**

1. Return rate: $R = 50/200 = 0.25$, $\hat{R} = \min(25, 100) = 25.0$
2. Ticket rate: $T = 0$, $\hat{T} = 0$
3. Keyword signals: "runs small" matches 1, "too narrow" matches 1, "didn't fit" matches 1, "poor quality" matches 1 → $K = 4$, $\hat{K} = \min(40, 100) = 40.0$
4. Reason concentration:
   - Distribution: {sizing: 47, quality: 3} (after classification)
   - $p_1 = 47/50 = 0.94$, $p_2 = 3/50 = 0.06$
   - $H = -(0.94 \log_2 0.94 + 0.06 \log_2 0.06) = 0.337$
   - $H_{\text{norm}} = 0.337 / \log_2(2) = 0.337$
   - $C = 1 - 0.337 = 0.663$, $\hat{C} = 66.3$

5. Composite: $S = (25 \times 40 + 0 \times 20 + 40 \times 25 + 66.3 \times 15) / 100 = 19.95$

6. Risk level: MEDIUM (25% > 10%, < 30%)
7. Primary issue: SIZING (47 hits)
8. Fixable by PDP: **Yes** (sizing is in FIXABLE_TYPES)
9. Confidence: $\min(0.7 + 200/200, 0.95) = 0.95$

**Interpretation:** This product has a clear, fixable signal. 94% of return reasons relate to sizing. The recommendation: add "Runs Small — Consider Sizing Up" to the title and a fit guidance note to the description.

### B.2 Low-Fixability Product

**Product:** "Bluetooth Headphones" by Brand Y
- Orders: 150, Returns: 45 (30% return rate)
- Return reasons: "poor quality" ×12, "too small" ×10, "not as described" ×10, "color off" ×8, "no instructions" ×5

**Computation:**

1. Return rate: $R = 45/150 = 0.30$, $\hat{R} = 30.0$
2. Reason concentration:
   - Distribution: 5 categories, counts: {quality: 12, sizing: 10, description_mismatch: 10, color_mismatch: 8, missing_info: 5}
   - $H = -\sum p_i \log_2 p_i = 2.241$
   - $H_{\text{norm}} = 2.241 / \log_2(5) = 2.241 / 2.322 = 0.965$
   - $C = 1 - 0.965 = 0.035$, $\hat{C} = 3.5$

**Interpretation:** Despite a high return rate (30%), the near-uniform reason distribution ($C = 0.035$) means there is no single dominant fix. This product has multiple quality dimensions to address, and a single PDP change is unlikely to significantly reduce returns.
