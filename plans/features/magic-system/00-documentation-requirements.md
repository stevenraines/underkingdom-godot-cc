# Documentation Requirements for All Phases

## IMPORTANT: Every Phase Must Update Documentation

Each implementation phase MUST include documentation updates as part of the completion criteria.

## Documentation Files to Update

### 1. CLAUDE.md
**File:** `.claude/CLAUDE.md`

Update with:
- New systems added (MagicSystem, SpellManager, etc.)
- New autoloads
- New keybindings
- Updated file structure

### 2. Help Screen
**File:** `ui/help_screen.gd`

Update in-game help with:
- New keybindings (C for cast, M for spell list, etc.)
- Brief explanation of magic mechanics
- Spell schools summary

### 3. System Documentation
**Directory:** `docs/systems/`

Create/update:
- `docs/systems/magic-system.md` - Core spell casting mechanics
- `docs/systems/spell-manager.md` - Spell loading and management
- `docs/systems/ritual-system.md` - Ritual mechanics (when implemented)

### 4. Data Documentation
**Directory:** `docs/data/`

Create/update:
- `docs/data/spells.md` - Spell JSON format
- `docs/data/rituals.md` - Ritual JSON format (when implemented)

## Per-Phase Documentation Checklist

Add this to each phase's testing checklist:

```markdown
## Documentation Updates

- [ ] CLAUDE.md updated with new systems/files
- [ ] Help screen updated with new keybindings
- [ ] System documentation created/updated
- [ ] Data format documentation created/updated
- [ ] In-game tooltips/descriptions accurate
```

## Help Screen Content to Add

```
=== MAGIC ===
C - Open spell casting menu
M - View known spells
Ctrl+C - Summon commands (if summons active)

Minimum 8 INT required for all magic.
Spells require level + INT to cast.
Scrolls can cast spells without knowing them.
Wands have limited charges.
Staves provide casting bonuses.

=== SPELL SCHOOLS ===
Evocation - Damage spells
Conjuration - Creation and summoning
Enchantment - Mind control
Transmutation - Transformation
Divination - Knowledge and detection
Necromancy - Death and undead
Abjuration - Protection
Illusion - Deception
```

## README Updates

When magic system is complete, update README.md:
- Add magic to feature list
- Brief description of spell/ritual system
- Note about 8 schools of magic
