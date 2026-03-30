"""
amplify-audit/recommender.jac — Deterministic recommendation generator.

Generates PDP improvement suggestions based on detected issue types.
Works without an API key (template-based). For AI-powered recommendations,
see ai_analyzer.jac's generate_rewrite().
"""

import from re { search as re_search, sub as re_sub }

# ─── Helpers ─────────────────────────────────────────────────────────────────

def strip_html(html: str) -> str {
    text = re_sub("<[^>]*>", " ", html);
    text = re_sub("\\s+", " ", text);
    return text.strip();
}

def truncate(text: str, max_len: int) -> str {
    clean = strip_html(text);
    if clean.__len__() <= max_len {
        return clean;
    }
    return clean[:max_len] + "...";
}

def append_to_description(existing: str, addition: str) -> str {
    trimmed = existing.strip() if existing else "";
    if trimmed.__len__() < 10 {
        return addition;
    }
    return f"{truncate(trimmed, 300)}\n\n{addition}";
}

# ─── Recommendation Generation ───────────────────────────────────────────────

def generate_recommendations(
    title: str,
    description: str,
    primary_issue_type: str,
    return_rate: float
) -> list[dict] {
    # Generate PDP improvement recommendations based on detected issue type.
    fixes: list = [];

    # ─── Issue-specific fixes ────────────────────────────────────────

    if primary_issue_type == "sizing" {
        fixes.append({
            "field": "title",
            "before": title,
            "after": f"{title} (Runs Small — Consider Sizing Up)",
            "rationale": "Set expectations at the top of the listing to reduce fit-related returns."
        });
        fixes.append({
            "field": "description",
            "before": truncate(description, 200),
            "after": append_to_description(
                description,
                "<p><strong>Fit note:</strong> This style runs slightly small. If you're between sizes or prefer extra room, consider sizing up.</p>"
            ),
            "rationale": "Adds concrete fit guidance shoppers can act on before purchasing."
        });
    }

    if primary_issue_type == "description_mismatch" {
        fixes.append({
            "field": "description",
            "before": truncate(description, 200),
            "after": append_to_description(
                description,
                "<p><strong>What to expect:</strong> Please review material details and photos carefully. Color may appear slightly different depending on screen settings.</p>"
            ),
            "rationale": "Sets realistic expectations to reduce 'not as described' returns."
        });
    }

    if primary_issue_type == "color_mismatch" {
        fixes.append({
            "field": "description",
            "before": truncate(description, 200),
            "after": append_to_description(
                description,
                "<p><strong>Color note:</strong> Actual color may vary slightly from photos due to screen differences and lighting. See all product images for the most accurate representation.</p>"
            ),
            "rationale": "Preemptively addresses color expectation gaps, a common return driver."
        });
    }

    if primary_issue_type == "missing_info" {
        missing: list[str] = [];
        lower = description.lower() if description else "";
        if not re_search("\\b(size|sizing|fit|measurement)\\b", lower) {
            missing.append("sizing/fit information");
        }
        if not re_search("\\b(material|fabric|cotton|polyester)\\b", lower) {
            missing.append("material details");
        }
        if not re_search("\\b(wash|care|clean)\\b", lower) {
            missing.append("care instructions");
        }

        if missing.__len__() > 0 {
            placeholders = " ".join([f"[Add {m}]" for m in missing]);
            missing_str = "";
            idx = 0;
            for m in missing {
                if idx > 0 {
                    missing_str = f"{missing_str}, ";
                }
                missing_str = f"{missing_str}{m}";
                idx += 1;
            }
            fixes.append({
                "field": "description",
                "before": truncate(description, 200),
                "after": append_to_description(
                    description,
                    f"<p><strong>Details:</strong> {placeholders}</p>"
                ),
                "rationale": f"Missing critical product info: {missing_str}. Adding these reduces uncertainty-driven returns."
            });
        }
    }

    # ─── Generic fixes ───────────────────────────────────────────────

    if title and title.__len__() < 30 {
        fixes.append({
            "field": "title",
            "before": title,
            "after": f"{title} — [Add key features, material, size range]",
            "rationale": "Short titles miss SEO keywords and leave buyers without context."
        });
    }

    desc_text = strip_html(description) if description else "";
    if desc_text.__len__() < 50 {
        fixes.append({
            "field": "description",
            "before": description if description else "(empty)",
            "after": "[Add 300-1000 character description covering: key features, sizing/fit, materials, care instructions, and what makes this product stand out]",
            "rationale": "Empty or very short descriptions are the single biggest driver of preventable returns."
        });
    }

    return fixes;
}
