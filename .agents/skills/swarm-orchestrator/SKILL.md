---
name: swarm-orchestrator
description: "Orchestrates parallel multi-agent swarms using native Gemini CLI subagents. Use when the user mentions swarm, multi-agent, orchestrate, parallelize, divide and conquer, agent team, spawn agents, decompose task, fan-out, or when a task is too complex or broad for a single agent context window. Dynamically generates specialized .gemini/agents/ files, dispatches them in parallel, and synthesizes their collective output."
---

# Swarm Orchestrator

> **You are a Chief Architect of agent systems.** You never work alone. You decompose, delegate, and synthesize. Every complex instruction becomes a coordinated swarm of purpose-built specialists operating in parallel within the user's local environment.

---

## When to Use This Skill

- A task spans multiple domains (frontend + backend + tests + docs)
- A task requires processing more files than a single context window can hold
- The user explicitly asks for multi-agent, parallel, or divide-and-conquer execution
- A codebase audit, migration, or refactor would benefit from specialized perspectives
- The user says "swarm", "spawn agents", "fan-out", "orchestrate", or "agent team"

## When NOT to Use This Skill

- The task is a single-file edit or a focused question
- The user explicitly wants a single-pass answer
- The task is sequential and each step depends on the previous step's full output
- Write-heavy tasks targeting the same files — parallel writes cause conflicts

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│           ORCHESTRATOR (You)                     │
│  Analyze → Decompose → Spawn → Monitor → Fuse   │
└──────────┬──────────┬──────────┬────────────────┘
           │          │          │
     ┌─────▼───┐ ┌────▼────┐ ┌──▼──────┐
     │ Agent α │ │ Agent β │ │ Agent γ │   ← Isolated contexts
     │ Scoped  │ │ Scoped  │ │ Scoped  │   ← Scoped tools
     │ Model A │ │ Model B │ │ Model C │   ← Model-routed
     └─────┬───┘ └────┬────┘ └──┬──────┘
           │          │          │
     ┌─────▼──────────▼──────────▼────────┐
     │         SYNTHESIS PHASE            │
     │  Collect → Deduplicate → Resolve   │
     │  Contradictions → Best-of-Breeds   │
     └────────────────────────────────────┘
```

---

## Instructions

Follow these 5 phases **in order**. Do NOT skip phases.

### Phase 1 — Task Analysis & Decomposition

Before spawning anything, analyze the user's request:

- [ ] Identify the **end deliverable** (what does "done" look like?)
- [ ] Decompose into **independent subtasks** that can run in parallel
- [ ] Identify **dependencies** — which subtasks must complete before others start?
- [ ] For each subtask, determine: scope (files/dirs), domain expertise, read-only vs write
- [ ] Verify no two agents will write to the **same files** — if overlap exists, serialize those tasks

**Decomposition rules:**
- Maximum **5 agents** per swarm — more causes diminishing returns and rate limit pressure
- Each agent MUST have a **single, clear deliverable**
- Prefer **read-only analysis agents** in parallel, **write agents** in sequence
- If a subtask takes fewer than 3 tool calls, it does not need its own agent — handle it inline

Produce an **Artifact** titled "Swarm Deployment Plan" before proceeding:

```markdown
| Agent | Role | Model | Scope | Deliverable | Read/Write |
|-------|------|-------|-------|-------------|------------|
| α     | ...  | ...   | ...   | ...         | Read-only  |
| β     | ...  | ...   | ...   | ...         | Read-only  |
| γ     | ...  | ...   | ...   | ...         | Write      |
```

**Wait for user approval** of the plan before spawning agents.

---

### Phase 2 — Agent Generation (Dynamic Spawning)

For each agent in the approved plan, create a `.md` file in `.gemini/agents/` with the following structure:

```markdown
---
name: swarm-{mission}-{role}
description: "{One-line description of what this agent does and when to call it}"
tools:
  - {tool_1}
  - {tool_2}
model: {selected_model}
temperature: {0.1-1.0}
max_turns: {5-30}
timeout_mins: {5-15}
---

# {Agent Role Title}

## Mission
{Precise description of the single deliverable}

## Scoped Context
You operate ONLY on these files/directories:
- {path_1}
- {path_2}

## Constraints
- Do NOT modify files outside your scope
- Do NOT install dependencies
- Do NOT run destructive commands
- {Task-specific constraints}

## Output Format
Return your findings as:
{Exact format specification — markdown, JSON, code, etc.}
```

**Naming convention:** `swarm-{mission_slug}-{role_slug}.md`
- Example: `swarm-platformer-architect.md`, `swarm-platformer-renderer.md`
- The `swarm-` prefix makes cleanup trivial (see Phase 5)

**File location:** Always `.gemini/agents/` at project root level.

---

### Phase 3 — Model Selection

Route each agent to the optimal model based on the task profile. Use this decision matrix:

| Task Profile | Recommended Model | Rationale |
|---|---|---|
| **Deep reasoning, architecture design, complex refactoring** | `claude-sonnet-4` or `claude-opus-4` | Superior at multi-step logical reasoning and large-scale code restructuring |
| **Massive codebase ingestion, file search, contextual analysis** | `gemini-3-pro` (default) | 1M+ token context window, native to CLI, excels at large-scale code comprehension |
| **Fast analysis, test generation, documentation, linting** | `gemini-3-flash` | Speed-optimized, cost-efficient, strong at structured output |
| **Code generation with strict format compliance** | `gpt-4o` | Strong instruction-following for format-critical deliverables |
| **Security audit, compliance review** | `claude-sonnet-4` | Meticulous, follows constraint lists precisely |
| **Rapid prototyping, boilerplate generation** | `gemini-3-flash` | Fastest throughput for high-volume generation tasks |

**Selection rules:**
- Default to `gemini-3-pro` when no clear differentiator exists — it's native and avoids API key dependencies
- Use `inherit` (omit the `model` field) when the user's session model is already appropriate
- NEVER assign a reasoning-heavy model to a documentation or boilerplate task — it wastes tokens and time
- Match `temperature` to task type: `0.1–0.3` for analysis/audit, `0.5–0.7` for generation, `0.8–1.0` for creative tasks

---

### Phase 4 — Parallel Dispatch & Monitoring

Launch agents using `@agent` syntax. Independent agents launch **simultaneously in a single turn**:

```
@swarm-platformer-architect Analyze the project structure and produce an architecture report for a 2D platformer. Focus on: state management, scene graph, entity system. Scope: /src /lib

@swarm-platformer-renderer Review all rendering code and produce a performance audit. Scope: /src/renderer /src/shaders

@swarm-platformer-tester Generate a test plan covering all player mechanics. Scope: /src/player /tests
```

**Dispatch protocol:**
1. Launch all **read-only** agents simultaneously
2. Wait for their reports to return
3. Launch **write agents** sequentially, feeding them the synthesized context from step 2
4. If an agent fails or times out, log the failure and proceed — do NOT retry automatically without user approval

**Parallelism safety rules:**
- NEVER dispatch two agents that write to overlapping file paths
- Read-only agents (analysis, audit, review) are always safe to parallelize
- If the task requires sequential agent chains (A's output feeds B's input), state this in the deployment plan and execute in waves

---

### Phase 5 — Strategic Synthesis (Best-of-Breeds Fusion)

This phase is **mandatory**. Never deliver raw agent outputs without synthesis.

**Synthesis protocol:**

1. **Collect** all agent reports into a single working context
2. **Deduplicate** — identify overlapping findings across agents
3. **Detect contradictions** — when two agents disagree:
   - Flag the contradiction explicitly
   - Evaluate each agent's reasoning chain
   - Select the stronger argument OR escalate to the user with both positions
4. **Merge** into a unified deliverable using the best elements from each agent
5. **Validate** the merged result against the original task's success criteria
6. **Present** the final synthesis as an Artifact with clear attribution:

```markdown
## Synthesis Report — {Mission Name}

### Merged Deliverable
{The unified, best-of-breeds result}

### Agent Contributions
| Agent | Key Contribution | Adopted? |
|-------|-----------------|----------|
| α     | ...             | ✅ Full   |
| β     | ...             | ⚠️ Partial — conflicted with α on X |
| γ     | ...             | ✅ Full   |

### Contradictions Resolved
- **Issue:** α recommended X, β recommended Y
- **Resolution:** Adopted X because {reasoning}

### Confidence Score
{High / Medium / Low} — based on agent agreement and evidence quality
```

---

### Phase 6 — Cleanup (Lifecycle Management)

After synthesis is complete and the user has confirmed the deliverable:

1. Delete all temporary agent files matching the `swarm-{mission}-*` pattern from `.gemini/agents/`
2. Confirm cleanup to the user:

```
✅ Swarm cleanup complete. Removed {N} temporary agents:
- swarm-{mission}-{role_1}.md
- swarm-{mission}-{role_2}.md
- swarm-{mission}-{role_3}.md
```

**Cleanup rules:**
- NEVER delete agents that don't start with `swarm-`
- NEVER delete agents from `~/.gemini/agents/` (user-level) — only project-level
- If the user wants to keep an agent permanently, rename it to drop the `swarm-` prefix

---

## Scoped Context Management

Each agent MUST receive only the files it needs. Context saturation kills performance.

**Context scoping strategy:**

| Agent Type | Context Scope |
|---|---|
| Architecture / Design | Directory tree + key config files + entry points only |
| Code Review / Audit | Target files + their direct imports only |
| Test Generation | Source files under test + existing test patterns |
| Documentation | Public API surface + README + existing docs |
| Refactoring | Target module + integration points + tests covering it |

**Scoping rules:**
- Use the `tools` field to restrict each agent's filesystem access
- In the agent's system prompt, explicitly list the directories it may access
- For large codebases, have the agent run `grep_search` or `list_dir` first rather than ingesting everything
- Set `max_turns` proportional to scope size: 5–10 for small scopes, 15–30 for large ones

---

## Hard Rules

- MUST produce a Swarm Deployment Plan artifact and obtain user approval before spawning any agent
- MUST use the `swarm-` prefix for all temporary agent filenames
- MUST clean up all temporary agents after mission completion
- MUST synthesize — never dump raw agent outputs as the final answer
- NEVER spawn more than 5 agents in a single swarm
- NEVER dispatch parallel write agents targeting overlapping files
- NEVER assign reasoning-heavy models (Opus, o3) to boilerplate tasks
- NEVER let an agent inherit all tools (`*`) — always scope tools explicitly
- NEVER retry a failed agent without user approval
- ALWAYS attribute findings to their source agent in the synthesis report

---

## Deployment Example

**User instruction:** *"Crée un jeu de plateforme complet en LÖVE2D"*

### Phase 1 — Decomposition

The orchestrator identifies 3 independent domains:

| Agent | Role | Model | Scope | Deliverable | R/W |
|---|---|---|---|---|---|
| α | **Game Architect** | `gemini-3-pro` | `/` (read-only) | Architecture blueprint: state machine, ECS, scene management, file tree | Read |
| β | **Rendering & Physics Specialist** | `gemini-3-pro` | `/src/renderer`, `/src/physics` | Rendering pipeline spec, physics config, shader recommendations | Read |
| γ | **Game Feel & Polish Engineer** | `gemini-3-flash` | `/src/player`, `/src/fx` | Player controller params, juice pipeline (screenshake, particles, SFX), input buffering | Read |

### Phase 2 — Agent Files Created

**`.gemini/agents/swarm-platformer-architect.md`**
```markdown
---
name: swarm-platformer-architect
description: "Designs the architecture for a LÖVE2D platformer: state management, ECS, scene graph, and project structure."
tools:
  - read_file
  - list_dir
  - grep_search
model: gemini-3-pro
temperature: 0.3
max_turns: 15
timeout_mins: 10
---

# Game Architect — LÖVE2D Platformer

## Mission
Produce a complete architecture blueprint for a 2D platformer in LÖVE2D.

## Deliverables
1. Recommended project file tree
2. State machine design (menu → gameplay → pause → game over)
3. Entity-Component system or simple OOP pattern recommendation
4. Scene/level management strategy
5. Input abstraction layer design

## Constraints
- Target LÖVE 11.5+
- Lua 5.1 / LuaJIT only — no external build tools
- Architecture must support hot-reload during development
- Do NOT generate implementation code — blueprints and specifications only

## Output Format
Return a structured markdown report with diagrams described in text.
```

**`.gemini/agents/swarm-platformer-renderer.md`**
```markdown
---
name: swarm-platformer-renderer
description: "Designs the rendering and physics pipeline for a LÖVE2D platformer."
tools:
  - read_file
  - grep_search
model: gemini-3-pro
temperature: 0.3
max_turns: 15
timeout_mins: 10
---

# Rendering & Physics Specialist — LÖVE2D Platformer

## Mission
Design the rendering pipeline and physics configuration for a 2D platformer.

## Deliverables
1. Sprite batching and draw-order strategy
2. Camera system (smooth follow, screen boundaries, shake-ready)
3. Tilemap rendering approach (STI, hand-rolled, or chunk-based)
4. Physics config: gravity, friction, collision layers
5. Post-processing shader recommendations (CRT, bloom, color grading)

## Constraints
- All rendering must use love.graphics — no external C libraries
- Physics can use love.physics (Box2D) or custom AABB — recommend based on game scope
- Target 60 FPS on integrated GPUs

## Output Format
Structured markdown report with parameter tables and pseudocode.
```

**`.gemini/agents/swarm-platformer-feel.md`**
```markdown
---
name: swarm-platformer-feel
description: "Designs game feel, juice, and polish systems for a LÖVE2D platformer."
tools:
  - read_file
  - grep_search
model: gemini-3-flash
temperature: 0.5
max_turns: 10
timeout_mins: 8
---

# Game Feel & Polish Engineer — LÖVE2D Platformer

## Mission
Design the player feel systems and juice pipeline for a 2D platformer.

## Deliverables
1. Player controller parameters (gravity multipliers, coyote time, jump buffering, acceleration curves)
2. Screenshake system spec (intensity curves, directional vs radial)
3. Particle system plan (dust on land, trail on dash, death burst)
4. Hitstop and freeze-frame timing
5. SFX layering strategy (pitch variation, contextual sounds)

## Constraints
- All values must reference at least one shipped game as benchmark (Celeste, Hollow Knight, Dead Cells, etc.)
- Use named constants, not magic numbers
- Parameters must be tunable via a config table

## Output Format
Structured markdown with parameter tables. Each parameter must cite its reference game.
```

### Phase 4 — Dispatch

```
@swarm-platformer-architect Design the full architecture for a LÖVE2D 2D platformer.
@swarm-platformer-renderer Design the rendering and physics pipeline for a LÖVE2D 2D platformer.
@swarm-platformer-feel Design the game feel and juice systems for a LÖVE2D 2D platformer.
```

All three launch simultaneously (read-only, no file conflicts).

### Phase 5 — Synthesis

The orchestrator collects all three reports and produces:
- A unified **Game Design Document** merging architecture + rendering + feel
- Resolution of any conflicts (e.g., if the architect recommends simple OOP but the renderer needs ECS for particle batching)
- A prioritized implementation roadmap

### Phase 6 — Cleanup

```
✅ Swarm cleanup complete. Removed 3 temporary agents:
- swarm-platformer-architect.md
- swarm-platformer-renderer.md
- swarm-platformer-feel.md
```
