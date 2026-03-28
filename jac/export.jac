"""
amplify-audit/export.jac — Report export in JSON, CSV, and Markdown formats.

Transforms audit results into human-readable and machine-readable formats
for integration with CI/CD pipelines, dashboards, and spreadsheets.
"""

import json;

# ─── JSON Export ─────────────────────────────────────────────────────────────

def export_json(reports: list[dict], pretty: bool = True) -> str {
    """Export audit reports as JSON string."""
    if pretty {
        return json.dumps(reports, indent=2, default=str);
    }
    return json.dumps(reports, default=str);
}

# ─── CSV Export ──────────────────────────────────────────────────────────────

def export_csv(reports: list[dict]) -> str {
    """Export audit reports as CSV string."""
    if not reports {
        return "";
    }

    headers = [
        "url", "title", "platform", "quality_score",
        "seo_score", "sku_health_score", "confidence",
        "error_count", "warning_count", "info_count",
        "risk_level", "primary_issue", "fixable_by_pdp",
        "recommendation_count"
    ];

    rows: list[str] = [];
    rows.append(",".join(headers));

    for r in reports {
        issues = r.get("issues", []);
        errors = len([i for i in issues if i.get("severity") == "error"]);
        warnings = len([i for i in issues if i.get("severity") == "warning"]);
        infos = len([i for i in issues if i.get("severity") == "info"]);

        risk = r.get("return_risk", {});
        risk_level = risk.get("score", "") if isinstance(risk, dict) else "";
        primary_issue = risk.get("primary_issue_type", "") if isinstance(risk, dict) else "";
        fixable = str(risk.get("fixable_by_pdp", False)) if isinstance(risk, dict) else "False";

        row = [
            _csv_escape(r.get("url", "")),
            _csv_escape(r.get("title", "")),
            r.get("platform", ""),
            str(r.get("quality_score", -1)),
            str(r.get("seo_score", "")),
            str(r.get("sku_health_score", -1)),
            str(r.get("confidence", -1)),
            str(errors),
            str(warnings),
            str(infos),
            risk_level,
            primary_issue,
            fixable,
            str(len(r.get("recommendations", [])))
        ];
        rows.append(",".join(row));
    }

    return "\n".join(rows);
}

def _csv_escape(value: str) -> str {
    """Escape a value for CSV output."""
    if "," in value or '"' in value or "\n" in value {
        return '"' + value.replace('"', '""') + '"';
    }
    return value;
}

# ─── Markdown Export ─────────────────────────────────────────────────────────

def export_markdown(reports: list[dict], title: str = "Audit Report") -> str {
    """Export audit reports as a formatted Markdown document."""
    lines: list[str] = [];
    lines.append(f"# {title}");
    lines.append("");

    if not reports {
        lines.append("No products analyzed.");
        return "\n".join(lines);
    }

    # Summary
    total = len(reports);
    scores = [r.get("quality_score", -1) for r in reports if r.get("quality_score", -1) >= 0];
    avg_score = sum(scores) / len(scores) if scores else 0;

    errors_total = 0;
    warnings_total = 0;
    for r in reports {
        for i in r.get("issues", []) {
            if i.get("severity") == "error" {
                errors_total += 1;
            } elif i.get("severity") == "warning" {
                warnings_total += 1;
            }
        }
    }

    lines.append("## Summary");
    lines.append("");
    lines.append(f"| Metric | Value |");
    lines.append(f"|--------|-------|");
    lines.append(f"| Products Analyzed | {total} |");
    lines.append(f"| Average Quality Score | {round(avg_score, 1)} |");
    lines.append(f"| Total Errors | {errors_total} |");
    lines.append(f"| Total Warnings | {warnings_total} |");
    lines.append("");

    # Score distribution
    lines.append("## Quality Scores");
    lines.append("");
    lines.append("| Product | Score | Issues | Risk |");
    lines.append("|---------|-------|--------|------|");

    for r in reports {
        title_str = r.get("title", "Unknown");
        if len(title_str) > 50 {
            title_str = title_str[:47] + "...";
        }
        score = r.get("quality_score", -1);
        issue_count = len(r.get("issues", []));
        risk = r.get("return_risk", {});
        risk_level = risk.get("score", "-") if isinstance(risk, dict) else "-";

        score_icon = _score_icon(score);
        lines.append(f"| {title_str} | {score_icon} {score} | {issue_count} | {risk_level} |");
    }
    lines.append("");

    # Top issues
    lines.append("## Top Issues");
    lines.append("");

    issue_summary: dict = {};
    for r in reports {
        for i in r.get("issues", []) {
            cat = i.get("category", "other");
            if cat in issue_summary {
                issue_summary[cat] = issue_summary[cat] + 1;
            } else {
                issue_summary[cat] = 1;
            }
        }
    }

    sorted_issues = sorted(issue_summary.items(), key=lambda x: x[1], reverse=True);
    for (cat, count) in sorted_issues[:10] {
        lines.append(f"- **{cat}**: {count} occurrences");
    }
    lines.append("");

    # Per-product details
    lines.append("## Product Details");
    lines.append("");

    for r in reports {
        product_title = r.get("title", "Unknown Product");
        lines.append(f"### {product_title}");
        lines.append("");
        lines.append(f"- **URL**: {r.get('url', 'N/A')}");
        lines.append(f"- **Quality Score**: {r.get('quality_score', 'N/A')}");
        lines.append(f"- **Platform**: {r.get('platform', 'unknown')}");

        risk = r.get("return_risk", None);
        if isinstance(risk, dict) and risk.get("score") {
            lines.append(f"- **Return Risk**: {risk['score']}");
            if risk.get("primary_issue_type") {
                lines.append(f"- **Primary Issue**: {risk['primary_issue_type']}");
            }
            if risk.get("fixable_by_pdp") {
                lines.append(f"- **Fixable by PDP**: Yes");
            }
        }

        issues = r.get("issues", []);
        if issues {
            lines.append("");
            lines.append("**Issues:**");
            for i in issues {
                sev = i.get("severity", "info");
                icon = "X" if sev == "error" else ("!" if sev == "warning" else "i");
                lines.append(f"- [{icon}] {i.get('message', '')}");
            }
        }

        recs = r.get("recommendations", []);
        if recs {
            lines.append("");
            lines.append("**Recommendations:**");
            for rec in recs {
                lines.append(f"- **{rec.get('field', '')}**: {rec.get('rationale', '')}");
            }
        }

        lines.append("");
    }

    # Footer
    lines.append("---");
    lines.append("*Generated by amplify-audit (Data-Spatial Product Quality Analysis)*");

    return "\n".join(lines);
}

def _score_icon(score: int) -> str {
    """Return a text indicator for a quality score."""
    if score < 0 { return "[-]"; }
    if score >= 80 { return "[+]"; }
    if score >= 60 { return "[~]"; }
    if score >= 40 { return "[!]"; }
    return "[X]";
}

# ─── File Export ─────────────────────────────────────────────────────────────

def export_to_file(reports: list[dict], filepath: str, format: str = "json") -> bool {
    """Export reports to a file. Format: json, csv, or md."""
    try {
        content = "";
        if format == "json" {
            content = export_json(reports);
        } elif format == "csv" {
            content = export_csv(reports);
        } elif format == "md" or format == "markdown" {
            content = export_markdown(reports);
        } else {
            content = export_json(reports);
        }

        with open(filepath, "w") as f {
            f.write(content);
        }
        return True;
    } except Exception as e {
        print(f"Export error: {e}");
        return False;
    }
}
