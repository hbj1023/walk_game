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

Each new migration has one responsibility: schema, catalog content, balance, shop linkage, or reviewed deletion. Required records must fail loudly; empty `catch` blocks and silent skips are forbidden. Add PocketBase fields through the collection field API and `app.save(collection)`, not raw `ALTER TABLE`.

Destructive migrations require a reference audit, explicit user review of record ids, immediate reference checks, and the marker `// migration-policy: destructive-reviewed`.

## Validation and deployment

```bash
node server/server-main/scripts/migrations/validate.js
```

The validator checks ids, JavaScript syntax, forbidden patterns, and new image references. Before deployment, back up `data.db`, rebuild the PocketBase image, apply migrations, and run content assertions. `No new migrations to apply` alone is not proof that content is correct. Rebuild the Flutter client separately when asset resolution changes.
