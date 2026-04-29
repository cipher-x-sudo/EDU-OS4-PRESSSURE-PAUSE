# CS325 Deep Research (70+ Findings)

This file provides 70+ analyzed findings focused on Linux-kernel vulnerabilities, flaws, loopholes, and drawbacks across:
- CPU scheduling
- synchronization/deadlocks/races
- page replacement and reclaim
- page-table, TLB, and isolation trade-offs

Use these as research-backed motivation for your project narrative.

---

## 1) CPU Scheduling Findings (R01-R20)

- **R01:** EuroSys "wasted cores" evidence shows runnable tasks can wait while cores are idle, violating work-conserving expectations.
- **R02:** Scheduler complexity (NUMA, cache locality, balancing) can hide invariant violations that do not crash systems but hurt throughput.
- **R03:** EEVDF wakeup-preempt tuning improves interactivity in some tests but can increase involuntary context switches.
- **R04:** A preemption criterion mismatch (`rq->nr_running` vs `cfs_rq->nr_running`) can trigger avoidable preempt churn.
- **R05:** Lag-based placement in EEVDF can regress alternating task patterns (observed in vhost/kworker discussions).
- **R06:** Starvation can appear in hierarchical cgroups if local queue checks ignore wider runqueue competition.
- **R07:** Incorrect vruntime normalization checks can starve tasks in stable branches (backport patch evidence).
- **R08:** sched_ext enable path has starvation risk when fair-class load saturates CPU and ext-class activation thread cannot run.
- **R09:** Moving starvation-prone control paths to RT kthreads is used as a practical kernel mitigation.
- **R10:** Short-slice favoring policies can become gaming vectors for frequent-wakeup tasks.
- **R11:** Thread-heavy applications can bias fairness if policy reward is per-thread without robust safeguards.
- **R12:** Tail latency and average latency can move in opposite directions under scheduler tuning.
- **R13:** Benchmark sensitivity means scheduler wins in hackbench may not generalize to database/web workloads.
- **R14:** Latency-focused patches can degrade throughput under long-running compute mixes.
- **R15:** Fairness and responsiveness need explicit bounded-waiting constraints to avoid starvation classes.
- **R16:** Scheduler regressions are often subtle and only visible with fine-grained tracing, not simple utilization graphs.
- **R17:** Policy knobs lacking decay mechanisms can over-amplify short-term wakeup behavior.
- **R18:** Cross-class interactions (CFS + RT + other classes) can distort assumptions made in class-local logic.
- **R19:** Cgroup hierarchy introduces non-obvious scheduling edge cases absent in single-queue theory.
- **R20:** Practical scheduler design must trade off fairness, response time, context-switch overhead, and predictability.

---

## 2) Synchronization, Deadlocks, and Race Findings (R21-R40)

- **R21:** ABBA lock ordering remains a recurring deadlock class in Linux subsystems.
- **R22:** lockdep detects potential cycles on first contradictory ordering, before a full deadlock manifests.
- **R23:** lockdep lock-class modeling catches class-level cycles even when concrete lock instances differ.
- **R24:** Network stack examples show deadlocks from `rtnl_mutex` and trigger-list lock inversion.
- **R25:** Filesystem paths (OCFS2/Btrfs) repeatedly show lock-order inversion risks in recovery and inode paths.
- **R26:** Refactoring that changes call-site lock context can silently create new circular dependencies.
- **R27:** Long lock hold times can produce stalls without strict deadlock, still damaging latency and throughput.
- **R28:** CVE records show race-to-UAF is common where lifecycle and asynchronous workqueues interact.
- **R29:** `cancel_work_sync()` does not guarantee "cannot be requeued elsewhere"; this creates cancellation loopholes.
- **R30:** Timer/workqueue races can access freed objects after teardown if lifecycle sequencing is incomplete.
- **R31:** Block/cgroup and net/sched code paths have UAF races from concurrent cleanup vs activation.
- **R32:** BFQ scheduler vulnerabilities show that missing lock protection around queue pointers can trigger UAF.
- **R33:** Scheduler/cgroup paths can revive structures during teardown via periodic timers, creating UAF windows.
- **R34:** Concurrency bugs often emerge from assumptions that "this path cannot run concurrently" without hard barriers.
- **R35:** Locking correctness and memory lifetime correctness must be argued together, not independently.
- **R36:** Debug kernels can detect lock classes and races, but overhead can mask performance behavior.
- **R37:** Deadlock avoidance requires globally consistent lock ordering documentation, not local function reasoning.
- **R38:** Circular wait can be introduced by error-handling paths even when fast paths look safe.
- **R39:** IRQ/context constraints (sleeping locks in atomic contexts) are another subtle lock correctness axis.
- **R40:** Safety claims should include contention behavior and progress guarantees, not only "no panic observed."

---

## 3) Page Replacement and Reclaim Findings (R41-R58)

- **R41:** Classic reclaim can overscan low-value pages, wasting CPU during memory pressure.
- **R42:** One-time sequential access (streaming reads) can pollute recency signals and trigger thrash-like behavior.
- **R43:** Unevictable-page interaction can cause vmscan to spend disproportionate effort with little reclaim progress.
- **R44:** Historical kernel notes describe systems spending near-100% CPU in vmscan under pathological conditions.
- **R45:** Direct reclaim can create severe latency spikes because user tasks block inside reclaim work.
- **R46:** kswapd wakeup/throttling corner cases can leave tasks waiting too long when reclaim signaling misfires.
- **R47:** Reclaim policies can mis-balance anon/file pressure, hurting either interactive file cache or anonymous working sets.
- **R48:** Swap storms and major-fault bursts are practical symptoms of reclaim policy mismatch.
- **R49:** PSI "full" stall is a useful thrash indicator when all non-idle tasks are blocked on memory/IO.
- **R50:** MGLRU improves many scenarios but introduces complexity and parameter interpretation burden.
- **R51:** 2024 characterization reports show MGLRU performance variability across identical runs/configurations.
- **R52:** Parameter tuning alone may not fix observed variability; workload/hardware coupling remains strong.
- **R53:** Reclaim success metrics must include both performance and stability variance, not only average runtime.
- **R54:** kswapd CPU and refault behavior are key indicators for judging replacement-policy quality.
- **R55:** Reclaim path changes require careful lock and IRQ-context checks due to frequent hot-path execution.
- **R56:** Hybrid heuristics can reduce thrashing but risk extra bookkeeping overhead and regressions on different mixes.
- **R57:** Memory-pressure behavior differs sharply between SSD swap, zram swap, and no-swap setups.
- **R58:** A robust page-replacement project should explicitly state failure modes and non-improving workloads.

---

## 4) Page Table, TLB, and Isolation Findings (R59-R76)

- **R59:** Meltdown-class attacks exposed that speculative execution can bypass expected isolation boundaries.
- **R60:** KPTI mitigates major leakage paths but imposes overhead that depends on syscall/context-switch intensity.
- **R61:** EntryBleed demonstrates that mitigations can retain side-channel loopholes (KASLR bypass under KPTI).
- **R62:** "Mapped entry pages" needed for transitions become a potential attack surface for address de-randomization.
- **R63:** Page-table security measures must be assessed alongside microarchitectural behavior, not only permission checks.
- **R64:** TLB shootdowns become a scalability bottleneck as core counts and NUMA complexity increase.
- **R65:** Academic work shows large gains by reducing unnecessary shootdowns; this implies baseline Linux overhead exists.
- **R66:** Lazy/coherence strategies improve performance but risk stale translations if barriers/ordering are mishandled.
- **R67:** mremap/ftruncate-style stale-TLB races can produce dangerous temporal windows if flushes are delayed.
- **R68:** ARM64 race discussions show remote-CPU barrier assumptions can leave stale entries theoretically valid.
- **R69:** x86 lazy-TLB paths have required more aggressive flushing in some fixes to avoid stale-walk artifacts.
- **R70:** Translation coherence bugs often arise from distributed state updates across cores and deferred invalidations.
- **R71:** Page-fault handler races historically enabled privilege escalation when synchronization around VMA growth was weak.
- **R72:** Fault-path nofault helpers can still fault in corner cases, creating reliability/security surprises.
- **R73:** userfaultfd + swap-cache races show page-table/memory-state transitions can corrupt assumptions and counters.
- **R74:** Swapoff/freeing races demonstrate teardown ordering risks in memory metadata and backing store state.
- **R75:** Hardware feature differences (PCID/ASID, TLB behavior) change measured mitigation costs significantly.
- **R76:** A page-table project must report both security rationale and workload-specific performance costs.

---

## 5) Cross-Cutting Drawbacks and Project Implications (R77-R84)

- **R77:** Many kernel regressions are not crashes; they are silent efficiency losses requiring workload-aware testing.
- **R78:** Patches that fix one dimension (latency) can regress another (fairness/throughput), so multi-metric evaluation is mandatory.
- **R79:** "Works on my benchmark" is weak evidence; repeated runs and variance reporting are needed.
- **R80:** Locking and scheduling/memory changes interact; subsystem-local optimization can create system-level regressions.
- **R81:** Backports can subtly differ; behavior across kernel versions must be called out as a portability risk.
- **R82:** Stable-branch fixes are strong evidence sources for real-world weakness classes in your topic.
- **R83:** A high-scoring project should include explicit risk register: starvation, deadlock, fairness drift, workload bias.
- **R84:** The best student projects pair an optimization with a safety proof strategy and rollback toggle.

---

## Source Families Consulted

- Kernel documentation (`docs.kernel.org`) for scheduler, lockdep, reclaim, PSI, RT mutexes, cache/TLB behavior
- LKML/lore threads and stable patch discussions for regressions and fixes
- EuroSys/USENIX/ACM-style research papers for empirical evidence and quantified trade-offs
- NVD/CVE and security advisories for vulnerability classes and impact narratives
- LWN and kernel-internals explainers for practical interpretation and historical context

This document is designed for project framing and report citations, not for copying external code.
