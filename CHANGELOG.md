# Changelog

## Unreleased

- **Preview and details panes:** View → Show Preview Pane (Command-Option-P) keeps a
  Quick Look preview beside the file list, following the selection. View → Show
  Details Pane (Command-Option-I) shows Kind, Size, Created, Modified, Where, and
  Tags for one item, or item count and total size for many. The footer shows the
  selected total size (capped at 500 items; larger selections show the count only).
- **Sidebar highlight:** browsing a subfolder highlights its nearest sidebar row.
- **Familiar navigation:** a toolbar up button and Backspace open the enclosing
  folder; Edit → Invert Selection swaps the selection for the unselected items.

## 0.4.3 — 2026-10-10

- **Faster folder loading:** bulk metadata reads are ~14× faster for regular files and ~36× faster for APFS subfolders; subfolder listing plus sorting is ~8× faster.
- **Faster sorting:** reuse filename order after metadata refreshes (~15×) and reverse valid cached order when changing direction (~21–71×).
- **Faster selection:** indexed row lookups make sparse selection updates ~1,700× faster in large folders.
- **Faster bulk-action UI updates:** batch trash removals (~397×) and index move/copy updates (~657×/~345×), preserving operation order and failure reconciliation.
- **Less main-thread work:** stop prefetch discovery after three folders; measured post-load work is ~16× faster.

Benchmarks use release builds and 10,000–30,000-entry fixtures. Figures compare individual stages with their previous implementations; they are not whole-app or disk-transfer speedups. Filesystem measurements use warm local caches. Verified with 109 passing tests.

## 0.4.2

- Reduced combined icon and thumbnail cache budgets by 75%, bounded image decoding resolution, and released offscreen images sooner.
