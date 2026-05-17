# Component Identification — PressurePause (v6.8.12)

Kernel version: **v6.8.12** (see [kernel-tag.txt](kernel-tag.txt))

Build and boot screenshots are in the project report ([Report.tex](../Report.tex), Section 3).

## Selected component

| Item | Detail |
|------|--------|
| Course category | Page replacement / reclaim |
| Primary files | `mm/page_alloc.c`, `mm/vmscan.c` |
| PSI context | `kernel/sched/psi.c`, `include/linux/psi_types.h` |
| Planned hook | `do_try_to_free_pages()` in `mm/vmscan.c`, line **6188**, before the `shrink_zones()` priority loop |

## Problem

When RAM is tight, allocating threads enter **direct reclaim** and evict pages synchronously. Under coordinated thrash, many threads reclaim in parallel; evicted pages are immediately refaulted. Direct reclaim lacks a cheap system-wide “we are thrashing together” signal to coordinate with **kswapd**.

## Call graph (allocating thread → reclaim)

```
__alloc_pages_slowpath          mm/page_alloc.c ~4040
  → wake_all_kswapds            mm/page_alloc.c ~3814
  → __alloc_pages_direct_reclaim mm/page_alloc.c ~3781
    → psi_memstall_enter
    → __perform_reclaim         mm/page_alloc.c ~3755
      → try_to_free_pages       mm/vmscan.c ~6406
        → do_try_to_free_pages  mm/vmscan.c ~6188  ← HOOK
          → shrink_zones        mm/vmscan.c ~6065
            → shrink_node       mm/vmscan.c ~5881
              → LRU shrink / swap
```

## Key code excerpts

### `__perform_reclaim` → `try_to_free_pages` (`mm/page_alloc.c`, lines 3753–3770)

```c
progress = try_to_free_pages(ac->zonelist, order, gfp_mask,
                           ac->nodemask);
```

### `try_to_free_pages` → `do_try_to_free_pages` (`mm/vmscan.c`, lines 6406–6446)

```c
trace_mm_vmscan_direct_reclaim_begin(order, sc.gfp_mask);
nr_reclaimed = do_try_to_free_pages(zonelist, &sc);
trace_mm_vmscan_direct_reclaim_end(nr_reclaimed);
```

### Reclaim loop at hook site (`mm/vmscan.c`, lines 6188–6206)

```c
do {
    sc->nr_scanned = 0;
    shrink_zones(zonelist, sc);
    if (sc->nr_reclaimed >= sc->nr_to_reclaim)
        break;
    ...
} while (--sc->priority >= 0);
```

## Watermarks

`get_page_from_freelist()` fails when zone free pages fall below **min**, **low**, or **high** watermarks. The allocator slowpath may wake kswapd, try compaction, then call `__alloc_pages_direct_reclaim()` for synchronous reclaim.

## kswapd vs direct reclaim

| Aspect | Direct reclaim | kswapd |
|--------|----------------|--------|
| Caller | Allocating task (slowpath) | `kswapd` kernel thread (~7078) |
| Entry | `try_to_free_pages` | `balance_pgdat` → `kswapd_shrink_node` |
| Shared core | `shrink_node` | `shrink_node` |
| GFP context | Caller's `gfp_mask` | `GFP_KERNEL` |
| PressurePause hook | Yes (`do_try_to_free_pages`) | No (unless explicitly guarded) |

## PSI (read-only for patch design)

- **Types:** `PSI_MEM_SOME`, `PSI_MEM_FULL` in `include/linux/psi_types.h`
- **Accounting:** `kernel/sched/psi.c`
- **Userspace:** `/proc/pressure/memory` — **`full`** indicates system-wide memory stall with no productive runners
- **Note:** `psi_memstall_enter` in `__alloc_pages_direct_reclaim` marks the *current task* during reclaim; the patch will read *system* memory PSI averages to gate coordination

## Hook justification

`shrink_node()` is used by both kswapd and direct reclaim. Hooking at `do_try_to_free_pages()` limits changes to the allocating-thread path. Hooking at `shrink_node()` alone would require `!current_is_kswapd()` guards.

## Optional future screenshots

- Editor view of `do_try_to_free_pages` in `vmscan.c`
- `grep` / `cscope` call chain
- `/proc/pressure/memory` under `stress-ng` load
