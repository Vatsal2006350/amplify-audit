"""
amplify-audit/main.jac — Entry point for Data-Spatial Product Quality Analysis.

This module orchestrates the full audit pipeline:
  1. Build graph: Ingest product data into a typed property graph
  2. Analyze: Spawn walkers to traverse and score
  3. Enrich: Optionally enrich with LLM analysis
  4. Report: Collect and return structured audit results

The graph topology:
  root
   ├── Brand("Nike")
   │    ├──[BelongsToBrand]── Product("Air Max 90")
   │    │                      ├──[HasReturn]── ReturnEvidence("runs small")
   │    │                      ├──[HasIssue]── IssueNode(SIZING)
   │    │                      └──[HasRecommendation]── RecommendationNode(...)
   │    └──[BelongsToBrand]── Product("Air Force 1")
   └── Category("Sneakers")
        └──[InCategory]── Product(...)
"""

import from .types {
    Product, Brand, Category, ReturnEvidence,
    Variant, AuditIssue, RecommendedFix,
    BelongsToBrand, InCategory, HasReturn
}
import from .walkers {
    QualityAnalyzer, ReturnAnalyzer, RecommendationWalker,
    AiEnricher, BrandAggregator, AuditReporter
}

# ─── Graph Construction ──────────────────────────────────────────────────────

def build_product_graph(
    products: list[dict],
    return_data: dict | None = None
) -> None {
    """
    Ingest raw product data into the graph rooted at `root`.

    Products are connected to Brand nodes (deduped by vendor name)
    and optionally to ReturnEvidence nodes.

    Args:
      products: List of dicts with keys matching Product fields
      return_data: Optional dict mapping product URL to return info:
                   {"reasons": [...], "order_count": N, "return_count": N}
    """
    brand_map: dict = {};

    for p_data in products {
        # Create product node
        variants = [];
        for v in p_data.get("variants", []) {
            variants.append(Variant(
                title=v.get("title", "Default"),
                sku=v.get("sku", ""),
                price=v.get("price", "")
            ));
        }

        product = Product(
            url=p_data.get("url", ""),
            platform=p_data.get("platform", "unknown"),
            source=p_data.get("source", "page"),
            title=p_data.get("title", ""),
            description=p_data.get("description", ""),
            tags=p_data.get("tags", []),
            vendor=p_data.get("vendor", ""),
            product_type=p_data.get("product_type", ""),
            price=p_data.get("price", ""),
            images=p_data.get("images", []),
            variants=variants
        );

        # Connect to root
        root ++> product;

        # Connect to brand node (create or reuse)
        vendor = p_data.get("vendor", "");
        if vendor {
            if vendor not in brand_map {
                brand_node = Brand(name=vendor);
                root ++> brand_node;
                brand_map[vendor] = brand_node;
            }
            brand_map[vendor] +>:BelongsToBrand:+> product;
        }

        # Attach return evidence if available
        if return_data {
            url = p_data.get("url", "");
            if url in return_data {
                ret_info = return_data[url];
                reasons = ret_info.get("reasons", []);
                for reason in reasons {
                    ev = ReturnEvidence(
                        reason=reason,
                        normalized=reason.strip().lower(),
                        count=1
                    );
                    product ++> ev;
                }
            }
        }
    }
}

# ─── Single Product Audit ────────────────────────────────────────────────────

def audit_single(
    product_data: dict,
    return_data: dict | None = None,
    use_ai: bool = False
) -> dict {
    """
    Audit a single product listing.

    This is the Jac equivalent of the TypeScript `audit()` function.
    Instead of calling functions sequentially, we:
      1. Build a graph with the product
      2. Spawn walkers to traverse and analyze
      3. Collect results via reports

    Args:
      product_data: Dict with product fields (title, description, etc.)
      return_data: Optional return info dict with reasons, order_count, etc.
      use_ai: Whether to enrich with LLM analysis

    Returns:
      Full audit report dict
    """
    # Build graph
    ret_map: dict | None = None;
    if return_data {
        url = product_data.get("url", "__single__");
        ret_map = {url: return_data};
    }
    build_product_graph([product_data], ret_map);

    # Phase 1: Quality analysis
    root spawn QualityAnalyzer();

    # Phase 2: Return analysis (if return data provided)
    if return_data {
        root spawn ReturnAnalyzer(
            order_count=return_data.get("order_count", 0),
            return_count=return_data.get("return_count", 0),
            ticket_count=return_data.get("ticket_count", 0)
        );
    }

    # Phase 3: Recommendations
    root spawn RecommendationWalker();

    # Phase 4: AI enrichment (optional)
    if use_ai {
        root spawn AiEnricher(max_products=1);
    }

    # Phase 5: Collect report
    reporter = root spawn AuditReporter();
    if reporter {
        return reporter;
    }
    return {};
}

# ─── Multi-Product (Store/Brand) Audit ───────────────────────────────────────

def audit_catalog(
    products: list[dict],
    return_data: dict | None = None,
    use_ai: bool = False,
    max_ai_products: int = 20
) -> dict {
    """
    Audit an entire catalog of products.

    Builds a full product graph and spawns walkers for
    quality analysis, return analysis, recommendations,
    optional AI enrichment, and brand aggregation.

    Returns:
      {
        "products": [...audit reports...],
        "brands": [...brand summaries...],
        "ai_powered": bool,
        "summary": {
          "total": int,
          "avg_quality": float,
          "critical_count": int,
          "fixable_count": int
        }
      }
    """
    # Build the full graph
    build_product_graph(products, return_data);

    # Phase 1: Quality analysis on all products
    quality_results = root spawn QualityAnalyzer();

    # Phase 2: Return analysis (if data provided)
    if return_data {
        root spawn ReturnAnalyzer();
    }

    # Phase 3: Generate recommendations
    root spawn RecommendationWalker();

    # Phase 4: AI enrichment
    ai_powered = False;
    if use_ai {
        ai_results = root spawn AiEnricher(max_products=max_ai_products);
        ai_powered = True;
    }

    # Phase 5: Brand aggregation
    brand_results = root spawn BrandAggregator();

    # Phase 6: Collect all reports
    reporter = root spawn AuditReporter();

    # Compute summary statistics
    total = len(reporter) if reporter else 0;
    total_score = 0;
    scored = 0;
    critical = 0;
    fixable = 0;

    reports = reporter if reporter else [];
    for r in reports {
        if isinstance(r, dict) {
            score = r.get("quality_score", -1);
            if score >= 0 {
                total_score += score;
                scored += 1;
            }
            risk = r.get("return_risk", None);
            if isinstance(risk, dict) {
                if risk.get("score", "") in ["HIGH", "CRITICAL"] {
                    critical += 1;
                }
                if risk.get("fixable_by_pdp", False) {
                    fixable += 1;
                }
            }
        }
    }

    return {
        "products": reports,
        "brands": brand_results if brand_results else [],
        "ai_powered": ai_powered,
        "summary": {
            "total": total,
            "avg_quality": round(total_score / scored, 1) if scored > 0 else 0.0,
            "critical_count": critical,
            "fixable_count": fixable
        }
    };
}

# ─── Entry Point ─────────────────────────────────────────────────────────────

with entry {
    print("amplify-audit: Data-Spatial Product Quality Analysis");
    print("====================================================");
    print("");
    print("Build a product graph and spawn walkers to analyze.");
    print("");

    # Example: audit a single product
    sample = {
        "url": "https://example.com/products/blue-sweater",
        "platform": "shopify",
        "title": "Blue Sweater",
        "description": "<p>A cozy blue sweater.</p>",
        "tags": ["clothing"],
        "vendor": "TestBrand",
        "price": "49.99",
        "images": ["img1.jpg"],
        "variants": [{"title": "Small", "sku": "BS-S", "price": "49.99"}]
    };

    sample_returns = {
        "reasons": ["runs small", "too tight", "size up", "too small for me"],
        "order_count": 100,
        "return_count": 25,
        "ticket_count": 5
    };

    result = audit_single(sample, sample_returns);
    print(f"Audit complete. Results: {result}");
}
