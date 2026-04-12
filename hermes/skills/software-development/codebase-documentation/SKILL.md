---
name: codebase-documentation
description: Systematically explore an unfamiliar codebase and produce comprehensive documentation -- both organized modular files and a single giant reference file.
tags: [documentation, codebase-analysis, exploration, reverse-engineering]
---

# Codebase Documentation

Systematically explore an unfamiliar codebase and produce comprehensive documentation -- both organized modular files and a single giant reference file.

## When to Use

- User asks to document/understand a codebase
- "What does this project do?", "explain this codebase", "document everything"
- Onboarding to a new project, auditing a codebase, preparing a handover

## Approach

### Phase 1: Discover Structure

```bash
# Top-level layout
ls -la <project_root>/

# Full directory tree
find <project_root> -type d | sort

# All source files
find <project_root>/src -name "*.py" -type f | sort

# All docs
find <project_root>/docs -type f | sort

# Test structure
find <project_root>/tests -type d | sort
find <project_root>/tests -name "*.py" -type f | wc -l
```

### Phase 2: Parallel Exploration (delegate_task)

Spawn 3-4 subagents in parallel, each covering a different area:

1. **Top-level docs** -- README, ARCHITECTURE, CONFIG, DATABASE, DEPLOYMENT, all docs/ files
2. **Core modules** -- gateway, core, memory, identity, graph, security, db
3. **Feature modules** -- evolution, learning, proactive, osint, social, kanban, audit, governance, telemetry, cron
4. **Infrastructure** -- mcp tools, channels, browser, cli, sdk, skills, i18n

Each subagent should:
- List all files in its area
- Read `__init__.py` for exports
- Read main class files
- Produce a structured technical summary

### Phase 3: Sample Tests

Read representative test files to understand:
- Behavioral patterns
- Integration test coverage
- What's actually tested vs. stubbed

### Phase 4: Synthesize

**Critical: Use `write_file` tool for output files, NOT `execute_code`.** The Python sandbox cannot write files outside its temp directory. Two options:

**Option A: `write_file` for giant file + Python script for organized files**
```bash
# Run Python script from project root (not in sandbox)
python3 /tmp/gen_docs.py
```
The script writes to `overview/` subdirectories. Then use `write_file` for the giant combined file.

**Option B: All `write_file` calls**
Build content as Python strings, then call `write_file` for each output file.

**WARNING: Triple backticks (```) inside Python triple-quoted strings (""") cause SyntaxError.** If generating docs via Python script, replace ``` with ~~~ in markdown content, or avoid docstrings inside code blocks.

### Phase 5: Output Structure

Create `overview/` folder organized by audience:

```
overview/
  README.md              -- Master index with categorized links
  user/                  -- End-user docs (installation, config, channels, deployment, troubleshooting, FAQ)
  technical/             -- Deep developer docs (architecture, each subsystem thoroughly documented)
  full/
    complete.md          -- Everything in one giant file
```

**Depth matters:** Users want thorough, deep technical documentation -- NOT summaries. Each technical file should be comprehensive (100-200+ lines) with architecture diagrams, data models, API details, and code examples. User docs should be practical guides with commands and configs.

Also create a giant file at project root: `PROJECT_DOCS.md`

## Pitfalls

- **Sandbox file persistence**: `execute_code` runs in a temp sandbox that cannot write files to the project directory. Use `write_file` tool directly, or run `python3 /tmp/script.py` from the project root (the script can write to relative paths from CWD).
- **Triple backticks in Python strings**: ``` inside """ strings causes SyntaxError. Use ~~~ as alternative in generated markdown, or avoid docstrings inside code blocks within triple-quoted strings.
- **Organize by audience**: Users expect docs organized by audience type (user/technical/full), not a flat list. User docs = practical guides. Technical docs = deep subsystem documentation (100-200+ lines each). Full = giant combined reference.
- **Depth over brevity**: Users want thorough, deep documentation -- not summaries. Each technical file should cover architecture, data models, APIs, code examples, and integration points comprehensively.
- **Don't read every file**: Read `__init__.py` for exports, then main class files. Skip test files unless behavior is unclear.
- **Watch for stubs**: Some modules may be stub implementations (check `is_available()` methods, empty return values).
- **Version drift**: Docs often lag behind code. Trust source code over docs when they conflict.
- **Large files**: Use `read_file` with `limit` and `offset` for files over 500 lines. Don't try to read 5000-line files in one call.
- **Naming inconsistencies**: Projects mid-rename (e.g., jarvis -> cognithor) will have mixed references everywhere.

## Output Checklist

- [ ] Master index README with categorized links by audience (user/technical/full)
- [ ] `user/` folder: practical guides (installation, config, channels, deployment, troubleshooting, FAQ)
- [ ] `technical/` folder: deep subsystem docs (100-200+ lines each, with architecture, data models, APIs, code examples)
- [ ] `full/complete.md`: giant combined reference file
- [ ] Known gaps/issues documented
- [ ] Source file inventory with line counts
- [ ] Stats summary (LOC, tests, coverage, file counts)
