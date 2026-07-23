# PocketBase Migration Policy

## Frozen legacy history

- Every migration through `20260715240000` is immutable production history.
- Do not rename, delete, reorder, or edit a frozen migration.
- Known duplicate ids are documented in `scripts/migrations/legacy_duplicate_ids.json` only so validation can report them without blocking future work.
- Repair a missed operation with a new unique migration. Never expand the legacy duplicate allowlist.

## Creating migrations

```bash
node server/server-main/scripts/migrations/create.js descriptive_english_name
```

Each new migration has one responsibility: schema, catalog content, balance, shop linkage, or reviewed deletion. Schema fields and record data must never be changed in the same migration because PocketBase may not expose the new SQLite column until the schema migration commits. Required records must fail loudly; empty `catch` blocks and silent skips are forbidden. Add PocketBase fields through the collection field API and `app.save(collection)`, not raw `ALTER TABLE`.

If the PocketBase collection schema contains a field but the physical SQLite column is still missing after the schema migration commits, add a separate repair migration before any data migration. A reviewed repair may use `ALTER TABLE ... ADD COLUMN` with the marker `// migration-policy: schema-drift-repair-reviewed`, must tolerate only the duplicate-column case, and must rethrow every other SQL error.

`collection.fields.getByName(name)` may return an empty value instead of throwing when a field is absent. Field guards must test the returned value and may use `try/catch` only as a version compatibility fallback. A migration history row or `No new migrations to apply` is not proof that a field exists; verify both the collection definition and the physical SQLite column after deployment.

When repairing canonical catalog content, select the record by immutable `catalog_key` first and only then fall back to image path or display name. Reapply every required field and shop link, deactivate duplicate templates and their shop links, and preserve referenced owned-equipment records instead of deleting them. A successful migration log is not enough; verify the expected active canonical count and retired duplicate count.

Destructive migrations require a reference audit, explicit user review of record ids, immediate reference checks, and the marker `// migration-policy: destructive-reviewed`.

## Validation and deployment

```bash
node server/server-main/scripts/migrations/validate.js
```

The validator checks ids, JavaScript syntax, forbidden patterns, and new image references. Before deployment, back up `data.db`, rebuild the PocketBase image, apply migrations, and run content assertions. `No new migrations to apply` alone is not proof that content is correct. Rebuild the Flutter client separately when asset resolution changes.
