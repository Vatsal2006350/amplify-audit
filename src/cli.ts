#!/usr/bin/env node

/**
 * amplify-audit CLI
 *
 * Usage:
 *   npx amplify-audit <product-url>
 *   npx amplify-audit <product-url> --json
 *   npx amplify-audit --product ./product.json --returns ./returns.csv
 */

import { program } from 'commander'
import { readFileSync } from 'fs'
import { audit } from './index'
import type { AuditReport, ReturnData, Product } from './types'

const VERSION = '0.1.0'

program
  .name('amplify-audit')
  .description('Audit any product listing. Get quality scores, return risk, and improvement recommendations.')
  .version(VERSION)
  .argument('[url]', 'Product URL to audit (Shopify, Amazon, or any product page)')
  .option('--product <path>', 'Path to product JSON file (instead of URL)')
  .option('--returns <path>', 'Path to returns JSON file (array of reason strings)')
  .option('--json', 'Output as JSON')
  .option('--min-score <n>', 'Exit with code 1 if quality score is below this threshold (for CI/CD)', parseInt)
  .action(async (url: string | undefined, opts: any) => {
    try {
      // Build options
      let product: Product | undefined
      let returns: ReturnData | undefined

      if (opts.product) {
        const raw = readFileSync(opts.product, 'utf-8')
        product = JSON.parse(raw)
      }

      if (opts.returns) {
        const raw = readFileSync(opts.returns, 'utf-8')
        const parsed = JSON.parse(raw)
        if (Array.isArray(parsed)) {
          returns = { reasons: parsed }
        } else {
          returns = parsed as ReturnData
        }
      }

      if (!url && !product) {
        console.error('Error: Provide a product URL or --product file path.')
        console.error('  amplify-audit https://mystore.myshopify.com/products/my-product')
        console.error('  amplify-audit --product ./product.json')
        process.exit(1)
      }

      // Run audit
      if (!opts.json) {
        console.log()
        console.log(`\x1b[32m⟳\x1b[0m Fetching product data...`)
      }

      const report = await audit({ url, product, returns })

      if (opts.json) {
        console.log(JSON.stringify(report, null, 2))
      } else {
        printReport(report)
      }

      // CI/CD threshold check
      if (opts.minScore && report.qualityScore < opts.minScore) {
        console.log()
        console.log(`\x1b[31m✗\x1b[0m Quality score ${report.qualityScore} is below threshold ${opts.minScore}`)
        process.exit(1)
      }

    } catch (error: any) {
      console.error(`\x1b[31m✗\x1b[0m ${error.message}`)
      process.exit(1)
    }
  })

function printReport(report: AuditReport) {
  const { product, qualityScore, issues, returnRisk, recommendations } = report

  console.log(`\x1b[32m⟳\x1b[0m Running quality analysis...`)
  if (returnRisk) {
    console.log(`\x1b[32m⟳\x1b[0m Classifying return risk...`)
  }
  console.log()

  // Product info
  console.log(`\x1b[1m${product.title || '(untitled)'}\x1b[0m`)
  if (product.platform) console.log(`\x1b[90mPlatform: ${product.platform}\x1b[0m`)
  if (product.url) console.log(`\x1b[90m${product.url}\x1b[0m`)
  console.log()

  // Quality score
  const scoreColor = qualityScore >= 70 ? '\x1b[32m' : qualityScore >= 40 ? '\x1b[33m' : '\x1b[31m'
  const scoreLabel = qualityScore >= 70 ? 'GOOD' : qualityScore >= 40 ? 'NEEDS WORK' : 'POOR'
  console.log(`Quality Score: ${scoreColor}\x1b[1m${qualityScore}/100\x1b[0m  ${scoreColor}${scoreLabel}\x1b[0m`)
  console.log()

  // Issues
  if (issues.length > 0) {
    console.log('\x1b[90m─── Issues Found ───\x1b[0m')
    for (const issue of issues) {
      const icon = issue.type === 'error' ? '\x1b[31m●\x1b[0m' : issue.type === 'warning' ? '\x1b[33m▲\x1b[0m' : '\x1b[90m○\x1b[0m'
      console.log(`  ${icon} ${issue.message}`)
    }
    console.log()
  }

  // Return risk
  if (returnRisk) {
    const riskColor = returnRisk.score === 'CRITICAL' ? '\x1b[31m' : returnRisk.score === 'HIGH' ? '\x1b[31m' : returnRisk.score === 'MEDIUM' ? '\x1b[33m' : '\x1b[32m'
    console.log('\x1b[90m─── Return Risk Analysis ───\x1b[0m')
    console.log(`  Risk Level: ${riskColor}\x1b[1m${returnRisk.score}\x1b[0m`)
    if (returnRisk.primaryIssueType) {
      console.log(`  Primary Issue: \x1b[1m${returnRisk.primaryIssueType.replace(/_/g, ' ')}\x1b[0m`)
      console.log(`  Fixable by PDP: ${returnRisk.fixableByPDP ? '\x1b[32mYes\x1b[0m' : '\x1b[31mNo\x1b[0m'}`)
    }
    if (returnRisk.topReasons.length > 0) {
      console.log()
      for (const r of returnRisk.topReasons) {
        const bar = '█'.repeat(Math.round(r.percentage / 5)) + '░'.repeat(20 - Math.round(r.percentage / 5))
        console.log(`  ${r.reason.padEnd(24)} ${bar} ${r.percentage}%`)
      }
    }
    console.log()
  }

  // SKU health
  if (report.skuHealthScore !== null) {
    console.log(`  SKU Health Score: \x1b[1m${report.skuHealthScore.toFixed(1)}/100\x1b[0m`)
    console.log(`  Confidence: \x1b[1m${((report.confidence || 0) * 100).toFixed(0)}%\x1b[0m`)
    console.log()
  }

  // Recommendations
  if (recommendations.length > 0) {
    console.log('\x1b[90m─── Recommendations ───\x1b[0m')
    for (const fix of recommendations) {
      console.log(`  \x1b[1m${fix.field}\x1b[0m`)
      console.log(`    \x1b[31m- ${truncate(fix.before, 80)}\x1b[0m`)
      console.log(`    \x1b[32m+ ${truncate(fix.after, 80)}\x1b[0m`)
      console.log(`    \x1b[90m${fix.rationale}\x1b[0m`)
      console.log()
    }
  }

  // Footer
  console.log(`\x1b[32m✓\x1b[0m Audit complete.`)
  console.log(`\x1b[90mWant to auto-fix across all channels? → https://use-amplify.com\x1b[0m`)
}

function truncate(text: string, maxLen: number): string {
  const clean = text.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
  if (clean.length <= maxLen) return clean
  return clean.slice(0, maxLen) + '...'
}

program.parse()
