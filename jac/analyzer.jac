"""
amplify-audit/analyzer.jac — Rule-based listing quality analyzer.

Implements programmatic PDP analysis as a pure function.
No external dependencies — works offline without API keys.

The analyzer checks: title quality, description completeness,
sizing/material/care info presence, image count, tags, price, and vendor.
"""

import from re { search as re_search, sub as re_sub }

# ─── HTML Stripping ──────────────────────────────────────────────────────────

def strip_html(html: str) -> str {
    # Remove HTML tags and normalize whitespace.
    text = re_sub("<[^>]*>", " ", html);
    text = re_sub("\\s+", " ", text);
    return text.strip();
}

# ─── Listing Quality Analysis ────────────────────────────────────────────────

def analyze_listing_quality(
    title: str,
    description: str,
    tags: list[str],
    images: list[str],
    price: str,
    vendor: str,
    source: str
) -> dict {
    # Analyze listing quality using rule-based heuristics.
    issues: list = [];
    is_search = source == "search";
    desc_text = strip_html(description);

    # ─── Title checks (always available) ─────────────────────────────
    if not title {
        issues.append({"severity": "error", "category": "title",
                       "message": "Product title is missing"});
    } else {
        title_len = title.__len__();
        if title_len < 20 {
            issues.append({"severity": "error", "category": "title",
                           "message": f"Title is too short ({title_len} chars). Aim for 50-80 characters."});
        } elif title_len < 50 {
            issues.append({"severity": "warning", "category": "title",
                           "message": f"Title could be longer ({title_len} chars). Optimal is 50-80 characters for SEO."});
        } elif title_len > 150 {
            issues.append({"severity": "warning", "category": "title",
                           "message": f"Title is very long ({title_len} chars). Consider trimming to under 150 characters."});
        }

        if title == title.upper() and title_len > 10 {
            issues.append({"severity": "warning", "category": "title",
                           "message": "Title is in ALL CAPS. Use title case for better readability."});
        }

        separators = title.split(",").__len__() + title.split("|").__len__() + title.split("/").__len__() - 2;
        if separators > 6 {
            issues.append({"severity": "info", "category": "title",
                           "message": "Title may have too many separators. Clean, readable titles convert better."});
        }
    }

    # ─── Description checks (skip for search results) ────────────────
    if not is_search {
        if not desc_text or desc_text.__len__() < 10 {
            issues.append({"severity": "error", "category": "description",
                           "message": "Product description is missing or empty"});
        } else {
            desc_len = desc_text.__len__();
            if desc_len < 100 {
                issues.append({"severity": "error", "category": "description",
                               "message": f"Description is too short ({desc_len} chars). Target 300-1000 characters."});
            } elif desc_len < 300 {
                issues.append({"severity": "warning", "category": "description",
                               "message": f"Description could be more detailed ({desc_len} chars). Target 300-1000 characters."});
            }

            lower_desc = desc_text.lower();

            has_sizing = bool(re_search(
                "\\b(size|sizing|fit|fits|measurement|dimensions|cm|inches|length|width|small|medium|large|xl)\\b",
                lower_desc
            ));
            if not has_sizing {
                issues.append({"severity": "warning", "category": "sizing",
                               "message": "No sizing or fit information found. This is the #1 driver of returns."});
            }

            has_material = bool(re_search(
                "\\b(material|fabric|cotton|polyester|leather|wool|linen|silk|nylon|synthetic|organic)\\b",
                lower_desc
            ));
            if not has_material {
                issues.append({"severity": "info", "category": "material",
                               "message": "No material/fabric information detected. Adding materials improves buyer confidence."});
            }

            has_care = bool(re_search(
                "\\b(wash|care|clean|dry|iron|machine wash|hand wash|tumble)\\b",
                lower_desc
            ));
            if not has_care {
                issues.append({"severity": "info", "category": "care",
                               "message": "No care instructions found. Consider adding washing/maintenance info."});
            }
        }
    }

    # ─── Image checks ────────────────────────────────────────────────
    if not is_search {
        if images.__len__() == 0 {
            issues.append({"severity": "error", "category": "images",
                           "message": "No product images found"});
        } elif images.__len__() < 3 {
            issues.append({"severity": "warning", "category": "images",
                           "message": f"Only {images.__len__()} image(s). Aim for 4+ images with lifestyle and detail shots."});
        }
    } else {
        if images.__len__() == 0 {
            issues.append({"severity": "warning", "category": "images",
                           "message": "No product image in listing"});
        }
    }

    # ─── Tag checks (skip for search) ────────────────────────────────
    if not is_search {
        if tags.__len__() == 0 {
            issues.append({"severity": "warning", "category": "tags",
                           "message": "No tags/categories found. Tags improve discoverability."});
        } elif tags.__len__() < 3 {
            issues.append({"severity": "info", "category": "tags",
                           "message": f"Only {tags.__len__()} tag(s). Consider adding more for better discoverability."});
        }
    }

    # ─── Price check ─────────────────────────────────────────────────
    if not price {
        issues.append({"severity": "warning", "category": "price",
                       "message": "No price information detected."});
    }

    # ─── Vendor check ────────────────────────────────────────────────
    if not is_search and not vendor {
        issues.append({"severity": "info", "category": "vendor",
                       "message": "No brand/vendor information. Adding brand name improves trust."});
    }

    # ─── Compute score ───────────────────────────────────────────────
    error_count = [i for i in issues if i["severity"] == "error"].__len__();
    warning_count = [i for i in issues if i["severity"] == "warning"].__len__();
    info_count = [i for i in issues if i["severity"] == "info"].__len__();

    quality_score = max(0, min(100, 100 - error_count * 20 - warning_count * 10 - info_count * 3));

    return {
        "quality_score": quality_score,
        "issues": issues
    };
}
