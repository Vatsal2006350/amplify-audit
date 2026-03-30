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

import from types_jac {
    Product, Brand, Category, ReturnEvidence,
    Variant, AuditIssue, RecommendedFix,
    BelongsToBrand, InCategory, HasReturn
}
import from walkers {
    QualityAnalyzer, ReturnAnalyzer, RecommendationWalker,
    AiEnricher, BrandAggregator, AuditReporter
}
import from seo_analyzer { SEOAnalyzer }
import from trend_analyzer { TrendAnalyzer, analyze_trends }
import from fetcher { fetch_product, fetch_store, detect_platform }
import from export { export_json, export_csv, export_markdown, export_to_file }
import sys;
import json;
import os;

# ─── Graph Construction ──────────────────────────────────────────────────────

def build_product_graph(
    products: list[dict],
    return_data: dict | None = None
) -> None {
    # Ingest raw products into the graph rooted at `root`.
    brand_map: dict[str, Brand] = {};

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
            brand_node = brand_map[vendor];
            brand_node ++> product;
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
    # Audit a single product listing through the walker pipeline.
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
    if reporter and hasattr(reporter, "reports") and reporter.reports {
        return reporter.reports[0];
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
    # Audit an entire product catalog and return aggregate results.
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
    reports = reporter.reports if reporter and hasattr(reporter, "reports") else [];

    # Compute summary statistics
    total = reports.__len__();
    total_score = 0;
    scored = 0;
    critical = 0;
    fixable = 0;
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
            "avg_quality": (total_score / scored) if scored > 0 else 0.0,
            "critical_count": critical,
            "fixable_count": fixable
        }
    };
}

# ─── CLI Argument Parsing ────────────────────────────────────────────────────

def parse_args() -> dict {
    # Parse command-line arguments.
    raw_args: list[str] = [a for a in sys.argv[1:]];
    args: list[str] = [];
    for a in raw_args {
        if a in ["run", "main.jac", "jac/main.jac"] {
            continue;
        }
        args.append(a);
    }
    opts: dict = {
        "url": "",
        "store": False,
        "ai": False,
        "seo": True,
        "format": "text",
        "output": "",
        "max_products": 50,
        "min_score": 0,
        "returns_file": "",
        "help": False
    };

    arg_count = args.__len__();
    i = 0;
    while i < arg_count {
        arg = args[i];
        if arg in ["--help", "-h"] {
            opts["help"] = True;
        } elif arg in ["--ai", "-a"] {
            opts["ai"] = True;
        } elif arg == "--no-seo" {
            opts["seo"] = False;
        } elif arg in ["--store", "-s"] {
            opts["store"] = True;
        } elif arg in ["--json", "-j"] {
            opts["format"] = "json";
        } elif arg == "--csv" {
            opts["format"] = "csv";
        } elif arg == "--markdown" or arg == "--md" {
            opts["format"] = "markdown";
        } elif arg in ["--output", "-o"] and i + 1 < arg_count {
            i += 1;
            opts["output"] = args[i];
        } elif arg == "--max" and i + 1 < arg_count {
            i += 1;
            opts["max_products"] = int(args[i]);
        } elif arg == "--min-score" and i + 1 < arg_count {
            i += 1;
            opts["min_score"] = int(args[i]);
        } elif arg == "--returns" and i + 1 < arg_count {
            i += 1;
            opts["returns_file"] = args[i];
        } elif not arg.startswith("-") and not opts["url"] {
            opts["url"] = arg;
        }
        i += 1;
    }
    if not opts["url"] {
        env_url = os.getenv("AMPLIFY_AUDIT_URL");
        if env_url {
            opts["url"] = env_url;
        }
    }
    return opts;
}

def print_help() -> None {
    # Print CLI usage help.
    print("amplify-audit: Data-Spatial Product Quality Analysis");
    print("====================================================");
    print("");
    print("Usage:");
    print("  AMPLIFY_AUDIT_URL=<url> jac run main.jac           Audit a single product");
    print("  AMPLIFY_AUDIT_URL=<url> jac run main.jac --store   Audit an entire store");
    print("  jac start api.jac                Start REST API server");
    print("");
    print("Options:");
    print("  <url>                Product or store URL to audit");
    print("  --store, -s          Treat URL as a store (fetch all products)");
    print("  --ai, -a             Enable AI-powered analysis (requires ANTHROPIC_API_KEY)");
    print("  --no-seo             Skip SEO analysis");
    print("  --json, -j           Output as JSON");
    print("  --csv                Output as CSV");
    print("  --markdown, --md     Output as Markdown");
    print("  --output, -o <file>  Write output to file");
    print("  --max <n>            Max products to fetch from store (default: 50)");
    print("  --min-score <n>      Only show products below this score (default: 0)");
    print("  --returns <file>     JSON file with return data");
    print("  --help, -h           Show this help");
    print("");
    print("Examples:");
    print("  AMPLIFY_AUDIT_URL=https://allbirds.com/products/mens-tree-runners jac run main.jac");
    print("  AMPLIFY_AUDIT_URL=https://allbirds.com jac run main.jac --store --json -o report.json");
    print("  AMPLIFY_AUDIT_URL=https://amazon.com/dp/B08N5WRWNW jac run main.jac --ai");
    print("");
    print("API Server:");
    print("  jac start api.jac --port 8002");
    print("  curl -X POST http://localhost:8002/walker/audit_product \\");
    print('    -H "Content-Type: application/json" \\');
    print('    -d \'{"url": "https://allbirds.com/products/mens-tree-runners"}\'');
}

def print_report(report_data: dict, min_score: int = 0) -> None {
    # Pretty-print a single product audit report.
    title = report_data.get("title", "Unknown");
    score = report_data.get("quality_score", -1);
    url = report_data.get("url", "");

    if min_score > 0 and score >= min_score {
        return;
    }

    # Score indicator
    if score >= 80 { indicator = "[GOOD]"; }
    elif score >= 60 { indicator = "[OK]"; }
    elif score >= 40 { indicator = "[WARN]"; }
    elif score >= 0 { indicator = "[POOR]"; }
    else { indicator = "[N/A]"; }

    print(f"\n{indicator} {title}");
    print(f"  URL: {url}");
    print(f"  Quality Score: {score}/100");

    # Issues
    issues = report_data.get("issues", []);
    if issues {
        errors = [i for i in issues if i.get("severity") == "error"];
        warnings = [i for i in issues if i.get("severity") == "warning"];
        print(f"  Issues: {len(errors)} errors, {len(warnings)} warnings");
        for i in errors[:3] {
            print(f"    [ERROR] {i.get('message', '')}");
        }
        for i in warnings[:3] {
            print(f"    [WARN]  {i.get('message', '')}");
        }
    }

    # Return risk
    risk = report_data.get("return_risk", None);
    if isinstance(risk, dict) and risk.get("score") {
        print(f"  Return Risk: {risk['score']}");
        if risk.get("primary_issue_type") {
            print(f"  Primary Issue: {risk['primary_issue_type']}");
        }
        if risk.get("fixable_by_pdp") {
            print(f"  Fixable by PDP: Yes");
        }
    }

    # Recommendations
    recs = report_data.get("recommendations", []);
    if recs {
        print(f"  Recommendations: {len(recs)}");
        for r in recs[:2] {
            print(f"    - {r.get('field', '')}: {r.get('rationale', '')}");
        }
    }
}

def dedupe_reports(reports: list[dict]) -> list[dict] {
    unique: list[dict] = [];
    seen: dict[str, bool] = {};
    for r in reports {
        key = f"{r.get('url', '')}|{r.get('title', '')}";
        if key not in seen {
            seen[key] = True;
            unique.append(r);
        }
    }
    return unique;
}

# ─── Entry Point ─────────────────────────────────────────────────────────────

with entry {
    opts = parse_args();

    if opts["help"] or not opts["url"] {
        print_help();
    } else {
        url = opts["url"];
        print(f"amplify-audit: Analyzing {url}...");
        print("");

        # Load return data if provided
        return_data: dict | None = None;
        if opts["returns_file"] {
            try {
                with open(opts["returns_file"], "r") as f {
                    return_data = json.load(f);
                }
            } except Exception as e {
                print(f"Warning: Could not load returns file: {e}");
            }
        }

        if opts["store"] {
            # Store-wide audit
            print(f"Fetching products from store (max {opts['max_products']})...");
            products = fetch_store(url, opts["max_products"]);
            print(f"Fetched {products.__len__()} products. Building graph...");

            result = audit_catalog(products, return_data, opts["ai"], min(20, opts["max_products"]));

            # SEO analysis
            if opts["seo"] {
                root spawn SEOAnalyzer();
            }

            # Trend analysis
            trend_walker = root spawn TrendAnalyzer();
            trends = analyze_trends(trend_walker) if trend_walker else {};
            result["trends"] = trends;

            # Output
            reports = result.get("products", []);
            reports = dedupe_reports(reports);
            if opts["format"] == "json" {
                output = export_json([result]);
                if opts["output"] {
                    export_to_file([result], opts["output"], "json");
                    print(f"Report saved to {opts['output']}");
                } else {
                    print(output);
                }
            } elif opts["format"] == "csv" {
                output = export_csv(reports);
                if opts["output"] {
                    with open(opts["output"], "w") as f {
                        f.write(output);
                    }
                    print(f"CSV saved to {opts['output']}");
                } else {
                    print(output);
                }
            } elif opts["format"] == "markdown" {
                output = export_markdown(reports, title=f"Audit Report: {url}");
                if opts["output"] {
                    with open(opts["output"], "w") as f {
                        f.write(output);
                    }
                    print(f"Markdown report saved to {opts['output']}");
                } else {
                    print(output);
                }
            } else {
                # Pretty text output
                summary = result.get("summary", {});
                print(f"Products: {summary.get('total', 0)}");
                print(f"Average Quality: {summary.get('avg_quality', 0)}/100");
                print(f"Critical: {summary.get('critical_count', 0)}");
                print(f"Fixable: {summary.get('fixable_count', 0)}");

                for r in reports {
                    if isinstance(r, dict) {
                        print_report(r, opts["min_score"]);
                    }
                }

                # Trends summary
                if trends and trends.get("summary") {
                    print(f"\n--- Trends ---");
                    print(trends["summary"]);
                }
            }
        } else {
            # Single product audit
            print("Fetching product data...");
            product_data = fetch_product(url);

            if not product_data.get("title", "") {
                print(f"Error: Could not fetch product data from {url}");
            } else {
                print(f"Product: {product_data.get('title', '')}");
                print(f"Platform: {product_data.get('platform', 'unknown')}");
                print("");

                result = audit_single(product_data, return_data, opts["ai"]);

                # SEO analysis
                if opts["seo"] {
                    root spawn SEOAnalyzer();
                }

                # Re-collect report with SEO data
                reporter = root spawn AuditReporter();
                reports = reporter.reports if reporter and hasattr(reporter, "reports") else [];
                reports = dedupe_reports(reports);

                if opts["format"] == "json" {
                    output = export_json(reports);
                    if opts["output"] {
                        export_to_file(reports, opts["output"], "json");
                        print(f"Report saved to {opts['output']}");
                    } else {
                        print(output);
                    }
                } elif opts["format"] == "csv" {
                    output = export_csv(reports);
                    if opts["output"] {
                        with open(opts["output"], "w") as f {
                            f.write(output);
                        }
                        print(f"CSV saved to {opts['output']}");
                    } else {
                        print(output);
                    }
                } elif opts["format"] == "markdown" {
                    output = export_markdown(reports);
                    if opts["output"] {
                        with open(opts["output"], "w") as f {
                            f.write(output);
                        }
                        print(f"Markdown report saved to {opts['output']}");
                    } else {
                        print(output);
                    }
                } else {
                    for r in reports {
                        if isinstance(r, dict) {
                            print_report(r, opts["min_score"]);
                        }
                    }
                }
            }
        }
    }
}
