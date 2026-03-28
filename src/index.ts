/**
 * amplify-audit — Free, open-source product listing analyzer.
 *
 * Audit any product listing: quality score, return risk, and
 * AI-generated improvement recommendations.
 *
 * https://github.com/Vatsal2006350/amplify-audit
 */

export type {
  Product,
  ReturnData,
  IssueType,
  AuditIssue,
  ReturnRisk,
  RecommendedFix,
  AuditReport,
} from './types'

// Legacy re-export (backward compat)
export { fetchProduct, detectPlatform } from './fetcher'

// New multi-platform exports
export {
  fetchSingleProduct,
  fetchAmazonSearchProducts,
  isAmazonSearchUrl,
  isStoreUrl,
  buildAmazonSearchUrl,
} from './product-fetcher'
export { normalizeStoreUrl, fetchAllProducts } from './store-fetcher'
export { isAiAvailable, analyzeWithAi, analyzeProductsWithAi } from './ai-analyzer'

export { analyzeListingQuality } from './analyzer'
export {
  classifyReasons,
  classifyText,
  getPrimaryIssueType,
  isFixableByPDP,
  buildReasonBreakdown,
} from './classifier'
export {
  computeReturnRate,
  computeTicketRate,
  computeReasonConcentration,
  computeFixabilityScore,
  computeConfidence,
} from './scoring'
export { generateRecommendations } from './recommender'

import type { Product, ReturnData, AuditReport, ReturnRisk } from './types'
import { fetchProduct } from './fetcher'
import { analyzeListingQuality } from './analyzer'
import { classifyReasons, getPrimaryIssueType, isFixableByPDP, buildReasonBreakdown } from './classifier'
import { computeReturnRate, computeTicketRate, computeFixabilityScore, computeConfidence } from './scoring'
import { generateRecommendations } from './recommender'

export interface AuditOptions {
  /** Product URL to fetch and audit. */
  url?: string
  /** Pre-fetched product data (skip URL fetching). */
  product?: Product
  /** Return data to enrich the audit with return risk analysis. */
  returns?: ReturnData
}

/**
 * Run a full audit on a product listing.
 *
 * @example
 * ```ts
 * import { audit } from 'amplify-audit'
 *
 * // Audit by URL
 * const report = await audit({ url: 'https://mystore.myshopify.com/products/blue-sweater' })
 * console.log(report.qualityScore) // 72
 *
 * // Audit with return data
 * const report = await audit({
 *   url: 'https://amazon.com/dp/B09V3KXJPB',
 *   returns: {
 *     reasons: ['too small', 'runs small', 'color different'],
 *     orderCount: 200,
 *     returnCount: 40,
 *   },
 * })
 * ```
 */
export async function audit(options: AuditOptions): Promise<AuditReport> {
  // 1. Get product data
  let product: Product
  if (options.product) {
    product = options.product
  } else if (options.url) {
    product = await fetchProduct(options.url)
  } else {
    throw new Error('Either url or product must be provided')
  }

  // 2. Analyze listing quality
  const { qualityScore, issues } = analyzeListingQuality(product)

  // 3. Return risk analysis (if return data provided)
  let returnRisk: ReturnRisk | null = null
  let skuHealthScore: number | null = null
  let confidence: number | null = null

  if (options.returns) {
    const { reasons, orderCount = 0, returnCount = 0, ticketCount = 0 } = options.returns

    // Classify return reasons
    const classification = classifyReasons(reasons)
    const primaryIssueType = getPrimaryIssueType(classification)
    const reasonBreakdown = buildReasonBreakdown(reasons)

    // Build top reasons list
    const reasonCounts = new Map<string, number>()
    for (const reason of reasons) {
      const trimmed = reason.trim().toLowerCase()
      if (trimmed) reasonCounts.set(trimmed, (reasonCounts.get(trimmed) || 0) + 1)
    }
    const totalReasons = reasons.length || 1
    const topReasons = [...reasonCounts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([reason, count]) => ({
        reason,
        percentage: Math.round((count / totalReasons) * 100),
      }))

    // Determine risk level
    const returnRate = computeReturnRate(returnCount, orderCount)
    let riskLevel: ReturnRisk['score'] = 'LOW'
    if (returnRate > 0.3) riskLevel = 'CRITICAL'
    else if (returnRate > 0.2) riskLevel = 'HIGH'
    else if (returnRate > 0.1) riskLevel = 'MEDIUM'

    returnRisk = {
      score: riskLevel,
      topReasons,
      primaryIssueType,
      fixableByPDP: primaryIssueType ? isFixableByPDP(primaryIssueType) : false,
    }

    // SKU health scoring
    let keywordSignalCount = 0
    for (const [, count] of classification) keywordSignalCount += count

    skuHealthScore = computeFixabilityScore(
      returnRate,
      computeTicketRate(ticketCount, orderCount),
      keywordSignalCount,
      reasonBreakdown,
    )
    confidence = computeConfidence(orderCount, returnCount)
  }

  // 4. Generate recommendations
  const primaryIssueType = returnRisk?.primaryIssueType ?? null
  const returnRate = options.returns ? computeReturnRate(options.returns.returnCount || 0, options.returns.orderCount || 0) : undefined
  const recommendations = generateRecommendations(product, primaryIssueType, returnRate)

  return {
    product,
    qualityScore,
    issues,
    returnRisk,
    recommendations,
    skuHealthScore,
    confidence,
  }
}
