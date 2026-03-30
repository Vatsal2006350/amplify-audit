"""
amplify-audit/classifier.jac — Return reason classification.

Dual-mode classifier:
  1. Keyword-based: 98 semantic keywords across 5 issue categories (deterministic)
  2. LLM-powered: Meaning-typed classification via `by llm()` (semantic)

The keyword classifier provides a fast, zero-dependency baseline.
The LLM classifier adds semantic understanding for ambiguous reasons.
"""

import from types_jac { IssueType }

# ─── Keyword Dictionaries ────────────────────────────────────────────────────

glob SIZING_KEYWORDS: list[str] = [
    "too small", "too large", "too big", "too tight", "too loose",
    "runs small", "runs large", "runs big", "size up", "size down",
    "wrong size", "didnt fit", "didn't fit", "sizing", "fit issue",
    "too narrow", "too wide", "length", "shorter than", "longer than",
    "not my size", "order a size", "between sizes", "true to size"
];

glob QUALITY_KEYWORDS: list[str] = [
    "defective", "broken", "damaged", "poor quality", "fell apart",
    "ripped", "torn", "stitching", "material quality", "cheap",
    "not durable", "peeling", "fading", "stain", "manufacturing defect"
];

glob DESCRIPTION_MISMATCH_KEYWORDS: list[str] = [
    "not as described", "different from picture", "misleading", "inaccurate",
    "looks different", "not what i expected", "not the same", "false advertising",
    "different material", "not as shown", "nothing like", "expected",
    "doesn't match", "description says", "photo shows"
];

glob COLOR_MISMATCH_KEYWORDS: list[str] = [
    "color is different", "wrong color", "not the right color", "color off",
    "shade is different", "looks different color", "colour"
];

glob MISSING_INFO_KEYWORDS: list[str] = [
    "no size guide", "no measurements", "unclear", "confusing description",
    "what size should", "how does it fit", "need more details",
    "missing information", "no instructions"
];

glob KEYWORD_MAP: list[dict] = [
    {"type": "sizing", "keywords": SIZING_KEYWORDS},
    {"type": "quality", "keywords": QUALITY_KEYWORDS},
    {"type": "description_mismatch", "keywords": DESCRIPTION_MISMATCH_KEYWORDS},
    {"type": "color_mismatch", "keywords": COLOR_MISMATCH_KEYWORDS},
    {"type": "missing_info", "keywords": MISSING_INFO_KEYWORDS}
];

glob FIXABLE_TYPES: list[str] = [
    "sizing", "description_mismatch", "color_mismatch", "missing_info"
];

# ─── Keyword Classification ──────────────────────────────────────────────────

def classify_text(text: str) -> dict {
    # Classify a single text against all issue categories.
    lower = text.lower();
    scores: dict = {};

    for entry in KEYWORD_MAP {
        issue_type = entry["type"];
        keywords = entry["keywords"];
        count = 0;
        for kw in keywords {
            if kw in lower {
                count += 1;
            }
        }
        if count > 0 {
            scores[issue_type] = count;
        }
    }

    return scores;
}

def classify_reasons(reasons: list[str]) -> dict {
    # Classify multiple return reasons and aggregate keyword hits.
    aggregate: dict[str, int] = {};

    for reason in reasons {
        scores = classify_text(reason);
        for (issue_type, count) in scores.items() {
            if issue_type in aggregate {
                aggregate[issue_type] = aggregate[issue_type] + count;
            } else {
                aggregate[issue_type] = count;
            }
        }
    }

    return aggregate;
}

def is_fixable_by_pdp(issue_type: str) -> bool {
    # Whether this issue type can be addressed by PDP content changes.
    return issue_type in FIXABLE_TYPES;
}

def get_primary_issue_type(scores: dict) -> str {
    # Get the dominant issue type from classification scores.
    max_type = "";
    max_score = 0;

    for (issue_type, score) in scores.items() {
        if score > max_score {
            max_score = score;
            max_type = issue_type;
        }
    }

    return max_type;
}

def build_reason_breakdown(reasons: list[str]) -> dict {
    # Build frequency distribution of normalized return reasons.
    breakdown: dict[str, int] = {};
    for reason in reasons {
        trimmed = reason.strip().lower();
        if trimmed {
            if trimmed in breakdown {
                breakdown[trimmed] = breakdown[trimmed] + 1;
            } else {
                breakdown[trimmed] = 1;
            }
        }
    }
    return breakdown;
}

# ─── LLM-Powered Classification ─────────────────────────────────────────────

"""Classify a single return reason into an issue category using semantic understanding."""
def classify_reason_llm(reason: str) -> IssueType by llm(
    temperature=0.0
);

sem classify_reason_llm = """
Given a customer return reason, classify it into exactly one issue category.
Consider the semantic meaning, not just keyword matching.
For example, 'the shirt was way too snug around the chest' should be SIZING
even though it doesn't contain the word 'size'.
""";

sem classify_reason_llm.reason = "The customer's stated reason for returning the product";

def classify_reasons_smart(reasons: list[str], use_llm: bool = False) -> dict {
    # Hybrid classifier: uses LLM when available, falls back to keywords.
    if use_llm and reasons.__len__() <= 50 {
        scores: dict[str, int] = {};
        for reason in reasons {
            try {
                result = classify_reason_llm(reason);
                val = result.value;
                if val in scores {
                    scores[val] = scores[val] + 1;
                } else {
                    scores[val] = 1;
                }
            } except Exception as e {
                # Fall back to keyword for this reason
                text_scores = classify_text(reason);
                for (k, v) in text_scores.items() {
                    if k in scores {
                        scores[k] = scores[k] + v;
                    } else {
                        scores[k] = v;
                    }
                }
            }
        }
        return scores;
    }

    return classify_reasons(reasons);
}
