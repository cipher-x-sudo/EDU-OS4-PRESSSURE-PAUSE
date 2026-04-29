# Deep-Dive Research for CS325 Kernel Project

This document implements the deep-dive plan by turning literature into actionable project direction.  
Scope is limited to the components allowed in your brief:

- CPU scheduling algorithm
- Page replacement algorithm
- Page table implementation

Reference brief: `CS325-Project.md`.

---

## A. Evidence-Backed Weaknesses You Can Claim

## 1) CPU Scheduling: Invariant and Preemption Drawbacks

### What research shows
- A well-known scheduler study reports cases where runnable threads wait while some cores stay idle (work-conserving behavior violated), causing measurable regressions.
- Recent EEVDF LKML discussions show wakeup-preemption tuning can improve interactivity but can also increase unnecessary involuntary context switches in some mixes.

### Vulnerability / loophole / flaw angle
- **Loophole:** aggressive wakeup-preemption may be abused by frequent wakeup patterns.
- **Flaw:** fairness can degrade when policy overreacts to short-sleeping tasks.
- **Drawback:** latency-throughput trade-off becomes unstable across workloads.

### Why this is useful for your project
It gives a concrete, modern, non-textbook motivation for a bounded adaptive scheduler tweak.

---

## 2) Synchronization & Deadlocks: Lock-Ordering Risk

### What research/docs show
- Lock-order inversion (ABBA) remains a common kernel failure mode.
- Lockdep is designed to detect potential cycles as soon as contradictory orderings appear, even before a hard deadlock happens.

### Vulnerability / loophole / flaw angle
- **Vulnerability class:** circular wait through inconsistent lock order.
- **Flaw:** long lock hold times increase contention and stall probability.
- **Drawback:** hot-path changes can silently introduce lock-order debt.

### Why this is useful for your project
You can add a formal safety argument (not only performance claims), which is a strong differentiator in viva.

---

## 3) Page Replacement: Reclaim Efficiency and Thrashing

### What research/docs show
- Traditional reclaim behavior can waste CPU on scanning and can be hurt by one-time streaming accesses.
- MGLRU improves many cases, but characterization studies still show variability and configuration sensitivity.

### Vulnerability / loophole / flaw angle
- **Loophole:** sequential one-time access can pollute reclaim signals.
- **Flaw:** reclaim may misclassify hot vs cold pages in pressure phases.
- **Drawback:** performance gains may be workload- or machine-dependent.

### Why this is useful for your project
You can justify a hybrid anti-thrash policy and explicitly discuss where it can fail.

---

## 4) Page Tables: Security-Performance Trade-off

### What research/docs show
- Meltdown-class lessons and KPTI responses highlight that stronger isolation can increase overhead for syscall/context-switch-heavy workloads.
- Hardware support and workload shape strongly affect the visible cost.

### Vulnerability / loophole / flaw angle
- **Vulnerability context:** translation/isolation assumptions can leak information through microarchitectural channels.
- **Flaw:** mitigation overhead is non-uniform and can surprise operators.
- **Drawback:** speed-only optimization can weaken security reasoning.

### Why this is useful for your project
Enables a mature project narrative: performance must be evaluated together with safety assumptions.

---

## B. Five Refined Project Ideas (In-Depth)

## Idea A: Bounded Wakeup Fair Scheduler (Recommended)

**Type:** CPU scheduling  
**Problem targeted:** interactive latency spikes and preemption overreaction  
**Core change:** bounded wakeup boost + fast decay + anti-gaming cap  
**Kernel touchpoints:** `kernel/sched/fair.c`, `kernel/sched/core.c`  
**Metrics:** response time, throughput, involuntary context switches, fairness spread  
**Major risks:** threshold sensitivity; potential starvation if guardrails are weak  
**Syllabus mapping:** Weeks 2, 4, 5-8

---

## Idea B: Lock-Aware Scheduler Optimization

**Type:** CPU scheduling + concurrency safety  
**Problem targeted:** hidden lock-order risk in scheduler-path updates  
**Core change:** small scheduler policy tweak with explicit lock-order proof and minimized critical-section scope  
**Kernel touchpoints:** scheduler files + lockdep-enabled validation workflow  
**Metrics:** baseline scheduler metrics + lockdep warning count + tail latency  
**Major risks:** debug config overhead affects absolute perf numbers  
**Syllabus mapping:** Weeks 5-8 strongly, plus Week 4

---

## Idea C: Hybrid Anti-Thrash Reclaimer

**Type:** Page replacement  
**Problem targeted:** reclaim inefficiency and fault storms under memory pressure  
**Core change:** LRU-like base + second-chance signal + anti-pollution for one-time streams  
**Kernel touchpoints:** `mm/vmscan.c` and reclaim counters in `mm/`  
**Metrics:** major/minor faults, swap traffic, kswapd CPU, completion time  
**Major risks:** may help some workloads and hurt others  
**Syllabus mapping:** Week 9 + lock correctness awareness from Weeks 5-8

---

## Idea D: Page Table Tradeoff Probe

**Type:** Page table implementation  
**Problem targeted:** uncertain security/performance balance in translation-related behavior  
**Core change:** narrow page-table-path instrumentation/toggle and controlled comparative analysis  
**Kernel touchpoints:** selected page-table path in `mm/` + arch-specific translation code (after version mapping)  
**Metrics:** syscall-heavy vs compute-heavy slowdown delta, context-switch sensitivity  
**Major risks:** highest implementation complexity and hardware dependence  
**Syllabus mapping:** Weeks 1 and 9 primarily

---

## Idea E: Fairness Against Thread-Gaming

**Type:** CPU scheduling  
**Problem targeted:** unfair gains by thread explosion or wakeup-pattern manipulation  
**Core change:** fairness guard that normalizes reward behavior under suspicious wakeup/thread patterns  
**Kernel touchpoints:** `kernel/sched/fair.c`  
**Metrics:** per-task fairness, cgroup fairness, p95/p99 latency, starvation incidence  
**Major risks:** false positives and tuning fragility  
**Syllabus mapping:** Week 4 + Week 2 process/thread behavior

---

## C. Selection Matrix

- **Best success probability + originality:** Idea A
- **Best safety-depth narrative:** Idea B
- **Best memory-management depth:** Idea C
- **Most advanced / highest risk:** Idea D
- **Most novel fairness angle:** Idea E

If your priority is marks + demo reliability, choose **Idea A**, with **Idea C** as second option.

---

## D. Vulnerability/Flaw Language for Report

Use this wording style in your report:

- “We target a known scheduler loophole where wakeup-centric policies can increase preemption churn.”
- “We enforce bounded waiting and starvation prevention to avoid priority inversion-like behavior.”
- “We evaluate deadlock exposure by documenting lock acquisition assumptions and checking for circular dependency warnings.”
- “We discuss reclaim policy drawbacks under sequential access pollution and stress-phase misclassification.”
- “We treat page-table changes as security-performance trade-offs, not pure throughput optimization.”

---

## E. Credible Sources to Cite

- EuroSys work on Linux scheduler wasted-core behavior
- LKML EEVDF wakeup-preempt regression/fix threads (2024)
- Linux lockdep design documentation
- Linux MGLRU documentation + 2024 characterization work
- Meltdown/KPTI and subsequent overhead analyses

These should be cited for concepts and motivation; external code should not be copied.

---

## F. What to Do Next

Pick one idea (A-E), then prepare:

1. Function-level touchpoint map
2. Minimal patch plan with rollback toggle
3. Benchmark set (baseline vs modified)
4. Safety argument (starvation/deadlock/fairness)
5. Rubric-aligned report sections and demo script
