// cds build does not ship CSV files for SQLite. The deployed app runs on in-memory SQLite
// (demo only), so copy the app's initial data next to the compiled model. CAP loads
// srv/data/*.csv on startup. The API_BUSINESS_PARTNER mock data is left out: in the cloud
// that entity is read live from S/4HANA.
import { cpSync, mkdirSync, readdirSync } from 'node:fs'

const target = 'gen/srv/srv/data'
mkdirSync(target, { recursive: true })
for (const file of readdirSync('db/data').filter(f => f.startsWith('bpgov-') && f.endsWith('.csv'))) {
  cpSync(`db/data/${file}`, `${target}/${file}`)
  console.log(`copied db/data/${file} -> ${target}/`)
}
