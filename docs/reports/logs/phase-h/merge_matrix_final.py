# 合并 Phase H 最终几何的四片解法矩阵，并与 Phase C 基线逐组比对。
# 用法：python docs/reports/logs/phase-h/merge_matrix_final.py
import json
from pathlib import Path

ROOT = Path(r"D:\GAMESTUDIO\TURBBIT")
REPORTS = ROOT / "docs" / "reports"
SHARDS = ["00-13", "14-27", "28-40", "41-54"]

merged = []
nosol = []
by_kind = {}
for s in SHARDS:
    p = REPORTS / f"stage4-solution-matrix-{s}.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    merged.extend(d["matrix"])
    nosol.extend(d.get("no_solution_groups", []))
    for k, v in (d.get("by_kind") or {}).items():
        by_kind.setdefault(k, set()).update(v if isinstance(v, list) else [])

merged.sort(key=lambda r: r["index"])
base = json.loads((REPORTS / "stage4-solution-matrix.json").read_text(encoding="utf-8"))


def keyed(rows):
    """用 (区, 种类, 该种类在本区的第几个) 作键。
    Phase H 对调了 Z1 的浮木与高墙槽位，index 会变，但种类序号不变，
    这样比较的是“同一个障碍”的新旧解法，而不是同一个数组下标。"""
    seen = {}
    out = {}
    for r in sorted(rows, key=lambda x: x["start"]):
        k = (r["zone"], r["kind"])
        seen[k] = seen.get(k, 0) + 1
        out[(r["zone"], r["kind"], seen[k])] = r
    return out


base_by = keyed(base["matrix"])
merged_by = keyed(merged)
missing = sorted(set(base_by) - set(merged_by))
diffs = []
design_miss = []
for k, r in merged_by.items():
    want = sorted(base_by[k]["passing_schemes"]) if k in base_by else None
    got = sorted(r["passing_schemes"])
    if want != got:
        diffs.append((k, r["index"], want, got))
    if r.get("design_answer") not in r["passing_schemes"]:
        design_miss.append((k, r["index"], r["kind"], r.get("design_answer")))

n = len(merged)
scheme_cover = {s: sum(1 for r in merged if s in r["passing_schemes"]) for s in
                ["jump", "crouch", "dive", "leap", "dive_jump", "leap_jump"]}
solution_counts = {}
for r in merged:
    solution_counts[len(r["passing_schemes"])] = solution_counts.get(len(r["passing_schemes"]), 0) + 1

print(f"merged groups: {n} (baseline {len(base['matrix'])}, missing {missing})")
print(f"no_solution_groups: {sorted(nosol)}")
print(f"design answer missing: {design_miss}")
print(f"passing_schemes diffs vs Phase C baseline: {len(diffs)}")
for d in diffs:
    print("  ", d)
print(f"coverage: {scheme_cover}")
must_shift = [r["index"] for r in merged
              if set(r["passing_schemes"]) and set(r["passing_schemes"]) <= {"dive_jump", "leap_jump"}]
print(f"must SHIFT (only combos pass): {len(must_shift)} -> {must_shift}")
print(f"solutions/group: {solution_counts}")
