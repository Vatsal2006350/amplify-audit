/**
 * AI-powered product listing analyzer using Claude.
 * Provides deep, contextual analysis that goes beyond rule-based checks.
 */

import Anthropic from '@anthropic-ai/sdk'
import type { Product, AuditIssue } from './types'

let client: Anthropic | null = null

function getClient(): Anthropic {
  if (!client) {
    client = new Anthropic()
  }
  return client
}

export function isAiAvailable(): boolean {
  return !!process.env.ANTHROPIC_API_KEY
}

interface AiAnalysis {
  qualityScore: number
  issues: AuditIssue[]
  summary: string
}

/** Analyze a single product with Claude. */
export async function analyzeWithAi(product: Product): Promise<AiAnalysis> {
  const anthropic = getClient()

  const productContext = [
    `Title: ${product.title || '(empty)'}`,
    `Description: ${product.description ? product.description.slice(0, 2000) : '(empty)'}`,
    `Price: ${product.price || '(not listed)'}`,
    `Brand: ${product.vendor || '(unknown)'}`,
    `Images: ${product.images.length} image(s)`,
    `Tags: ${product.tags.length > 0 ? product.tags.join(', ') : '(none)'}`,
    `Variants: ${product.variants.length > 0 ? product.variants.map(v => v.title).join(', ') : '(none)'}`,
    `Platform: ${product.platform || 'unknown'}`,
    `URL: ${product.url || '(none)'}`,
  ].join('\n')

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-5-20250929',
    max_tokens: 1024,
    system: `You are an expert e-commerce listing quality auditor. You analyze product listings and identify specific, actionable issues that hurt conversion rates and drive returns.

Be direct and specific. Don't repeat obvious things. Focus on what ACTUALLY matters for this specific product category.

Respond with valid JSON only, no markdown. Schema:
{
  "score": number (0-100, be realistic — most decent listings score 55-80),
  "summary": string (1 sentence, the single most important thing about this listing),
  "issues": [
    {
      "type": "error" | "warning" | "info",
      "category": string (sizing|description|title|images|material|care|tags|price|seo|trust),
      "message": string (specific, actionable — reference the actual product)
    }
  ]
}

Scoring guide:
- 90-100: Exceptional listing, nothing significant to improve
- 70-89: Good listing with minor improvements possible
- 50-69: Decent but missing important information
- 30-49: Poor listing, significant gaps
- 0-29: Very poor, critical information missing`,
    messages: [
      {
        role: 'user',
        content: `Analyze this product listing:\n\n${productContext}`,
      },
    ],
  })

  const text = response.content[0].type === 'text' ? response.content[0].text : ''

  try {
    // Try parsing the JSON directly
    let parsed = JSON.parse(text)

    // Handle if Claude wraps in markdown code block
    if (typeof parsed === 'string') {
      parsed = JSON.parse(parsed)
    }

    return {
      qualityScore: Math.max(0, Math.min(100, parsed.score || 50)),
      issues: (parsed.issues || []).map((i: any) => ({
        type: i.type || 'info',
        category: i.category || 'description',
        message: i.message || '',
      })),
      summary: parsed.summary || '',
    }
  } catch {
    // Try extracting JSON from potential markdown wrapper
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0])
        return {
          qualityScore: Math.max(0, Math.min(100, parsed.score || 50)),
          issues: (parsed.issues || []).map((i: any) => ({
            type: i.type || 'info',
            category: i.category || 'description',
            message: i.message || '',
          })),
          summary: parsed.summary || '',
        }
      } catch { /* fall through */ }
    }

    return {
      qualityScore: 50,
      issues: [{ type: 'info', category: 'description', message: 'AI analysis could not parse results' }],
      summary: '',
    }
  }
}

/** Analyze multiple products with Claude in parallel batches. */
export async function analyzeProductsWithAi(
  products: Product[],
  opts?: { maxAiProducts?: number; onProgress?: (done: number) => void },
): Promise<Map<number, AiAnalysis>> {
  const maxAi = opts?.maxAiProducts ?? 20
  const results = new Map<number, AiAnalysis>()
  const toAnalyze = products.slice(0, maxAi)

  // Process in batches of 5 to avoid rate limits
  const batchSize = 5
  for (let i = 0; i < toAnalyze.length; i += batchSize) {
    const batch = toAnalyze.slice(i, i + batchSize)
    const batchResults = await Promise.all(
      batch.map((product, idx) =>
        analyzeWithAi(product)
          .then(result => ({ index: i + idx, result }))
          .catch(() => ({
            index: i + idx,
            result: null as AiAnalysis | null,
          }))
      )
    )

    for (const { index, result } of batchResults) {
      if (result) results.set(index, result)
    }

    opts?.onProgress?.(Math.min(i + batchSize, toAnalyze.length))
  }

  return results
}
