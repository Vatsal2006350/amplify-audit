"""
amplify-audit/api.jac — REST API endpoints via Jac's walker-as-API pattern.

When running `jac start api.jac`, each walker becomes an HTTP endpoint:
  POST /walker/audit_product   → Audit a single product URL
  POST /walker/audit_catalog   → Audit an entire store
  POST /walker/get_brands      → Get brand-level aggregation
  POST /walker/get_trends      → Get cross-product trends
  GET  /walker/health          → Health check

Usage:
  jac start api.jac --port 8002

Then:
  curl -X POST http://localhost:8002/walker/audit_product \
    -H "Content-Type: application/json" \
    -d '{"url": "https://allbirds.com/products/mens-tree-runners"}'
"""

import from http { HTTPMethod }

import from types_jac {
    Product, Brand, ReturnEvidence, AuditIssue, RecommendedFix,
    BelongsToBrand, HasReturn
}
import from fetcher { fetch_product, fetch_store, detect_platform }
import from walkers {
    QualityAnalyzer, ReturnAnalyzer, RecommendationWalker,
    AiEnricher, BrandAggregator, AuditReporter
}
import from seo_analyzer { SEOAnalyzer }
import from trend_analyzer { TrendAnalyzer, analyze_trends }
import from export { export_json, export_csv, export_markdown }
import from main { build_product_graph }

# ─── Health Check ────────────────────────────────────────────────────────────

@restspec(method=HTTPMethod.GET)
walker :pub health {
    """Health check endpoint."""
    can check with `root entry {
        report {"status": "healthy", "service": "amplify-audit", "version": "0.2.0"};
    }
}

# ─── Single Product Audit ────────────────────────────────────────────────────

walker :pub audit_product {
    """
    Audit a single product by URL.

    Request body:
      {"url": "https://...", "use_ai": false, "include_seo": true}

    Response:
      Full audit report with quality score, issues, SEO, recommendations.
    """
    has url: str;
    has use_ai: bool = False;
    has include_seo: bool = True;
    has return_reasons: list[str] = [];
    has order_count: int = 0;
    has return_count: int = 0;

    can audit with `root entry {
        # Fetch product data
        product_data = fetch_product(self.url);

        if not product_data.get("title", "") {
            report {"error": "Could not fetch product data from URL", "url": self.url};
            return;
        }

        # Build return data if provided
        ret_map: dict | None = None;
        if self.return_reasons {
            ret_map = {
                self.url: {
                    "reasons": self.return_reasons,
                    "order_count": self.order_count,
                    "return_count": self.return_count
                }
            };
        }

        # Build graph
        build_product_graph([product_data], ret_map);

        # Run analysis walkers
        root spawn QualityAnalyzer();

        if self.return_reasons {
            root spawn ReturnAnalyzer(
                order_count=self.order_count,
                return_count=self.return_count
            );
        }

        root spawn RecommendationWalker();

        if self.include_seo {
            root spawn SEOAnalyzer();
        }

        if self.use_ai {
            root spawn AiEnricher(max_products=1);
        }

        # Collect report
        reporter = root spawn AuditReporter();
        if reporter {
            report reporter;
        } else {
            report {"error": "No audit results generated"};
        }
    }
}

# ─── Store/Catalog Audit ─────────────────────────────────────────────────────

walker :pub audit_catalog {
    """
    Audit an entire store or catalog.

    Request body:
      {"url": "https://store.myshopify.com", "max_products": 50, "use_ai": false}

    Response:
      Full catalog report with per-product audits, brand aggregation, and trends.
    """
    has url: str;
    has max_products: int = 50;
    has use_ai: bool = False;
    has include_seo: bool = True;

    can audit with `root entry {
        # Fetch all products from store
        products = fetch_store(self.url, self.max_products);

        if not products {
            report {"error": "Could not fetch products from store", "url": self.url};
            return;
        }

        # Build graph
        build_product_graph(products, None);

        # Run analysis pipeline
        root spawn QualityAnalyzer();
        root spawn RecommendationWalker();

        if self.include_seo {
            root spawn SEOAnalyzer();
        }

        if self.use_ai {
            root spawn AiEnricher(max_products=min(20, self.max_products));
        }

        # Brand aggregation
        brand_results = root spawn BrandAggregator();

        # Trend analysis
        trend_walker = root spawn TrendAnalyzer();
        trends = analyze_trends(trend_walker) if trend_walker else {};

        # Collect all reports
        reporter = root spawn AuditReporter();
        reports = reporter if reporter else [];

        # Compute summary
        total = len(reports) if isinstance(reports, list) else 0;
        scored = [r for r in reports if isinstance(r, dict) and r.get("quality_score", -1) >= 0];
        avg_score = sum(r["quality_score"] for r in scored) / len(scored) if scored else 0;

        report {
            "store_url": self.url,
            "product_count": total,
            "products": reports,
            "brands": brand_results if brand_results else [],
            "trends": trends,
            "ai_powered": self.use_ai,
            "summary": {
                "total": total,
                "avg_quality": round(avg_score, 1),
                "products_fetched": products.__len__()
            }
        };
    }
}

# ─── Brand Analysis ──────────────────────────────────────────────────────────

walker :pub get_brands {
    """
    Get brand-level quality aggregation from the current graph.

    Response:
      List of brand summaries with avg scores and common issues.
    """
    can fetch with `root entry {
        results = root spawn BrandAggregator();
        report results if results else [];
    }
}

# ─── Trend Analysis ──────────────────────────────────────────────────────────

walker :pub get_trends {
    """
    Get cross-product trend analysis from the current graph.

    Response:
      Trend reports: health distribution, top issues, co-occurrence, brand patterns.
    """
    can fetch with `root entry {
        trend_walker = root spawn TrendAnalyzer();
        trends = analyze_trends(trend_walker) if trend_walker else {};
        report trends;
    }
}

# ─── Export ───────────────────────────────────────────────────────────────────

walker :pub export_report {
    """
    Export the current graph's audit data in various formats.

    Request body:
      {"format": "json"}  — json, csv, or markdown
    """
    has format: str = "json";

    can export with `root entry {
        reporter = root spawn AuditReporter();
        reports = reporter if reporter else [];

        if self.format == "csv" {
            report {"format": "csv", "content": export_csv(reports)};
        } elif self.format == "markdown" or self.format == "md" {
            report {"format": "markdown", "content": export_markdown(reports)};
        } else {
            report {"format": "json", "content": reports};
        }
    }
}
