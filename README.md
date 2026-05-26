# Playtest & Launch Validator Toolkit (Godot 4)

**Not another analytics SaaS, but a medical-grade diagnostic plugin (Interpretation Engine) for indie developers on Godot 4 launching games on Steam.**

Indie developers frequently make fatal product mistakes that bury their games in the Steam "algorithmic graveyard": falling into *Teal Ghetto* price traps (under $5), suffering from hidden UX-driven refunds, or experiencing poor retention within the first 120 minutes. Most analytics systems simply dump raw charts that developers don't know how to read.

The **Launch Validator Toolkit** captures telemetry (during playtests, Steam Next Fest demos and initial release days) and delivers a **ready-to-action business diagnosis** built on Steam visibility algorithms and market quantiles, following a **Local-First / Zero-DevOps** architecture.

---

## Architectural Philosophy

* **Zero-DevOps & Cost-Aware:** No heavy servers, cloud databases (like PostgreSQL/ClickHouse), or monthly infrastructure bills. The system scales to tens of thousands of players for free using Edge infrastructure.
* **Industrial-Grade I/O:** Data collection is designed around real-time system paradigms (inspired by industrial robotics) — disk write operations are isolated in a background thread, preventing main-thread blocking and ensuring **0% FPS impact**.
* **Local-First Analytics:** Complex analytical computations and SQL queries run directly on the developer's machine via an embedded OLAP database (DuckDB) that reads columnar files straight from cloud object storage.

---

## Roadmap & Technical Stages

### STAGE 1: Local Core (Zero-Cloud MVP)

**Goal:** In-engine data collection, local storage configuration, and standalone analytical interpretation with zero network dependency.

* **Telemetry Core:** A thread-safe singleton (`Autoload`) based on the *Producer-Consumer* pattern. The main game thread only pushes events to a queue, while a background worker (`Thread`, `Mutex`, `Semaphore`) handles batched, atomic disk writes (`.tmp` -> `.json` rename) to `user://telemetry_buffer/` ensuring **0% FPS impact**.
* **Critical Metrics Collection:**
* *Session Telemetry:* Launch/exit times, hardware, and OS environment parameters.
* *Funnel Events:* Milestone progressions, checkpoints, and tutorial completion.
* *Early Churn Moments:* Pinpointing the exact moment and scene where a player closed the game within the first 120 minutes.

#### STAGE 1.1: Privacy Opt-in/Opt-out Mechanism & Playtest Ops  — 🟢 WE ARE HERE

**Goal:** Maintain GDPR/CCPA compliance from day one and provide a manual fallback data-pipeline for closed playtests.

* **Privacy Gateway:** A mandatory UI overlay component triggered on the very first game launch. It prompts the player with a clear, non-legalistic disclaimer regarding anonymous telemetry collection.
* If the user selects `[Accept]`, the toolkit functions normally.
* If the user selects `[Decline]`, the toolkit instantly sets `_accepting_events = false`, completely halting queue processing and disk I/O.


* **The "Export Logs" Fallback Button:** A dedicated, developer-facing debug option (can be mapped to an in-game settings menu or a hotkey like `F12`). When pressed, it executes `ProjectSettings.globalize_path("user://telemetry_buffer/")` and triggers `OS.shell_open()`, instantly opening the native OS file manager (Explorer/Finder) for the tester.

> ⚠️ **STAGE 1 PLAYTEST OPERATIONS (THE MANUAL CRUTCH):**
> Since Cloudflare integration is decoupled into Stage 2, running a playtest right now relies on a **closed-community loop**.
> 1. The developer distributes the game build to trusted testers (via Discord, Itch.io, or Steam Playtest).
> 2. Testers complete their gameplay session.
> 3. Before closing or from the main menu, the tester clicks the **"Open Logs Folder"** button, packs the accumulated `batch_*.json` files into a `.zip` archive, and manually sends it back to the developer (via Discord DM, form upload, or email).
> 
> 
> 🛑 **NOTE:** This manual friction is a temporary bottleneck. **It will be completely deprecated and removed in STAGE 2**, where all background logs will silently and asynchronously flush directly to the serverless cloud without interrupting the player.

#### STAGE 1.2: In-Engine UI Dashboard (EditorPlugin)

**Goal:** Prevent data-hoarding and give indie developers an instant, actionable business diagnosis without leaving the Godot Editor.

Instead of staring at thousands of raw JSON files received from testers, the developer drops those `.json` files into their own local `user://telemetry_buffer/` folder and opens a custom **Telemetry** viewport tab integrated right into the Godot 4 editor layout.

* **Funnel Analytics View:** Automatically parses all available batches, aggregates milestones, and renders a visual step-by-step conversion chart. Steps with a drop-off rate higher than 50% are automatically highlighted in red with contextual debugging recommendations.
* **The 2-Hour Ghost (Refund Predictor):** A specialized density chart mapping playtester session durations. If a high concentration of session-end triggers is detected between minutes 100 and 119, the dashboard throws a critical alert: *«High Refund Risk: Mass churn detected immediately before the Steam 120-minute refund window closes.»*
* **Ragequit / Drop-off Heatmap:** Displays a ranked list of scene paths and level names where players most frequently triggered `session_end` or ungraceful exits, identifying hidden UX bottlenecks and pacing flaws.

### STAGE 2: Distributed Transport (Edge Serverless Transport)

**Goal:** Scalable and free data collection from thousands of players during Steam Next Fest with zero server maintenance.

```
[Game (Godot 4)] 
       │ (Asynchronous HTTP batching / ITransport)
       ▼
[Cloudflare Workers (Edge)] ── (Schema Validation & Append-only)
       │
       ▼
[Cloudflare R2 (Object Storage)] -> Immutable log storage (/events/YYYY/MM/DD/*.json)

```

* **Smart Client Batching:** Implementing an `ITransport` interface. The game buffers events in memory and sends them in a single compressed HTTP payload upon session exit or every few minutes.
* **Serverless Ingestion (Cloudflare Workers):** A lightweight script running on Edge architecture that accepts JSON, validates its structure against a schema and flushes it to storage instantly. The free tier covers 100,000 requests per day.
* **Immutable Storage (Cloudflare R2):** Telemetry is stored as flat, *append-only* files in an S3-compatible object store with zero egress fees. Structured via paths: `/events/YYYY/MM/DD/session_id.json`.

### STAGE 3: Analytical DB & Heuristics Layer (OLAP & Strategy)

**Goal:** A high-performance data analysis engine transforming the plugin into a strategic consulting asset.

* **Storage Optimization:** Migrating the pipeline from heavy JSON to binary columnar **Parquet** format, compressing data 8-10x and accelerating analytical queries.
* **Embedded DuckDB:** Integrating the lightweight OLAP database `DuckDB` right into the Godot plugin. It runs locally on the developer's PC and executes `Remote Querying` via standard SQL – reading Parquet files directly from Cloudflare R2 without downloading them entirely.
* **Steam Heuristics Layer:** Automated computation of specialized business metrics:
* *The 2-Hour Refund Ghost:* Analyzing session density distribution within the first 120 minutes to predict refund rates based on session dynamics.
* *Teal Ghetto Price-to-Content Friction:* Mapping average Time-to-Completion against the Steam price point to flag mismatches in player expectations.
* *Algorithmic Risk Heuristics:* Evaluating playtester retention profiles. Triggers warnings if metrics signal that Steam's recommendation algorithms will penalize the game's visibility post-launch.



---

## Quick Start (STAGE 1)

### 1. Singleton Installation

1. Copy the `TelemetryCore.gd` file into your project.
2. Go to **Project Settings -> Autoload**, add the `TelemetryCore` script, and enable it.

### 2. In-Game Integration

Use the global singleton API to log core events:

```gdscript
# Logging tutorial completion
func _on_tutorial_finished() -> void:
	TelemetryCore.track_funnel("tutorial_basic", "completed")

# Tracking a critical churn point before the player quits
func _on_user_ragequit() -> void:
	var total_time = GameplayTimer.get_seconds()
	var current_level = get_tree().current_scene.name
	
	TelemetryCore.track_early_churn(current_level, total_time)

```

### 3. Local Logs

All events are accumulated as isolated atomic JSON batches in the following directory before network transmission:
`user://telemetry_buffer/batch_[session_id]_[timestamp].json`

You can open this folder via the Godot interface (*Project -> Open Project Data Folder*) to verify the batch payload structure.

---

## Security & Data Privacy

* A strict append-only model is enforced: player data cannot be modified or overwritten externally.
* The system is strictly designed to collect raw gameplay metrics (session info, game loop triggers) and does not gather PII (Personally Identifiable Information) without explicit consent, remaining fully compliant with Steam distribution rules.