# Risk-Driven CS325 Project Ideas (In-Depth)

This document gives five original project ideas that stay within your allowed CS325 scope:

1. CPU scheduling algorithm
2. Page replacement algorithm
3. Page table implementation

Each idea is framed around real weaknesses reported in Linux-kernel research and bug-fix history: fairness regressions, wakeup-preemption instability, lock-order deadlocks, reclaim inefficiency under pressure, and page-table security/performance trade-offs.

---

## 1) Adaptive Interactive Fairness Guard (CPU Scheduling)

### Core Problem
Linux scheduler behavior can become unstable for mixed workloads (interactive + CPU-bound + many short wakeups). Literature and kernel discussions around CFS/EEVDF evolution show trade-offs between responsiveness and unnecessary preemptions.

### Flaw / Loophole Addressed
- Interactive tasks may get delayed if wakeup behavior is not favored enough.
- Over-favoring wakeups can increase involuntary context switches and reduce throughput.
- Thread-heavy programs can gain unfair advantage if policy is not bounded.

### Proposed Modification
Implement a bounded wakeup boost in scheduler logic:
- Boost short-sleeping interactive tasks on wakeup.
- Decay boost quickly for CPU-heavy tasks.
- Add fairness guardrail so a task cannot repeatedly exploit wakeup boosts.

### Why It Is Original
Not a plain FCFS/RR/SJF copy; it is a hybrid fairness-latency heuristic inspired by modern Linux scheduling concerns.

### Kernel Area
- `kernel/sched/fair.c`
- `kernel/sched/core.c`

### Evaluation Metrics
- Response time for interactive command batches
- Throughput for CPU-bound workload batch
- Context-switch rate
- CPU utilization and runqueue latency

### Main Risks
- Starvation risk for long-running compute tasks
- Over-tuning to synthetic workloads

### Week Mapping
- Week 4 (Scheduling criteria/algorithms)
- Weeks 5-8 (starvation, bounded waiting, lock safety during path changes)

---

## 2) Anti-Thrash Hybrid Reclaimer (Page Replacement)

### Core Problem
Classic active/inactive reclaim can misclassify hot/cold pages under memory pressure and spend too much CPU on scanning, especially with one-time large file access patterns.

### Flaw / Loophole Addressed
- One-time streaming I/O can pollute page lists.
- Heavy scan overhead can hurt system responsiveness.
- Wrong reclaim choices increase page faults and swap storms.

### Proposed Modification
Create a lightweight hybrid policy:
- Base behavior remains LRU-like.
- Add second-chance style protection for recently re-referenced pages.
- Add anti-pollution filter for single-use sequential pages.

### Why It Is Original
Combines simple textbook reclaim logic with practical Linux pressure behavior and explicit anti-thrashing guardrails.

### Kernel Area
- `mm/vmscan.c`
- reclaim decision points/counters in `mm/`

### Evaluation Metrics
- Minor/major page fault rate
- Swap in/out activity
- Time-to-completion for memory-pressure workload
- kswapd CPU usage

### Main Risks
- Extra bookkeeping overhead can offset gains
- Workload-specific bias (better for some patterns, worse for others)

### Week Mapping
- Week 9 (paging, page replacement, swapping)
- Weeks 5-8 (locking assumptions in reclaim path)

---

## 3) Lock-Safe Scheduler Patch with Lockdep Validation (CPU + Concurrency Focus)

### Core Problem
Kernel regressions often arise from lock ordering mistakes (ABBA patterns), especially in hot paths touched by scheduler or memory-management changes.

### Flaw / Loophole Addressed
- Circular wait conditions can produce hard deadlocks.
- Long lock hold times amplify contention and latency.

### Proposed Modification
Implement a small scheduler enhancement, but make lock-safety a first-class deliverable:
- Document lock acquisition order of modified path.
- Minimize time spent inside protected critical section.
- Validate with lockdep-enabled test kernel.

### Why It Is Original
Most student projects optimize only performance; this idea combines performance with formal deadlock-risk reduction and proof strategy.

### Kernel Area
- Scheduler path (same files as Idea 1)
- Validation with lockdep kernel configuration and runtime logs

### Evaluation Metrics
- Functional scheduler metrics (latency/throughput)
- Number of lockdep warnings under stress
- Tail latency under concurrency-heavy tests

### Main Risks
- Debug config overhead can affect benchmark purity
- Requires disciplined test methodology

### Week Mapping
- Week 5 (critical section, atomicity concepts)
- Week 6 (classical synchronization reasoning)
- Weeks 7-8 (deadlock prevention/detection mindset)

---

## 4) Priority Aging with Abuse Resistance (CPU Scheduling)

### Core Problem
Priority-leaning policies improve responsiveness but are vulnerable to starvation and gaming (frequent sleeps to look interactive).

### Flaw / Loophole Addressed
- Low-priority tasks may starve.
- Tasks can game priority by artificial behavior.

### Proposed Modification
Add a priority-aging inspired mechanism inside scheduler behavior:
- Waiting tasks gain bounded priority credit over time.
- Rapidly waking tasks are checked against abuse heuristics.
- Apply cap so no class dominates indefinitely.

### Why It Is Original
Transforms Week-4 theory (priority + aging + fairness) into kernel-grade anti-abuse control.

### Kernel Area
- `kernel/sched/fair.c`

### Evaluation Metrics
- Waiting-time distribution (not just average)
- 95th/99th percentile response time
- Starvation incidence (tasks exceeding threshold wait)

### Main Risks
- Heuristic thresholds can be fragile
- More knobs increase tuning complexity

### Week Mapping
- Week 4 (priority scheduling, aging, RR integration)
- Week 2 (process state transitions and waiting behavior)

---

## 5) Page-Table-Aware Performance/Security Trade-off Study (Page Table Implementation)

### Core Problem
Page-table isolation and translation-path hardening improve security, but can increase syscall/context-switch overhead depending on hardware support.

### Flaw / Loophole Addressed
- Security features can have non-uniform performance penalties.
- Misconfiguration or assumptions about hardware support can hide regressions.

### Proposed Modification
Implement a constrained page-table experiment with measurement-first methodology:
- Add instrumentation or controlled policy toggle in page-table-related path.
- Compare baseline vs modified behavior under syscall-heavy and compute-heavy loads.
- Include explicit security discussion (what threat is reduced, what cost is introduced).

### Why It Is Original
Most projects optimize for speed only; this idea frames page tables as a security-performance co-design problem.

### Kernel Area
- Page-table relevant logic in `mm/` and architecture-specific translation path (final scope chosen after kernel-version inspection)

### Evaluation Metrics
- Syscall latency microbenchmarks
- Context-switch-sensitive benchmark behavior
- Aggregate workload throughput
- Overhead variance by hardware capability

### Main Risks
- Harder than scheduler ideas
- Strong dependency on kernel version and CPU features

### Week Mapping
- Week 9 (address translation, TLB, page-table structures)
- Week 1 (OS architecture and kernel subsystem boundaries)

---

## Best Choice for Your Team (Balanced + Advanced)

If your goal is **high marks with manageable risk**, choose:

1. **Idea 1: Adaptive Interactive Fairness Guard** (primary recommendation)
2. **Idea 2: Anti-Thrash Hybrid Reclaimer** (second option, slightly harder debugging)

Why:
- Strong measurable outcomes for demo
- Clear mapping to course topics
- Enough novelty to look original
- Lower failure risk than deep page-table work

---

## Suggested Report Narrative (Use This Structure)

1. **Observed weakness from literature**
2. **Your threat/failure model**
3. **Design goals and constraints**
4. **Kernel touchpoints and implementation steps**
5. **Safety analysis (deadlock/starvation/fairness)**
6. **Before/after experimental protocol**
7. **Results, regressions, and limitations**
8. **Future extension**

---

## Research Anchors You Can Cite

- Linux scheduler documentation (EEVDF and scheduler evolution)
- LKML patch discussions on wakeup preemption and fairness trade-offs
- Linux lockdep design/runtime locking validator docs
- MGLRU design/performance discussions (LWN + kernel docs)
- Meltdown/KPTI/EntryBleed material for page-table trade-off context

Use these as conceptual references; do not copy code from external repositories.
