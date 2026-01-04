---
name: implement-feature
description: Checkout a new branch and implement a feature from a plan file. Use when the user says "/implement-feature {feature-file}" to start implementing a feature defined in plans/features/.
---

# Implement Feature

Implements a feature defined in a plan file by creating a new branch and following the implementation steps.

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
3. Read the file to understand the feature requirements

### 2. Create a Feature Branch

Create a new git branch from main:

```bash
git checkout main
git pull
git checkout -b feature/{feature-name}
```

The branch name should be derived from the feature file name (e.g., `prevent-unnecessary-item-use` becomes `feature/prevent-unnecessary-item-use`).

### 3. Plan the Implementation

Before writing code:

1. Read the feature requirements carefully
2. Use the TodoWrite tool to create a task list
3. Identify which files need to be modified
4. Understand the existing code patterns
5. Ask clarifying questions, as needed

### 4. Implement the Feature

Follow the task list:

1. Mark each task as in_progress when starting
2. Make the necessary code changes
3. Mark tasks as completed when done
4. Test by running the project (e.g., Godot headless mode)

### 5. Commit the Changes

After implementation:

1. Stage all changed files
2. Create a descriptive commit message
3. The commit should summarize what the feature does

## Example

```
User: /implement-feature prevent-unnecessary-item-use

Claude will:
1. Read plans/features/prevent-unnecessary-item-use.md
2. Create branch feature/prevent-unnecessary-item-use
3. Create a todo list for the implementation
4. Implement the feature
5. Commit the changes
```

## Notes

- Always ensure main is up to date before branching
- Use the existing code patterns found in the project
- Reference the project's CLAUDE.md for architecture guidelines
- Test that the code compiles before committing
