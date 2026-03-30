"""
amplify-audit/seo_analyzer.jac — SEO-specific quality analysis walker.

Evaluates product listings for search engine optimization quality:
  - Title keyword density and structure
  - URL slug analysis
  - Image alt text coverage
  - Description keyword richness
  - Schema.org structured data readiness
  - Mobile-friendliness signals
"""

import re;
import from types_jac { Product, Brand, AuditIssue }

# ─── SEO Constants ───────────────────────────────────────────────────────────

glob SEO_TITLE_MIN: int = 30;
glob SEO_TITLE_MAX: int = 70;
glob SEO_TITLE_OPTIMAL: int = 55;
glob SEO_DESC_MIN: int = 120;
glob SEO_DESC_MAX: int = 320;
glob SEO_MIN_IMAGES: int = 3;
glob SEO_MIN_TAGS: int = 3;

# Common filler words to exclude from keyword analysis
glob STOP_WORDS: list[str] = [
    "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
    "of", "with", "by", "from", "is", "it", "this", "that", "are", "was",
    "be", "has", "had", "do", "does", "did", "will", "would", "could",
    "should", "may", "might", "can", "not", "no", "so", "if", "than",
    "too", "very", "just", "about", "up", "out", "new", "one", "all"
];

# High-value e-commerce keywords that should appear in titles/descriptions
glob POWER_WORDS: list[str] = [
    "free", "sale", "best", "premium", "exclusive", "limited",
    "organic", "natural", "handmade", "sustainable", "eco",
    "waterproof", "lightweight", "durable", "comfortable", "soft"
];

# ─── SEO Analysis Functions ──────────────────────────────────────────────────

def analyze_title_seo(title: str) -> dict {
    issues: list[dict] = [];
    score = 100;
    words = title.split();
    char_count = title.__len__();

    # Length check
    if char_count < SEO_TITLE_MIN {
        issues.append({
            "severity": "warning",
            "category": "seo",
            "message": f"Title too short for SEO ({char_count} chars, aim for {SEO_TITLE_MIN}-{SEO_TITLE_MAX})"
        });
        score -= 15;
    } elif char_count > SEO_TITLE_MAX {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": f"Title may be truncated in search results ({char_count} chars, max {SEO_TITLE_MAX})"
        });
        score -= 5;
    }

    # Word count (ideal 6-12 words)
    if words.__len__() < 4 {
        issues.append({
            "severity": "warning",
            "category": "seo",
            "message": "Title has too few words for keyword optimization"
        });
        score -= 10;
    }

    # Keyword stuffing (same word >3 times)
    word_freq: dict = {};
    for w in words {
        lower_w = w.lower().strip(".,!?;:-");
        if lower_w not in STOP_WORDS and len(lower_w) > 2 {
            if lower_w in word_freq {
                word_freq[lower_w] = word_freq[lower_w] + 1;
            } else {
                word_freq[lower_w] = 1;
            }
        }
    }
    for (word, count) in word_freq.items() {
        if count > 3 {
            issues.append({
                "severity": "warning",
                "category": "seo",
                "message": f"Possible keyword stuffing: '{word}' appears {count} times"
            });
            score -= 10;
        }
    }

    # All caps check
    upper_count = 0;
    for c in title {
        if c.isupper() {
            upper_count += 1;
        }
    }
    if char_count > 0 and upper_count / char_count > 0.5 {
        issues.append({
            "severity": "warning",
            "category": "seo",
            "message": "Excessive capitalization hurts readability and may be penalized"
        });
        score -= 10;
    }

    # Special characters
    if re.search(r'[!@#$%^&*()]{2,}', title) {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": "Avoid excessive special characters in title"
        });
        score -= 5;
    }

    # Power words bonus
    lower_title = title.lower();
    power_found = [w for w in POWER_WORDS if w in lower_title];
    if power_found.__len__() > 0 {
        score = min(100, score + 5);
    }

    return {"score": max(0, score), "issues": issues, "word_count": words.__len__(), "power_words": power_found};
}

def analyze_description_seo(description: str) -> dict {
    issues: list[dict] = [];
    score = 100;
    char_count = description.__len__();
    words = description.split();

    if char_count < SEO_DESC_MIN {
        issues.append({
            "severity": "warning",
            "category": "seo",
            "message": f"Description too short for SEO ({char_count} chars, aim for {SEO_DESC_MIN}+)"
        });
        score -= 20;
    }

    # Keyword diversity
    unique_words: set = set();
    for w in words {
        lower_w = w.lower().strip(".,!?;:-");
        if lower_w not in STOP_WORDS and len(lower_w) > 2 {
            unique_words.add(lower_w);
        }
    }
    keyword_ratio = unique_words.__len__() / words.__len__() if words.__len__() > 0 else 0;
    if keyword_ratio < 0.3 {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": "Low keyword diversity in description — use more varied terminology"
        });
        score -= 10;
    }

    # Check for structured content signals (bullets, sizing, etc.)
    has_bullets = "•" in description or "- " in description or "✓" in description;
    has_measurements = bool(re.search(r'\d+\s*(?:inch|cm|mm|oz|lb|kg|ml|")', description, re.IGNORECASE));
    has_materials = bool(re.search(r'(?:cotton|polyester|silk|leather|wool|nylon|organic|recycled)', description, re.IGNORECASE));

    if not has_bullets and char_count > 200 {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": "Consider using bullet points for better scannability"
        });
    }
    if has_measurements {
        score = min(100, score + 5);
    }
    if has_materials {
        score = min(100, score + 5);
    }

    return {
        "score": max(0, score),
        "issues": issues,
        "keyword_count": unique_words.__len__(),
        "keyword_ratio": round(keyword_ratio, 2),
        "has_structured_content": has_bullets,
        "has_measurements": has_measurements,
        "has_materials": has_materials
    };
}

def analyze_url_slug(url: str) -> dict {
    issues: list[dict] = [];
    score = 100;

    # Extract path
    path = url.split("?")[0].split("#")[0];
    parts = path.rstrip("/").split("/");
    slug = parts[-1] if parts else "";

    if not slug {
        return {"score": 50, "issues": [{"severity": "info", "category": "seo", "message": "Could not extract URL slug"}], "slug": ""};
    }

    # Length check
    if slug.__len__() > 75 {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": f"URL slug is long ({slug.__len__()} chars) — shorter slugs rank better"
        });
        score -= 10;
    }

    # Readability: hyphens vs underscores
    if "_" in slug {
        issues.append({
            "severity": "info",
            "category": "seo",
            "message": "URL uses underscores — hyphens are preferred for SEO"
        });
        score -= 5;
    }

    # Numeric-only slugs
    if slug.replace("-", "").replace("_", "").isdigit() {
        issues.append({
            "severity": "warning",
            "category": "seo",
            "message": "URL slug is numeric-only — use descriptive keywords"
        });
        score -= 20;
    }

    return {"score": max(0, score), "issues": issues, "slug": slug};
}

def compute_seo_score(
    title_result: dict,
    desc_result: dict,
    url_result: dict,
    image_count: int,
    tag_count: int
) -> dict {
    # Compute overall SEO score from component analyses.
    all_issues: list[dict] = [];
    all_issues.extend(title_result.get("issues", []));
    all_issues.extend(desc_result.get("issues", []));
    all_issues.extend(url_result.get("issues", []));

    # Image count check
    if image_count < SEO_MIN_IMAGES {
        all_issues.append({
            "severity": "warning",
            "category": "seo",
            "message": f"Only {image_count} images — aim for {SEO_MIN_IMAGES}+ for better conversion"
        });
    }

    # Tag count check
    if tag_count < SEO_MIN_TAGS {
        all_issues.append({
            "severity": "info",
            "category": "seo",
            "message": f"Only {tag_count} tags — more tags improve discoverability"
        });
    }

    # Weighted composite
    title_weight = 0.35;
    desc_weight = 0.30;
    url_weight = 0.15;
    image_weight = 0.10;
    tag_weight = 0.10;

    image_score = min(100, image_count * 20);
    tag_score = min(100, tag_count * 15);

    composite = (
        title_result["score"] * title_weight +
        desc_result["score"] * desc_weight +
        url_result["score"] * url_weight +
        image_score * image_weight +
        tag_score * tag_weight
    );

    return {
        "seo_score": max(0, min(100, composite)),
        "title_score": title_result["score"],
        "description_score": desc_result["score"],
        "url_score": url_result["score"],
        "issues": all_issues,
        "power_words": title_result.get("power_words", []),
        "keyword_count": desc_result.get("keyword_count", 0)
    };
}

# ─── SEO Walker ──────────────────────────────────────────────────────────────

walker SEOAnalyzer {
    has analyzed_count: int = 0;
    has seo_results: list[dict] = [];

    can start with `root entry {
        visit [-->](`?Product);
    }

    can analyze_seo with Product entry {
        title_result = analyze_title_seo(here.title);
        desc_result = analyze_description_seo(here.description);
        url_result = analyze_url_slug(here.url);

        seo = compute_seo_score(
            title_result,
            desc_result,
            url_result,
            here.images.__len__(),
            here.tags.__len__()
        );

        # Append SEO issues to product's issue list
        for issue_dict in seo["issues"] {
            here.issues.append(AuditIssue(
                severity=issue_dict["severity"],
                category=issue_dict["category"],
                message=issue_dict["message"]
            ));
        }

        result = {
            "url": here.url,
            "title": here.title,
            "seo_score": seo["seo_score"],
            "title_score": seo["title_score"],
            "description_score": seo["description_score"],
            "url_score": seo["url_score"],
            "power_words": seo["power_words"],
            "keyword_count": seo["keyword_count"],
            "issue_count": seo["issues"].__len__()
        };

        self.seo_results.append(result);
        self.analyzed_count += 1;
    }

    can traverse_brand with Brand entry {
        visit [-->](`?Product);
    }
}
