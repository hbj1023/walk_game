migrate((app) => {
  // Kept as a migration boundary for databases that already applied this file.
  // Step core collection definitions are split by collection in later files.
}, (app) => {
  // No-op: split collection migrations own their own rollback behavior.
})
