# Example: Prompt with Test Cases

This example demonstrates how to create a prompt with built-in test cases and success criteria, following [Anthropic's testing guidelines](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests).

---

# Task: Generate TypeScript Utility Functions

## Context

TypeScript developer creating utility functions for a React application.

Project conventions:

- Utilities in `/utils/[category]/index.ts`
- Pure functions with JSDoc comments
- Comprehensive type annotations
- No external dependencies for simple utilities

## Source Files

### Existing Patterns

- `utils/string/index.ts` - String manipulation utilities
- `utils/date/index.ts` - Date formatting utilities

### Requirements

- `docs/utility-specs.md` - Function specifications

## Tasks

### Phase 1: Analyze Existing Patterns

1. Read existing utility files to understand conventions
2. Extract common patterns:
   - Function signature style
   - JSDoc format
   - Error handling approach
   - Export structure

### Phase 2: Generate Functions

Create utility functions following the specifications:

1. Match existing code style exactly
2. Add comprehensive JSDoc with examples
3. Include type guards where appropriate
4. Handle edge cases gracefully

### Phase 3: Validate Output

Run all test cases against generated functions.

## Output Format

```typescript
/**
 * Formats a phone number to (XXX) XXX-XXXX format.
 *
 * @param phone - Raw phone number string
 * @returns Formatted phone number or original if invalid
 *
 * @example
 * formatPhoneNumber('1234567890') // Returns: '(123) 456-7890'
 * formatPhoneNumber('123-456-7890') // Returns: '(123) 456-7890'
 */
export const formatPhoneNumber = (phone: string): string => {
  const digits = phone.replace(/\D/g, '');
  if (digits.length !== 10) return phone;
  return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
};
```

## Success Criteria

### Measurable Goals

- [ ] All generated functions compile with `tsc --noEmit`
- [ ] 100% of test cases pass (see Test Cases below)
- [ ] JSDoc present on every exported function
- [ ] No `any` types in public APIs

### Validation Method

1. Run TypeScript compiler on generated file
2. Execute test cases programmatically
3. Verify JSDoc presence with regex check

## Test Cases

### formatPhoneNumber

| Input | Expected Output | Category |
|-------|-----------------|----------|
| `'1234567890'` | `'(123) 456-7890'` | Happy path |
| `'123-456-7890'` | `'(123) 456-7890'` | With dashes |
| `'(123) 456-7890'` | `'(123) 456-7890'` | Already formatted |
| `'123.456.7890'` | `'(123) 456-7890'` | With dots |
| `''` | `''` | Empty string |
| `'12345'` | `'12345'` | Too short |
| `'12345678901'` | `'12345678901'` | Too long |
| `'abcdefghij'` | `'abcdefghij'` | Non-numeric |

### truncateText

| Input | Expected Output | Category |
|-------|-----------------|----------|
| `('Hello World', 5)` | `'Hello...'` | Basic truncation |
| `('Hi', 10)` | `'Hi'` | No truncation needed |
| `('', 5)` | `''` | Empty string |
| `('Hello', 5)` | `'Hello'` | Exact length |
| `('Hello World', 0)` | `'...'` | Zero length |
| `('Hello World', -1)` | `'Hello World'` | Negative length |

### isValidEmail

| Input | Expected Output | Category |
|-------|-----------------|----------|
| `'user@example.com'` | `true` | Valid email |
| `'user.name@example.co.uk'` | `true` | Complex domain |
| `'user+tag@example.com'` | `true` | With plus sign |
| `'user@example'` | `false` | No TLD |
| `'@example.com'` | `false` | No local part |
| `'user@'` | `false` | No domain |
| `'user example.com'` | `false` | Missing @ |
| `''` | `false` | Empty string |
| `'user@@example.com'` | `false` | Double @ |

## Automated Test Runner

```typescript
// test-utilities.ts
import { formatPhoneNumber, truncateText, isValidEmail } from './utils/string';

interface TestCase<I, O> {
  input: I;
  expected: O;
  category: string;
}

const runTests = <I, O>(
  fn: (input: I) => O,
  testCases: TestCase<I, O>[],
  fnName: string
): void => {
  let passed = 0;
  let failed = 0;

  testCases.forEach(({ input, expected, category }) => {
    const result = fn(input);
    const success = result === expected;

    if (success) {
      passed++;
    } else {
      failed++;
      console.error(`❌ ${fnName}(${JSON.stringify(input)})`);
      console.error(`   Expected: ${JSON.stringify(expected)}`);
      console.error(`   Received: ${JSON.stringify(result)}`);
      console.error(`   Category: ${category}`);
    }
  });

  console.log(`\n${fnName}: ${passed}/${passed + failed} tests passed`);
};

// Run all tests
runTests(formatPhoneNumber, phoneTestCases, 'formatPhoneNumber');
runTests(truncateText, truncateTestCases, 'truncateText');
runTests(isValidEmail, emailTestCases, 'isValidEmail');
```

## Constraints

- DO NOT use external libraries (lodash, validator, etc.)
- DO NOT modify existing utility files
- ONLY create new functions as specified
- Preserve existing code style exactly
- Handle null/undefined inputs gracefully

## Grading Rubric

For LLM-based evaluation of generated code quality:

```markdown
Rate the generated utility functions on a scale of 1-5:

### Correctness (weight: 40%)
1: Multiple test cases fail
3: Most test cases pass, minor edge case issues
5: All test cases pass, handles all edge cases

### Code Quality (weight: 30%)
1: Poor naming, no types, inconsistent style
3: Acceptable naming, basic types, mostly consistent
5: Clear naming, comprehensive types, matches project style

### Documentation (weight: 20%)
1: No JSDoc or comments
3: Basic JSDoc, missing examples
5: Complete JSDoc with examples and edge case notes

### Robustness (weight: 10%)
1: Crashes on invalid input
3: Returns fallback but may be unexpected
5: Graceful handling with sensible defaults
```
