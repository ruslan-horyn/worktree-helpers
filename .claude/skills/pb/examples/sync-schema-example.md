# Example: Schema Synchronization Prompt

This is a well-structured prompt for synchronizing database documentation with migrations.

---

# Task: Synchronize Database Documentation

## Context

Database expert working with PostgreSQL and TypeScript in a Next.js/Supabase project.

Project stack:
- Supabase (PostgreSQL database)
- Zod (input validation)
- Auto-generated TypeScript types (`types/database.ts`)

Detected discrepancy between schema documentation and actual migrations. Documentation must reflect current database state.

## Source Files

### Migrations (Source of Truth)

- `supabase/migrations/20251209220746_tables.sql` - table definitions
- `supabase/migrations/20251209220747_indexes.sql` - indexes
- `supabase/migrations/20251209220748_functions_triggers.sql` - functions and triggers
- `supabase/migrations/20251209220749_rls_policies.sql` - RLS policies

### Documentation (To Update)

- `docs/db-plan.md` - database schema documentation

### Validation Schemas (To Verify)

- `services/shared/schemas.ts` - shared base schemas
- `services/clients/schemas.ts` - client schemas
- `services/workers/schemas.ts` - worker schemas

### Type Reference

- `types/database.ts` - auto-generated TypeScript types

## Tasks

### Phase 1: Migration Analysis

Read all migration files and extract for each table:

1. **Column structure:**
   - Column name
   - PostgreSQL data type
   - Constraints (NOT NULL, UNIQUE, DEFAULT, CHECK)
   - Foreign keys (REFERENCES)

2. **Indexes:**
   - Index name
   - Type (B-tree, GIN, partial)
   - Columns

### Phase 2: Documentation Update

Update `docs/db-plan.md` to match migrations exactly:

**Table format:**

```markdown
### Table `table_name`

| Column | Data Type | Constraints |
|--------|-----------|-------------|
| id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() |
| name | VARCHAR(255) | NOT NULL |
| email | VARCHAR(255) | NULL |
```

**Critical checks:**
- Is column `NOT NULL` or nullable?
- Are there default values (`DEFAULT`)?
- Are there `CHECK` constraints?
- Foreign key `ON DELETE` actions?

### Phase 3: Schema Verification

Compare Zod schemas with updated documentation:

**For each schema check:**

1. **Required vs optional fields:**
   - `NOT NULL` in DB → required in Zod (no `.optional()`)
   - Nullable in DB → optional in Zod (`.optional()` or `.nullable()`)

2. **Data types:**
   - `VARCHAR(n)` → `z.string().max(n)`
   - `UUID` → `z.string().uuid()`
   - `BOOLEAN` → `z.boolean()`
   - `TIMESTAMPTZ` → `z.string().datetime()`

## Output Format

### 1. Documentation Discrepancy Report

```markdown
## Discrepancies in db-plan.md

### Table: clients
| Column | db-plan.md | Migration | Action |
|--------|------------|-----------|--------|
| email | NULL | NOT NULL | Change to NOT NULL |
```

### 2. Schema Discrepancy Report

```markdown
## Discrepancies in Zod Schemas

### File: services/clients/schemas.ts

#### Schema: createClientSchema
| Field | Expected (per DB) | Actual | Status |
|-------|-------------------|--------|--------|
| email | required (NOT NULL) | optional | ❌ Mismatch |
| name | required | required | ✅ Match |
```

### 3. Change Summary

List of specific changes per file.

## Constraints

- DO NOT modify migration files - they are source of truth
- DO NOT modify `types/database.ts` - auto-generated
- ONLY update `docs/db-plan.md` and `services/*/schemas.ts`
- Preserve existing documentation format and style
