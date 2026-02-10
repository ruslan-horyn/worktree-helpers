# Standard Output Format Templates

## Report Formats

### Discrepancy Report

```markdown
## Discrepancy Report: [Topic]

**Generated:** [Date]
**Files Analyzed:** [Count]

### Summary

| Metric | Value |
|--------|-------|
| Total items checked | X |
| Issues found | Y |
| Warnings | Z |

### Issues

#### Issue 1: [Title]

- **Location:** `path/to/file.ts:42`
- **Expected:** [description]
- **Actual:** [description]
- **Severity:** High/Medium/Low
- **Fix:** [action required]

#### Issue 2: [Title]
...
```

### Comparison Report

```markdown
## Comparison: [Source A] vs [Source B]

### Matching Items ✅

| Item | Source A | Source B |
|------|----------|----------|
| ... | ... | ... |

### Differences ❌

| Item | Source A | Source B | Action |
|------|----------|----------|--------|
| ... | ... | ... | ... |

### Missing in Source A

- item1
- item2

### Missing in Source B

- item3
- item4
```

### Validation Report

```markdown
## Validation Report: [Target]

### Results

| Check | Status | Details |
|-------|--------|---------|
| Structure valid | ✅ | All required fields present |
| Types match | ❌ | 3 type mismatches found |
| Constraints met | ⚠️ | 1 warning |

### Details

#### ❌ Type Mismatches

1. `field1`: expected `string`, got `number`
2. `field2`: expected `Date`, got `string`
3. `field3`: expected `boolean | null`, got `boolean`

#### ⚠️ Warnings

1. `field4`: deprecated type usage
```

## Code Output Formats

### Schema File Template

```typescript
/**
 * @file [Module] Schemas
 * @description Zod validation schemas for [module] operations
 */

import { z } from 'zod';
import { uuidSchema, paginationSchema } from '@/services/shared/schemas';

// ============================================================================
// Create Schemas
// ============================================================================

/**
 * Schema for creating a new [entity]
 */
export const create[Entity]Schema = z.object({
  name: z.string().min(1).max(255),
  // ... fields
});

export type Create[Entity]Input = z.infer<typeof create[Entity]Schema>;

// ============================================================================
// Update Schemas
// ============================================================================

/**
 * Schema for updating an existing [entity]
 */
export const update[Entity]Schema = z.object({
  id: uuidSchema,
  name: z.string().min(1).max(255).optional(),
  // ... optional fields
});

export type Update[Entity]Input = z.infer<typeof update[Entity]Schema>;

// ============================================================================
// Query Schemas
// ============================================================================

/**
 * Schema for filtering [entities]
 */
export const [entity]FilterSchema = paginationSchema.extend({
  search: z.string().optional(),
  // ... filter fields
});

export type [Entity]Filter = z.infer<typeof [entity]FilterSchema>;
```

### Migration File Template

```sql
-- ============================================================================
-- Migration: [timestamp]_[name].sql
-- Purpose: [description]
-- ============================================================================

-- [Section 1]
-- ----------------------------------------------------------------------------

[SQL statements]

-- [Section 2]
-- ----------------------------------------------------------------------------

[SQL statements]
```

### Documentation Update Template

```markdown
## [Section Title]

### [Subsection]

| Column | Type | Constraints |
|--------|------|-------------|
| id | UUID | PRIMARY KEY |
| name | VARCHAR(255) | NOT NULL |
| ... | ... | ... |

**Notes:**
- [Important note 1]
- [Important note 2]
```

## List Formats

### Action Items

```markdown
## Required Changes

### High Priority

1. **[File 1]** - [change description]
   - Line X: change A to B
   - Line Y: add C

2. **[File 2]** - [change description]
   - Remove deprecated field

### Medium Priority

3. **[File 3]** - [change description]

### Low Priority

4. **[File 4]** - [optional improvement]
```

### Checklist

```markdown
## Pre-merge Checklist

### Code Quality
- [ ] All schemas have corresponding types exported
- [ ] Field validations match database constraints
- [ ] Error messages are user-friendly

### Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

### Documentation
- [ ] README updated
- [ ] API docs reflect changes
- [ ] Migration notes added
```

## Structured Data Formats

### JSON Output

```json
{
  "summary": {
    "total": 10,
    "passed": 8,
    "failed": 2
  },
  "results": [
    {
      "name": "item1",
      "status": "passed",
      "details": null
    },
    {
      "name": "item2",
      "status": "failed",
      "details": "Missing required field"
    }
  ]
}
```

### YAML Output

```yaml
report:
  title: Schema Validation
  date: 2024-01-15

results:
  - file: services/clients/schemas.ts
    status: valid
    warnings: []

  - file: services/workers/schemas.ts
    status: invalid
    errors:
      - field: phone
        message: Missing .optional() for nullable column
```

## Progress Indicators

### Step-by-Step Progress

```markdown
## Progress

1. ✅ Read migration files
2. ✅ Parse table definitions
3. 🔄 Compare with schemas (in progress)
4. ⏳ Generate report (pending)
5. ⏳ Apply fixes (pending)
```

### Summary Statistics

```markdown
## Analysis Complete

📊 **Statistics:**
- Files scanned: 12
- Schemas found: 34
- Fields validated: 156

✅ **Passed:** 142 fields (91%)
❌ **Failed:** 8 fields (5%)
⚠️ **Warnings:** 6 fields (4%)
```
