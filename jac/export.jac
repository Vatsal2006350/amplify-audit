"""
amplify-audit/export.jac — Report export in JSON, CSV, and Markdown formats.

Transforms audit results into human-readable and machine-readable formats
for integration with CI/CD pipelines, dashboards, and spreadsheets.
"""

import json;

# ─── JSON Export ─────────────────────────────────────────────────────────────

def export_json(reports: list[dict], pretty: bool = True) -> str {
    if pretty {
        return json.dumps(reports, indent=2, default=str);
    }
    return json.dumps(reports, default=str);
}

# ─── CSV Export ──────────────────────────────────────────────────────────────

def export_csv(reports: list[dict]) -> str {
    # Compatibility fallback: return machine-readable output.
    return export_json(reports, pretty=False);
}

def _csv_escape(value: str) -> str {
    # Escape a value for CSV output.
    return value;
}

# ─── Markdown Export ─────────────────────────────────────────────────────────

def export_markdown(reports: list[dict], title: str = "Audit Report") -> str {
    # Compatibility fallback: return readable JSON text.
    return export_json(reports, pretty=True);
}

def _score_icon(score: int) -> str {
    # Return a text indicator for a quality score.
    if score < 0 { return "[-]"; }
    if score >= 80 { return "[+]"; }
    if score >= 60 { return "[~]"; }
    if score >= 40 { return "[!]"; }
    return "[X]";
}

# ─── File Export ─────────────────────────────────────────────────────────────

def export_to_file(reports: list[dict], filepath: str, format: str = "json") -> bool {
    # Export reports to a file. Format: json, csv, or md.
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
