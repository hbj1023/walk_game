const fs = require("fs")
const path = require("path")
const { spawnSync } = require("child_process")

const serverRoot = path.resolve(__dirname, "..", "..")
const repoRoot = path.resolve(serverRoot, "..", "..")
const migrationDir = path.join(serverRoot, "pb_migrations")
const legacyCutoff = "20260715240000"
const legacyDuplicates = require("./legacy_duplicate_ids.json")
const errors = []
const warnings = []
const migrationFiles = fs.readdirSync(migrationDir).filter((name) => name.endsWith(".js")).sort()
const byID = new Map()

for (const fileName of migrationFiles) {
  const match = /^(\d{14})_([a-z0-9_]+)\.js$/.exec(fileName)
  if (!match) {
    errors.push(`${fileName}: migration filename must be <14 digits>_<snake_case>.js`)
    continue
  }
  const [, id] = match
  const group = byID.get(id) || []
  group.push(fileName)
  byID.set(id, group)

  const syntax = spawnSync(process.execPath, ["--check", path.join(migrationDir, fileName)], { encoding: "utf8" })
  if (syntax.status !== 0) errors.push(`${fileName}: JavaScript syntax check failed\n${syntax.stderr.trim()}`)
  if (id <= legacyCutoff) continue

  const source = fs.readFileSync(path.join(migrationDir, fileName), "utf8")
  if (/catch\s*\([^)]*\)\s*\{\s*\}/s.test(source)) errors.push(`${fileName}: empty catch blocks are forbidden`)
  if (/ALTER\s+TABLE\s+item_templates\s+(ADD|DROP)\s+COLUMN/i.test(source)) {
    errors.push(`${fileName}: manage item_templates fields through PocketBase collection fields`)
  }
  if (/\.fields\.add\s*\(/.test(source) && /(findRecordsByFilter|findFirstRecordByFilter|app\.save\s*\(\s*(template|record))/i.test(source)) {
    errors.push(`${fileName}: schema fields and record data must be changed in separate migrations`)
  }
  if (/\.length\s*===\s*0\)\s*continue/.test(source)) errors.push(`${fileName}: silently skipping required records is forbidden`)
  if (/(app\.delete\(|DELETE\s+FROM)/i.test(source) && !source.includes("migration-policy: destructive-reviewed")) {
    errors.push(`${fileName}: destructive migrations require a reviewed policy marker`)
  }

  const assetPattern = /["'`](assets\/images\/[^"'`]+)["'`]/g
  for (const assetMatch of source.matchAll(assetPattern)) {
    const assetPath = path.join(repoRoot, "client", "client-main", assetMatch[1])
    if (!fs.existsSync(assetPath)) errors.push(`${fileName}: missing asset ${assetMatch[1]}`)
  }
}

for (const [id, files] of byID.entries()) {
  if (files.length < 2) continue
  const expected = (legacyDuplicates[id] || []).slice().sort()
  const actual = files.slice().sort()
  if (JSON.stringify(expected) === JSON.stringify(actual)) warnings.push(`${id}: frozen legacy duplicate`)
  else errors.push(`${id}: duplicate migration id (${actual.join(", ")})`)
}
for (const [id, files] of Object.entries(legacyDuplicates)) {
  const actual = (byID.get(id) || []).slice().sort()
  if (JSON.stringify(actual) !== JSON.stringify(files.slice().sort())) {
    errors.push(`${id}: legacy duplicate allowlist no longer matches frozen files`)
  }
}

for (const warning of warnings) console.warn(`WARN ${warning}`)
if (errors.length > 0) {
  for (const error of errors) console.error(`ERROR ${error}`)
  process.exit(1)
}
console.log(`Validated ${migrationFiles.length} migrations (${warnings.length} frozen duplicate ids).`)
