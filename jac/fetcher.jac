"""
amplify-audit/fetcher.jac — Multi-platform product data fetcher.

Fetches product data from Shopify, Amazon, and generic e-commerce sites
using Python's requests library and regex-based HTML parsing.

Supports:
  - Shopify: /products/{handle}.json API
  - Amazon: HTML scraping with cheerio-style parsing
  - Generic: JSON-LD structured data + OpenGraph fallback
"""

import re;
import json;

::py::
import requests
from urllib.parse import urlparse, urljoin

def _fetch_html(url, timeout=15):
    """Fetch HTML content from a URL with browser-like headers."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9"
    }
    try:
        resp = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
        resp.raise_for_status()
        return resp.text
    except Exception as e:
        return ""

def _fetch_json(url, timeout=15):
    """Fetch JSON from a URL."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
        "Accept": "application/json"
    }
    try:
        resp = requests.get(url, headers=headers, timeout=timeout)
        resp.raise_for_status()
        return resp.json()
    except Exception:
        return None

def _extract_json_ld(html):
    """Extract JSON-LD Product data from HTML."""
    import re as _re
    pattern = r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>'
    matches = _re.findall(pattern, html, _re.DOTALL | _re.IGNORECASE)
    for match in matches:
        try:
            data = json.loads(match.strip())
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get("@type") == "Product":
                        return item
            elif isinstance(data, dict):
                if data.get("@type") == "Product":
                    return data
                if "@graph" in data:
                    for item in data["@graph"]:
                        if isinstance(item, dict) and item.get("@type") == "Product":
                            return item
        except Exception:
            continue
    return None

def _extract_meta(html, property_name):
    """Extract content from a meta tag."""
    import re as _re
    pattern = rf'<meta[^>]*(?:property|name)=["\'](?:og:)?{_re.escape(property_name)}["\'][^>]*content=["\']([^"\']*)["\']'
    match = _re.search(pattern, html, _re.IGNORECASE)
    if match:
        return match.group(1)
    # Try reversed order (content before property)
    pattern2 = rf'<meta[^>]*content=["\']([^"\']*)["\'][^>]*(?:property|name)=["\'](?:og:)?{_re.escape(property_name)}["\']'
    match2 = _re.search(pattern2, html, _re.IGNORECASE)
    return match2.group(1) if match2 else ""

def _extract_images_from_html(html):
    """Extract product image URLs from HTML."""
    import re as _re
    images = []
    # Look for high-res images in various patterns
    for pattern in [
        r'data-zoom-image=["\']([^"\']+)["\']',
        r'"hiRes":"([^"]+)"',
        r'"large":"([^"]+)"',
        r'<img[^>]*class=["\'][^"\']*product[^"\']*["\'][^>]*src=["\']([^"\']+)["\']',
    ]:
        matches = _re.findall(pattern, html, _re.IGNORECASE)
        images.extend(matches)
    return list(dict.fromkeys(images))[:10]  # Dedupe, max 10

def _strip_html_tags(text):
    """Remove HTML tags from text."""
    import re as _re
    return _re.sub(r'<[^>]+>', ' ', text).strip()
::py::

# ─── Platform Detection ─────────────────────────────────────────────────────

def detect_platform(url: str) -> str {
    """Detect e-commerce platform from URL."""
    lower = url.lower();
    if "amazon.com" in lower or "amazon.co" in lower or "amzn." in lower {
        return "amazon";
    }
    if "bestbuy.com" in lower {
        return "bestbuy";
    }
    if "shopify" in lower or "/products/" in lower {
        return "shopify";
    }
    return "unknown";
}

def is_store_url(url: str) -> bool {
    """Check if URL is a store root (not a single product page)."""
    lower = url.lower();
    if "/products/" in lower and not lower.endswith("/products/") and not lower.endswith("/products") {
        return False;
    }
    if "/dp/" in lower or "/gp/" in lower {
        return False;
    }
    return True;
}

# ─── Shopify Fetcher ─────────────────────────────────────────────────────────

def fetch_shopify_product(url: str) -> dict {
    """Fetch a Shopify product via the .json API endpoint."""
    json_url = url.rstrip("/") + ".json";
    data = _fetch_json(json_url);

    if not data or "product" not in data {
        # Fallback to generic
        return fetch_generic_product(url);
    }

    p = data["product"];
    images = [img.get("src", "") for img in p.get("images", [])];
    variants = [
        {"title": v.get("title", ""), "sku": v.get("sku", ""), "price": v.get("price", "")}
        for v in p.get("variants", [])
    ];
    tags = p.get("tags", "");
    if isinstance(tags, str) {
        tags = [t.strip() for t in tags.split(",") if t.strip()];
    }

    return {
        "url": url,
        "platform": "shopify",
        "source": "page",
        "title": p.get("title", ""),
        "description": _strip_html_tags(p.get("body_html", "")),
        "vendor": p.get("vendor", ""),
        "product_type": p.get("product_type", ""),
        "price": str(variants[0]["price"]) if variants else "",
        "images": images,
        "tags": tags,
        "variants": variants
    };
}

def fetch_shopify_store(store_url: str, max_products: int = 100) -> list[dict] {
    """Fetch all products from a Shopify store via /products.json."""
    products: list[dict] = [];
    page = 1;

    while len(products) < max_products {
        api_url = f"{store_url.rstrip('/')}/products.json?limit=250&page={page}";
        data = _fetch_json(api_url);

        if not data or "products" not in data or len(data["products"]) == 0 {
            break;
        }

        for p in data["products"] {
            images = [img.get("src", "") for img in p.get("images", [])];
            variants = [
                {"title": v.get("title", ""), "sku": v.get("sku", ""), "price": v.get("price", "")}
                for v in p.get("variants", [])
            ];
            tags = p.get("tags", "");
            if isinstance(tags, str) {
                tags = [t.strip() for t in tags.split(",") if t.strip()];
            }

            products.append({
                "url": f"{store_url.rstrip('/')}/products/{p.get('handle', '')}",
                "platform": "shopify",
                "source": "page",
                "title": p.get("title", ""),
                "description": _strip_html_tags(p.get("body_html", "")),
                "vendor": p.get("vendor", ""),
                "product_type": p.get("product_type", ""),
                "price": str(variants[0]["price"]) if variants else "",
                "images": images,
                "tags": tags,
                "variants": variants
            });

            if len(products) >= max_products {
                break;
            }
        }
        page += 1;
    }

    return products;
}

# ─── Amazon Fetcher ──────────────────────────────────────────────────────────

def fetch_amazon_product(url: str) -> dict {
    """Fetch an Amazon product page via HTML scraping."""
    html = _fetch_html(url);
    if not html {
        return {"url": url, "platform": "amazon", "source": "page", "title": "", "description": ""};
    }

    # Try JSON-LD first
    json_ld = _extract_json_ld(html);
    if json_ld {
        title = json_ld.get("name", "");
        description = json_ld.get("description", "");
        images = [];
        img_data = json_ld.get("image", []);
        if isinstance(img_data, str) {
            images = [img_data];
        } elif isinstance(img_data, list) {
            images = img_data;
        }
        price = "";
        offers = json_ld.get("offers", {});
        if isinstance(offers, dict) {
            price = str(offers.get("price", ""));
        }
        brand = "";
        brand_data = json_ld.get("brand", {});
        if isinstance(brand_data, dict) {
            brand = brand_data.get("name", "");
        }

        return {
            "url": url,
            "platform": "amazon",
            "source": "page",
            "title": title,
            "description": description,
            "vendor": brand,
            "price": price,
            "images": images,
            "tags": [],
            "variants": []
        };
    }

    # Fallback: regex extraction
    title = _extract_meta(html, "title");
    if not title {
        match = re.search(r'<span[^>]*id=["\']productTitle["\'][^>]*>([^<]+)', html);
        if match {
            title = match.group(1).strip();
        }
    }

    description = _extract_meta(html, "description");
    images = _extract_images_from_html(html);
    price = _extract_meta(html, "price:amount");

    return {
        "url": url,
        "platform": "amazon",
        "source": "page",
        "title": title,
        "description": description,
        "vendor": _extract_meta(html, "brand") if _extract_meta(html, "brand") else "",
        "price": price,
        "images": images,
        "tags": [],
        "variants": []
    };
}

# ─── Generic Fetcher ─────────────────────────────────────────────────────────

def fetch_generic_product(url: str) -> dict {
    """Fetch product data from any site using JSON-LD + OpenGraph fallback."""
    html = _fetch_html(url);
    if not html {
        return {"url": url, "platform": "unknown", "source": "page", "title": "", "description": ""};
    }

    # Try JSON-LD
    json_ld = _extract_json_ld(html);
    if json_ld {
        title = json_ld.get("name", "");
        description = json_ld.get("description", "");
        images = [];
        img_data = json_ld.get("image", []);
        if isinstance(img_data, str) {
            images = [img_data];
        } elif isinstance(img_data, list) {
            images = img_data;
        }
        price = "";
        offers = json_ld.get("offers", {});
        if isinstance(offers, dict) {
            price = str(offers.get("price", ""));
        }
        brand = "";
        brand_data = json_ld.get("brand", {});
        if isinstance(brand_data, dict) {
            brand = brand_data.get("name", "");
        }

        return {
            "url": url,
            "platform": detect_platform(url),
            "source": "page",
            "title": title,
            "description": _strip_html_tags(description),
            "vendor": brand,
            "price": price,
            "images": images,
            "tags": [],
            "variants": []
        };
    }

    # Fallback: OpenGraph meta tags
    return {
        "url": url,
        "platform": detect_platform(url),
        "source": "page",
        "title": _extract_meta(html, "title"),
        "description": _extract_meta(html, "description"),
        "vendor": "",
        "price": _extract_meta(html, "price:amount"),
        "images": [_extract_meta(html, "image")] if _extract_meta(html, "image") else [],
        "tags": [],
        "variants": []
    };
}

# ─── Unified Fetch ───────────────────────────────────────────────────────────

def fetch_product(url: str) -> dict {
    """Fetch a product from any supported platform. Auto-detects platform."""
    platform = detect_platform(url);

    if platform == "shopify" {
        return fetch_shopify_product(url);
    }
    if platform == "amazon" {
        return fetch_amazon_product(url);
    }
    return fetch_generic_product(url);
}

def fetch_store(url: str, max_products: int = 100) -> list[dict] {
    """Fetch all products from a store URL."""
    platform = detect_platform(url);

    if platform == "shopify" or is_store_url(url) {
        return fetch_shopify_store(url, max_products);
    }
    # Single product fallback
    return [fetch_product(url)];
}
