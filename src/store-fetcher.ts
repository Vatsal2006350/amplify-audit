/**
 * Store-wide product fetcher.
 * Scrapes all products from a Shopify store via the public /products.json endpoint.
 */

import type { Product } from './types'

interface ShopifyProductRaw {
  id: number
  title: string
  handle: string
  body_html: string
  vendor: string
  product_type: string
  tags: string
  variants: Array<{
    title: string
    sku: string
    price: string
    available: boolean
  }>
  images: Array<{ src: string }>
}

/** Normalize a user-entered URL into a clean store origin. */
export function normalizeStoreUrl(input: string): string {
  let url = input.trim()
  if (!url.startsWith('http')) url = 'https://' + url
  try {
    const parsed = new URL(url)
    return parsed.origin
  } catch {
    return url
  }
}

/** Check if a URL points to a Shopify store. */
export async function isShopifyStore(storeUrl: string): Promise<boolean> {
  try {
    const res = await fetch(storeUrl, {
      method: 'HEAD',
      headers: { 'User-Agent': 'amplify-audit/0.1.0' },
      redirect: 'follow',
    })
    const powered = res.headers.get('x-shopify-stage') || res.headers.get('powered-by') || ''
    if (powered.toLowerCase().includes('shopify')) return true

    // Fallback: try the products endpoint
    const check = await fetch(`${storeUrl}/products.json?limit=1`, {
      headers: { 'User-Agent': 'amplify-audit/0.1.0' },
    })
    return check.ok
  } catch {
    return false
  }
}

/** Fetch all products from a Shopify store. Max 250 per page, paginate until empty. */
export async function fetchAllProducts(
  storeUrl: string,
  opts?: { maxProducts?: number; onProgress?: (fetched: number) => void },
): Promise<Product[]> {
  const maxProducts = opts?.maxProducts ?? 500
  const products: Product[] = []
  let page = 1

  while (products.length < maxProducts) {
    const url = `${storeUrl}/products.json?limit=250&page=${page}`
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'amplify-audit/0.1.0',
        'Accept': 'application/json',
      },
    })

    if (!res.ok) break

    const data = (await res.json()) as { products: ShopifyProductRaw[] }
    if (!data.products || data.products.length === 0) break

    for (const p of data.products) {
      if (products.length >= maxProducts) break
      products.push({
        url: `${storeUrl}/products/${p.handle}`,
        platform: 'shopify',
        title: p.title || '',
        description: p.body_html || '',
        tags: Array.isArray(p.tags) ? p.tags : (p.tags || '').split(',').map((t: string) => t.trim()).filter(Boolean),
        vendor: p.vendor || undefined,
        productType: p.product_type || undefined,
        price: p.variants?.[0]?.price || undefined,
        images: (p.images || []).map((img) => img.src),
        variants: (p.variants || []).map((v) => ({
          title: v.title || 'Default',
          sku: v.sku || undefined,
          price: v.price || undefined,
        })),
      })
    }

    opts?.onProgress?.(products.length)
    page++

    // Small delay to be respectful
    await new Promise((r) => setTimeout(r, 200))
  }

  return products
}
