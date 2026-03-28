"""
amplify-audit/trend_analyzer.jac — Cross-product pattern detection walker.

Traverses the entire product graph to detect:
  - Category-level issue frequency
  - Brand-wide quality patterns
  - Issue co-occurrence (products with multiple correlated issues)
  - Fixability hotspots (highest-impact PDP fixes)

This is where graph-aware analysis truly shines over flat tools —
detecting patterns invisible when products are analyzed in isolation.
"""

import from .types {
    Product, Brand, Category, ReturnEvidence, IssueNode,
    AuditIssue, BelongsToBrand, HasIssue, SimilarTo
};

# ─── Trend Detection Walker ─────────────────────────────────────────────────

walker TrendAnalyzer {
    """
    Multi-pass walker that detects cross-product patterns.

    Pass 1: Collect all product scores, issues, and return data
    Pass 2: Compute cross-product correlations
    Pass 3: Generate trend reports
    """
    has products_data: list[dict] = [];
    has brand_patterns: dict = {};
    has category_patterns: dict = {};
    has issue_cooccurrence: dict = {};
    has fixability_hotspots: list[dict] = [];

    can start with `root entry {
        # First pass: collect data from all products
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can collect_product with Product entry {
        # Gather product data for cross-product analysis
        issue_categories = [i.category for i in here.issues];
        issue_severities = [i.severity for i in here.issues];

        product_entry = {
            "url": here.url,
            "title": here.title,
            "vendor": here.vendor,
            "quality_score": here.quality_score,
            "sku_health": here.sku_health_score,
            "issue_categories": issue_categories,
            "issue_count": len(here.issues),
            "error_count": len([s for s in issue_severities if s == "error"]),
            "has_return_risk": here.return_risk is not None,
            "return_risk_level": here.return_risk.score if here.return_risk else "NONE",
            "primary_issue": here.return_risk.primary_issue_type if here.return_risk else "",
            "fixable": here.return_risk.fixable_by_pdp if here.return_risk else False,
            "recommendation_count": len(here.recommendations)
        };

        self.products_data.append(product_entry);

        # Track issue co-occurrence
        for (i, cat1) in enumerate(issue_categories) {
            for cat2 in issue_categories[i+1:] {
                pair = tuple(sorted([cat1, cat2]));
                pair_key = f"{pair[0]}|{pair[1]}";
                if pair_key in self.issue_cooccurrence {
                    self.issue_cooccurrence[pair_key] = self.issue_cooccurrence[pair_key] + 1;
                } else {
                    self.issue_cooccurrence[pair_key] = 1;
                }
            }
        }

        # Track brand patterns
        if here.vendor {
            if here.vendor not in self.brand_patterns {
                self.brand_patterns[here.vendor] = {
                    "scores": [],
                    "issues": [],
                    "fixable_count": 0,
                    "total": 0
                };
            }
            bp = self.brand_patterns[here.vendor];
            if here.quality_score >= 0 {
                bp["scores"].append(here.quality_score);
            }
            bp["issues"].extend(issue_categories);
            bp["total"] = bp["total"] + 1;
            if product_entry["fixable"] {
                bp["fixable_count"] = bp["fixable_count"] + 1;
            }
        }

        visit [-->](`?Product);
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}

# ─── Post-Traversal Analysis ────────────────────────────────────────────────

def analyze_trends(analyzer: TrendAnalyzer) -> dict {
    """Compute trend analysis from collected walker data."""
    products = analyzer.products_data;

    if len(products) == 0 {
        return {"trends": [], "summary": "No products analyzed"};
    }

    trends: list[dict] = [];

    # ─── 1. Overall Health Distribution ──────────────────────────────────
    scores = [p["quality_score"] for p in products if p["quality_score"] >= 0];
    avg_score = sum(scores) / len(scores) if scores else 0;
    critical_count = len([p for p in products if p["return_risk_level"] in ["HIGH", "CRITICAL"]]);
    fixable_count = len([p for p in products if p["fixable"]]);

    trends.append({
        "type": "health_distribution",
        "title": "Catalog Health Overview",
        "data": {
            "total_products": len(products),
            "avg_quality_score": round(avg_score, 1),
            "critical_products": critical_count,
            "fixable_products": fixable_count,
            "fixable_pct": round(fixable_count / len(products) * 100, 1) if len(products) > 0 else 0
        }
    });

    # ─── 2. Top Issue Categories ─────────────────────────────────────────
    issue_freq: dict = {};
    for p in products {
        for cat in p["issue_categories"] {
            if cat in issue_freq {
                issue_freq[cat] = issue_freq[cat] + 1;
            } else {
                issue_freq[cat] = 1;
            }
        }
    }
    sorted_issues = sorted(issue_freq.items(), key=lambda x: x[1], reverse=True);

    trends.append({
        "type": "issue_frequency",
        "title": "Most Common Issues Across Catalog",
        "data": {
            "issues": [
                {"category": cat, "count": count, "pct": round(count / len(products) * 100, 1)}
                for (cat, count) in sorted_issues[:10]
            ]
        }
    });

    # ─── 3. Issue Co-occurrence ──────────────────────────────────────────
    cooccur = analyzer.issue_cooccurrence;
    sorted_cooccur = sorted(cooccur.items(), key=lambda x: x[1], reverse=True);
    if sorted_cooccur {
        trends.append({
            "type": "issue_cooccurrence",
            "title": "Issues That Appear Together",
            "data": {
                "pairs": [
                    {"pair": pair, "count": count}
                    for (pair, count) in sorted_cooccur[:5]
                ]
            }
        });
    }

    # ─── 4. Brand-Level Patterns ─────────────────────────────────────────
    brand_trends: list[dict] = [];
    for (brand, bp) in analyzer.brand_patterns.items() {
        if bp["total"] < 2 {
            continue;
        }
        brand_avg = sum(bp["scores"]) / len(bp["scores"]) if bp["scores"] else 0;

        # Find dominant issues for this brand
        brand_issue_freq: dict = {};
        for issue in bp["issues"] {
            if issue in brand_issue_freq {
                brand_issue_freq[issue] = brand_issue_freq[issue] + 1;
            } else {
                brand_issue_freq[issue] = 1;
            }
        }
        sorted_brand = sorted(brand_issue_freq.items(), key=lambda x: x[1], reverse=True);
        dominant = sorted_brand[0] if sorted_brand else ("none", 0);

        # Check if dominant issue affects >50% of brand's products
        if dominant[1] > bp["total"] * 0.5 {
            brand_trends.append({
                "brand": brand,
                "product_count": bp["total"],
                "avg_score": round(brand_avg, 1),
                "dominant_issue": dominant[0],
                "dominant_pct": round(dominant[1] / bp["total"] * 100, 1),
                "fixable_count": bp["fixable_count"],
                "insight": f"{brand} products consistently have {dominant[0]} issues ({dominant[1]}/{bp['total']} products)"
            });
        }
    }

    if brand_trends {
        trends.append({
            "type": "brand_patterns",
            "title": "Brand-Wide Quality Patterns",
            "data": {"brands": sorted(brand_trends, key=lambda x: x["dominant_pct"], reverse=True)}
        });
    }

    # ─── 5. Fixability Hotspots ──────────────────────────────────────────
    fixable_by_type: dict = {};
    for p in products {
        if p["fixable"] and p["primary_issue"] {
            issue_type = p["primary_issue"];
            if issue_type in fixable_by_type {
                fixable_by_type[issue_type] = fixable_by_type[issue_type] + 1;
            } else {
                fixable_by_type[issue_type] = 1;
            }
        }
    }

    if fixable_by_type {
        sorted_fixable = sorted(fixable_by_type.items(), key=lambda x: x[1], reverse=True);
        trends.append({
            "type": "fixability_hotspots",
            "title": "Highest-Impact PDP Fixes",
            "data": {
                "hotspots": [
                    {"issue_type": t, "fixable_count": c, "pct": round(c / fixable_count * 100, 1) if fixable_count > 0 else 0}
                    for (t, c) in sorted_fixable
                ]
            }
        });
    }

    # ─── 6. Score Distribution Buckets ───────────────────────────────────
    buckets = {"0-20": 0, "21-40": 0, "41-60": 0, "61-80": 0, "81-100": 0};
    for s in scores {
        if s <= 20 { buckets["0-20"] += 1; }
        elif s <= 40 { buckets["21-40"] += 1; }
        elif s <= 60 { buckets["41-60"] += 1; }
        elif s <= 80 { buckets["61-80"] += 1; }
        else { buckets["81-100"] += 1; }
    }

    trends.append({
        "type": "score_distribution",
        "title": "Quality Score Distribution",
        "data": {"buckets": buckets, "total_scored": len(scores)}
    });

    return {
        "trends": trends,
        "summary": f"Analyzed {len(products)} products: avg score {round(avg_score, 1)}, {critical_count} critical, {fixable_count} fixable by PDP changes"
    };
}
