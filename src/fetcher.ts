/**
 * Product URL fetcher.
 * Fetches product data from public storefronts (Shopify, Amazon).
 * Uses cheerio for HTML parsing — no headless browser required.
 */

import * as cheerio from 'cheerio'
import type { Product } from './types'

/** Detect which platform a URL belongs to. */
export function detectPlatform(url: string): 'shopify' | 'amazon' | 'unknown' {
  const lower = url.toLowerCase()
  if (lower.includes('amazon.') || lower.includes('/dp/') || lower.includes('/gp/product/')) {
    return 'amazon'
  }
  if (lower.includes('.myshopify.com') || lower.includes('/products/')) {
    return 'shopify'
  }
  return 'unknown'
}

/** Fetch product from Shopify public JSON endpoint. */
async function fetchShopify(url: string): Promise<Product> {
  // Shopify exposes product data at {product_url}.json
  const jsonUrl = url.replace(/\/$/, '') + '.json'

  const res = await fetch(jsonUrl, {
    headers: {
      'User-Agent': 'amplify-audit/0.1.0',
      'Accept': 'application/json',
    },
  })

  if (!res.ok) {
    // Fallback: try scraping the HTML page
    return fetchByHtml(url, 'shopify')
  }

  const data = (await res.json()) as any
  const p = data.product

  return {
    url,
    platform: 'shopify',
    title: p.title || '',
    description: p.body_html || '',
    tags: (p.tags || '').split(',').map((t: string) => t.trim()).filter(Boolean),
    vendor: p.vendor || undefined,
    productType: p.product_type || undefined,
    price: p.variants?.[0]?.price || undefined,
    images: (p.images || []).map((img: any) => img.src),
    variants: (p.variants || []).map((v: any) => ({
      title: v.title || 'Default',
      sku: v.sku || undefined,
      price: v.price || undefined,
    })),
  }
}

/** Fetch product from Amazon by scraping the product page. */
async function fetchAmazon(url: string): Promise<Product> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  })

  if (!res.ok) {
    throw new Error(`Failed to fetch Amazon page: HTTP ${res.status}`)
  }

  const html = await res.text()
  const $ = cheerio.load(html)

  const title = $('#productTitle').text().trim() || $('h1').first().text().trim()

  // Description from various Amazon locations
  const description =
    $('#productDescription').text().trim() ||
    $('#feature-bullets').text().trim() ||
    $('[data-feature-name="productDescription"]').text().trim() ||
    ''

  // Bullet points
  const bullets: string[] = []
  $('#feature-bullets li span').each((_, el) => {
    const text = $(el).text().trim()
    if (text) bullets.push(text)
  })

  // Images
  const images: string[] = []
  $('[data-a-image-name="landingImage"]').each((_, el) => {
    const src = $(el).attr('src') || $(el).attr('data-old-hires')
    if (src) images.push(src)
  })
  // Also try altImages
  $('.imageThumbnail img, #altImages img').each((_, el) => {
    const src = $(el).attr('src')
    if (src && !src.includes('sprite')) images.push(src.replace(/\._.*_\./, '.'))
  })

  // Price
  const price =
    $('.a-price .a-offscreen').first().text().trim() ||
    $('#priceblock_ourprice').text().trim() ||
    ''

  // Brand
  const vendor = $('#bylineInfo').text().replace(/^(Visit the |Brand: )/, '').trim() || undefined

  // Combine description and bullets
  const fullDescription = [description, ...bullets].filter(Boolean).join('\n\n')

  return {
    url,
    platform: 'amazon',
    title,
    description: fullDescription,
    tags: [], // Amazon doesn't expose tags publicly
    vendor,
    price: price || undefined,
    images: [...new Set(images)],
    variants: [],
  }
}

/** Generic HTML fallback for unknown platforms. */
async function fetchByHtml(url: string, platform: 'shopify' | 'amazon' | 'unknown' = 'unknown'): Promise<Product> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html',
    },
  })

  if (!res.ok) {
    throw new Error(`Failed to fetch page: HTTP ${res.status}`)
  }

  const html = await res.text()
  const $ = cheerio.load(html)

  // Try structured data (JSON-LD)
  let structured: any = null
  $('script[type="application/ld+json"]').each((_, el) => {
    try {
      const data = JSON.parse($(el).html() || '')
      if (data['@type'] === 'Product' || data?.['@graph']?.find?.((n: any) => n['@type'] === 'Product')) {
        structured = data['@type'] === 'Product' ? data : data['@graph'].find((n: any) => n['@type'] === 'Product')
      }
    } catch { /* ignore invalid JSON-LD */ }
  })

  if (structured) {
    return {
      url,
      platform,
      title: structured.name || '',
      description: structured.description || '',
      tags: [],
      vendor: structured.brand?.name || undefined,
      price: structured.offers?.price?.toString() || undefined,
      images: Array.isArray(structured.image) ? structured.image : structured.image ? [structured.image] : [],
      variants: [],
    }
  }

  // Fallback: meta tags + heuristics
  const title = $('meta[property="og:title"]').attr('content') || $('title').text().trim() || ''
  const description = $('meta[property="og:description"]').attr('content') || $('meta[name="description"]').attr('content') || ''
  const image = $('meta[property="og:image"]').attr('content')

  return {
    url,
    platform,
    title,
    description,
    tags: [],
    images: image ? [image] : [],
    variants: [],
  }
}

/** Fetch product data from any supported URL. */
export async function fetchProduct(url: string): Promise<Product> {
  const platform = detectPlatform(url)

  switch (platform) {
    case 'shopify':
      return fetchShopify(url)
    case 'amazon':
      return fetchAmazon(url)
    default:
      return fetchByHtml(url)
  }
}
