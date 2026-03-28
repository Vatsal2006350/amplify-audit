"""
amplify-audit/types.jac — Core type system for Data-Spatial Product Quality Analysis.

Defines the graph schema: nodes (data entities), edges (relationships),
enums (classification categories), and objects (structured analysis results).

This module implements a typed property graph where products, brands, evidence,
issues, and recommendations form a connected topology that walkers traverse
for quality analysis.
"""

# ─── Enums ───────────────────────────────────────────────────────────────────

enum Platform {
    SHOPIFY = "shopify",
    AMAZON = "amazon",
    BESTBUY = "bestbuy",
    UNKNOWN = "unknown"
}

enum DataSource {
    PAGE = "page",
    SEARCH = "search"
}

enum IssueSeverity {
    ERROR = "error",
    WARNING = "warning",
    INFO = "info"
}

enum IssueCategory {
    TITLE = "title",
    DESCRIPTION = "description",
    IMAGES = "images",
    SIZING = "sizing",
    MATERIAL = "material",
    CARE = "care",
    TAGS = "tags",
    PRICE = "price",
    VENDOR = "vendor",
    SEO = "seo",
    TRUST = "trust"
}

enum IssueType {
    SIZING = "sizing",
    QUALITY = "quality",
    DESCRIPTION_MISMATCH = "description_mismatch",
    COLOR_MISMATCH = "color_mismatch",
    MISSING_INFO = "missing_info"
}

sem IssueType.SIZING = "Fit and sizing issues: runs small/large, wrong measurements";
sem IssueType.QUALITY = "Product quality defects: broken, defective, poor materials";
sem IssueType.DESCRIPTION_MISMATCH = "Product does not match listing description or photos";
sem IssueType.COLOR_MISMATCH = "Color appears different from photos or description";
sem IssueType.MISSING_INFO = "Critical product information is absent from listing";

enum RiskLevel {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    CRITICAL = "CRITICAL"
}

# ─── Structured Objects ──────────────────────────────────────────────────────

obj Variant {
    has title: str = "Default";
    has sku: str = "";
    has price: str = "";
}

obj AuditIssue {
    has severity: str = "info";
    has category: str = "description";
    has message: str = "";
}

obj TopReason {
    has reason: str;
    has percentage: int;
}

obj ReturnRisk {
    has score: str = "LOW";
    has top_reasons: list[TopReason] = [];
    has primary_issue_type: str = "";
    has fixable_by_pdp: bool = False;
}

obj RecommendedFix {
    has field: str;
    has before: str;
    has after: str;
    has rationale: str;
}

obj AiInsight {
    has summary: str = "";
    has quality_score: int = 50;
    has issues: list[AuditIssue] = [];
}

sem AiInsight = "AI-generated deep analysis of a product listing's quality and issues";
sem AiInsight.summary = "One-sentence summary of the single most important finding";
sem AiInsight.quality_score = "Quality score 0-100. Most decent listings score 55-80";
sem AiInsight.issues = "Specific actionable issues found, referencing the actual product";

# ─── Graph Nodes ─────────────────────────────────────────────────────────────

node Product {
    has url: str = "";
    has platform: str = "unknown";
    has source: str = "page";
    has title: str = "";
    has description: str = "";
    has tags: list[str] = [];
    has vendor: str = "";
    has product_type: str = "";
    has price: str = "";
    has images: list[str] = [];
    has variants: list[Variant] = [];
    has quality_score: int = -1;
    has issues: list[AuditIssue] = [];
    has ai_insight: AiInsight | None = None;
    has sku_health_score: float = -1.0;
    has confidence: float = -1.0;
    has return_risk: ReturnRisk | None = None;
    has recommendations: list[RecommendedFix] = [];
}

node Brand {
    has name: str;
    has product_count: int = 0;
    has avg_quality_score: float = 0.0;
    has common_issues: list[str] = [];
}

node Category {
    has name: str;
    has product_count: int = 0;
    has avg_quality_score: float = 0.0;
}

node ReturnEvidence {
    has reason: str;
    has normalized: str = "";
    has classified_type: str = "";
    has count: int = 1;
}

node IssueNode {
    has issue_type: str;
    has severity: str = "warning";
    has signal_count: int = 0;
    has fixable_by_pdp: bool = False;
    has score: float = 0.0;
}

node RecommendationNode {
    has field: str;
    has before: str;
    has after: str;
    has rationale: str;
}

# ─── Graph Edges ─────────────────────────────────────────────────────────────

edge BelongsToBrand {
    has since: str = "";
}

edge InCategory {
    has relevance: float = 1.0;
}

edge HasReturn {
    has weight: float = 1.0;
}

edge HasIssue {
    has detected_by: str = "rule";
}

edge HasRecommendation {
    has priority: int = 0;
}

edge SimilarTo {
    has similarity: float = 0.0;
    has shared_issues: list[str] = [];
}
