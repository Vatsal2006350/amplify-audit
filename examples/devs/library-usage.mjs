import { audit } from '../../dist/index.js'

async function main() {
  const sampleUrl = 'https://allbirds.com/products/mens-tree-runners'

  const report = await audit({
    url: sampleUrl,
    returns: {
      reasons: ['too small', 'runs small', 'fit issue', 'color different'],
      orderCount: 150,
      returnCount: 35,
      ticketCount: 8,
    },
  })

  console.log('Product:', report.product.title)
  console.log('Quality Score:', report.qualityScore)
  console.log('Issues Found:', report.issues.length)
  console.log('Top Recommendation:', report.recommendations[0]?.rationale || 'None')
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
