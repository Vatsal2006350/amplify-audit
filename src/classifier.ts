/**
 * Return reason classifier.
 * Keyword-based classification across 5 issue categories.
 * 98 semantic keywords — zero external dependencies.
 *
 * Extracted from Amplify's production return analysis pipeline.
 */

import type { IssueType } from './types'

const SIZING_KEYWORDS = [
  'too small', 'too large', 'too big', 'too tight', 'too loose',
  'runs small', 'runs large', 'runs big', 'size up', 'size down',
  'wrong size', 'didnt fit', "didn't fit", 'sizing', 'fit issue',
  'too narrow', 'too wide', 'length', 'shorter than', 'longer than',
  'not my size', 'order a size', 'between sizes', 'true to size',
]

const QUALITY_KEYWORDS = [
  'defective', 'broken', 'damaged', 'poor quality', 'fell apart',
  'ripped', 'torn', 'stitching', 'material quality', 'cheap',
  'not durable', 'peeling', 'fading', 'stain', 'manufacturing defect',
]

const DESCRIPTION_MISMATCH_KEYWORDS = [
  'not as described', 'different from picture', 'misleading', 'inaccurate',
  'looks different', 'not what i expected', 'not the same', 'false advertising',
  'different material', 'not as shown', 'nothing like', 'expected',
  "doesn't match", 'description says', 'photo shows',
]

const COLOR_MISMATCH_KEYWORDS = [
  'color is different', 'wrong color', 'not the right color', 'color off',
  'shade is different', 'looks different color', 'colour',
]

const MISSING_INFO_KEYWORDS = [
  'no size guide', 'no measurements', 'unclear', 'confusing description',
  'what size should', 'how does it fit', 'need more details',
  'missing information', 'no instructions',
]

const KEYWORD_MAP: Array<{ type: IssueType; keywords: string[] }> = [
  { type: 'sizing', keywords: SIZING_KEYWORDS },
  { type: 'quality', keywords: QUALITY_KEYWORDS },
  { type: 'description_mismatch', keywords: DESCRIPTION_MISMATCH_KEYWORDS },
  { type: 'color_mismatch', keywords: COLOR_MISMATCH_KEYWORDS },
  { type: 'missing_info', keywords: MISSING_INFO_KEYWORDS },
]

const FIXABLE_ISSUE_TYPES: Set<IssueType> = new Set([
  'sizing',
  'description_mismatch',
  'color_mismatch',
  'missing_info',
])

/** Classify a single text string against all issue categories. */
export function classifyText(text: string): Map<IssueType, number> {
  const lower = text.toLowerCase()
  const scores = new Map<IssueType, number>()

  for (const { type, keywords } of KEYWORD_MAP) {
    let count = 0
    for (const kw of keywords) {
      if (lower.includes(kw)) count++
    }
    if (count > 0) {
      scores.set(type, count)
    }
  }

  return scores
}

/** Classify multiple return reason strings. Aggregates scores. */
export function classifyReasons(reasons: string[]): Map<IssueType, number> {
  const aggregate = new Map<IssueType, number>()

  for (const reason of reasons) {
    const scores = classifyText(reason)
    for (const [type, count] of scores) {
      aggregate.set(type, (aggregate.get(type) || 0) + count)
    }
  }

  return aggregate
}

/** Whether this issue type can be fixed by PDP changes (vs operational). */
export function isFixableByPDP(issueType: IssueType): boolean {
  return FIXABLE_ISSUE_TYPES.has(issueType)
}

/** Get the dominant issue type from classification scores. */
export function getPrimaryIssueType(scores: Map<IssueType, number>): IssueType | null {
  let maxType: IssueType | null = null
  let maxScore = 0

  for (const [type, score] of scores) {
    if (score > maxScore) {
      maxScore = score
      maxType = type
    }
  }

  return maxType
}

/** Build a reason breakdown from raw reason strings. */
export function buildReasonBreakdown(reasons: string[]): Record<string, number> {
  const breakdown: Record<string, number> = {}
  for (const reason of reasons) {
    const trimmed = reason.trim().toLowerCase()
    if (trimmed) {
      breakdown[trimmed] = (breakdown[trimmed] || 0) + 1
    }
  }
  return breakdown
}
