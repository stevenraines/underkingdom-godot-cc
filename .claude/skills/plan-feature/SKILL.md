---
name: plan-feature
description: Plan a new feature by creating a feature plan document. Use when the user says "Plan a new feature " followed by a description. Creates a branch from main. Asks clarifying questions to help guide you to the correct solution. Writes a plan file as a .MD in the /plans/features folder, but does not implement the feature.
mode: Plan
---

# Plan Feature

Creates a detailed feature plan document through an interactive process of clarifying questions and iterative refinement.

## CRITICAL RULES

1. **ALWAYS START WITH A NEW BRANCH** - Before doing anything else, checkout main, pull, and create `feature/plan-<feature-name>` branch
2. **NEVER IMPLEMENT** - This skill is for PLANNING ONLY. Do not write any code, create any scenes, or modify any game files.
3. **OUTPUT IS A PLAN FILE** - The only file you create is `plans/features/<feature-name>.md`
4. **DONE WHEN FILE IS WRITTEN** - Once the plan file is committed, your task is COMPLETE. Stop immediately.

## Usage

```
Plan a new feature:

<feature description>
```

## Workflow

### 1. Update Repository and Create Branch

First, ensure the repository is up to date and create a feature planning branch:

```bash
git checkout main
git fetch origin main
git pull origin main
git checkout -b feature/plan-<feature-name>
```

The branch name should be derived from the feature description (e.g., "add inventory sorting" becomes `feature/plan-inventory-sorting`).

### 2. Understand the Feature Request

Read and analyze the feature description provided by the user. Consider:

- What is the core functionality being requested?
- How does it relate to existing systems in the codebase?
- What are potential technical approaches?
- What information is missing or ambiguous?

### 3. Ask Clarifying Questions

Before writing the plan, ask the user clarifying questions to ensure the plan is accurate and complete. Questions should cover:

**Functional Requirements:**
- What specific user actions trigger this feature?
- What are the expected outcomes/results?
- Are there edge cases to consider?
- How should errors or invalid states be handled?

**Integration:**
- How does this interact with existing game systems?
- Are there dependencies on other features?
- What existing code patterns should be followed?

**Scope:**
- What is in scope vs out of scope for this feature?
- Are there optional enhancements vs required functionality?
- What is the priority order if there are multiple components?

**Technical Considerations:**
- Are there performance constraints?
- Are there specific UI/UX requirements?
- Should this be data-driven (JSON) or code-driven?

Wait for the user to answer these questions before proceeding.

### 4. Create the Feature Plan Document

After receiving answers to clarifying questions, create the feature plan document at `plans/features/<feature-name>.md`.

#### Document Structure

```markdown
# Feature - <Feature Name>
**Goal**: <One-sentence summary of the feature's purpose>

---

## Overview

<2-3 paragraph description of what the feature does and why it's valuable>

---

## Core Mechanics

<Detailed description of how the feature works>

### <Subsystem 1>
<Details about this component>

### <Subsystem 2>
<Details about this component>

---

## Data Structures

<JSON schemas and GDScript class definitions>

---

## Implementation Plan

### Phase 1: <First Phase Name>
1. <Task 1>
2. <Task 2>

### Phase 2: <Second Phase Name>
1. <Task 1>
2. <Task 2>

---

## New Files Required

### Data Files
```
data/
└── <new data files>
```

### Code Files
```
<new code files>
```

### Modified Files
- `<file1>` - <what changes>
- `<file2>` - <what changes>

---

## Input Bindings (if applicable)

| Key | Action | Description |
|-----|--------|-------------|

---

## UI Messages (if applicable)

- "Message 1" - When <condition>
- "Message 2" - When <condition>

---

## Future Enhancements

1. <Enhancement 1>
2. <Enhancement 2>

---

## Testing Checklist

- [ ] Test case 1
- [ ] Test case 2
```

### 5. Present the Plan for Review

After creating the plan document, inform the user:

1. The plan has been created at `plans/features/<feature-name>.md`
2. Summarize the key points of the plan
3. Ask if they would like to make any changes

### 6. Handle Change Requests

If the user requests changes:

1. Ask clarifying questions about the requested changes if needed
2. Update the plan document with the changes
3. Present the updated plan to the user
4. Repeat until the user is satisfied

### 7. Commit the Plan and STOP

Once the user approves the plan:

```bash
git add plans/features/<feature-name>.md
git commit -m "docs: Add <feature-name> feature plan"
```

**YOUR TASK IS NOW COMPLETE.**

Tell the user:
- The plan file location: `plans/features/<feature-name>.md`
- To implement later, run: `/implement-feature <feature-name>`

**DO NOT:**
- Start implementing the feature
- Create any code files
- Modify any game files
- Offer to "get started" on implementation

## Example

```
User: Plan a new feature:

I want to add a companion system where the player can recruit NPCs to follow them and help in combat.

Claude will:
1. Update from main and create feature/plan-companion-system branch
2. Ask clarifying questions:
   - How are companions recruited? (dialogue, payment, quest completion?)
   - How many companions can the player have at once?
   - How do companions behave in combat? (AI controlled, commands?)
   - Do companions have their own inventory/equipment?
   - Can companions die permanently?
   - How do companions affect game balance?
3. Create plans/features/companion-system.md based on answers
4. Present the plan for review
5. Make any requested changes
6. Commit the approved plan
7. STOP - Tell user the plan is at plans/features/companion-system.md
   and they can run /implement-feature companion-system later
```

## Guidelines

- Always ask questions before writing the plan
- Reference existing code patterns from CLAUDE.md
- Keep plans detailed but realistic in scope
- Include both required functionality and optional enhancements
- Add a testing checklist for implementation verification
- Follow the data-driven design patterns established in the project
- **NEVER START IMPLEMENTATION** - Your job ends when the plan file is committed
