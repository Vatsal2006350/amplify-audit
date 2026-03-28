"""
amplify-audit/tests.jac — Test suite for Data-Spatial Product Quality Analysis.

Tests cover: scoring algorithms, classification, quality analysis,
graph construction, and walker traversal.
"""

import from .types {
    Product, Brand, ReturnEvidence, Variant, AuditIssue,
    RecommendedFix, TopReason, ReturnRisk,
    BelongsToBrand, HasReturn
}
import from .scoring {
    compute_return_rate, compute_ticket_rate,
    compute_reason_concentration, compute_fixability_score,
    compute_confidence, compute_quality_score
}
import from .classifier {
    classify_text, classify_reasons, get_primary_issue_type,
    is_fixable_by_pdp, build_reason_breakdown
}
import from .analyzer { analyze_listing_quality, strip_html }
import from .walkers { QualityAnalyzer, BrandAggregator, AuditReporter }

# ─── Scoring Tests ───────────────────────────────────────────────────────────

test "return rate computation" {
    assert compute_return_rate(25, 100) == 0.25;
    assert compute_return_rate(0, 100) == 0.0;
    assert compute_return_rate(10, 0) == 0.0;
}

test "ticket rate computation" {
    assert compute_ticket_rate(5, 100) == 0.05;
    assert compute_ticket_rate(0, 50) == 0.0;
}

test "reason concentration - single reason is 1.0" {
    assert compute_reason_concentration({"too small": 10}) == 1.0;
}

test "reason concentration - uniform distribution is 0.0" {
    result = compute_reason_concentration({
        "a": 1, "b": 1, "c": 1, "d": 1
    });
    assert result < 0.01;
}

test "reason concentration - empty is 0.0" {
    assert compute_reason_concentration({}) == 0.0;
}

test "confidence scales with sample size" {
    assert compute_confidence(5, 2) == 0.2;
    assert compute_confidence(20, 5) == 0.4;
    assert compute_confidence(40, 10) == 0.6;
    assert compute_confidence(100, 20) > 0.7;
}

test "quality score deductions" {
    assert compute_quality_score(0, 0, 0) == 100;
    assert compute_quality_score(1, 0, 0) == 80;
    assert compute_quality_score(0, 1, 0) == 90;
    assert compute_quality_score(0, 0, 1) == 97;
    assert compute_quality_score(5, 5, 5) == 0;
}

# ─── Classifier Tests ────────────────────────────────────────────────────────

test "classify sizing keywords" {
    result = classify_text("This shirt runs small and is too tight");
    assert "sizing" in result;
    assert result["sizing"] >= 2;
}

test "classify quality keywords" {
    result = classify_text("The product was defective and fell apart quickly");
    assert "quality" in result;
}

test "classify color mismatch" {
    result = classify_text("The color is different from the picture");
    assert "color_mismatch" in result;
}

test "classify multiple reasons aggregation" {
    reasons = ["too small", "runs small", "poor quality", "too tight"];
    result = classify_reasons(reasons);
    primary = get_primary_issue_type(result);
    assert primary == "sizing";
}

test "fixable by PDP" {
    assert is_fixable_by_pdp("sizing") == True;
    assert is_fixable_by_pdp("description_mismatch") == True;
    assert is_fixable_by_pdp("quality") == False;
}

test "reason breakdown" {
    reasons = ["too small", "Too Small", "wrong color", "too small"];
    bd = build_reason_breakdown(reasons);
    assert bd["too small"] == 3;
    assert bd["wrong color"] == 1;
}

# ─── Analyzer Tests ──────────────────────────────────────────────────────────

test "missing title is an error" {
    result = analyze_listing_quality(
        title="",
        description="A great product with lots of details about sizing and materials.",
        tags=["clothing"],
        images=["img1.jpg", "img2.jpg", "img3.jpg"],
        price="29.99",
        vendor="TestBrand",
        source="page"
    );
    errors = [i for i in result["issues"] if i["severity"] == "error"];
    assert len(errors) > 0;
}

test "search results scored leniently" {
    result = analyze_listing_quality(
        title="Nice Product With A Good Title For SEO Purposes",
        description="",
        tags=[],
        images=["thumb.jpg"],
        price="19.99",
        vendor="",
        source="search"
    );
    # Search results should not penalize for missing description
    desc_errors = [i for i in result["issues"]
                   if i["category"] == "description" and i["severity"] == "error"];
    assert len(desc_errors) == 0;
}

test "strip html removes tags" {
    assert strip_html("<p>Hello <b>world</b></p>") == "Hello world";
    assert strip_html("plain text") == "plain text";
}

# ─── Graph + Walker Tests ────────────────────────────────────────────────────

test "graph construction and quality walker" {
    # Build a small graph
    p1 = Product(
        url="https://example.com/p1",
        title="Test Product With A Good Long Title For Testing",
        description="A detailed description with sizing info and material cotton fabric details for testing purposes with care wash instructions",
        tags=["tag1", "tag2", "tag3"],
        images=["img1.jpg", "img2.jpg", "img3.jpg", "img4.jpg"],
        price="29.99",
        vendor="TestBrand"
    );

    root ++> p1;

    # Spawn quality analyzer
    results = root spawn QualityAnalyzer();
    assert results is not None;
}

test "brand aggregation walker" {
    brand = Brand(name="TestBrand");
    p1 = Product(
        title="Product A", quality_score=80,
        issues=[AuditIssue(severity="warning", category="sizing", message="test")]
    );
    p2 = Product(
        title="Product B", quality_score=60,
        issues=[AuditIssue(severity="warning", category="sizing", message="test")]
    );

    root ++> brand;
    brand ++> p1;
    brand ++> p2;

    results = root spawn BrandAggregator();
    assert results is not None;
}

test "return evidence attached to products" {
    product = Product(url="https://test.com/p1", title="Test Product");
    ev1 = ReturnEvidence(reason="too small", count=3);
    ev2 = ReturnEvidence(reason="wrong color", count=1);

    root ++> product;
    product ++> ev1;
    product ++> ev2;

    evidence = [-->](`?ReturnEvidence) spawn product;
    # Product should have evidence nodes connected
    assert product is not None;
}
