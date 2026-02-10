---
name: pb
description: This skill should be used when the user asks to "create a prompt", "write a prompt", "generate a prompt template", "stwórz prompt", "napisz prompt", or needs to create reusable prompts for AI agents following Claude prompt engineering best practices. Saves prompts to `.ai/prompts/` directory.
version: 1.0.0
---

# Prompt Engineering Skill

Create well-structured, reusable prompts following Claude prompt engineering best practices.

## When to Use

- Creating new prompts for repetitive AI tasks
- Writing prompt templates for code generation
- Designing prompts for data analysis or transformation
- Building prompts for documentation or schema synchronization

## Output Location

Save all prompts to: `.ai/prompts/[prompt-name].md`

## Prompt Structure Template

Every prompt follows this structure:

```markdown
# [Task Title]

## Context

[Role definition and project context]

## Source Files

[List of files to read/analyze]

## Tasks

### Phase 1: [Analysis/Research]
[Steps for understanding the problem]

### Phase 2: [Implementation/Transformation]
[Steps for executing the task]

### Phase 3: [Validation/Output]
[Steps for verifying results]

## Output Format

[Expected output structure with examples]

## Success Criteria

[Measurable goals and validation methods]

## Constraints

[Rules and limitations]
```

## Core Principles

### 1. Clear Role Definition

Start with explicit context about the AI's role:

```markdown
## Context

Expert [domain] developer working with [technology stack].
Project uses:
- [Technology 1]
- [Technology 2]
- [Technology 3]
```

### 2. Explicit File References

List all files the AI should read:

```markdown
## Source Files

### Primary (must read):
- `path/to/file1.ts` - description
- `path/to/file2.ts` - description

### Reference (read as needed):
- `path/to/types.ts` - type definitions
```

### 3. Phased Task Breakdown

Break complex tasks into sequential phases:

```markdown
## Tasks

### Phase 1: Analysis
1. Read all source files
2. Extract [specific information]
3. Identify [patterns/issues]

### Phase 2: Implementation
1. Create [output]
2. Apply [transformations]
3. Validate [constraints]
```

### 4. Concrete Output Examples

Show exact expected format:

```markdown
## Output Format

### Report Structure
| Column A | Column B | Column C |
|----------|----------|----------|
| value1   | value2   | value3   |

### Code Structure
\`\`\`typescript
export const example = z.object({
  field: z.string(),
});
\`\`\`
```

### 5. Explicit Constraints

Define what NOT to do:

```markdown
## Constraints

- DO NOT modify [specific files]
- DO NOT change [specific patterns]
- ONLY update [specific scope]
- Preserve [specific formatting]
```

## Language Guidelines

- Use imperative form: "Read the file", "Extract data", "Generate output"
- Avoid second person: NO "You should...", YES "Start by..."
- Be specific: NO "process the data", YES "parse JSON and extract `name` field"
- Use Polish or English consistently (match user's language)

## Naming Convention

Use descriptive kebab-case names:
- `sync-db-plan-schemas.md` - synchronization prompts
- `generate-zod-schemas.md` - generation prompts
- `create-api-endpoints.md` - creation prompts
- `validate-migrations.md` - validation prompts

## Quick Reference

### Minimal Prompt (~500 words)

For simple, focused tasks:
- Context (2-3 sentences)
- Source files (2-3 files)
- Single task phase
- Output format
- 2-3 constraints

### Standard Prompt (~1500 words)

For moderate complexity:
- Full context section
- Categorized source files
- 2-3 task phases
- Detailed output examples
- Comprehensive constraints

### Comprehensive Prompt (~3000 words)

For complex workflows:
- Extensive context with tech stack
- Multiple file categories
- 3+ task phases with sub-steps
- Multiple output format examples
- Detailed constraints and edge cases

## Success Criteria (Required)

Every prompt must define measurable success criteria. Based on [Anthropic's Define Success guide](https://platform.claude.com/docs/en/test-and-evaluate/define-success).

### Template

```markdown
## Success Criteria

### Measurable Goals
- [ ] [Specific, quantifiable outcome]
- [ ] [Accuracy threshold if applicable]
- [ ] [Consistency requirement]

### Validation Method
- How to verify the output is correct
- Edge cases to test against
```

### Example

```markdown
## Success Criteria

### Measurable Goals
- All generated schemas pass `tsc --noEmit` validation
- 100% of required DB fields are marked as required in Zod
- No type mismatches between DB types and Zod validators

### Validation Method
- Run TypeScript compiler on generated files
- Compare field count: generated schema vs database table
- Verify optionality matches NULL constraints
```

### Good vs Bad Criteria

| Bad | Good |
|-----|------|
| "The model should work well" | "F1 score ≥ 0.85 on test set" |
| "Safe outputs" | "< 0.1% outputs flagged by content filter" |
| "Handle edge cases" | "Pass all 10 defined edge case tests" |

## Prompt Sizing Strategy

Based on [Anthropic's Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): "Find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome."

### Right Altitude Principle

Prompts should be:
- **Specific enough** to guide behavior effectively
- **Flexible enough** to provide strong heuristics

### Start Minimal

Begin with the smallest prompt that could work:

1. Core task in 1-2 sentences
2. Essential source files only
3. Single expected output example
4. Basic success criteria

### Add Based on Failure

Only add complexity when you observe:
- Missing context causing errors
- Ambiguous outputs
- Edge cases not handled
- Inconsistent results

### Avoid Premature Specification

```markdown
❌ DON'T:
- List every possible edge case upfront
- Add constraints "just in case"
- Specify implementation details unless required
- Include boilerplate that can be inferred

✅ DO:
- Start with core requirements only
- Add specificity after testing reveals gaps
- Use examples instead of exhaustive rules
- Trust the model's reasoning capabilities
```

## Example-Driven Specification

Based on [Anthropic's Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): "Replace exhaustive edge-case lists with diverse, canonical examples that effectively portray the expected behavior."

### Why Examples Beat Rules

- LLMs learn patterns from examples more effectively than from rules
- Examples serve as "mental shortcuts" for expected behavior
- Diverse examples cover more edge cases implicitly

### Transform Rules to Examples

**Instead of:**
```markdown
## Constraints
- Handle nullable fields with .optional()
- Handle arrays with z.array()
- Handle nested objects with z.object()
- Handle dates with z.string().datetime()
```

**Use canonical examples:**
```markdown
## Examples

### Nullable Field
DB: `email VARCHAR(255) NULL`
Zod: `email: z.string().optional().nullable()`

### Array Field
DB: `tags TEXT[]`
Zod: `tags: z.array(z.string())`

### Nested Object
DB: `metadata JSONB`
Zod: `metadata: z.record(z.unknown())`
```

## Testing Your Prompts

Based on [Anthropic's Develop Tests guide](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests).

### Quick Validation

Run the prompt and check:

1. Does output match expected format?
2. Are all requested transformations applied?
3. Do edge cases produce correct results?
4. Is the output consistent across runs?

### Automated Testing (for critical prompts)

For prompts used repeatedly:

1. Create 5-10 test inputs with known expected outputs
2. Run prompt against each input
3. Compare outputs programmatically
4. Track success rate over time

### Grading Methods

Choose the fastest reliable method:

| Method | Speed | Use When |
|--------|-------|----------|
| **Code-based** | Fastest | Exact match, TypeScript compilation, regex patterns |
| **LLM-based** | Fast | Complex judgement, semantic similarity |
| **Human review** | Slow | Subjective quality, edge cases |

### Edge Cases to Test

Include tests for:
- Empty or missing input data
- Overly long inputs
- Malformed data
- Ambiguous cases
- Boundary conditions

## Formatting with XML Tags

Based on [Anthropic's Prompt Engineering guide](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview).

### When to Use XML Tags

- Embedding code that shouldn't be parsed as prompt
- Separating distinct data sections
- Providing examples that might be confused with instructions
- Marking boundaries for complex nested content

### Example

```markdown
Analyze the following code and generate a Zod schema:

<source_code>
const user = {
  name: "John",
  email: "john@example.com"
};
</source_code>

<expected_output>
export const userSchema = z.object({
  name: z.string(),
  email: z.string().email(),
});
</expected_output>
```

### Common XML Sections

| Tag | Purpose |
|-----|---------|
| `<source_code>` | Input code to analyze |
| `<expected_output>` | Example of correct output |
| `<context>` | Background information |
| `<constraints>` | Rules and limitations |
| `<examples>` | Input/output pairs |

## Context Window Management

Based on [Anthropic's Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): Context is a "precious, finite resource."

### Just-In-Time Loading

```markdown
✅ Reference file paths - let AI read as needed:
"Read `services/clients/schemas.ts` to understand current patterns"

❌ Don't inline entire files in prompts:
"Here is the full content of schemas.ts: [500 lines of code]"
```

### High-Signal Content Only

Include only information that affects decisions:
- Remove boilerplate from examples
- Focus on decision-affecting details
- Exclude obvious or inferrable information
- Summarize verbose sections

### When Prompts Get Too Long

If your prompt exceeds ~2000 words:

1. **Split into focused prompts** - Each handles one specific task
2. **Use sub-agent pattern** - Main agent coordinates, sub-agents execute
3. **Summarize verbose sections** - Condense detailed explanations
4. **Reference instead of inline** - Point to files rather than copying

## Additional Resources

### Anthropic Official Documentation

- [Prompt Engineering Overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview) - Core techniques
- [Define Success Criteria](https://platform.claude.com/docs/en/test-and-evaluate/define-success) - Measuring prompt effectiveness
- [Develop Tests](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests) - Building evaluations
- [Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Advanced context strategies

### Reference Files

Consult for detailed guidelines:
- **`references/prompt-patterns.md`** - Common prompt patterns and anti-patterns
- **`references/output-formats.md`** - Standard output format templates

### Example Files

Working examples in `examples/`:
- **`sync-schema-example.md`** - Schema synchronization prompt
- **`generate-code-example.md`** - Code generation prompt
- **`testing-prompt-example.md`** - Prompt with test cases

## Workflow

1. **Understand the task**: Clarify what repetitive work needs automation
2. **Identify inputs**: List all files and data sources needed
3. **Define outputs**: Specify exact expected format
4. **Define success criteria**: How will you know the prompt works?
5. **Start minimal**: Write the smallest prompt that could work
6. **Test and iterate**: Run prompt, observe failures, add specificity
7. **Save to `.ai/prompts/`**: Use descriptive filename
