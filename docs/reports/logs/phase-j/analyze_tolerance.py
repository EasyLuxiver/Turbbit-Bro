"""Phase J 容差分析：把 stage4_solution_audit --tolerance 的三片 JSON 合并，
算出每组设计答案方案的“连续通过 lead 区间”，换算成人类能按出来的时间窗。

连续通过区间：把通过的 lead 排序，取最长的一段相邻（扫描步长内）区间。
不连续（例如 240 和 120 都能过、中间 200 不能过）会被拆开，只取最长那一段——
宁可低估容差，不夸大。
"""
import glob
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
SPEED = {1: 220.0, 2: 240.0, 3: 260.0}
WARN_PX = 1100.0
FILE_GLOB = "docs/reports/stage4-tolerance-scan-*.json"


def runs(passing, gap):
    """把通过点切成连续段，返回 [(lo, hi, count)]。"""
    if not passing:
        return []
    passing = sorted(passing)
    out = []
    lo = hi = passing[0]
    n = 1
    for p in passing[1:]:
        if p - hi <= gap + 1e-6:
            hi = p
            n += 1
        else:
            out.append((lo, hi, n))
            lo = hi = p
            n = 1
    out.append((lo, hi, n))
    return out


def main():
    rows = []
    for path in sorted(glob.glob(os.path.join(ROOT, FILE_GLOB))):
        with open(path, encoding="utf-8") as f:
            rows += json.load(f)["rows"]
    rows.sort(key=lambda r: r["index"])
    print("rows=%d" % len(rows))
    worst = []
    table = []
    for r in rows:
        v = SPEED[r["zone"]]
        leads = sorted(float(x) for x in r["leads"])
        gap = (leads[1] - leads[0]) if len(leads) > 1 else 20.0
        gap = min(gap, 60.0)
        pass_leads = [float(x) for x in r["passing_leads"]]
        rs = runs(pass_leads, gap)
        if not rs:
            table.append((r["group"], r["kind"], r["design_answer"], 0.0, 0.0, "NO PASS"))
            worst.append((0.0, r["group"], r["kind"]))
            continue
        lo, hi, _ = max(rs, key=lambda x: x[1] - x[0])
        tol = (hi - lo) / v
        react = (WARN_PX - lo) / v
        table.append((r["group"], r["kind"], r["design_answer"], tol, react,
                      "%s..%s px (n=%d, segs=%d)" % (int(lo), int(hi), len(pass_leads), len(rs))))
        worst.append((tol, r["group"], r["kind"]))
    table.sort(key=lambda x: x[3])
    print("\n== 最紧的 12 组（按容差） ==")
    for t in table[:12]:
        print("  %-8s %-13s %-9s tol=%.3f s react=%.2f s  %s" % t)
    print("\n最松的 5 组：")
    for t in table[-5:]:
        print("  %-8s %-13s %-9s tol=%.3f s" % t[:4])
    tight = min(table, key=lambda x: x[3])
    shortest = tight[3]
    print("\n最小容差 = %.3f s（%s %s）" % (shortest, tight[0], tight[1]))
    print("容差 <0.15 s 的组数 = %d" % sum(1 for x in table if x[3] < 0.15))
    print("无解组数 = %d" % sum(1 for x in table if x[4] == 0.0 and "NO PASS" in x[5]))

    by_kind = {}
    for t in table:
        by_kind.setdefault(t[1], []).append(t[3])
    print("\n== 按种类 ==")
    for k in sorted(by_kind):
        v = by_kind[k]
        print("  %-13s n=%2d  tol min=%.3f  median=%.3f" % (
            k, len(v), min(v), sorted(v)[len(v) // 2]))

    out = {"min_tolerance_s": shortest,
           "groups_under_0_15": sum(1 for x in table if x[3] < 0.15),
           "rows": [{"group": t[0], "kind": t[1], "scheme": t[2],
                     "tolerance_s": round(t[3], 3), "reaction_s": round(t[4], 2),
                     "window": t[5]} for t in table]}
    path = os.path.join(ROOT, "docs/reports/logs/phase-j/tolerance.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("\n-> %s" % path)


if __name__ == "__main__":
    main()
