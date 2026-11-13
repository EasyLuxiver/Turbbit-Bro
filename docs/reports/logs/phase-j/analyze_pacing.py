"""Phase J 节奏 / 容差离线分析（只读，不改游戏）。

输入：
  docs/reports/logs/phase-j/groups.json          55 组的 x/w，来自 level_data.GROUPS
  docs/reports/stage4-solution-matrix-*.json     55 组的解法矩阵（最终几何）
  docs/reports/stage4-metrics.json               空档数据（交叉核对）

口径：
  预警距离 WARN_PX = 1100（镜头在 turtle.x+300，1600 宽视口 => 前方可见 1100 px，
  与 Tuning.PROMPT_RANGE 相同）。
  反应预算 = (1100 - 最小通过 lead) / 区速
  输入容差 = (最大通过 lead - 最小通过 lead) / 区速
  恢复时间 = (下一组 start - 本组 end) / 区速
"""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ROOT = os.path.abspath(os.path.join(ROOT, "..", ".."))
WARN_PX = 1100.0
SPEED = {1: 220.0, 2: 240.0, 3: 260.0}


def load():
    with open(os.path.join(ROOT, "docs/reports/logs/phase-j/groups.json"), encoding="utf-8") as f:
        groups = json.load(f)["groups"]
    rows = []
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/reports/stage4-solution-matrix-*.json"))):
        with open(path, encoding="utf-8") as f:
            rows += json.load(f)["matrix"]
    rows.sort(key=lambda r: r["index"])
    assert len(rows) == len(groups) == 55, (len(rows), len(groups))
    for r, g in zip(rows, groups):
        assert r["kind"] == g["kind"], (r["index"], r["kind"], g["kind"])
        r["group"] = g["group"]
        r["start"] = g["start"]
        r["end"] = g["end"]
        r["zone"] = g["zone"]
    return groups, rows


def main():
    groups, rows = load()
    schemes = ["crouch", "jump", "dive", "leap", "dive_jump", "leap_jump"]
    cover = {s: 0 for s in schemes}
    per_group = []
    for r in rows:
        v = SPEED[r["zone"]]
        info = {"group": r["group"], "zone": r["zone"], "kind": r["kind"],
                "design": r["design_answer"], "best": None}
        for s in schemes:
            sch = r["schemes"].get(s)
            if not sch:
                continue
            leads = [t["lead"] for t in sch["trials"] if t.get("passed")]
            if leads:
                cover[s] += 1
                lo, hi = min(leads), max(leads)
                info.setdefault("windows", {})[s] = (lo, hi)
        if "windows" not in info:
            per_group.append(info)
            continue
        # 挑容差最大的方案当"最好解"
        best = max(info["windows"].items(), key=lambda kv: kv[1][1] - kv[1][0])
        info["best"] = best[0]
        info["best_lo"], info["best_hi"] = best[1]
        info["tolerance_s"] = (best[1][1] - best[1][0]) / v
        info["reaction_s"] = (WARN_PX - best[1][0]) / v
        info["min_lead_s"] = best[1][0] / v
        per_group.append(info)

    print("== 方案覆盖（任何通过 lead 都算覆盖，55 组）==")
    for s in schemes:
        print("  %-10s %2d/55  %.0f%%" % (s, cover[s], cover[s] / 55 * 100))
    print("  %-10s %2d/55" % ("no_solution", sum(1 for r in rows if not r["passing_schemes"])))

    print("\n== 反应预算（预警 1100 px 到最晚起手）==")
    rs = sorted(per_group, key=lambda x: x.get("reaction_s", 99))
    for x in rs[:5]:
        print("  %-8s Z%d %-13s best=%-9s lead=%3.0f px  reaction=%.2f s" % (
            x["group"], x["zone"], x["kind"], x["best"], x["best_lo"], x["reaction_s"]))
    print("  min = %.2f s" % rs[0]["reaction_s"])

    print("\n== 输入容差（同一方案能通过的最早到最晚）==")
    ts = sorted(per_group, key=lambda x: x.get("tolerance_s", 99))
    for x in ts[:6]:
        print("  %-8s Z%d %-13s best=%-9s lead %3.0f-%3.0f px  tolerance=%.3f s" % (
            x["group"], x["zone"], x["kind"], x["best"], x["best_lo"], x["best_hi"],
            x["tolerance_s"]))
    print("  min = %.3f s" % ts[0]["tolerance_s"])

    print("\n== 恢复时间（本组结束到下一组开始）==")
    rec = []
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        v = SPEED[b["zone"]]
        rec.append(((b["start"] - a["end"]) / v, a["group"], b["group"], b["zone"]))
    rec.sort()
    for x in rec[:6]:
        print("  %6.2f s  %s -> %s (Z%d)" % x)
    print("  min = %.2f s" % rec[0][0])

    print("\n== 首次教学（首次出现的组，预警 1100 px）==")
    seen = {}
    for g in groups:
        k = g["kind"]
        if k in seen:
            continue
        v = SPEED[g["zone"]]
        seen[k] = (g["group"], g["zone"], WARN_PX / v)
    for k, (grp, z, t) in seen.items():
        print("  %-13s first=%-8s Z%d  %.2f s" % (k, grp, z, t))

    out = {
        "coverage": cover,
        "reaction_min_s": rs[0]["reaction_s"],
        "reaction_min_group": rs[0]["group"],
        "tolerance_min_s": ts[0]["tolerance_s"],
        "tolerance_min_group": ts[0]["group"],
        "recovery_min_s": rec[0][0],
        "recovery_min_pair": [rec[0][1], rec[0][2]],
        "lesson": {k: v[2] for k, v in seen.items()},
        "per_group": [{k: v for k, v in x.items() if k != "windows"} for x in per_group],
    }
    path = os.path.join(ROOT, "docs/reports/logs/phase-j/pacing.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("\n-> %s" % path)


if __name__ == "__main__":
    main()
