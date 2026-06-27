const PocketBase = require("pocketbase/cjs");
const path = require("path");

require("dotenv").config({ path: path.resolve(__dirname, "../../.env"), quiet: true });

const pocketBaseUrl = process.env.POCKETBASE_URL || "http://localhost:8090";
const pb = new PocketBase(pocketBaseUrl);

module.exports = pb;
