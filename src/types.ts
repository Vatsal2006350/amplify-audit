/** Normalized product data from any platform */
export interface Product {
  url?: string
  platform?: 'shopify' | 'amazon' | 'unknown'
  title: string
  description: string
  tags: string[]
  vendor?: string
  productType?: string
  price?: string
  images: string[]
  variants: Array<{
    title: string
    sku?: string
    price?: string
  }>
}

/** Return data (optional, enriches the audit) */
export interface ReturnData {
  reasons: string[]
  orderCount?: number
  returnCount?: number
  ticketCount?: number
}

/** Issue types that can be detected */
export type IssueType =
  | 'sizing'
  | 'quality'
  | 'description_mismatch'
  | 'color_mismatch'
  | 'missing_info'

/** A single issue found in the listing */
export interface AuditIssue {
  type: 'error' | 'warning' | 'info'
  category: string
  message: string
}

/** Return risk breakdown */
export interface ReturnRisk {
  score: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  topReasons: Array<{ reason: string; percentage: number }>
  primaryIssueType: IssueType | null
  fixableByPDP: boolean
}

/** A recommended change */
export interface RecommendedFix {
  field: string
  before: string
  after: string
  rationale: string
}

/** Full audit report */
export interface AuditReport {
  product: Product
  qualityScore: number
  issues: AuditIssue[]
  returnRisk: ReturnRisk | null
  recommendations: RecommendedFix[]
  skuHealthScore: number | null
  confidence: number | null
}
