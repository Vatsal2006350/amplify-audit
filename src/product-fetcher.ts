/**
 * Single-product fetcher for any platform.
 * Supports Amazon, Best Buy, Shopify individual products, and any site with JSON-LD.
 */

import * as cheerio from 'cheerio'
import type { Product } from './types'

type Platform = 'shopify' | 'amazon' | 'bestbuy' | 'unknown'

/** Detect which platform a URL belongs to. */
export function detectPlatform(url: string): Platform {
  const lower = url.toLowerCase()
  if (lower.includes('amazon.') || lower.includes('/dp/') || lower.includes('/gp/product/')) return 'amazon'
  if (lower.includes('bestbuy.com')) return 'bestbuy'
  if (lower.includes('.myshopify.com') || lower.includes('/products/')) return 'shopify'
  return 'unknown'
}

/** Detect if a URL is a store-level URL (can scan multiple products) vs a single product. */
export function isStoreUrl(url: string): boolean {
  const lower = url.toLowerCase().replace(/\/$/, '')
  // Shopify store root (no /products/handle path)
  if (lower.match(/^https?:\/\/[^/]+\.(com|co|io|store|shop|net|org)(\/)?$/)) return true
  if (lower.match(/^https?:\/\/[^/]+\.myshopify\.com(\/)?$/)) return true
  // Has no product-specific path segments
  if (!lower.includes('/products/') && !lower.includes('/dp/') && !lower.includes('/gp/') && !lower.includes('/ip/') && !lower.includes('/site/')) {
    // Could be a bare domain
    try {
      const parsed = new URL(lower.startsWith('http') ? lower : `https://${lower}`)
      return parsed.pathname === '/' || parsed.pathname === ''
    } catch { return false }
  }
  return false
}

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
}

/** Fetch a single Amazon product page. */
async function fetchAmazon(url: string): Promise<Product> {
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch Amazon page: HTTP ${res.status}`)

  const html = await res.text()
  const $ = cheerio.load(html)

  const title = $('#productTitle').text().trim() || $('h1 #title span').text().trim() || $('h1').first().text().trim()

  // Description from various Amazon locations
  const descParts: string[] = []
  const prodDesc = $('#productDescription p, #productDescription').text().trim()
  if (prodDesc) descParts.push(prodDesc)

  // Bullet points
  $('#feature-bullets li span.a-list-item').each((_, el) => {
    const text = $(el).text().trim()
    if (text && text.length > 5) descParts.push(text)
  })

  // A+ content
  const aplusText = $('#aplus .aplus-module').text().trim()
  if (aplusText) descParts.push(aplusText)

  // Images
  const images: string[] = []
  $('img[data-old-hires]').each((_, el) => {
    const src = $(el).attr('data-old-hires')
    if (src) images.push(src)
  })
  $('#imgTagWrapperId img, #landingImage').each((_, el) => {
    const src = $(el).attr('src') || $(el).attr('data-old-hires')
    if (src && !images.includes(src)) images.push(src)
  })
  $('#altImages img').each((_, el) => {
    const src = $(el).attr('src')
    if (src && !src.includes('sprite') && !src.includes('play-icon')) {
      const hiRes = src.replace(/\._[A-Z]+\d+_\./, '.')
      if (!images.includes(hiRes)) images.push(hiRes)
    }
  })

  // Price
  const price =
    $('.a-price .a-offscreen').first().text().trim().replace(/[^0-9.]/g, '') ||
    $('#priceblock_ourprice').text().trim().replace(/[^0-9.]/g, '') ||
    $('[data-a-color="price"] .a-offscreen').first().text().trim().replace(/[^0-9.]/g, '') ||
    undefined

  // Brand
  const vendor =
    $('#bylineInfo').text().replace(/^(Visit the |Brand: )/, '').replace(/ Store$/, '').trim() ||
    $('a#bylineInfo').text().replace(/^(Visit the |Brand: )/, '').replace(/ Store$/, '').trim() ||
    undefined

  return {
    url,
    platform: 'amazon',
    title,
    description: descParts.join('\n\n'),
    tags: [],
    vendor,
    price,
    images: [...new Set(images)].slice(0, 10),
    variants: [],
  }
}

/** Fetch a single Best Buy product page. */
async function fetchBestBuy(url: string): Promise<Product> {
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch Best Buy page: HTTP ${res.status}`)

  const html = await res.text()
  const $ = cheerio.load(html)

  // Try JSON-LD first (Best Buy typically has good structured data)
  let structured: any = null
  $('script[type="application/ld+json"]').each((_, el) => {
    try {
      const data = JSON.parse($(el).html() || '')
      if (data['@type'] === 'Product') structured = data
      if (Array.isArray(data)) {
        const prod = data.find((d: any) => d['@type'] === 'Product')
        if (prod) structured = prod
      }
      if (data['@graph']) {
        const prod = data['@graph'].find((n: any) => n['@type'] === 'Product')
        if (prod) structured = prod
      }
    } catch { /* ignore */ }
  })

  if (structured) {
    return {
      url,
      platform: 'amazon', // using 'amazon' as generic non-shopify
      title: structured.name || '',
      description: structured.description || '',
      tags: structured.category ? [structured.category] : [],
      vendor: structured.brand?.name || undefined,
      price: structured.offers?.price?.toString() || structured.offers?.lowPrice?.toString() || undefined,
      images: Array.isArray(structured.image) ? structured.image : structured.image ? [structured.image] : [],
      variants: [],
    }
  }

  // Fallback: HTML scraping
  const title = $('h1.heading').text().trim() || $('h1').first().text().trim()
  const description = $('.product-description, [data-testid="product-description"]').text().trim()
  const price = $('[data-testid="customer-price"] span').first().text().trim().replace(/[^0-9.]/g, '') || undefined
  const image = $('img.primary-image, [data-testid="product-hero-image"] img').first().attr('src')

  return {
    url,
    platform: 'amazon',
    title,
    description,
    tags: [],
    price,
    images: image ? [image] : [],
    variants: [],
  }
}

/** Generic fallback using JSON-LD and meta tags. */
async function fetchGeneric(url: string): Promise<Product> {
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch page: HTTP ${res.status}`)

  const html = await res.text()
  const $ = cheerio.load(html)

  // Try JSON-LD
  let structured: any = null
  $('script[type="application/ld+json"]').each((_, el) => {
    try {
      const data = JSON.parse($(el).html() || '')
      if (data['@type'] === 'Product') structured = data
      if (data['@graph']) {
        const prod = data['@graph'].find((n: any) => n['@type'] === 'Product')
        if (prod) structured = prod
      }
    } catch { /* ignore */ }
  })

  if (structured) {
    return {
      url,
      platform: 'unknown',
      title: structured.name || '',
      description: structured.description || '',
      tags: [],
      vendor: structured.brand?.name || undefined,
      price: structured.offers?.price?.toString() || undefined,
      images: Array.isArray(structured.image) ? structured.image : structured.image ? [structured.image] : [],
      variants: [],
    }
  }

  // Meta tag fallback
  const title = $('meta[property="og:title"]').attr('content') || $('title').text().trim() || ''
  const description = $('meta[property="og:description"]').attr('content') || $('meta[name="description"]').attr('content') || ''
  const image = $('meta[property="og:image"]').attr('content')
  const price = $('meta[property="product:price:amount"]').attr('content') || undefined

  return {
    url,
    platform: 'unknown',
    title,
    description,
    tags: [],
    price,
    images: image ? [image] : [],
    variants: [],
  }
}

/** Fetch a single Shopify product. */
async function fetchShopifyProduct(url: string): Promise<Product> {
  const jsonUrl = url.replace(/\/$/, '') + '.json'
  const res = await fetch(jsonUrl, {
    headers: { 'User-Agent': 'amplify-audit/0.1.0', 'Accept': 'application/json' },
  })

  if (!res.ok) return fetchGeneric(url)

  const data = (await res.json()) as any
  const p = data.product

  return {
    url,
    platform: 'shopify',
    title: p.title || '',
    description: p.body_html || '',
    tags: Array.isArray(p.tags) ? p.tags : (p.tags || '').split(',').map((t: string) => t.trim()).filter(Boolean),
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

/** Fetch product data from any supported URL. */
export async function fetchSingleProduct(url: string): Promise<Product> {
  const platform = detectPlatform(url)
  switch (platform) {
    case 'amazon': return fetchAmazon(url)
    case 'bestbuy': return fetchBestBuy(url)
    case 'shopify': return fetchShopifyProduct(url)
    default: return fetchGeneric(url)
  }
}

/** Check if URL is an Amazon search/brand page. */
export function isAmazonSearchUrl(url: string): boolean {
  const lower = url.toLowerCase()
  return (lower.includes('amazon.') && (lower.includes('/s?') || lower.includes('/s/')))
}

/** Extract Amazon domain from a URL. */
function getAmazonDomain(url: string): string {
  try {
    return new URL(url).origin
  } catch {
    return 'https://www.amazon.com'
  }
}

interface AmazonSearchProduct {
  asin: string
  title: string
  image: string | null
  price: string | null
}

/** Scrape a single page of Amazon search results. Returns product stubs + next page URL. */
async function scrapeAmazonSearchPage(url: string): Promise<{ products: AmazonSearchProduct[]; nextPageUrl: string | null }> {
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) throw new Error(`Amazon returned HTTP ${res.status}`)

  const html = await res.text()
  const $ = cheerio.load(html)
  const domain = getAmazonDomain(url)
  const products: AmazonSearchProduct[] = []

  $('[data-component-type="s-search-result"]').each((_, el) => {
    const asin = $(el).attr('data-asin')
    if (!asin) return

    const title = $(el).find('h2 a span, h2 span').first().text().trim()
    if (!title) return

    const image = $(el).find('img.s-image').attr('src') || null
    const price = $(el).find('.a-price .a-offscreen').first().text().trim() || null

    products.push({ asin, title, image, price })
  })

  const nextHref = $('a.s-pagination-next').attr('href')
  const nextPageUrl = nextHref ? `${domain}${nextHref}` : null

  return { products, nextPageUrl }
}

/** Fetch all products from an Amazon search/brand page. Paginates through results. */
export async function fetchAmazonSearchProducts(
  searchUrl: string,
  opts?: { maxProducts?: number; onProgress?: (fetched: number) => void },
): Promise<Product[]> {
  const maxProducts = opts?.maxProducts ?? 200
  const domain = getAmazonDomain(searchUrl)
  const allProducts: Product[] = []
  const seenAsins = new Set<string>()
  let currentUrl: string | null = searchUrl
  let pageNum = 0

  while (currentUrl && allProducts.length < maxProducts && pageNum < 10) {
    pageNum++
    const { products: pageProducts, nextPageUrl } = await scrapeAmazonSearchPage(currentUrl)

    if (pageProducts.length === 0) break

    for (const p of pageProducts) {
      if (seenAsins.has(p.asin) || allProducts.length >= maxProducts) continue
      seenAsins.add(p.asin)

      allProducts.push({
        url: `${domain}/dp/${p.asin}`,
        platform: 'amazon',
        source: 'search',
        title: p.title,
        description: '',
        tags: [],
        price: p.price?.replace(/[^0-9.]/g, '') || undefined,
        images: p.image ? [p.image] : [],
        variants: [],
      })
    }

    opts?.onProgress?.(allProducts.length)
    currentUrl = nextPageUrl

    // Respectful delay between pages
    if (currentUrl) await new Promise((r) => setTimeout(r, 500))
  }

  return allProducts
}

/** Build an Amazon search URL from a brand name and marketplace domain. */
export function buildAmazonSearchUrl(brand: string, marketplace: string): string {
  let domain = marketplace.trim().toLowerCase()
  if (!domain.startsWith('http')) domain = 'https://' + domain
  try {
    const parsed = new URL(domain)
    return `${parsed.origin}/s?k=${encodeURIComponent(brand)}&ref=nb_sb_noss`
  } catch {
    return `https://www.amazon.com/s?k=${encodeURIComponent(brand)}&ref=nb_sb_noss`
  }
}
