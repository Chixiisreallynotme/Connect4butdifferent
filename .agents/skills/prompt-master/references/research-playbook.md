# Research Playbook Reference

Detailed research methodology for Prompt Master v2. Read this file when you need the full research protocol, model-specific sweet spots, or token optimization strategies.

---

## Research Protocol

### When to Research

| Trigger | Action |
|---------|--------|
| User names a model not in the routing table | Search for `[model name] prompt engineering best practices 2025 2026` |
| User asks about a specific framework (DSPy, TextGrad) | Use Context7 to fetch framework documentation |
| User mentions "latest techniques" or "state of the art" | Search for latest prompt engineering research papers and playbooks |
| User's task involves structured outputs or function calling | Search for `[model name] structured output JSON schema 2025 2026` |
| User asks about prompt caching or token optimization | Search for `[model name] API prompt caching token optimization` |

### Research Tool Routing

```
1. Context7 (resolve-library-id → query-docs)
   └── Best for: Framework docs (DSPy, LangChain, LlamaIndex, model SDKs)
   └── Query format: Use the user's full question, not keywords

2. Web Search (brave_web_search or web_search_exa)
   └── Best for: Blog posts, papers, model-specific playbooks, latest techniques
   └── Query format: "[model] prompt engineering [specific topic] 2025 2026"

3. Documentation Search (ref_search_documentation)
   └── Best for: Official API docs, changelogs, migration guides
   └── Query format: "[library] [specific API or feature]"
```

### Research Absorption Rules

- Do NOT surface raw research to the user
- Do NOT cite papers or blog posts unless the user explicitly asks for sources
- Silently absorb findings and apply them to the prompt you are building
- If research contradicts your existing routing table, apply the newer information
- If research is ambiguous or conflicting, default to the more conservative technique

---

## Model-Specific Sweet Spots (2025-2026)

### Claude (4.x, 4.5, 4.6)

| Feature | Sweet Spot |
|---------|-----------|
| **Structure** | XML tags (`<context>`, `<task>`, `<constraints>`, `<output_format>`) for complex prompts |
| **Extended Thinking** | Use adaptive mode. Do NOT add CoT. Do NOT pass thinking blocks back on subsequent turns |
| **Prompt Caching** | First ~1500 tokens cached automatically on API. Place static instructions first |
| **Opus behavior** | Over-engineers by default — always add scope constraints |
| **Instruction style** | Explicit, literal, contract-style. Provide reasoning WHY, not just WHAT |
| **Hallucination control** | Claude is relatively conservative — grounding rules still recommended for factual tasks |

### GPT-5.x (ChatGPT, API)

| Feature | Sweet Spot |
|---------|-----------|
| **Architecture** | Router-based — multiple models behind one endpoint. Pin snapshots for production |
| **Instruction style** | Start minimal, add structure only when needed. GPT-5 infers intent well from minimal context |
| **Structured output** | Handles dense instruction well. JSON mode reliable |
| **Verbosity control** | Explicit word counts and "No preamble" constraints are effective |
| **Long context** | Strong synthesis up to 128K tokens |
| **Zero-shot** | Try zero-shot first. GPT-5 surprises with minimal prompting |

### o3 / o4-mini / Reasoning Models

| Feature | Sweet Spot |
|---------|-----------|
| **Instruction length** | System prompt under 200 words. Shorter = better |
| **CoT** | NEVER add. These models reason internally across thousands of tokens |
| **Few-shot** | Zero-shot preferred. Few-shot only if strictly needed |
| **Task framing** | State goal + done condition. Nothing more |
| **Performance** | Excels at math, logic, analysis. Overkill for simple tasks |

### Gemini (2.x, 3 Pro)

| Feature | Sweet Spot |
|---------|-----------|
| **Context window** | 2M tokens. Excellent for document-heavy prompts |
| **Instruction style** | Shorter and more direct than Claude or GPT |
| **Few-shot** | ALWAYS include — Google's research shows Gemini benefits significantly from examples |
| **Deep Think / Thinking Mode** | Treat like o3 — short instructions, no CoT |
| **Hallucination** | Prone to hallucinated citations. Always add citation grounding rules |
| **Format adherence** | Can drift — use explicit format locks with labeled examples |
| **Multimodal** | Strong at image + text combined prompts |

### DeepSeek-R1

| Feature | Sweet Spot |
|---------|-----------|
| **Reasoning** | Native — do NOT add CoT |
| **Output** | Reasoning in `<think>` tags by default. Add "Output only the final answer" if unwanted |
| **Instruction style** | Short, clean, goal-oriented |

### Qwen3 (Thinking Mode)

| Feature | Sweet Spot |
|---------|-----------|
| **Thinking mode** | `/think` or `enable_thinking=True` — treat like o3 |
| **Non-thinking mode** | Treat like Qwen2.5 instruct — full structure, explicit format |
| **Hybrid** | Can switch between thinking and non-thinking within a session |

### Open-Weight Models (Llama, Mistral, local via Ollama)

| Feature | Sweet Spot |
|---------|-----------|
| **Instruction length** | Short. Coherence degrades with deeply nested instructions |
| **Structure** | Flat. No multi-level hierarchies |
| **Role** | Always include in system prompt |
| **Temperature** | 0.1 for deterministic, 0.7-0.8 for creative |
| **Explicitness** | Be more explicit than with Claude or GPT — instruction following is weaker |

---

## Token Optimization Strategies

### Prompt Caching (API-level)

Prompt caching reduces cost and latency by reusing the processing of static prompt content across API calls.

**How to structure for caching:**
```
┌─────────────────────────────────────────────┐
│  CACHEABLE PREFIX (static across calls)     │
│  - System identity and role                 │
│  - Hard rules and constraints               │
│  - Output format specification              │
│  - Few-shot examples (if always the same)   │
├─────────────────────────────────────────────┤
│  VARIABLE SUFFIX (changes per call)         │
│  - User input / query                       │
│  - Dynamic context / documents              │
│  - Session-specific memory block            │
└─────────────────────────────────────────────┘
```

**Provider specifics:**
- **Claude API**: Automatic caching on first ~1500 tokens. Explicit `cache_control` breakpoints available
- **OpenAI API**: Automatic prompt caching on longer prompts. No manual control needed
- **Gemini API**: Context caching available for repeated large contexts

### Compression Techniques

| Technique | When to use | Example |
|-----------|------------|---------|
| **Remove default restaters** | Always | Remove "be helpful" from ChatGPT prompts — it's already the default |
| **Merge redundant instructions** | When multiple rules say the same thing | "Do not add features" + "Do not refactor" → "Only make changes directly requested" |
| **Format spec over example** | When format is simple | "Output as JSON with keys: name, age, role" instead of showing a full example |
| **Example over format spec** | When format is complex | Show 2-3 examples instead of a long format description |
| **Structured > prose** | For instructions | Tables and numbered lists compress better than paragraphs |
| **Signal word upgrade** | Always | MUST > should, NEVER > avoid, ALWAYS > typically |

### Cost Equation Reference

```
Total AI Cost = (Input Tokens × Input Price) + (Output Tokens × Output Price) × Number of Calls
```

- Shorter structured prompts → less variance, lower latency, lower cost
- Hill-climb quality first, then down-climb cost
- A 76% cost reduction is achievable by switching from verbose to structured prompts (Aakash Gupta, 2025)

---

## Advanced Framework Quick Reference

### DSPy — When the User Asks

DSPy replaces manual prompting with programmable signatures, modules, and optimizers.

**Key concepts to know:**
- **Signatures**: Declarative input/output specs (e.g., `question -> answer`)
- **Modules**: `Predict`, `ChainOfThought`, `ReAct`, `Module`
- **Optimizers**: `MIPROv2` (flagship, joint instruction + few-shot), `BootstrapFewShot`, `BestOfN`, `Refine`
- **Model-agnostic**: Same signature compiles to different prompts for GPT, Claude, Llama
- **Upfront cost**: 100-500 LLM calls for compilation, but guaranteed runtime reliability

**When to recommend DSPy:**
- User is building a production pipeline with multiple LLM steps
- User needs cross-model portability (switch between GPT, Claude, Llama without rewriting)
- User needs 99%+ reliability on structured outputs
- User has evaluation data to drive optimization

**When NOT to recommend DSPy:**
- User wants a single prompt to paste into ChatGPT
- User has no evaluation data or metrics
- Task is simple enough that manual prompting suffices

### TextGrad — When the User Asks

TextGrad uses natural language feedback as gradients for prompt refinement. Published in Nature 2025.

**When to recommend:**
- User is iterating on a single hard task (coding, scientific QA)
- User has a clear quality metric and wants automated refinement
- Instance-level optimization needed (one specific input, not a pipeline)

### Meta-Prompting — When the User Asks

Using an LLM to generate, evaluate, and refine its own prompts.

**When to recommend:**
- User wants to automate prompt improvement
- User has a feedback loop (metric → refine → re-evaluate)
- User is building a self-improving system

---

## "Lost in the Middle" — Context Placement Rules

Research consistently shows that LLMs attend more strongly to the beginning and end of their context window, with weaker attention in the middle (the "lost in the middle" effect).

**Placement strategy:**
1. **First 30%**: Critical instructions, identity, hard rules → highest attention
2. **Middle**: Supporting context, documents, data → weakest attention
3. **Last 20%**: Output format, final constraints → recency bias reinforces these

The 4-Block Layout in SKILL.md is specifically designed to exploit this effect:
- Block 1 (Instructions) → first 30%
- Block 2 (Context/Inputs) → middle
- Block 3 (Constraints) → late-middle, reinforced by signal words
- Block 4 (Output Format) → last position, recency bias
