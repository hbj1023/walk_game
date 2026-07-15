const fs = require("fs")
const path = require("path")

const migrationDir = path.resolve(__dirname, "..", "..", "pb_migrations")
const rawName = process.argv[2] || ""
const name = rawName.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
if (!name) {
  console.error("Usage: node scripts/migrations/create.js <english migration name>")
  process.exit(1)
}

const parts = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Seoul", year: "numeric", month: "2-digit", day: "2-digit",
  hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
}).formatToParts(new Date())
const value = (type) => parts.find((part) => part.type === type).value
const id = `${value("year")}${value("month")}${value("day")}${value("hour")}${value("minute")}${value("second")}`
const fileName = `${id}_${name}.js`
if (fs.readdirSync(migrationDir).some((candidate) => candidate.startsWith(`${id}_`))) {
  console.error(`Migration id ${id} already exists. Wait one second and retry.`)
  process.exit(1)
}
fs.writeFileSync(path.join(migrationDir, fileName), "migrate((app) => {\n  // Apply migration.\n}, (app) => {\n  // Revert migration.\n})\n", { flag: "wx" })
console.log(path.join(migrationDir, fileName))
