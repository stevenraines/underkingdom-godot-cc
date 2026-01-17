---
name: implement-feature
description: Checkout a new branch and implement a feature from a plan file. Use when the user says "/implement-feature {feature-file}" to start implementing a feature defined in plans/features/.
---

# Implement Feature

Implements a feature defined in a plan file by creating a new branch and following the implementation steps.

## CRITICAL RULES

1. **CREATE A NEW BRANCH FIRST** - ALWAYS create a new git branch BEFORE making ANY code changes. This is non-negotiable.
2. **PLAN FILE IS THE SOURCE OF TRUTH** - Only implement what is written in `plans/features/<feature-name>.md`
3. **NEVER ALTER THE PLAN SILENTLY** - Do not change the plan file without user approval
4. **CLARIFYING QUESTIONS REQUIRE PLAN UPDATES** - If you ask a question and get an answer, update the plan file BEFORE continuing implementation
5. **FOLLOW THE PLAN EXACTLY** - Do not add features, skip steps, or deviate from what the plan specifies

## Usage

```
/implement-feature {feature-file-name}
```

The feature file name should correspond to a file in `plans/features/` directory (with or without the `.md` extension).

## Workflow

### 1. Validate the Feature File

First, locate and read the feature plan file:

1. Check if the argument is provided
2. Look for the file in `plans/features/{argument}.md` (add `.md` if not present)
3. **If file does not exist, STOP and tell the user**
4. Read the file to understand the feature requirements

### 2. Create a Feature Branch (MANDATORY - DO THIS FIRST)

⚠️ **WARNING: NEVER skip this step. NEVER make code changes on main.**

Create a new git branch from main BEFORE writing any code:

```bash
git checkout main
git fetch
git pull
git checkout -b feature/{feature-name}
```

The branch name should be derived from the feature file name (e.g., `debug-test-mode` becomes `feature/debug-test-mode`).

**Verify you are on the new branch before proceeding:**
```bash
git branch --show-current
```

### 3. Review the Plan

Before writing code:

1. Read the entire feature plan carefully
2. Identify the implementation phases/steps
3. Identify which files need to be created or modified
4. Check if anything is unclear or ambiguous

### 4. Ask Clarifying Questions (If Needed)

If the plan has ambiguities or missing details:

1. Ask the user specific questions about the unclear parts
2. **WAIT for the user to answer**
3. **UPDATE the plan file** with the clarified information
4. Show the user what you updated in the plan
5. Only then proceed with implementation

**Example:**
```
The plan says "implement teleport command" but doesn't specify:
- Should it list all visited locations or allow coordinate input?

Please clarify so I can update the plan before implementing.
```

After user answers:
```
Updated plans/features/debug-test-mode.md with:
- Teleport shows list of visited locations
- No coordinate input for now

Continuing with implementation...
```

### 5. Implement the Feature

Follow the plan's implementation phases:

1. Use TodoWrite to track tasks from the plan
2. Mark each task as in_progress when starting
3. Implement EXACTLY what the plan specifies
4. Mark tasks as completed when done
5. Do not add extra features not in the plan
6. Do not skip steps that are in the plan

### 6. Commit the Changes

After implementation:

1. Stage all changed files
2. Create a descriptive commit message referencing the feature
3. The commit should summarize what was implemented

## What NOT To Do

- **DO NOT** make ANY code changes before creating a new branch - this is the #1 rule
- **DO NOT** implement features not specified in the plan
- **DO NOT** silently change the plan file
- **DO NOT** skip implementation steps from the plan
- **DO NOT** add "improvements" beyond what the plan specifies
- **DO NOT** proceed with ambiguous requirements - ask first, update plan, then implement

## Example

```
User: /implement-feature debug-test-mode

Claude will:
1. Read plans/features/debug-test-mode.md
2. Create branch feature/debug-test-mode
3. Review the plan for any unclear parts
4. If unclear: Ask questions → Get answers → Update plan file → Continue
5. Create a todo list matching the plan's phases
6. Implement exactly what the plan specifies
7. Commit the changes
```

## Notes

- The plan file is authoritative - follow it exactly
- Always ensure main is up to date before branching
- Use the existing code patterns found in the project
- Reference the project's CLAUDE.md for architecture guidelines
- Test that the code compiles before committing
- If you discover the plan is wrong during implementation, STOP and ask the user before changing it