# Prompt Patterns and Anti-Patterns

## Effective Patterns

### Pattern 1: Source of Truth Declaration

Establish which files are authoritative:

```markdown
### Source of Truth

Migrations are the source of truth for database schema.
- `supabase/migrations/*.sql` - AUTHORITATIVE
- `docs/db-plan.md` - DERIVED (update to match migrations)
- `types/database.ts` - AUTO-GENERATED (do not modify)
```

**When to use:** Schema sync, documentation updates, type generation

### Pattern 2: Comparison Table Format

Structure comparisons clearly:

```markdown
## Output Format

### Discrepancy Report

| Location | Expected | Actual | Action |
|----------|----------|--------|--------|
| file.ts:15 | `string \| null` | `string` | Change to nullable |
```

**When to use:** Validation, auditing, synchronization tasks

### Pattern 3: Progressive Analysis

Build understanding step by step:

```markdown
### Phase 1: Discovery
1. List all files matching pattern `services/*/schemas.ts`
2. For each file, extract schema names

### Phase 2: Analysis
1. For each schema, map fields to database columns
2. Identify type mismatches

### Phase 3: Report
1. Generate discrepancy table
2. Prioritize by severity
```

**When to use:** Complex analysis requiring multiple passes

### Pattern 4: Conditional Branching

Handle different scenarios:

```markdown
## Constraints

### If field is nullable in DB:
- Schema must use `.optional()` or `.nullable()`
- Type must include `| null`

### If field has DEFAULT in DB:
- Schema for INSERT can mark as `.optional()`
- Schema for UPDATE should keep as optional
```

**When to use:** Tasks with multiple valid paths

### Pattern 5: Example-Driven Specification

Show don't tell:

```markdown
## Expected Transformation

### Input (from migration):
\`\`\`sql
email VARCHAR(255) NULL
\`\`\`

### Output (Zod schema):
\`\`\`typescript
email: z.string().email().optional().nullable()
\`\`\`
```

**When to use:** Code transformation, format conversion

## Anti-Patterns to Avoid

### Anti-Pattern 1: Vague Instructions

❌ **Bad:**
```markdown
Analyze the code and fix any issues.
```

✅ **Good:**
```markdown
Compare Zod schema field optionality with database NULL constraints.
Report fields where schema allows null but DB requires NOT NULL.
```

### Anti-Pattern 2: Missing File Paths

❌ **Bad:**
```markdown
Read the schema files and migration files.
```

✅ **Good:**
```markdown
### Files to Read:
- `services/clients/schemas.ts`
- `supabase/migrations/20251209220746_tables.sql`
```

### Anti-Pattern 3: Implicit Assumptions

❌ **Bad:**
```markdown
Update the types to match the database.
```

✅ **Good:**
```markdown
Update TypeScript types to match database constraints:
- `NOT NULL` column → required field (no `?`)
- Nullable column → optional field with `| null`
- `DEFAULT` value → optional in create, required in response
```

### Anti-Pattern 4: No Output Format

❌ **Bad:**
```markdown
Generate a report of the findings.
```

✅ **Good:**
```markdown
## Output Format

### Summary Section
- Total schemas analyzed: [N]
- Discrepancies found: [N]
- Files requiring changes: [list]

### Detail Section
For each discrepancy:
| Schema | Field | Issue | Fix |
```

### Anti-Pattern 5: Unbounded Scope

❌ **Bad:**
```markdown
Review and improve all the code.
```

✅ **Good:**
```markdown
## Scope
- ONLY files in `services/*/schemas.ts`
- ONLY Zod validation schemas
- DO NOT modify `types/database.ts`
- DO NOT create new files
```

## Domain-Specific Patterns

### Database Schema Prompts

```markdown
## Database Mapping Rules

| PostgreSQL Type | Zod Validator | TypeScript Type |
|-----------------|---------------|-----------------|
| VARCHAR(n) | `z.string().max(n)` | `string` |
| TEXT | `z.string()` | `string` |
| UUID | `z.string().uuid()` | `string` |
| BOOLEAN | `z.boolean()` | `boolean` |
| TIMESTAMPTZ | `z.string().datetime()` | `string` |
| JSONB | `z.record(z.unknown())` | `Record<string, unknown>` |
```

### Code Generation Prompts

```markdown
## Code Style Requirements

- Use `const` arrow functions for components
- Export types alongside schemas
- Add JSDoc comments for public APIs
- Follow existing naming conventions in codebase
```

### Validation Prompts

```markdown
## Validation Checklist

For each item, mark as:
- ✅ Passed
- ❌ Failed (with reason)
- ⚠️ Warning (needs review)
```

## Composition Techniques

### Merging Multiple Concerns

```markdown
## Task: Sync and Validate

### Step 1: Sync (from sync-db-plan-schemas.md)
[Import relevant sections]

### Step 2: Validate (from validate-schemas.md)
[Import relevant sections]

### Step 3: Report Combined Results
[Unified output format]
```

### Parameterized Prompts

```markdown
## Configuration

Replace these placeholders before use:
- `{{MODULE}}` - Target module name (e.g., "clients")
- `{{TABLE}}` - Database table name (e.g., "clients")
- `{{SCHEMA_PATH}}` - Path to schema file
```

### Pattern 6: Example-Driven Specification

Based on [Anthropic's Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): "Replace exhaustive edge-case lists with diverse, canonical examples."

**When to use:** When rules would be verbose; when showing is clearer than telling

```markdown
## Examples

### Input → Output Pairs

#### Example 1: Simple case
<input>
email VARCHAR(255) NULL
</input>
<output>
email: z.string().email().optional().nullable()
</output>

#### Example 2: Required field
<input>
name VARCHAR(100) NOT NULL
</input>
<output>
name: z.string().min(1).max(100)
</output>

#### Example 3: Array type
<input>
tags TEXT[] DEFAULT '{}'
</input>
<output>
tags: z.array(z.string()).default([])
</output>
```

### Pattern 7: XML-Structured Content

Use XML tags to clearly separate different content types.

**When to use:** Complex prompts with multiple data sections; code that might be misinterpreted

```markdown
Analyze the source code and generate corresponding tests:

<source_code language="typescript">
export const validateEmail = (email: string): boolean => {
  const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return regex.test(email);
};
</source_code>

<expected_behavior>
- Returns true for valid email formats
- Returns false for invalid formats
- Handles edge cases: empty string, missing @, multiple @
</expected_behavior>

<output_format>
Generate Jest test file with describe/it blocks.
Include at least 5 test cases covering happy path and edge cases.
</output_format>
```

### Pattern 8: Success Criteria Integration

Based on [Anthropic's Define Success guide](https://platform.claude.com/docs/en/test-and-evaluate/define-success).

**When to use:** Every prompt should include success criteria

```markdown
## Success Criteria

### Measurable Goals
- [ ] All generated code compiles without errors
- [ ] 100% of database fields are represented
- [ ] Type mappings match the conversion table exactly

### Validation Method
Run these checks after generation:
1. `tsc --noEmit` - TypeScript compilation
2. Field count comparison: DB table vs generated schema
3. Manual review of 3 random fields

### Edge Cases to Verify
| Input | Expected Output |
|-------|-----------------|
| NULL column | `.optional().nullable()` |
| NOT NULL with DEFAULT | `.default(value)` |
| JSONB type | `z.record(z.unknown())` |
```

## XML Tag Patterns

### Common XML Tags Reference

| Tag | Purpose | Example |
|-----|---------|---------|
| `<source_code>` | Input code to analyze | `<source_code>const x = 1;</source_code>` |
| `<expected_output>` | Desired result format | `<expected_output>export type X = number;</expected_output>` |
| `<context>` | Background information | `<context>This is a Next.js project...</context>` |
| `<constraints>` | Hard rules | `<constraints>Do not modify existing files</constraints>` |
| `<examples>` | Input/output pairs | `<examples><input>...</input><output>...</output></examples>` |
| `<requirements>` | Feature specs | `<requirements>Must support pagination...</requirements>` |
| `<validation>` | Success criteria | `<validation>Output must compile...</validation>` |

### Nesting XML for Complex Structures

```markdown
<test_cases>
  <case name="valid_email">
    <input>user@example.com</input>
    <expected>true</expected>
  </case>
  <case name="invalid_email">
    <input>not-an-email</input>
    <expected>false</expected>
  </case>
</test_cases>
```

### XML vs Markdown Headers

| Use XML When | Use Markdown When |
|--------------|-------------------|
| Content contains code | Structuring prompt sections |
| Data might be misinterpreted | Simple hierarchical organization |
| Need clear boundaries | Human readability is priority |
| Nesting is required | Flat structure suffices |
