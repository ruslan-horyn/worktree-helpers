# Example: Code Generation Prompt

This is a well-structured prompt for generating TypeScript code from specifications.

---

# Task: Generate Zod Validation Schemas

## Context

TypeScript developer creating Zod validation schemas for a Next.js application with Supabase backend.

Project conventions:
- Schemas in `/services/[module]/schemas.ts`
- Shared schemas in `/services/shared/schemas.ts`
- Types exported alongside schemas
- JSDoc comments for public APIs

## Source Files

### Database Models

- `types/database.ts` - auto-generated database types

### Existing Patterns

- `services/shared/schemas.ts` - reusable field schemas
- `services/clients/schemas.ts` - reference implementation

### Requirements

- `docs/server-actions-plan.md` - action specifications

## Tasks

### Phase 1: Pattern Analysis

1. Read existing schema files to understand conventions
2. Extract reusable patterns:
   - UUID validation
   - Phone number format
   - Email validation
   - Pagination parameters

### Phase 2: Schema Generation

For each module, create schemas following naming conventions:

- `create[Entity]Schema` - create operations
- `update[Entity]Schema` - update operations
- `delete[Entity]Schema` - delete operations
- `[entity]FilterSchema` - query parameters
- `[entity]IdSchema` - single ID validation

### Phase 3: Type Export

For each schema, export inferred TypeScript type:

```typescript
export const createClientSchema = z.object({ ... });
export type CreateClientInput = z.infer<typeof createClientSchema>;
```

## Schema Requirements

### String Validations

- Use `.trim()` for text inputs
- Apply `.min(1)` for required strings
- Apply `.max(n)` based on database constraints
- Use `.email()` for email fields
- Use `.uuid()` for ID fields

### Optional vs Nullable

- `.optional()` - field can be omitted
- `.nullable()` - field can be explicitly null
- `.optional().nullable()` - both allowed

### Date/Time

- `.datetime()` for ISO datetime strings
- `.date()` for date-only strings
- `.refine()` for range validations

## Output Format

### File Structure

```typescript
/**
 * @file [Module] Schemas
 * @description Zod validation schemas for [module] server actions
 */

import { z } from 'zod';
import { uuidSchema, phoneSchema, paginationSchema } from '@/services/shared/schemas';

// ============================================================================
// Create Schemas
// ============================================================================

/**
 * Schema for creating a new [entity]
 * @example
 * const input = { name: "Example", email: "test@example.com" };
 * create[Entity]Schema.parse(input);
 */
export const create[Entity]Schema = z.object({
  name: z.string().trim().min(1, 'Name is required').max(255),
  email: z.string().email('Invalid email').optional().nullable(),
});

export type Create[Entity]Input = z.infer<typeof create[Entity]Schema>;

// ============================================================================
// Update Schemas
// ============================================================================

/**
 * Schema for updating an existing [entity]
 * All fields except id are optional
 */
export const update[Entity]Schema = z.object({
  id: uuidSchema,
  name: z.string().trim().min(1).max(255).optional(),
  email: z.string().email().optional().nullable(),
});

export type Update[Entity]Input = z.infer<typeof update[Entity]Schema>;

// ============================================================================
// Delete Schemas
// ============================================================================

/**
 * Schema for deleting an [entity]
 */
export const delete[Entity]Schema = z.object({
  id: uuidSchema,
});

export type Delete[Entity]Input = z.infer<typeof delete[Entity]Schema>;

// ============================================================================
// Query Schemas
// ============================================================================

/**
 * Schema for filtering [entities] list
 */
export const [entity]FilterSchema = paginationSchema.extend({
  search: z.string().trim().optional(),
  includeDeleted: z.boolean().optional().default(false),
});

export type [Entity]Filter = z.infer<typeof [entity]FilterSchema>;
```

## Constraints

- Match field types exactly to database columns
- Use descriptive error messages for UX
- Keep schemas DRY by using shared schemas
- Follow existing code style in the project
- DO NOT add fields not in database schema
- DO NOT skip required validations
