/**
 * Listing quality analyzer.
 * Programmatic PDP analysis — no API key required.
 *
 * Extracted from Amplify's listing agent quality checks.
 */

import type { Product, AuditIssue } from './types'

/** Strip HTML tags for text analysis. */
function stripHtml(html: string): string {
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
}

/** Analyze listing quality. Returns score (0-100) and issues. */
export function analyzeListingQuality(product: Product): {
  qualityScore: number
  issues: AuditIssue[]
} {
  const issues: AuditIssue[] = []
  const title = product.title || ''
  const description = product.description || ''
  const descText = stripHtml(description)
  const tags = product.tags || []
  const isSearch = product.source === 'search'

  // --- Title checks (always available) ---
  if (!title) {
    issues.push({ type: 'error', category: 'title', message: 'Product title is missing' })
  } else {
    if (title.length < 20) {
      issues.push({ type: 'error', category: 'title', message: `Title is too short (${title.length} chars). Aim for 50-80 characters.` })
    } else if (title.length < 50) {
      issues.push({ type: 'warning', category: 'title', message: `Title could be longer (${title.length} chars). Optimal is 50-80 characters for SEO.` })
    } else if (title.length > 150) {
      issues.push({ type: 'warning', category: 'title', message: `Title is very long (${title.length} chars). Consider trimming to under 150 characters.` })
    }

    if (title === title.toUpperCase() && title.length > 10) {
      issues.push({ type: 'warning', category: 'title', message: 'Title is in ALL CAPS. Use title case for better readability.' })
    }

    // Title keyword analysis — check for keyword stuffing or missing key info
    if (title.split(/[,|\/\-]/).length > 6) {
      issues.push({ type: 'info', category: 'title', message: 'Title may have too many separators. Clean, readable titles convert better.' })
    }
  }

  // --- Description checks (skip if data came from search results) ---
  if (!isSearch) {
    if (!descText || descText.length < 10) {
      issues.push({ type: 'error', category: 'description', message: 'Product description is missing or empty' })
    } else {
      if (descText.length < 100) {
        issues.push({ type: 'error', category: 'description', message: `Description is too short (${descText.length} chars). Target 300-1000 characters.` })
      } else if (descText.length < 300) {
        issues.push({ type: 'warning', category: 'description', message: `Description could be more detailed (${descText.length} chars). Target 300-1000 characters.` })
      }

      const lowerDesc = descText.toLowerCase()

      const hasSizing = /\b(size|sizing|fit|fits|measurement|dimensions|cm|inches|length|width|small|medium|large|xl)\b/.test(lowerDesc)
      if (!hasSizing) {
        issues.push({ type: 'warning', category: 'sizing', message: 'No sizing or fit information found. This is the #1 driver of returns.' })
      }

      const hasMaterial = /\b(material|fabric|cotton|polyester|leather|wool|linen|silk|nylon|synthetic|organic)\b/.test(lowerDesc)
      if (!hasMaterial) {
        issues.push({ type: 'info', category: 'material', message: 'No material/fabric information detected. Adding materials improves buyer confidence.' })
      }

      const hasCareInstructions = /\b(wash|care|clean|dry|iron|machine wash|hand wash|tumble)\b/.test(lowerDesc)
      if (!hasCareInstructions) {
        issues.push({ type: 'info', category: 'care', message: 'No care instructions found. Consider adding washing/maintenance info.' })
      }
    }
  }

  // --- Image checks (search results only have 1 thumbnail — don't penalize) ---
  if (!isSearch) {
    if (product.images.length === 0) {
      issues.push({ type: 'error', category: 'images', message: 'No product images found' })
    } else if (product.images.length < 3) {
      issues.push({ type: 'warning', category: 'images', message: `Only ${product.images.length} image(s). Aim for 4+ images with lifestyle and detail shots.` })
    }
  } else {
    if (product.images.length === 0) {
      issues.push({ type: 'warning', category: 'images', message: 'No product image in listing' })
    }
  }

  // --- Tag checks (skip for search results — Amazon doesn't expose tags) ---
  if (!isSearch) {
    if (tags.length === 0) {
      issues.push({ type: 'warning', category: 'tags', message: 'No tags/categories found. Tags improve discoverability.' })
    } else if (tags.length < 3) {
      issues.push({ type: 'info', category: 'tags', message: `Only ${tags.length} tag(s). Consider adding more for better discoverability.` })
    }
  }

  // --- Price check (always available) ---
  if (!product.price) {
    issues.push({ type: 'warning', category: 'price', message: 'No price information detected.' })
  }

  // --- Vendor check (skip for search results) ---
  if (!isSearch && !product.vendor) {
    issues.push({ type: 'info', category: 'vendor', message: 'No brand/vendor information. Adding brand name improves trust.' })
  }

  // Calculate score
  const errorCount = issues.filter((i) => i.type === 'error').length
  const warningCount = issues.filter((i) => i.type === 'warning').length
  const infoCount = issues.filter((i) => i.type === 'info').length

  const qualityScore = Math.max(0, Math.min(100, 100 - errorCount * 20 - warningCount * 10 - infoCount * 3))

  return { qualityScore, issues }
}
