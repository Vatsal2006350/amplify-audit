/**
 * SKU health scoring algorithms.
 * Pure math — zero external dependencies.
 *
 * Extracted from Amplify's production issue detection pipeline.
 */

const WEIGHTS = {
  returnRate: 40,
  ticketRate: 20,
  keywordSignals: 25,
  reasonConcentration: 15,
}

export function computeReturnRate(returnCount: number, orderCount: number): number {
  if (orderCount === 0) return 0
  return returnCount / orderCount
}

export function computeTicketRate(ticketCount: number, orderCount: number): number {
  if (orderCount === 0) return 0
  return ticketCount / orderCount
}

/**
 * Shannon entropy of reason distribution.
 * Lower entropy = more concentrated reasons = clearer signal.
 * Returns 0 (single reason) to 1 (uniform distribution).
 * Inverted so concentrated reasons score higher.
 */
export function computeReasonConcentration(breakdown: Record<string, number>): number {
  const values = Object.values(breakdown)
  const total = values.reduce((a, b) => a + b, 0)
  if (total === 0) return 0

  const probs = values.map((v) => v / total)
  const maxEntropy = Math.log2(values.length || 1) || 1
  const entropy = -probs.reduce((sum, p) => {
    if (p === 0) return sum
    return sum + p * Math.log2(p)
  }, 0)

  const normalized = maxEntropy > 0 ? entropy / maxEntropy : 0
  return 1 - normalized
}

/**
 * Composite fixability score (0-100).
 * Higher = more likely a PDP fix will reduce returns.
 */
export function computeFixabilityScore(
  returnRate: number,
  ticketRate: number,
  keywordSignalCount: number,
  reasonBreakdown: Record<string, number>,
): number {
  const returnRateScore = Math.min(returnRate * 100, 100)
  const ticketRateScore = Math.min(ticketRate * 100, 100)
  const keywordScore = Math.min(keywordSignalCount * 10, 100)
  const concentrationScore = computeReasonConcentration(reasonBreakdown) * 100

  const composite =
    (returnRateScore * WEIGHTS.returnRate +
      ticketRateScore * WEIGHTS.ticketRate +
      keywordScore * WEIGHTS.keywordSignals +
      concentrationScore * WEIGHTS.reasonConcentration) /
    100

  return Math.round(composite * 100) / 100
}

/**
 * Confidence based on sample size.
 * More orders + returns = higher confidence.
 */
export function computeConfidence(orderCount: number, returnCount: number): number {
  if (orderCount < 10) return 0.2
  if (orderCount < 30) return 0.4
  if (orderCount < 50) return 0.6
  if (returnCount < 5) return 0.5

  const sampleBonus = Math.min(orderCount / 200, 0.2)
  return Math.min(0.7 + sampleBonus, 0.95)
}
