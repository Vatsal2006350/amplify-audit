"""
amplify-audit/walkers.jac — Data-Spatial Analysis Walkers.

This module implements the core computational agents that traverse
the product graph to perform quality analysis.

In Object-Spatial Programming, walkers are mobile agents that visit
nodes and trigger abilities. This replaces the traditional pattern of
calling functions with data — instead, we send computation TO the data.

Walker Architecture:
  1. QualityAnalyzer   — traverses products, runs rule-based checks
  2. ReturnAnalyzer    — traverses products with evidence, classifies & scores
  3. RecommendationWalker — traverses products with issues, generates fixes
  4. AiEnricher        — traverses products, enriches with LLM analysis
  5. BrandAggregator   — traverses brands, aggregates cross-product metrics
  6. AuditReporter     — traverses entire graph, collects full audit reports
"""

import from .types {
    Product, Brand, Category, ReturnEvidence, IssueNode,
    RecommendationNode, AuditIssue, ReturnRisk, TopReason,
    RecommendedFix, AiInsight,
    BelongsToBrand, HasReturn, HasIssue, HasRecommendation
}
import from .analyzer { analyze_listing_quality, strip_html }
import from .classifier {
    classify_reasons, classify_reasons_smart,
    get_primary_issue_type, is_fixable_by_pdp, build_reason_breakdown
}
import from .scoring {
    compute_return_rate, compute_ticket_rate,
    compute_fixability_score, compute_confidence
}
import from .recommender { generate_recommendations }
import from .ai_analyzer { analyze_product_listing }

# ─── Walker 1: Quality Analyzer ──────────────────────────────────────────────

walker QualityAnalyzer {
    """
    Traverses Product nodes and computes rule-based quality scores.

    For each product node visited:
      1. Runs analyze_listing_quality() with product attributes
      2. Writes quality_score and issues back to the node
      3. Reports the score for aggregation
    """
    has analyzed_count: int = 0;

    can start with `root entry {
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can analyze_product with Product entry {
        result = analyze_listing_quality(
            title=here.title,
            description=here.description,
            tags=here.tags,
            images=here.images,
            price=here.price,
            vendor=here.vendor,
            source=here.source
        );

        here.quality_score = result["quality_score"];
        here.issues = [
            AuditIssue(
                severity=i["severity"],
                category=i["category"],
                message=i["message"]
            )
            for i in result["issues"]
        ];

        self.analyzed_count += 1;
        report {"url": here.url, "title": here.title, "score": here.quality_score};
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}

# ─── Walker 2: Return Analyzer ───────────────────────────────────────────────

walker ReturnAnalyzer {
    """
    Traverses products with return evidence to classify reasons and compute
    SKU health scores.

    For each product:
      1. Collects all connected ReturnEvidence nodes
      2. Classifies reasons (keyword or LLM-based)
      3. Computes fixability score and confidence
      4. Determines risk level
      5. Creates IssueNode for the primary issue type
    """
    has order_count: int = 0;
    has return_count: int = 0;
    has ticket_count: int = 0;
    has use_llm: bool = False;
    has products_analyzed: int = 0;

    can start with `root entry {
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can analyze_returns with Product entry {
        # Collect return evidence from connected nodes
        evidence_nodes = [-->](`?ReturnEvidence);
        if len(evidence_nodes) == 0 {
            visit [-->](`?Product);
            return;
        }

        reasons: list[str] = [];
        for ev in evidence_nodes {
            for _ in range(ev.count) {
                reasons.append(ev.reason);
            }
        }

        # Classify reasons
        classification = classify_reasons_smart(reasons, use_llm=self.use_llm);
        primary_type = get_primary_issue_type(classification);
        reason_breakdown = build_reason_breakdown(reasons);

        # Compute scores — derive from evidence if walker-level counts not set
        total_evidence = sum(ev.count for ev in evidence_nodes);
        order_count = self.order_count if self.order_count > 0 else max(total_evidence * 4, 1);
        return_count = self.return_count if self.return_count > 0 else total_evidence;
        ticket_count = self.ticket_count;

        return_rate = compute_return_rate(return_count, order_count);
        ticket_rate = compute_ticket_rate(ticket_count, order_count);

        keyword_count = 0;
        for (k, v) in classification.items() {
            keyword_count += v;
        }

        sku_health = compute_fixability_score(
            return_rate, ticket_rate, keyword_count, reason_breakdown
        );
        confidence = compute_confidence(order_count, return_count);

        # Determine risk level
        risk_level = "LOW";
        if return_rate > 0.3 {
            risk_level = "CRITICAL";
        } elif return_rate > 0.2 {
            risk_level = "HIGH";
        } elif return_rate > 0.1 {
            risk_level = "MEDIUM";
        }

        # Build top reasons
        reason_counts: dict = {};
        for reason in reasons {
            trimmed = reason.strip().lower();
            if trimmed {
                if trimmed in reason_counts {
                    reason_counts[trimmed] = reason_counts[trimmed] + 1;
                } else {
                    reason_counts[trimmed] = 1;
                }
            }
        }
        total_reasons = len(reasons) if len(reasons) > 0 else 1;
        sorted_reasons = sorted(reason_counts.items(), key=lambda x: x[1], reverse=True);
        top_reasons = [
            TopReason(reason=r, percentage=round(c / total_reasons * 100))
            for (r, c) in sorted_reasons[:5]
        ];

        # Write results to product node
        here.sku_health_score = sku_health;
        here.confidence = confidence;
        here.return_risk = ReturnRisk(
            score=risk_level,
            top_reasons=top_reasons,
            primary_issue_type=primary_type,
            fixable_by_pdp=is_fixable_by_pdp(primary_type) if primary_type else False
        );

        # Create issue node if primary type detected
        if primary_type {
            issue = IssueNode(
                issue_type=primary_type,
                severity="error" if return_rate > 0.2 else "warning",
                signal_count=keyword_count,
                fixable_by_pdp=is_fixable_by_pdp(primary_type),
                score=sku_health
            );
            here +>:HasIssue(detected_by="classifier"):+> issue;
        }

        self.products_analyzed += 1;
        report {
            "url": here.url,
            "risk": risk_level,
            "primary_issue": primary_type,
            "health_score": sku_health
        };

        visit [-->](`?Product);
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}

# ─── Walker 3: Recommendation Generator ─────────────────────────────────────

walker RecommendationWalker {
    """
    Traverses products and generates PDP fix recommendations
    based on detected issues and return patterns.
    """
    has generated_count: int = 0;

    can start with `root entry {
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can generate with Product entry {
        primary_type = "";

        if here.return_risk {
            primary_type = here.return_risk.primary_issue_type;
        }

        # Compute return rate from evidence
        evidence_nodes = [-->](`?ReturnEvidence);
        total_returns = 0;
        for ev in evidence_nodes {
            total_returns += ev.count;
        }
        return_rate = total_returns / max(total_returns * 4, 1) if total_returns > 0 else 0.0;

        fixes = generate_recommendations(
            title=here.title,
            description=here.description,
            primary_issue_type=primary_type,
            return_rate=return_rate
        );

        here.recommendations = [
            RecommendedFix(
                field=f["field"],
                before=f["before"],
                after=f["after"],
                rationale=f["rationale"]
            )
            for f in fixes
        ];

        # Create recommendation nodes in the graph
        for (i, f) in enumerate(fixes) {
            rec_node = RecommendationNode(
                field=f["field"],
                before=f["before"],
                after=f["after"],
                rationale=f["rationale"]
            );
            here +>:HasRecommendation(priority=i):+> rec_node;
        }

        self.generated_count += 1;
        report {"url": here.url, "fix_count": len(fixes)};

        visit [-->](`?Product);
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}

# ─── Walker 4: AI Enricher ──────────────────────────────────────────────────

walker AiEnricher {
    """
    Traverses products and enriches them with LLM-powered analysis.

    Uses Jac's Meaning-Typed Programming: the function signature
    of analyze_product_listing() IS the LLM specification.

    Only enriches products with actual page data (not search stubs).
    Blends AI scores with rule-based scores: 30% rule + 70% AI.
    """
    has enriched_count: int = 0;
    has max_products: int = 20;

    can start with `root entry {
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can enrich with Product entry {
        if self.enriched_count >= self.max_products {
            disengage;
        }

        # Skip search stubs — not enough data for meaningful AI analysis
        if here.source == "search" {
            visit [-->](`?Product);
            return;
        }

        desc_text = here.description if here.description else "";
        if len(desc_text) < 20 {
            visit [-->](`?Product);
            return;
        }

        try {
            ai_result = analyze_product_listing(
                title=here.title,
                description=desc_text[:2000],
                price=here.price,
                brand=here.vendor,
                image_count=len(here.images),
                tag_count=len(here.tags),
                variant_count=len(here.variants),
                platform=here.platform
            );

            here.ai_insight = ai_result;

            # Blend scores: 30% rule-based + 70% AI
            if here.quality_score >= 0 {
                here.quality_score = round(
                    here.quality_score * 0.3 + ai_result.quality_score * 0.7
                );
            }

            # Merge AI issues with existing
            existing_categories = {i.category for i in here.issues};
            for ai_issue in ai_result.issues {
                if ai_issue.category not in existing_categories {
                    here.issues.append(ai_issue);
                }
            }

            self.enriched_count += 1;
            report {"url": here.url, "ai_score": ai_result.quality_score, "summary": ai_result.summary};
        } except Exception as e {
            report {"url": here.url, "error": str(e)};
        }

        visit [-->](`?Product);
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}

# ─── Walker 5: Brand Aggregator ─────────────────────────────────────────────

walker BrandAggregator {
    """
    Traverses Brand nodes, then their connected Products, to compute
    brand-level aggregate metrics.

    This demonstrates graph-aware scoring: a brand's quality profile
    emerges from traversing the product subgraph rooted at each Brand node.
    """
    has brand_reports: list = [];

    can start with `root entry {
        visit [-->](`?Brand);
    }

    can aggregate_brand with Brand entry {
        products = [-->](`?Product);
        if len(products) == 0 {
            visit [-->](`?Brand);
            return;
        }

        total_score = 0;
        scored_count = 0;
        issue_counts: dict = {};

        for product in products {
            if product.quality_score >= 0 {
                total_score += product.quality_score;
                scored_count += 1;
            }
            for issue in product.issues {
                cat = issue.category;
                if cat in issue_counts {
                    issue_counts[cat] = issue_counts[cat] + 1;
                } else {
                    issue_counts[cat] = 1;
                }
            }
        }

        here.product_count = len(products);
        here.avg_quality_score = total_score / scored_count if scored_count > 0 else 0.0;

        # Top 3 most common issues across the brand
        sorted_issues = sorted(issue_counts.items(), key=lambda x: x[1], reverse=True);
        here.common_issues = [k for (k, v) in sorted_issues[:3]];

        self.brand_reports.append({
            "brand": here.name,
            "products": here.product_count,
            "avg_score": round(here.avg_quality_score, 1),
            "top_issues": here.common_issues
        });

        report {
            "brand": here.name,
            "avg_score": round(here.avg_quality_score, 1),
            "product_count": here.product_count,
            "common_issues": here.common_issues
        };
    }
}

# ─── Walker 6: Audit Reporter ───────────────────────────────────────────────

walker AuditReporter {
    """
    Traverses the entire product graph and collects full audit reports.

    This is the final aggregation walker that produces the output
    equivalent to the TypeScript `audit()` function.
    """
    has reports: list = [];

    can start with `root entry {
        visit [-->](`?Product);
        visit [-->](`?Brand);
    }

    can collect with Product entry {
        report_entry: dict = {
            "url": here.url,
            "platform": here.platform,
            "title": here.title,
            "quality_score": here.quality_score,
            "issues": [
                {"severity": i.severity, "category": i.category, "message": i.message}
                for i in here.issues
            ],
            "recommendations": [
                {"field": r.field, "before": r.before, "after": r.after, "rationale": r.rationale}
                for r in here.recommendations
            ],
            "sku_health_score": here.sku_health_score,
            "confidence": here.confidence
        };

        if here.return_risk {
            report_entry["return_risk"] = {
                "score": here.return_risk.score,
                "top_reasons": [
                    {"reason": tr.reason, "percentage": tr.percentage}
                    for tr in here.return_risk.top_reasons
                ],
                "primary_issue_type": here.return_risk.primary_issue_type,
                "fixable_by_pdp": here.return_risk.fixable_by_pdp
            };
        }

        if here.ai_insight {
            report_entry["ai_summary"] = here.ai_insight.summary;
            report_entry["ai_score"] = here.ai_insight.quality_score;
        }

        self.reports.append(report_entry);
        report report_entry;

        visit [-->](`?Product);
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}
