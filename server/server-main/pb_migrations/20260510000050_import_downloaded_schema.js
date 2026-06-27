migrate((app) => {
  // Kept as a migration boundary for databases that already applied this file.
  // The imported schema snapshot is now split into per-collection migrations.
}, (app) => {
  // No-op: rollback should not delete existing PocketBase data from a shared
  // development instance.
})
