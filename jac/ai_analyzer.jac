"""
amplify-audit/ai_analyzer.jac — Meaning-Typed Product Analysis.

Uses Jac's `by llm()` for semantic product listing analysis.
The function signatures and type annotations serve as the LLM specification —
no prompt engineering required. This is Meaning-Typed Programming (MTP).

The LLM receives:
  1. The function name (semantic intent)
  2. Parameter names and types (input schema)
  3. Return type (output schema with field annotations via `sem`)
  4. Semantic strings (disambiguation and constraints)

And produces type-validated structured output automatically.
"""

import from types_jac { AuditIssue, AiInsight }

# ─── Meaning-Typed Analysis Functions ────────────────────────────────────────

"""Analyze a product listing and produce a quality assessment.

The analysis should consider: title effectiveness, description completeness,
SEO optimization, image sufficiency, trust signals, and category-specific
requirements. Be direct and specific — reference the actual product."""
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

sem analyze_product_listing = """
You are an expert e-commerce listing quality auditor. Analyze this product listing
and identify specific, actionable issues that hurt conversion rates and drive returns.

Be realistic with scoring — most decent listings score 55-80.
Focus on what ACTUALLY matters for this specific product category.
""";

sem analyze_product_listing.title = "The product title as it appears on the listing page";
sem analyze_product_listing.description = "Product description text (HTML stripped, max 2000 chars)";
sem analyze_product_listing.price = "Listed price or empty if not available";
sem analyze_product_listing.brand = "Brand/vendor name or empty if unknown";
sem analyze_product_listing.image_count = "Number of product images on the listing";
sem analyze_product_listing.tag_count = "Number of tags/categories assigned";
sem analyze_product_listing.variant_count = "Number of product variants (sizes, colors, etc.)";
sem analyze_product_listing.platform = "E-commerce platform: shopify, amazon, bestbuy, or unknown";


"""Given return reasons for a product, identify the root cause pattern
and suggest a specific PDP content fix that would prevent these returns."""
def diagnose_return_pattern(
    product_title: str,
    return_reasons: list[str],
    return_rate: float
) -> str by llm(temperature=0.2);

sem diagnose_return_pattern = """
Analyze the return reasons as a whole to identify the dominant pattern.
Suggest ONE specific, actionable change to the product listing that
would address the root cause. Be concrete — reference the actual product.
""";


obj CompetitorInsight {
    has strengths: list[str];
    has weaknesses: list[str];
    has missing_from_listing: list[str];
    has seo_suggestions: list[str];
}

sem CompetitorInsight = "Analysis of how a listing compares to category best practices";
sem CompetitorInsight.strengths = "What this listing does well relative to the category";
sem CompetitorInsight.weaknesses = "Where this listing falls short of category standards";
sem CompetitorInsight.missing_from_listing = "Specific information buyers expect but is absent";
sem CompetitorInsight.seo_suggestions = "Keyword and SEO improvements to boost discoverability";

"""Compare a product listing against category best practices and identify gaps."""
def analyze_competitive_position(
    title: str,
    description: str,
    price: str,
    category: str,
    platform: str
) -> CompetitorInsight by llm(temperature=0.4);

sem analyze_competitive_position = """
Compare this listing against what best-in-class listings in this category look like.
Consider: information completeness, persuasiveness, SEO, trust signals, and
category-specific expectations (e.g., sizing charts for apparel, specs for electronics).
""";


obj RewriteSuggestion {
    has original_title: str;
    has improved_title: str;
    has title_rationale: str;
    has key_additions: list[str];
    has estimated_impact: str;
}

sem RewriteSuggestion = "A concrete rewrite suggestion for the product listing";
sem RewriteSuggestion.original_title = "The current product title";
sem RewriteSuggestion.improved_title = "An improved version of the title";
sem RewriteSuggestion.title_rationale = "Why the new title is better (SEO, clarity, conversion)";
sem RewriteSuggestion.key_additions = "Specific pieces of information to add to the description";
sem RewriteSuggestion.estimated_impact = "Expected impact: 'low', 'medium', or 'high'";

"""Generate a concrete listing rewrite suggestion based on detected issues."""
def generate_rewrite(
    title: str,
    description: str,
    issues: list[str],
    return_reasons: list[str]
) -> RewriteSuggestion by llm(temperature=0.5);

sem generate_rewrite = """
Given the current listing and its issues, generate a specific rewrite suggestion.
The improved title should be SEO-friendly, accurate, and include key product attributes.
Key additions should be specific content to add to the description.
""";
