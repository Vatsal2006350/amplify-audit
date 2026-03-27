/**
 * Recommendation generator.
 * Generates PDP improvement suggestions based on issue type.
 * Works without an API key (deterministic templates).
 *
 * Extracted from Amplify's production recommendation pipeline.
 */

import type { Product, IssueType, RecommendedFix } from './types'

/** Generate recommendations based on detected issues. No API key needed. */
export function generateRecommendations(
  product: Product,
  primaryIssueType: IssueType | null,
  returnRate?: number,
): RecommendedFix[] {
  const fixes: RecommendedFix[] = []

  if (primaryIssueType === 'sizing') {
    fixes.push({
      field: 'title',
      before: product.title,
      after: `${product.title} (Runs Small — Consider Sizing Up)`,
      rationale: 'Set expectations at the top of the listing to reduce fit-related returns.',
    })
    fixes.push({
      field: 'description',
      before: truncate(product.description, 200),
      after: appendToDescription(product.description,
        '<p><strong>Fit note:</strong> This style runs slightly small. If you\'re between sizes or prefer extra room, consider sizing up.</p>'
      ),
      rationale: 'Adds concrete fit guidance shoppers can act on before purchasing.',
    })
  }

  if (primaryIssueType === 'description_mismatch') {
    fixes.push({
      field: 'description',
      before: truncate(product.description, 200),
      after: appendToDescription(product.description,
        '<p><strong>What to expect:</strong> Please review material details and photos carefully. Color may appear slightly different depending on screen settings.</p>'
      ),
      rationale: 'Sets realistic expectations to reduce "not as described" returns.',
    })
  }

  if (primaryIssueType === 'color_mismatch') {
    fixes.push({
      field: 'description',
      before: truncate(product.description, 200),
      after: appendToDescription(product.description,
        '<p><strong>Color note:</strong> Actual color may vary slightly from photos due to screen differences and lighting. See all product images for the most accurate representation.</p>'
      ),
      rationale: 'Preemptively addresses color expectation gaps, a common return driver.',
    })
  }

  if (primaryIssueType === 'missing_info') {
    const missing: string[] = []
    const lower = (product.description || '').toLowerCase()
    if (!/\b(size|sizing|fit|measurement)\b/.test(lower)) missing.push('sizing/fit information')
    if (!/\b(material|fabric|cotton|polyester)\b/.test(lower)) missing.push('material details')
    if (!/\b(wash|care|clean)\b/.test(lower)) missing.push('care instructions')

    if (missing.length > 0) {
      fixes.push({
        field: 'description',
        before: truncate(product.description, 200),
        after: appendToDescription(product.description,
          `<p><strong>Details:</strong> ${missing.map(m => `[Add ${m}]`).join(' ')}</p>`
        ),
        rationale: `Missing critical product info: ${missing.join(', ')}. Adding these reduces uncertainty-driven returns.`,
      })
    }
  }

  // Generic: title length fix
  if (product.title && product.title.length < 30) {
    fixes.push({
      field: 'title',
      before: product.title,
      after: `${product.title} — [Add key features, material, size range]`,
      rationale: 'Short titles miss SEO keywords and leave buyers without context.',
    })
  }

  // Generic: empty description
  if (!product.description || stripHtml(product.description).length < 50) {
    fixes.push({
      field: 'description',
      before: product.description || '(empty)',
      after: '[Add 300-1000 character description covering: key features, sizing/fit, materials, care instructions, and what makes this product stand out]',
      rationale: 'Empty or very short descriptions are the single biggest driver of preventable returns.',
    })
  }

  return fixes
}

function truncate(text: string, maxLen: number): string {
  const clean = stripHtml(text)
  if (clean.length <= maxLen) return clean
  return clean.slice(0, maxLen) + '...'
}

function stripHtml(html: string): string {
  return (html || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
}

function appendToDescription(existing: string, addition: string): string {
  const trimmed = (existing || '').trim()
  if (trimmed.length < 10) return addition
  return truncate(trimmed, 300) + '\n\n' + addition
}
