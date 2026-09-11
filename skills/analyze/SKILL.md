---
name: analyze
description: Analyze a feature or task to prepare for implementation. Use when understanding existing code patterns, dependencies, and planning changes.
argument-hint: [feature/task description]
allowed-tools: Read, Grep, Glob, Task, WebFetch, WebSearch
---

# Analyze for Implementation

Perform a thorough analysis to prepare for implementing $ARGUMENTS.

## Analysis Steps

### 1. Understand the Request
- Clarify the scope and requirements
- Identify key functionality to be added or modified
- Note any constraints or preferences mentioned

### 2. Explore Existing Code
- Find related files and modules using Glob and Grep
- Read key files to understand current patterns
- Map out the data flow and dependencies
- Identify similar implementations to follow as patterns

### 3. Architecture Review
Discover the stack from the repo — do not assume languages or folder names.

- Locate README, justfile, package manifests, and `docs/`
- Map **backend**: services, controllers/handlers, schemas/models, jobs/queues
- Map **frontend**: routes/pages, components, server actions or API clients, types
- Map **tests**: unit, integration, browser/e2e locations and how they are run
- Note in-container vs host commands (agents should prefer the project's documented helpers)

### 4. Identify Affected Areas
- List files that will need modification
- Note any database schema changes required
- Identify API endpoint changes
- Consider test files that may need updates

### 5. Document Patterns to Follow
- Find similar features as implementation templates
- Note code style conventions used
- Identify shared utilities or helpers to reuse
- Check for existing types/interfaces to extend

### 6. Define Browser Test Scenarios (if UI changes)

**Skip this section** if the changes are backend-only or have no user-facing UI impact.

For features that touch the frontend, define concrete browser test scenarios that can be executed against the running local app:

- **Navigation paths** — exact URL patterns to visit
- **Preconditions** — data or state that must exist before testing
- **Actions** — step-by-step interactions (click, type, select, drag)
- **Expected results** — observable outcomes (element visible, toast, data update, navigation)
- **Edge cases** — empty states, error states, permission boundaries

These scenarios inform the browser testing phase during implementation but should be treated as a starting point — the final test plan must reflect the actual code changes.

### 7. Create Implementation Plan
Provide a structured plan as a `.md` file in the `docs/` folder (e.g., `docs/feature-name-plan.md`), with:
- Clear sequence of changes
- File-by-file breakdown
- Key implementation details
- Potential challenges or edge cases
- Browser test scenarios (from step 6, if applicable)
- Questions that need clarification before starting

## Output Format

Structure your analysis as:

```
## Summary
[Brief description of what will be implemented]

## Relevant Files
- [file path]: [why it's relevant]

## Patterns to Follow
[Reference similar implementations]

## Implementation Plan
1. [Step 1]
2. [Step 2]
...

## Browser Test Scenarios (if applicable)
- [ ] [Scenario 1]: Navigate to [path], [action], verify [expected result]
- [ ] [Scenario 2]: ...

## Questions/Considerations
- [Any clarifications needed]
- [Edge cases to handle]
- [Potential risks]
```

Do NOT start implementing. This analysis is preparation only.
