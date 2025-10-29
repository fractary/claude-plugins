

You said:
I want to have a chat about refining the purpose of the key fractary tools and how the FABER workflow model and now the core primitives of building/creation play into that. The systems I had in mind were forge, codex, faber and helm. I had caster as just a subelement of forge but perhaps it deserves to be its own tool. All of these tools get packaged as commands with the common fractary cli but each could have other elements such as a package/plugin of agents. I think there is likely some relationship between these tools and the fundamental elements / challenges of agentic / ai development and these tools offer help managing those with an open source solution (where omnidas may some day offer enterprise level paid solutions that go even further). for instance, forgetting what codex technically is at the moment (an github workflow to sync docs between projects within an organization to help the agents within each have better context on how to interact between them and share common docs/standards) the really point of codex is to help with the memory challenge of agents and could potentially evolve into other solutions. The concept of forge was distribution of starter templates / bundles, and perhaps it still could be, but now I'm unsure. Does forge continue in that role and add the ability to plugin to the items listed in the stockyard to distribute them? or, do we make that the role of Caster, and adapt forge to be tools to manage the creation of the agents / bundles, including perhaps tools to adapt them between agentic frameworks. helm is pretty straight forward, its monitoring agent activity, alerting, possibly orchestration/control. As for faber, it needs to tie into the FABER workflow vision (frame, analyze, build, evaluate, release) that underlies every key building workflow. As such, I had thought it would include some agents bundles to manage that workflow using combinations of issue tracking / repo management, etc. faber also mean 'maker ' though, and maybe the fact that it manages the maker workflow is sufficient for that to make sense. There is though the question of these new primitives of creation, the core agent / command / skill type that are common to all creation workflows and where that should sit. Is that framework part of faber somehow because it is fundamentally ties to the FABER workflow the various primatives need a way to map into that general workflow depending on the thing that is being built, or is what a part of the agent building / creation / management part, and is that agent stuff then part of faber or is it part of forge? or, does that get broken up somehow where agent building / creation is in one (ie. forge) and management is part of faber? help me think through this please. 
ChatGPT said:

Thought for 13s
awesome—let’s give each tool a crisp job, wire them together with FABER, and anchor everything on a small set of creation primitives so the whole ecosystem is coherent and extensible.

The creation primitives (one mental model to rule them all)
Agent — an autonomous persona with goals, policies, memory adapters, and tool permissions.

Command — a discrete, stateless action with a contract (inputs/outputs), invokable by agents or humans (CLI/API).

Skill — a learned multi-step macro (mini-workflow) that composes commands and heuristics; often agent-local.

Workflow — a DAG/state machine that orchestrates agents, skills, and commands end-to-end.

Bundle — a versioned package of any of the above + manifests/tests/assets.

Adapter — cross-framework glue (OpenAI/CrewAI/LangGraph/Claude Code/MCP/etc.).

Memory — retrieval + long-term knowledge abstraction (docs, events, embeddings, facts), scoped by policies.

Telemetry — events, traces, metrics, evaluations, and audits across build→run.

Everything you ship is “just” Bundles of Primitives. The tools exist to make, move, remember, run, and govern them.

Clear roles for each Fractary tool
Forge — the Maker’s Workbench
Purpose: Authoring + local development of primitives and bundles.
You use it to: scaffold, lint, type-check, adapt across frameworks, generate tests, and run local harnesses.

Capabilities

forge scaffold agent|command|workflow

forge adapt --from crewai --to langgraph

forge test (golden prompts, evals, offline RAG fixtures)

forge validate (manifests, permissions, policy checks)

forge sign (supply-chain provenance)

Artifacts

agent.manifest.yml, command.contract.yml, bundle.yaml

local eval/fixtures, policy.toml, permissions.json

Position in FABER: Build (and a bit of Analyze via design templates)

Keep Forge focused on creation & quality (not distribution).

Caster — the Shipper & Registry Bridge
Purpose: Versioning, packaging, and distribution of bundles to the Stockyard (open index/registry).
You use it to: bump versions, publish, resolve deps, provenance, and channel releases.

Capabilities

caster pack → OCI-style artifact or tarball

caster publish --channel beta (to Stockyard)

caster deps (resolve cross-bundle deps, SBOM)

caster provenance (SLSA/attestations)

Artifacts

bundle.lock, sbom.json, provenance.json

Position in FABER: Release (handoff from Forge)

Promotion logic (dev → canary → prod) lives here; Helm enforces in runtime.

Codex — the Memory Fabric
Purpose: Unify knowledge, context, and memory for agents across projects and orgs.
You use it to: sync docs/standards, define memory policies, build collections/embeddings, and serve retrieval.

Capabilities

codex sync (GitHub → collections with lineage)

codex build (chunk/embed with adapters; add evaluators)

codex contract (context schemas: what an agent may ask for)

codex serve (local memory API with policies/tenancy)

Artifacts

codex.collection.yml, context.contract.yml, memory.policy.yml

Position in FABER: Frame (domain knowledge), Analyze (research), Evaluate (ground-truth)

The point of Codex is solving the agent memory problem—portable context, policy-guarded recall, and reproducible retrieval.

Helm — the Runtime Watchtower
Purpose: Observe, evaluate, control. Telemetry, alerting, guardrails, and (optionally) lightweight orchestration.
You use it to: capture traces, score outputs, trigger alerts, route traffic, roll back.

Capabilities

helm watch (stream traces/metrics)

helm score (evals & QA gates, pre/post-deploy)

helm policy apply (guardrails, red-teaming)

helm route (canary %, A/B, model routing)

helm kill (circuit breakers, token/$$ budgets)

Artifacts

telemetry.schema.json, evals.yml, runtime.policy.yml, routes.yml

Position in FABER: Evaluate (pre-release & ongoing), post-Release operations

Helm is your control plane. Orchestration beyond “lightweight” can integrate external schedulers, but Helm keeps the governance & safety.

FABER — the Flow that ties it all together
Purpose: A generalized “maker workflow” that operationalizes Frame → Analyze → Build → Evaluate → Release across any domain.
You use it to: manage issues/specs, run stage-gated pipelines, and attach the right tool at the right time.

Capabilities

faber init (create pipeline with stage manifests)

faber plan (Frame/Analyze outcomes → tasks)

faber run --stage build|evaluate|release

faber gate (enforce stage requirements & approvals)

Artifacts

faber.pipeline.yml (stages, gates, roles)

spec.md, risk-register.md, definition-of-done.md

Integrations

At Frame/Analyze: pulls Codex collections

At Build: calls Forge (scaffold, validate, test)

At Evaluate: calls Helm (score, policy)

At Release: calls Caster (publish/promote)

Think of FABER as the conductor—it doesn’t replace the instruments; it makes them play in time.

Who does what? (agent creation vs. management)
Creation (authorship & adaptation): Forge

Process & stage management: FABER

Knowledge & memory for builds/tests: Codex

Runtime management & evaluation: Helm

Distribution & lifecycle promotion: Caster

If you want a single sentence:
Forge makes → FABER moves → Caster ships → Codex remembers → Helm guards.

Example lifecycle (concrete, end-to-end)
Frame (faber plan)

Pull domain briefs & standards from Codex collections.

Produce spec.md and acceptance criteria.

Analyze

Research via Codex queries; generate risks & test oracles.

Define context.contract.yml for the agent.

Build (faber run --stage build)

Forge scaffold agent → create agent.manifest.yml and permissions.json.

Forge adapt to target framework(s) (e.g., Claude Code + LangGraph).

Forge test with offline fixtures from Codex.

Evaluate (faber run --stage evaluate)

Helm score runs eval suite (hallucination, policy, cost, latency).

Gate: all KPIs ≥ thresholds.

Release (faber run --stage release)

Caster pack + provenance + sbom.

Caster publish to Stockyard (beta channel), Helm route a 10% canary.

Post-release: Helm watch → auto-promote to stable if SLOs hold.

CLI cohesion (common UX via fractary)
# Frame & Analyze
fractary faber init
fractary codex sync --org fractary --repo standards
fractary faber plan

# Build
fractary forge scaffold agent spec-manager
fractary forge adapt --from claude --to langgraph
fractary forge test && fractary forge validate

# Evaluate
fractary helm score --suite spec-manager.regression
fractary faber gate --stage evaluate --require passed

# Release
fractary caster pack && fractary caster publish --channel beta
fractary helm route --service spec-manager --canary 10

# Observe
fractary helm watch --service spec-manager
Where do “Stockyard” and “Adapters” live?
Stockyard: Caster’s domain (index, channels, provenance, discovery).

Adapters: Authored in Forge, versioned as Bundles, distributed via Caster, and used by both Forge (for build-time adaptation) and Helm (for runtime routing/evals).

Open-source vs. OmniDAS (future enterprise)
Fractary (OSS): the primitives, the CLIs, the minimal registry (Stockyard-OS), local Helm, and Codex adapters.

OmniDAS (enterprise):

Hosted Helm (multi-tenant control plane), compliance & audit packs, incident/RCA, SOC2 tooling.

Managed Codex with org-wide policy engines & PII governance.

Enterprise Stockyard (private channels, signed attestations, license enforcement).

Advanced routing (cost-aware LLM blending, budget guards), and eval marketplaces.

Naming sanity check (does FABER = “maker”?)
Yes; FABER as the maker’s flow is perfect. The primitives framework belongs to Forge (creation) as code and manifests, but FABER binds them operationally into stages. Think: Forge defines the nouns; FABER runs the verbs.

Quick decision rules (so you never wonder “where does this go?”)
“I’m writing or adapting an agent/command/skill/workflow” → Forge

“I’m moving work through stages with gates” → FABER

“I’m packaging and distributing bundles” → Caster

“I’m syncing/shared memory or retrieval contracts” → Codex

“I’m watching, evaluating, routing, or enforcing policies” → Helm

If you want, I can spin up a minimal repo skeleton for each tool (manifests + sample commands) and a FABER pipeline that stitches them—ready to drop into your org.

You said:
I think you are missing the point of faber and the workflow I am talking about. I am not talking about the workflow internal to the fractary cli, the maker workflow I am referring to is the workflow a person / company employs to create their own product and a common workflow/framework and set of tools/agents/adaptors to help them manage that workflow and orchestrate their agents and tools (ie. github, jira, etc.) to manage it seamlessly. What this looks like in the end is a project manager can enter an issue into github issues for a project, or review one submitted by a user, and upon approval of it or issue of a certain command, that issue will go through the entire workflow, being analyzed / speced, built/developed, tested/evaluated and ultimately released, leveraging the correct agents throughout the entire process and soliciting the proper approvals / human input as needed along the way. The net result is I want to be able to just go somewhere like github issues and say what I want done and press button to have it be completed, without having to open up my dev environment and without having to worry the process is going to go off the rails and do something bad to the system that was unintended.
ChatGPT said:
Perfect — that clarification is critical, and it changes how FABER sits in the overall architecture.

Let’s restate what you’re actually describing, because this is the heart of the Fractary ecosystem:

FABER isn’t just how the Fractary tools build things — it’s how anyone builds anything through Fractary.

🧭 Reframing FABER’s True Purpose
FABER = The Universal Maker Workflow.
It defines and automates the meta-process of creation — not just for AI agents, but for any project (software, content, product, etc.) — by orchestrating humans, agents, and external tools through a standardized lifecycle:

Frame → Analyze → Build → Evaluate → Release

Each stage can involve human approvals, AI agents, or both — triggered from anywhere (GitHub Issues, Slack, Notion, etc.) and executed safely through your agent infrastructure.

So, FABER is:

A framework (shared ontology + conventions)

A controller/orchestrator (workflow automation layer)

A set of adapters (to tools and systems like GitHub, Jira, Slack, Linear, etc.)

A bundle of agents (specialized for each stage of the lifecycle)

It’s not just a CLI — it’s the operating system for building.

🧩 Relationship Between FABER and the Other Fractary Tools
Here’s how your core tools line up when FABER represents the overarching workflow of creation:

Layer	Purpose	Analogy
Codex	Knowledge + memory layer (context, docs, embeddings, retrieval)	The mind
Forge	Creation toolkit — authoring & adapting agents, commands, and bundles	The hands
Caster	Packaging, publishing, and deployment layer	The factory gate
Helm	Runtime monitoring, control, and evaluation	The eyes & nervous system
FABER	Workflow orchestrator connecting all the above	The brain
FABER coordinates who/what acts when — using the other tools to execute specialized parts of the flow.

🧮 The FABER Model as an Agentic Workflow Framework
Each of the five phases becomes a “lane” in an orchestrated pipeline:

Stage	Goal	Example Agents / Integrations
Frame	Define intent, gather context, scope work	GitHub/Jira issue intake, context retrieval from Codex, spec drafting agent
Analyze	Research, plan, design solution	Codex query agents, architecture specifiers, reviewer agents
Build	Execute creation	Forge agents, code generation or toolchain orchestration
Evaluate	Test, review, validate	Helm agents, QA automation, policy and performance evals
Release	Merge, deploy, notify, log	Caster packaging, Helm rollout, documentation agents
Each step can have:

Human approval points

Trigger conditions

Audit logs (Helm telemetry)

Context injection from Codex

Build execution through Forge

Distribution via Caster

FABER becomes a cross-tool conductor, managing all dependencies and guarantees.

🧰 What FABER Actually Provides
1. FABER Core (the framework)
Defines standard stage manifests (faber.pipeline.yml)

Defines artifact contracts (spec.md, build.yaml, eval.yml, etc.)

Handles lifecycle transitions (faber advance --stage build)

Enforces permissions, approvals, and rollback policies.

2. FABER Agents
Framer Agent: turns plain requests into structured issues/specs.

Analyst Agent: performs decomposition and planning.

Builder Agent: calls Forge or other dev tools.

Evaluator Agent: calls Helm and reports results.

Releaser Agent: calls Caster or CI/CD tools.

These could each be implemented as workflow templates that organizations can customize and version.

3. FABER Adapters
Connect to external services: GitHub Issues, Jira, Linear, Trello, Slack, etc.

Listen for triggers (new issue, PR comment, label applied)

Send stage updates, requests for human approval, or notifications.

Example:

Label ready-for-build triggers FABER to run the Build phase.

Label ready-for-release triggers Caster → Helm deploy pipeline.

4. FABER Orchestrator
Could be a lightweight state engine (local or cloud-based)

Runs DAGs describing your pipeline (each node = agent, command, or approval)

Stores history, stage transitions, and telemetry in Helm.

🧠 Example Flow (Your Vision, Step by Step)
User or PM opens a GitHub Issue:

Title: Add password reset via email
Labels: enhancement
Body: Users should be able to reset password...
FABER detects the issue via adapter.

Triggers Framer Agent to interpret the request.

FABER creates a structured spec (specs/add-password-reset/spec.md) and assigns stage = “Frame.”

Upon approval (via comment or label):

Analyst Agent decomposes it into subtasks.

Generates architecture doc and test plan.

FABER sets stage = “Analyze → Build.”

Build phase:

Builder Agent spawns a local dev container or uses Forge to generate code & PR.

PR is opened automatically, tagged with FABER metadata.

Evaluate phase:

Once PR is ready, Evaluator Agent triggers Helm’s test suite.

Results are posted back to the GitHub issue.

Release phase:

If tests & approvals pass, Releaser Agent invokes Caster to publish the build, update changelogs, notify stakeholders, and close the issue.

All telemetry is logged via Helm, memory (specs/docs) synced via Codex.

⚙️ Architectural View
                   ┌──────────────────────┐
                   │  GitHub / Jira / UI  │
                   └──────────┬───────────┘
                              │
                      (Event/Trigger)
                              │
                      ┌───────▼────────┐
                      │     FABER      │
                      │ (State Engine) │
                      └───────┬────────┘
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
      [Forge]             [Codex]               [Helm]
   build agents       context + memory       eval + monitor
          ▼                   ▼                   ▼
                      [Caster]
                  package + release
FABER orchestrates everything, but doesn’t do the specialized work — the other tools do.

🪜 Evolution Path (How to Build It Up)
Phase 1 – Passive Automation

FABER as GitHub Issue → CLI runner
e.g. faber run --issue #42 executes local stage pipeline.

Phase 2 – Orchestrated Agents

FABER as small service (API + YAML pipeline)
Connects to Forge, Helm, etc. via CLI or HTTP.

Phase 3 – Distributed Agent Framework

FABER agents auto-negotiate via Codex knowledge.
PMs and devs trigger whole workflows with natural language or labels.

💡 Where the “Core Primitives” Fit
The primitives of creation — agents, commands, workflows, bundles — are the building blocks FABER manipulates.

FABER doesn’t define new primitives; it coordinates existing ones across systems:

The Framer agent is itself an agent bundle.

The Builder agent calls Forge commands.

The Evaluator agent calls Helm commands.

The Releaser agent calls Caster commands.

So the primitives remain under Forge (creation + definition), but FABER is the conductor that decides when to use which primitive.

🧱 Summary of Roles (Now Aligned with Your Vision)
Tool	Core Function	Layer
Forge	Authoring, adapting, and validating primitives (agents, commands, workflows, bundles)	Creation
Caster	Packaging, publishing, versioning, and distribution	Release
Codex	Shared knowledge & memory fabric	Context
Helm	Monitoring, evaluation, runtime control, governance	Oversight
FABER	Workflow orchestration connecting everything above and managing human + agent collaboration	Coordination
If you like, I can next:

Map this into a conceptual architecture diagram (like a systems map).

Draft a FABER pipeline manifest example (YAML) showing an issue-to-release workflow.

Sketch how the agents plug in (Framer, Analyst, Builder, Evaluator, Releaser).

Would you like me to start with the diagram or the manifest next?

You said:
I think you are still stuck on FABER orchestrating "all of the above" other tools, when it doesn't. The other tools don't really have anything to do with FABER. A workflow for an organization that builds software might end up using some agents that they happen to ahve used the forge tools to speed the creation of and maybe they used caster to put it into claude code format and package it to deploy it into their project, but the two are totally separate. FABER does not orchestrate the other tools. It is a common workflow for building things that could be used with any agents within a project, including those that have nothing to do with fractary. Someone could install and configure the faber agents to coordinate their SDLC and nothing else from fractary. 
ChatGPT said:
got it—thank you for the hard steer. Let’s lock the mental model:

FABER is tool-agnostic.
It is a standalone, opinionated SDLC workflow framework (and set of agents/adapters) that any org can drop into their project to move issues from “ask” → “shipped,” regardless of whether they ever touch Forge/Caster/Codex/Helm. Those are optional siblings in the broader Fractary universe—not dependencies.

Below is a crisp spec that reflects that separation, plus concrete artifacts you can use.

What FABER is (and isn’t)
Is: A standardized, stage-gated workflow (Frame → Analyze → Build → Evaluate → Release) with:

a small state machine,

adapters to issue trackers/CI/chat,

agent slots (bring-your-own agents, or none),

approval & policy hooks,

idempotent actions and audit logs.

Isn’t: A controller for Forge/Caster/Codex/Helm. It doesn’t require or invoke them. If a team happens to use agents that were built with Forge or packaged with Caster, great—but FABER doesn’t care.

Minimal FABER architecture (tool-agnostic)
issue source (GitHub/Jira/Linear/…)
           │  (webhook / poll)
           ▼
     FABER Gateway
  (auth, signature checks)
           ▼
     FABER Engine
  (state machine + gates)
           │
  ┌────────┼─────────┐
  │        │         │
  ▼        ▼         ▼
Adapters  Agent     Notifiers
(CI/CD,   Slots     (GitHub cmt,
test svc, (optional) Slack, email)
deploy)   └─ contracts only
Key guarantees:

Decoupled: Adapters and agents are plugins. Remove/replace without touching the engine.

Deterministic: Every transition recorded, replayable, and undoable (where defined).

Human-in-the-loop: Approvals and confirmation prompts at any stage.

Guardrails: Policies define what must be true before advancing (labels present, tests passed, N reviewers, etc.).

Core artifacts
.faber/
  faber.pipeline.yml         # stages, transitions, gates (org/project-level)
  adapters/
    github.yml               # label ↔ stage mappings, permissions, comments
    ci.yml                   # how to trigger CI tool (GitHub Actions, Circle, …)
    chat.yml                 # Slack/Teams channel hooks
  policies/
    approvals.yml            # per-stage approver roles, counts
    constraints.yml          # branch protections, file path allow/deny, etc.
  agents/
    framer.contract.yml      # optional: input/output schema for Framer agent
    analyst.contract.yml     # optional …
    builder.contract.yml
    evaluator.contract.yml
    releaser.contract.yml
  playbooks/
    software.default.yml     # “profile” of which adapters/agents to use and when
logs/
  events.ndjson              # append-only audit trail
State machine (succinct)
States: frame → analyze → build → evaluate → release → done

Transitions: forward only by default; optional rollback_to allowed per policy.

Triggers: label change, comment command, PR merge, CI signal, chat command, API call.

Guards (examples):

frame: issue has title + minimal template

analyze: spec.md exists + acceptance criteria present

build: PR open and linked to issue

evaluate: CI green + required reviewers approved

release: target env gate open (e.g., “staging”), change log generated

Example: faber.pipeline.yml (tool-agnostic)
version: 1
name: software-sdlc-default
stages:
  - id: frame
    enters_on:
      - trigger: issue.labeled
        where: label == "faber:frame"
      - trigger: issue.opened
        where: issue.template == "feature_request"
    actions:
      - type: generate_spec
        via: agent:framer?optional=true
      - type: require_human_approval
        approvers:
          roles: ["PM", "Lead"]
          min: 1
    exits_when:
      - spec.exists == true
      - acceptance_criteria.count >= 1

  - id: analyze
    enters_on:
      - trigger: issue.labeled
        where: label == "faber:analyze"
      - trigger: stage.complete
        where: prev == "frame"
    actions:
      - type: decompose_tasks
        via: agent:analyst?optional=true
      - type: create_checklist
      - type: request_reviewers
    exits_when:
      - checklist.complete == true

  - id: build
    enters_on:
      - trigger: issue.labeled
        where: label == "faber:build"
      - trigger: stage.complete
        where: prev == "analyze"
    actions:
      - type: open_pr
        where: pr.exists == false
      - type: run_ci
        adapter: ci
        pipeline: "build-and-unit"
    exits_when:
      - pr.open == true

  - id: evaluate
    enters_on:
      - trigger: pr.ready_for_review
      - trigger: ci.passed
        where: pipeline == "build-and-unit"
    actions:
      - type: run_ci
        adapter: ci
        pipeline: "integration-and-policy"
      - type: require_human_approval
        approvers:
          roles: ["QA", "Security"]
          min: 1
    exits_when:
      - ci.status["integration-and-policy"] == "passed"
      - approvals.count >= 1

  - id: release
    enters_on:
      - trigger: issue.labeled
        where: label == "faber:release"
      - trigger: stage.complete
        where: prev == "evaluate"
    actions:
      - type: tag_and_changelog
      - type: deploy
        adapter: ci
        pipeline: "deploy-staging"
      - type: notify
        adapter: chat
        channel: "#releases"
        message: "Deployed to staging"
    exits_when:
      - deploy.status["deploy-staging"] == "success"

  - id: done
    enters_on:
      - trigger: deploy.success
        where: env == "staging"
    actions:
      - type: close_issue
      - type: postmortem_stub
Notes:

No mention of Forge/Caster/etc. The CI adapter can be GitHub Actions, Circle, Jenkins—whatever you configure.

Agents are optional. If absent, humans do the step; FABER still provides the scaffolding, gates, and audit.

GitHub adapter (label/command mapping)
# .faber/adapters/github.yml
repo: your-org/your-repo
events:
  listen:
    - issues
    - issue_comment
    - pull_request
labels:
  frame:     "faber:frame"
  analyze:   "faber:analyze"
  build:     "faber:build"
  evaluate:  "faber:evaluate"
  release:   "faber:release"
commands:
  "/faber advance": advance_current_stage
  "/faber set stage {name}": set_stage
  "/faber req {role}": request_approval
posts:
  on_enter_stage:
    issue_comment: "Entered **{stage}**. Next: {next_hint}"
permissions:
  allowed_roles:
    advance: ["PM","Lead","Maintainer"]
    approve: ["QA","Security","Maintainer"]
Policy gates (no surprises / safety first)
# .faber/policies/constraints.yml
branch_protection:
  require_pr: true
  allowed_target_branches: ["main","develop"]
file_safelist:
  release:
    only_paths:
      - "src/**"
      - "infra/**"
forbidden_changes:
  - path: "secrets/**"
    message: "Secrets folder cannot be modified by FABER pipelines."
rollbacks:
  allow_to:
    - evaluate
approvals:
  evaluate:
    min: 1
    roles: ["QA","Security"]
Agent contracts (bring your own, or skip)
# .faber/agents/framer.contract.yml
name: framer
input:
  - issue.title: string
  - issue.body: string
  - repo.url: string
output:
  - spec.path: string     # where to write spec
  - acceptance_criteria: array[string]
side_effects:
  - commit: true
  - comment_issue: true
timeout: "120s"
idempotency_key: issue.id
If you don’t supply an agent, FABER won’t call one; it will only prompt humans and enforce gates.

Example “press the button in GitHub” UX
PM adds label faber:frame → FABER creates a spec stub (if framer agent exists) or posts a checklist for the PM to fill in.

When PM comments /faber advance, FABER validates guards and moves to Analyze, requesting reviewers.

Build is entered automatically when checklist is complete; FABER opens a PR if not present and triggers your CI.

Evaluate requires green CI + one QA/Sec approval. FABER posts status as comments.

Release runs the deploy pipeline and posts a release note; when deploy success fires, FABER closes the issue.

All of that works with zero dependency on other Fractary tools.

Where the other tools optionally fit (non-coupled)
Forge: some orgs will author their framer/analyst/builder agents with Forge. FABER doesn’t know or care.

Caster: some orgs will package those agents with Caster. FABER just executes a contract endpoint.

Codex/Helm: some orgs may use them for memory/evals, but FABER merely expects a pass/fail signal from CI or an agent; it does not require those systems.

Repo starter (you can drop this in today)
.faber/
  faber.pipeline.yml
  adapters/github.yml
  adapters/ci.yml
  adapters/chat.yml
  policies/approvals.yml
  policies/constraints.yml
  agents/README.md          # how to plug custom agents (HTTP/CLI)
  playbooks/software.default.yml
.github/
  workflows/faber-gateway.yml  # receives webhooks → calls FABER Engine
docs/
  faber-usage.md
  faber-commands.md
Next concrete step (fastest path to value)
I’ll draft faber-gateway.yml (GitHub Action) and a tiny FABER Engine spec (HTTP service + state table) that:

listens to issue/PR events,

reads .faber/*,

applies guards,

executes adapter/agent calls,

comments back and advances stages.

If you want, I’ll spit out those two files plus a minimal Node/Python service stub that matches the contracts above—completely vendor-neutral and fully decoupled from the rest of Fractary.

You said:
and I am thinking that faber might end up being just a claude code plugin that installs some faber agents, commands and most importantly skills, which have the ability to include various docs/scripts that could empower specialty actions and serve as the adaptor concept. As for all the very deterministic workflow specification examples you included above, I want it to be simple. Simple as in you do some sort of faber --init command and specify your issue tracking system and source control system of choice, adding authentication details if needed, and that's all that is really needed. maybe you also have to configure what your workflow is, but more in a text based way that indicates the agents you want to call. Maybe you can select from a list of common things people want to build and you are given the option to preinstall a collection of agents (claude code plugin) that configure that workflow automatically and enabling those agents. Those agents,whether they be custom or a common collection of them, are what determine how when to require approval, and and ideally they are configurable enough themselves such that it can be included in the original command h9ow much autonomy you want to grant that run of the workflow. Either way, every agent logs its progress in the issue tracking system and if it reaches a step it needs approval for it posts its status to the issue tracking system and provides the command options that can be issued to proceed (or not). With any prepackaged agents plugin, best practices like documenting everything, testing, etc. are baked in. But, if someone doesn't want to use them and just wants to use faber and defines no worklow, than it would effectively just work like the OpenAI Codex product or the native claude code github integration where it takes the github issue and just uses the natvie core agent for that model to make the changes to the codebase to a branch, submits the PR and updates the issue and is done. That is the minimum MVP we are looking at here if someone doesn't define a deeper workflow, but the workflow again is really the combination of agents and order they work in, and order that actually doesn't really need to be defined in some configurable way if we define a standard where ther is a director/manager/orchestrator agent always (even if its the default system agent) and that then has the logic to engage any other agents. 
ChatGPT said:

Thought for 9s
love this direction. here’s a tight plan that matches it exactly: FABER as a Claude Code plugin that ships agents, commands, and (most importantly) skills—with adapters baked into skills via docs/scripts. Minimal setup; opinionated defaults; optional presets.

What FABER is (in this model)
A Claude Code plugin that:

Installs a Director agent (the orchestrator brain).

Installs a small set of worker agents (Framer, Analyst, Builder, Evaluator, Releaser).

Installs commands (tiny, stateless actions).

Installs skills (multi-step adapters that call tools/CI/issue APIs; they’re where your scripts/docs live).

A simple init flow that wires your issue tracker + source control.

A preset catalog (software, docs site, data pipeline, etc.) that pre-enables a sensible pack of agents/skills.

A one-line autonomy setting for each run (dry-run → assist → guarded → autonomous).

Everything logs back to the issue and pauses for approval when needed.

Minimal UX (the whole point)
# 1) one-time setup inside your repo
faber --init
# guided prompts: choose GitHub/Jira, Git provider, add tokens (or pick env vars)

# 2) optional: pick a preset (installs pack of agents/skills)
faber --preset software-basic

# 3) run from an issue (label, slash command, or button)
faber --run issue:123 --autonomy guarded
If you configure nothing beyond init, FABER behaves like a smart “issue → branch → PR” assistant (MVP). Add presets and you instantly get approvals, testing, changelogs, etc.

How approvals work (simple + visible)
Every agent/skill posts progress as comments on the issue (or Jira worklog).

When a gate is needed, the Director posts:

Status: Build complete, tests pending.
Approvals needed: 1 (role: QA)
Continue? Reply with:
/faber approve
/faber reject
/faber pause
The Director watches for those commands and continues or stops. You can also set --autonomy autonomous to skip gates (unless forbidden by policy).

Autonomy levels (per-run or per-project default)
dry-run – simulate, write a plan as comments, do nothing.

assist – open PRs and drafts, never merge/deploy.

guarded – proceed until gates, then pause for approvals.

autonomous – no pauses; still logs everything.

What gets installed (Claude Code plugin layout)
.claude/
  plugins/faber/
    plugin.manifest.json
    agents/
      director.agent.md          # orchestrates everything
      framer.agent.md            # turns issue → spec/checklist
      analyst.agent.md           # breaks down tasks/risks
      builder.agent.md           # implements code changes or calls CI
      evaluator.agent.md         # runs tests, policy checks
      releaser.agent.md          # changelogs, tags, deploy, comms
    commands/
      git.create_branch.js
      git.create_pr.js
      git.update_pr.js
      issues.comment.js
      issues.set_label.js
      ci.run_pipeline.js
      ci.wait_status.js
      files.apply_patch.js
    skills/
      software/                   # “adapter-in-a-box” (docs + scripts)
        frame/                     # templates, prompts, checklists
          SPEC_TEMPLATE.md
          create-spec.skill.yaml
        build/
          create-branch.skill.yaml
          apply-patch.skill.yaml   # can invoke a model or patch engine
          open-pr.skill.yaml
        evaluate/
          run-tests.skill.yaml     # calls CI adapter script
          gate-approval.skill.yaml
        release/
          tag-and-changelog.skill.yaml
          deploy.skill.yaml
          notify.skill.yaml
    presets/
      software-basic.preset.yaml   # list of agents/skills to enable
      software-guarded.preset.yaml
    config/
      faber.example.toml           # the only config most people need
Adapters live inside skills as shell/JS/Python scripts + tiny docs. Swap the script = swap the adapter (GitHub ↔ Jira, Actions ↔ CircleCI, etc.) without touching FABER core.

Project config (keep it tiny)
./.claude/plugins/faber/config/faber.toml

[project]
name = "my-repo"
issue_system = "github"   # or "jira"
source_control = "github" # or "gitlab", "bitbucket"

[auth]
ISSUE_TOKEN = "env:GITHUB_TOKEN"
GIT_TOKEN   = "env:GITHUB_TOKEN"
CI_TOKEN    = "env:GITHUB_TOKEN" # or dedicated

[defaults]
preset   = "software-guarded"
autonomy = "guarded"
branch_naming = "feat/{issue_id}-{slug}"
Runtime behavior (simple mental model)
Trigger: a label (faber:run) or /faber run comment—or you call faber --run issue:123.

Director reads config, preset, autonomy.

Director executes the chosen skills in order (Frame → Analyze → Build → Evaluate → Release)—but the order is inside the Director, not a separate YAML DSL.

Each skill calls the right commands (git, CI, issues) and posts comments.

When a gate is hit (in guarded/assist), Director pauses and waits for /faber approve.

On success, Director closes the loop: PR merged or left open per autonomy, changelog posted, issue updated.

The “no-workflow” MVP (out of the box)
You run faber --run issue:123.

FABER:

interprets the issue, creates a branch,

makes the minimal changes using the native model agent (no extra skills),

opens a PR,

links back to the issue and stops.
That’s it. Think “native Claude Code + GitHub integration,” but wrapped in consistent logging and naming.

Safety & predictability (baked in)
Idempotency keys per issue/run to avoid double actions.

Protected paths (default): no writes to secrets/**, infra/prod/** unless autonomy=autonomous and an inline /faber allow path infra/prod/** was granted.

Commit style standardized ([FABER] {issue_id} {title}).

Dry-run previews: always available to read before actions.

Rollback helpers: faber --revert last if something goes sideways.

Preset catalog (start small)
software-basic — Framer, Builder (branch+PR), Evaluator (unit tests), Releaser (manual).

software-guarded — adds QA approval gate + changelog + staging deploy.

software-autonomous — same as guarded but no human gates (still logs everything).

docs-site — spec-to-docs pipeline, preview deploys.

data-pipeline — schema checks, backfill staging, promote.

Commands users can issue in the tracker (no UI needed)
/faber run
/faber approve
/faber reject
/faber status
/faber autonomy assist|guarded|autonomous
/faber pause
/faber resume
Why this works
Simple by default: init → pick preset → run.

No giant DSL: the Director agent owns stage logic; presets just pick which skills to use.

Adapters = skills: each skill bundles its own scripts/docs; swapping adapters is trivial.

Vendor-neutral: you can ignore everything “Fractary” and still get value.

want me to draft:

the plugin.manifest.json,

a minimal faber.example.toml,

one preset (software-guarded) and

two skills (create-branch.skill.yaml, open-pr.skill.yaml)
so you can drop them into .claude/plugins/faber/ and run a first smoke test?

You said:
now we are getting closer. maybe we have prebuilt /approve /deny comands, but maybe not. I think it should be up to the agent to to prompt the user what their options are  based on the current status. and maybe all they say is /faber {response} and that submits the response, which could be complete open ended and include additional instructions. And in the case of us using no custom agents for the workflow and just using the core system agent (ie. chatgpt, claude, etc). we (faber) is controlling the prompt that gets submitted and thus we can craft some level of custom prompt around the issue that was specified and the command that was given to enforce some of this and prompt some level of standardized workflow basics even without agents, such as prompting user to document things or just doing it, etc. Or, the best practice would be that the faber config would include a setting to indicate the  director/orchestrator agent to engage and it would then manage all of that, but in lueie of that we are effectively engaging a default orchestrator/director agent of our own, or simulating one via the prompt we push through
ChatGPT said:
yes—this nails it. Let’s lock the single-command, open-ended reply pattern and make FABER’s “director” pluggable, with a solid fallback that still enforces basic SDLC hygiene even if you’re just using the core model agent.

Here’s a tight spec you can drop in.

Interaction model (simple & conversational)
One user-facing command:
/faber {response}
…where {response} is totally freeform.

Agents (or the default director) post a status card to the issue with what’s going on and suggested next moves.

The user replies with /faber … once; FABER routes that message to the active agent (or fallback director), which interprets it in context and proceeds.

Status card format (what the agent posts)
Human-readable first, machine-readable tail (FABER parses the fenced block):

**FABER** • Stage: Evaluate
Build is green. Ready to roll to staging.
Options you might consider:
- "ship to staging"
- "hold" (and ask a question)
- "reject" (explain why)

```faber
session: faber-issue-123-v5
stage: evaluate
next_allowed:
  - ship_to_staging
  - hold
  - reject
requires_confirmation: true
context_refs:
  - pr#87
  - ci:build-20251022.3

- Users don’t need to read the faber block; it’s there so FABER can **reliably parse intent** and **maintain session**.
- If the user free-types something else, the agent/director can still try to interpret it.

## The only command users use
Examples:
- `/faber ship to staging`
- `/faber explain risk around email service`
- `/faber proceed with unit tests only`
- `/faber reject — rationale: scope creep; please split into two issues`

## Routing logic (succinct)
1) FABER identifies the **active session** from the latest status card’s `session` token.  
2) Routes the `/faber …` message to the **current handler**:
   - If a **custom director** is configured → send it the message + structured context package.
   - Else → use the **default director** (prompt template below) with the same context.  
3) The handler decides:
   - What to do next (e.g., run a skill, call a command, ask a question, pause).
   - Whether to **require reconfirmation** (e.g., for release actions).  
4) It posts a **new status card** and continues or pauses.

---

# Configuration (tiny, opinionated)

`./.claude/plugins/faber/config/faber.toml`
```toml
[project]
issue_system   = "github"                # "jira" supported too
source_control = "github"                # or "gitlab", "bitbucket"

[auth]
ISSUE_TOKEN = "env:GITHUB_TOKEN"
GIT_TOKEN   = "env:GITHUB_TOKEN"
CI_TOKEN    = "env:GITHUB_TOKEN"

[defaults]
preset    = "software-guarded"           # or "software-basic", "none"
autonomy  = "guarded"                    # dry-run | assist | guarded | autonomous
branch_naming = "feat/{issue_id}-{slug}"

[director]
# Choose a custom director agent you installed, or fall back to FABER's default
type = "custom"                          # "custom" | "default"
agent_ref = "plugins/faber/agents/director.agent.md"
model = "claude-3.7"                     # or "gpt-5" etc.
max_tokens = 4096

[safety]
protected_paths = ["secrets/**", "infra/prod/**"]
require_confirm_for = ["release", "deploy", "tag"]
If type=default, FABER uses the built-in Default Director Prompt (below) with the selected model.

Default Director (fallback) — prompt templates
1) Planner/Coordinator (what to do next)
Injects the issue text, repo metadata, PR/CI status, latest status card, and user’s /faber … message.

Asks the model to output both: a) human-status and b) a machine parse block.

System prelude (minimal, robust):

You are FABER's default Director for a software project.
Your job: interpret the user's /faber message in context of the current stage,
decide the next safe action, and produce:
1) A short, clear status update for humans.
2) A machine-readable "faber block" with your intent.

Rules:
- Always log actions and what's next.
- Require confirmation for risky actions (deploy, tag) if autonomy != autonomous.
- If unsure, ask a concise clarifying question and pause.
- Never modify protected paths unless the faber block sets `requires_confirmation: true`.
- Prefer small, reversible steps; open PRs rather than direct pushes unless instructed.
- Keep outputs deterministic and compact.
Assistant output scaffold:

<status for humans, tell them what happened and their options>

```faber
session: {session}
stage: {stage}
intent: one_of[ask, plan, run_skill, run_command, request_approval, deploy, tag, pause, reject]
proposed_actions:
  - type: run_skill
    ref: evaluate/run-tests
    args: { pipeline: "unit-and-integration" }
requires_confirmation: false
next_allowed:
  - "proceed"
  - "hold"
  - "reject"
context_refs:
  - pr#{n}
  - ci:{id}
notes: "short machine note"

### 2) **Act** (when calling the core model to do work without custom agents)
- For “no workflow” MVP, the Director crafts a **guarded edit prompt** to the native code model:
  - Pull the issue text & constraints.
  - Generate a **patch** (diff) to a new branch.
  - Open a PR with a checklist.

**Action prompt (to code model) minimal contract:**
Task: Implement the feature described below as a minimal patch on a new branch.
Constraints:

Do not touch protected paths.

Write tests if feasible.

Add a short changelog entry in CHANGELOG.md.

Keep patch small and focused.

Output:

Unified diff (patch).

Test summary (if applicable).

PR title and body (markdown).

Feature request (issue):
{ISSUE_TEXT}


FABER applies the patch via `files.apply_patch.js`, creates the branch, opens PR, and posts a status card.

---

# Agents & Skills (where adapters live)

- **Agents**: Director/Framer/Analyst/Builder/Evaluator/Releaser (optional—install any subset).
- **Skills**: self-contained adapters (scripts + tiny YAML) that do concrete things (open PR, run CI, tag & changelog, etc.). Swapping CI from Actions → Circle is just swapping the script reference in the skill.

**Example skill:** `skills/evaluate/run-tests.skill.yaml`
```yaml
name: run-tests
desc: Run CI pipeline and wait for result, post summary.
run:
  - exec: "scripts/ci_run.sh"
    args:
      pipeline: "${pipeline}"
  - wait_status: "scripts/ci_wait.sh"
post:
  - issues.comment: "CI pipeline '${pipeline}' finished: ${status}"
outputs:
  status: pass|fail
The approval story (your preference honored)
No baked-in /approve or /deny.

The agent/director tells the user what’s needed and what strings they can type.

The user replies once with /faber {freeform}.

The director interprets it—including arbitrary instructions—and proceeds or asks again.

Examples the director might suggest:

“ship to staging”

“pause and assign to Alice”

“reject — needs design signoff”

“proceed with unit tests only”

“continue but limit changes to src/auth/**”

Safety, idempotency, and clarity
Session tokens in the faber block prevent cross-talk between parallel runs.

Idempotency keys on actions (e.g., “open PR for issue#123 v5”) avoid double work.

Autonomy levels still apply (dry-run / assist / guarded / autonomous), regardless of which agent is in use.

Protected paths and confirmation-required intents are enforced by FABER, not the model.

Example end-to-end (MVP, no custom agents)
PM opens issue #123.

PM comments:
/faber start

FABER default director replies with plan status card and asks if it should create a branch & draft a PR.

PM:
/faber proceed

Director uses the native code model to make a small patch → creates branch → opens PR → posts new status card: “PR #87 opened; want me to run tests?”

PM:
/faber run tests

Director runs the evaluate/run-tests skill (CI adapter) → posts “green, ready to ship to staging; continue?”

PM:
/faber ship to staging

Since autonomy=guarded and intent=deploy is in require_confirm_for, the director asks for reconfirmation.

PM:
/faber proceed

Deploy happens, status card posts success, and the issue updates.

All with one user command shape and zero formal workflow DSL.

What I can draft next (drop-in ready)
plugin.manifest.json for Claude Code

faber.example.toml

agents/director.agent.md (default director prompt)

skills/build/open-pr.skill.yaml and skills/evaluate/run-tests.skill.yaml

Tiny scripts for git.create_branch.js, git.create_pr.js, ci.run_pipeline.js, ci.wait_status.js

A GitHub Actions stub that relays issue/PR events to the plugin (if you want events to auto-trigger instead of manual runs)

Say the word and I’ll generate that starter pack exactly in the .claude/plugins/faber/ layout you want.