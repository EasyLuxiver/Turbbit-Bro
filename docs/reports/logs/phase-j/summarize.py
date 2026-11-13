"""Phase J 汇总：把四份数据合成验收标准 1–5 需要的数。

输入：
  logs/phase-j/groups.json                 55 组的 x/w（level_data.GROUPS）
  logs/phase-j/tolerance.json              密扫：每组设计答案方案的 lead 通过区间
  logs/phase-j/pacing.json                 方案覆盖 / 恢复时间
  logs/phase-j/log-windows.json            8 块浮木的二维（lead × delay）窗口
  logs/phase-j/lesson-prompts.json         首次教学提示的触发距离

口径：
  容差 = 同一方案连续可过的 lead 宽度 / 区速。浮木是二维操作（跳 + 下潜），
  一维密扫会把延迟固定死、低估窗口，因此浮木组改用二维扫描的 lead 窗口。
  反应预算 = (1100 - 最早可通过 lead) / 区速；1100 px 是前方可见距离
  （镜头 turtle.x+300，1600 宽视口，与 Tuning.PROMPT_RANGE 相同）。
  恢复时间 = (下一组起点 - 本组终点) / 下一组区速。
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
LOG = os.path.join(ROOT, "docs/reports/logs/phase-j")
SPEED = {1: 220.0, 2: 240.0, 3: 260.0}
WARN_PX = 1100.0
MIN_TOL = 0.15
MIN_REACT = 0.35
MIN_RECOVER = 1.0


def load(name):
    for d in (LOG, os.path.join(ROOT, "docs/reports/longrun")):
        p = os.path.join(d, name)
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                return json.load(f)
    return None


def main():
    groups = load("groups.json")["groups"]
    tol = load("tolerance.json")
    pacing = load("pacing.json")
    combo = load("phase-j-log-windows.json")
    lesson = load("lesson-prompts.json")

    # 直接用密扫原始行（带 passing_leads），不用 tolerance.json 的摘要，
    # 因为摘要里没有“最早可通过 lead”，算不出反应预算。
    import glob
    raw = []
    for p in sorted(glob.glob(os.path.join(ROOT, "docs/reports/stage4-tolerance-scan-*.json"))):
        with open(p, encoding="utf-8") as f:
            raw += json.load(f)["rows"]
    raw.sort(key=lambda r: r["index"])
    by_group = {}
    for r in raw:
        leads = sorted(float(x) for x in r["leads"])
        step = (leads[1] - leads[0]) if len(leads) > 1 else 20.0
        ok = sorted(float(x) for x in r["passing_leads"])
        lo = hi = None
        if ok:
            lo = hi = ok[0]
            best = (ok[0], ok[0])
            for p in ok[1:]:
                if p - hi <= step + 1e-6:
                    hi = p
                else:
                    if hi - lo > best[1] - best[0]:
                        best = (lo, hi)
                    lo = hi = p
            if hi - lo > best[1] - best[0]:
                best = (lo, hi)
            lo, hi = best
        by_group[r["group"]] = {
            "group": r["group"], "kind": r["kind"], "scheme": r["design_answer"],
            "zone": r["zone"], "source": "dense 1D (%.0f px step)" % step,
            "tolerance_s": round((hi - lo) / SPEED[r["zone"]], 3) if ok else 0.0,
            "lead_first": lo, "lead_last": hi,
            "min_pass_lead": ok[0] if ok else None,
            "window": ("%.0f..%.0f px" % (lo, hi)) if ok else "NO PASS",
        }

    # 高墙的连招窗口在 Phase H 已经二维扫过；几何自那以后没动，可直接复用。
    hwall = load("phase-e-combo-windows.phaseh-after.json")
    if hwall:
        combo = dict(combo or {"cases": []})
        combo["cases"] = list(combo.get("cases", [])) + [
            c for c in hwall["cases"] if c["kind"] == "HIGH_WALL"]

    if combo:
        for c in combo["cases"]:
            g = c["group"]
            s = c["summary"]
            if g not in by_group:
                continue
            # 只用“至少一个 delay 能过”的 lead，并取最长连续段（防止稀疏点夸大窗口）
            ok_leads = sorted(float(row["lead"]) for row in c["leads"]
                              if int(row["pass_count"]) > 0)
            step = float(c["lead_range"][2])
            best = (0.0, 0.0)
            if ok_leads:
                lo = hi = ok_leads[0]
                for l in ok_leads[1:]:
                    if l - hi <= step + 1e-6:
                        hi = l
                    else:
                        if hi - lo > best[1] - best[0]:
                            best = (lo, hi)
                        lo = hi = l
                if hi - lo > best[1] - best[0]:
                    best = (lo, hi)
            v = float(c["base_speed"])
            by_group[g]["tolerance_s"] = round((best[1] - best[0]) / v, 3)
            by_group[g]["delay_window_s"] = round(float(s["best_delay_window_s"]), 3)
            by_group[g]["best_lead"] = float(s["best_lead"])
            by_group[g]["lead_first"] = best[0]
            by_group[g]["lead_last"] = best[1]
            by_group[g]["min_pass_lead"] = ok_leads[0] if ok_leads else None
            by_group[g]["source"] = "2D lead x delay"
            by_group[g]["window"] = "lead %.0f..%.0f px (step %.0f), delay<=%.2f s" % (
                best[0], best[1], step, float(s["best_delay_window_s"]))

    # ---- 1/2: 反应预算 & 输入容差 ----
    per = []
    for g in groups:
        name = g["group"]
        r = by_group.get(name)
        if not r:
            continue
        v = SPEED[g["zone"]]
        # 反应预算看“最晚还能起手”的那一档：通过点里最小的 lead。
        # 二维扫描没有逐档通过了，用 lead_first 当保守近似。
        lo = r.get("min_pass_lead")
        if lo is None:
            lo = r.get("lead_first") if r.get("lead_first") is not None else 0.0
        react = (WARN_PX - float(lo)) / v
        per.append({
            "group": name, "zone": g["zone"], "kind": g["kind"],
            "scheme": r["scheme"], "source": r["source"],
            "tolerance_s": float(r["tolerance_s"]),
            "reaction_s": round(react, 2),
            "window": r.get("window", ""),
        })

    tight_tol = min(per, key=lambda x: x["tolerance_s"])
    tight_react = min(per, key=lambda x: x["reaction_s"])
    under_tol = [x for x in per if x["tolerance_s"] < MIN_TOL]
    under_react = [x for x in per if x["reaction_s"] < MIN_REACT]

    # ---- 3: 恢复时间 ----
    rec = []
    for i in range(len(groups) - 1):
        a, b = groups[i], groups[i + 1]
        v = SPEED[b["zone"]]
        rec.append({
            "gap_s": round((b["start"] - a["end"]) / v, 2),
            "from": a["group"], "to": b["group"], "zone": b["zone"],
        })
    rec.sort(key=lambda x: x["gap_s"])
    under_rec = [x for x in rec if x["gap_s"] < MIN_RECOVER]
    gap_max = max(rec, key=lambda x: x["gap_s"])

    # ---- 4: 首次教学 ----
    lessons = []
    if lesson:
        lessons = lesson["records"]
    bad_lessons = [r for r in lessons if float(r["seconds_to_obstacle"]) < 1.0]
    kinds_total = len(lesson["first_of_kind"]) if lesson else 0

    # ---- 5: 方案覆盖 ----
    cover = pacing["coverage"] if pacing else {}

    out = {
        "min_tolerance": tight_tol,
        "groups_under_0_15": under_tol,
        "min_reaction": tight_react,
        "groups_under_0_35": under_react,
        "min_recovery": rec[0],
        "max_gap": gap_max,
        "pairs_under_1_0": under_rec,
        "lessons": lessons,
        "lessons_under_1_0": bad_lessons,
        "kinds_taught": len(lessons),
        "kinds_total": kinds_total,
        "coverage": cover,
        "max_scheme_coverage": max(cover.values()) if cover else None,
        "per_group": per,
    }
    path = os.path.join(LOG, "phase-j-summary.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    print("== 2 输入容差 ==")
    print("  最小 %.3f s  %s %s (%s) %s" % (
        tight_tol["tolerance_s"], tight_tol["group"], tight_tol["kind"],
        tight_tol["scheme"], tight_tol["source"]))
    print("  <%.2f s 的组数 = %d  %s" % (
        MIN_TOL, len(under_tol), [x["group"] for x in under_tol]))
    print("== 1 反应预算 ==")
    print("  最小 %.2f s  %s %s" % (
        tight_react["reaction_s"], tight_react["group"], tight_react["kind"]))
    print("  <%.2f s 的组数 = %d  %s" % (
        MIN_REACT, len(under_react), [x["group"] for x in under_react]))
    print("== 3 恢复时间 ==")
    print("  最小 %.2f s  %s -> %s (Z%d)" % (
        rec[0]["gap_s"], rec[0]["from"], rec[0]["to"], rec[0]["zone"]))
    print("  <%.1f s 的空档 = %d；最长空档 %.2f s %s -> %s" % (
        MIN_RECOVER, len(under_rec), gap_max["gap_s"], gap_max["from"], gap_max["to"]))
    print("== 4 首次教学 ==")
    print("  教到 %d/%d 种；<1.0 s 的 = %d" % (len(lessons), kinds_total, len(bad_lessons)))
    for r in lessons:
        print("    %-13s %-8s Z%d  d=%.0f px  %.2f s  emitted=%s" % (
            r["kind"], r["group"], r["zone"], r["distance_px"],
            r["seconds_to_obstacle"], r["prompt_emitted_within_0_1s"]))
    print("== 5 方案覆盖 ==")
    for k in sorted(cover, key=lambda x: -cover[x]):
        print("    %-10s %2d/55" % (k, cover[k]))
    print("  单一方案最大覆盖 = %s/55" % out["max_scheme_coverage"])
    print("\n-> %s" % path)


if __name__ == "__main__":
    main()
