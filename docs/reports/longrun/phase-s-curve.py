#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PHASE S §七-8：从仓库内固定数据重算三区难度曲线。

不跑 Godot；只读：
  scripts/systems/level_data.gd            —— 组表、区速、种子抽取池
  docs/reports/stage4-tolerance-scan-fine-*.json —— 5 px 细扫窗口
  docs/reports/longrun/phase-e-combo-windows.phaseh-after.json —— 连招二维网格（基速）
  docs/reports/longrun/phase-n-*-x115.json —— 连招二维网格（×1.15）
输出：docs/reports/longrun/phase-s-difficulty-curve.json
"""

import io
import json
import os
import re
import statistics

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "docs/reports/longrun/phase-s-difficulty-curve.json")

LEVEL = os.path.join(ROOT, "scripts/systems/level_data.gd")
SCAN = "docs/reports/stage4-tolerance-scan-fine-%s.json"
COMBO_BASE = "docs/reports/longrun/phase-e-combo-windows.phaseh-after.json"
COMBO_X115 = {
    "log": "docs/reports/longrun/phase-n-log5-x115.json",
    "wall": "docs/reports/longrun/phase-n-wall3-x115-wide.json",
}

COMBO_KINDS = {"FLOATING_LOG", "HIGH_WALL"}
SWITCH_KINDS = {"SHARK", "DIVE_GATE", "FLOATING_LOG", "HIGH_WALL"}
VISIBLE_PX = 1100.0


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


def load_json(path):
    with io.open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return json.load(f)


def parse_level():
    src = read(LEVEL)
    groups = []
    for m in re.finditer(
        r'\{"group": "(\w+)", "zone": (\d), "kind": "(\w+)", "x": ([\d.]+), "w": ([\d.]+)\}',
        src,
    ):
        groups.append(
            {
                "group": m.group(1),
                "zone": int(m.group(2)),
                "kind": m.group(3),
                "x": float(m.group(4)),
                "w": float(m.group(5)),
            }
        )
    zones = []
    for m in re.finditer(
        r'"id": (\d), "name": "[^"]+", "start": ([\d.]+), "end": ([\d.]+|WORLD_END),\s*'
        r'"base_speed": ([\d.]+)',
        src,
    ):
        end_raw = m.group(3)
        zones.append(
            {
                "id": int(m.group(1)),
                "start": float(m.group(2)),
                "end": 67600.0 if end_raw == "WORLD_END" else float(end_raw),
                "base_speed": float(m.group(4)),
            }
        )
    return groups, zones


def fine_window(name, speed, scale=1.0):
    path = SCAN % (name + ("-x1.15" if scale != 1.0 else ""))
    d = load_json(path)["rows"][0]
    passing = [x for x in d["leads"] if x in d["passing_leads"]]
    lo, hi = min(passing), max(passing)
    px = hi - lo
    return {
        "file": path,
        "group": d["group"],
        "kind": d["kind"],
        "zone": d.get("zone"),
        "lead_px": [lo, hi],
        "window_px": px,
        "speed": speed * scale,
        "window_s": round(px / (speed * scale), 3),
        "scan_cap": hi >= max(d["leads"]) - 1e-6,
    }


def combo_grid(path):
    d = load_json(path)
    out = []
    for c in d["cases"]:
        cells = c["cells"]
        passed = [x for x in cells if x["passed"]]
        if not passed:
            continue
        leads = sorted({x["lead"] for x in passed})
        best = 0.0
        best_delay = None
        best_lead = None
        for lead in sorted({x["lead"] for x in cells}):
            ds = sorted({x["delay"] for x in cells if x["lead"] == lead and x["passed"]})
            if ds and (max(ds) - min(ds)) > best:
                best, best_delay, best_lead = max(ds) - min(ds), [min(ds), max(ds)], lead
        speed = float(c["base_speed"])
        out.append(
            {
                "group": c.get("group"),
                "kind": c.get("kind"),
                "speed": speed,
                "lead_px": [min(leads), max(leads)],
                "first_stage_s": round((max(leads) - min(leads)) / speed, 3),
                "delay_s": best_delay,
                "best_delay_lead": best_lead,
                "passes": len(passed),
                "cells": len(cells),
            }
        )
    return out


def zone_stats(groups, zone):
    z = [g for g in groups if g["zone"] == zone["id"]]
    speed = zone["base_speed"]
    gaps = []
    prev = None
    for g in z:
        if prev is not None:
            px = g["x"] - (prev["x"] + prev["w"])
            gaps.append(
                {
                    "from": prev["group"],
                    "to": g["group"],
                    "px": round(px, 1),
                    "s": round(px / speed, 2),
                }
            )
        prev = g
    kinds = {}
    for g in z:
        kinds[g["kind"]] = kinds.get(g["kind"], 0) + 1
    combos = [g["group"] for g in z if g["kind"] in COMBO_KINDS]
    switches = [g["group"] for g in z if g["kind"] in SWITCH_KINDS]
    # 空档：区起点→第一组、组间、最后一组→区终点
    empty = [{"from": "ZONE_START", "to": z[0]["group"],
              "px": round(z[0]["x"] - zone["start"], 1),
              "s": round((z[0]["x"] - zone["start"]) / speed, 2)}]
    empty += gaps
    empty.append({"from": z[-1]["group"], "to": "ZONE_END",
                  "px": round(zone["end"] - (z[-1]["x"] + z[-1]["w"]), 1),
                  "s": round((zone["end"] - (z[-1]["x"] + z[-1]["w"])) / speed, 2)})
    worst = max(empty, key=lambda e: e["s"])
    gap_s = [g["s"] for g in gaps]
    combo_gaps = []
    prev = None
    for g in z:
        if prev is not None and g["kind"] in COMBO_KINDS:
            px = g["x"] - (prev["x"] + prev["w"])
            combo_gaps.append({"group": g["group"], "kind": g["kind"],
                               "px": round(px, 1), "s": round(px / speed, 2)})
        prev = g
    return {
        "id": zone["id"],
        "start": zone["start"],
        "end": zone["end"],
        "base_speed": speed,
        "groups": len(z),
        "kinds": kinds,
        "combo_groups": combos,
        "combo_count": len(combos),
        "combo_share": round(len(combos) / len(z), 3),
        "switch_groups": switches,
        "switch_count": len(switches),
        "switch_share": round(len(switches) / len(z), 3),
        "density_groups_per_min": round(len(z) / ((zone["end"] - zone["start"]) / speed) * 60, 1),
        "gap_s": {
            "min": min(gap_s),
            "median": round(statistics.median(gap_s), 2),
            "max": max(gap_s),
            "min_pair": f'{next(g["from"] for g in gaps if g["s"] == min(gap_s))}'
                        f'->{next(g["to"] for g in gaps if g["s"] == min(gap_s))}',
            "max_pair": f'{next(g["from"] for g in gaps if g["s"] == max(gap_s))}'
                        f'->{next(g["to"] for g in gaps if g["s"] == max(gap_s))}',
        },
        "combo_prep_gap_s": combo_gaps,
        "longest_empty": {"s": worst["s"], "at": f'{worst["from"]}->{worst["to"]}',
                          "px": worst["px"]},
        "empty_stretches": empty,
        "visibility_s": round(VISIBLE_PX / speed, 2),
        "gaps": gaps,
    }


def main():
    groups, zones = parse_level()
    zmap = {z["id"]: z for z in zones}
    out = {
        "generated_at": "2026-11-12",
        "note": "PHASE S 三区难度曲线重算；只读 level_data.gd 与已测扫描文件，不跑游戏。",
        "visible_px": VISIBLE_PX,
        "zone_speed": {str(k): v["base_speed"] for k, v in zmap.items()},
        "groups_total": len(groups),
        "zones": {str(z["id"]): zone_stats(groups, z) for z in zones},
        "windows_base": {},
        "windows_boost": {},
        "combo_base": {},
        "combo_boost": {},
    }

    # 单动作 5 px 细扫（基速）
    for zone_id, names in {
        1: ["beam1", "bird1", "gate1", "rock1", "shark1"],
        2: ["rock4", "shark3"],
        3: ["rock8", "shark8"],
    }.items():
        speed = zmap[zone_id]["base_speed"]
        out["windows_base"][str(zone_id)] = {n: fine_window(n, speed) for n in names}
    # 加速 ×1.15 代表组
    out["windows_boost"]["1"] = {
        "beam1": fine_window("beam1", 220.0, 1.15),
        "bird1": fine_window("bird1", 220.0, 1.15),
        "gate1": fine_window("gate1", 220.0, 1.15),
        "rock1": fine_window("rock1", 220.0, 1.15),
    }
    out["windows_boost"]["2"] = {
        "rock4": fine_window("rock4", 240.0, 1.15),
    }
    out["windows_boost"]["3"] = {
        "rock8": fine_window("rock8", 260.0, 1.15),
        "shark8": fine_window("shark8", 260.0, 1.15),
    }

    # 连招 2D 网格
    base = combo_grid(COMBO_BASE)
    for c in base:
        z = 1 if c["group"] in ("log1", "wall1") else 2 if c["group"] in ("log3", "wall2", "log2") else 3
        out["combo_base"].setdefault(str(z), []).append(c)
    for key, path in COMBO_X115.items():
        for c in combo_grid(path):
            out["combo_boost"].setdefault(c["group"], []).append(c)

    # 首食 / 随机池
    out["first_food"] = {
        "encounter": 1,
        "group": "beam1",
        "kind": "LOW_BEAM",
        "answer": "crouch（按住 ↓，整段接近都能过）",
        "fixed": True,
        "boost_speed": 253.0,
        "warning_s": 4.75,
        "base_window": out["windows_base"]["1"]["beam1"]["window_s"],
        "boost_window": out["windows_boost"]["1"]["beam1"]["window_s"],
        "draw_log": "docs/reports/logs/phase-p/draw-after-q.log",
        "zone_probe": "docs/reports/logs/phase-p/zones-after-q.log",
    }
    out["random_pool"] = {
        "Z1": ["LOW_BIRD", "LOW_BEAM", "SURFACE_ROCK"],
        "Z2": ["DIVE_GATE", "SHARK"],
        "Z3": ["SURFACE_ROCK", "LOW_BEAM", "SHARK"],
        "excluded_complex": ["FLOATING_LOG", "HIGH_WALL"],
        "seeds": {
            "20261112": "docs/reports/logs/phase-p/zones-after-q.log",
            "424242": "docs/reports/logs/phase-p/zones-seed424242-after-q.log",
        },
    }
    out["warning"] = {
        "min_boost_s": 4.017,
        "min_boost_at": "shark8/beam8/shark9/gate8 (Z3)",
        "z3_sight_cap_s": round(VISIBLE_PX / 260.0, 3),
        "log": "docs/reports/logs/phase-p/warning-audit-after-q.log",
    }
    with io.open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    # 终端摘要
    print("PHASE S curve ->", OUT)
    for zid in ("1", "2", "3"):
        z = out["zones"][zid]
        print(
            "Z%s speed=%d groups=%d density=%.1f/min combos=%d(%.0f%%) switches=%d(%.0f%%) "
            "gap min/med/max=%.2f/%.2f/%.2f longest_empty=%.2f@%s"
            % (
                zid, z["base_speed"], z["groups"], z["density_groups_per_min"],
                z["combo_count"], z["combo_share"] * 100,
                z["switch_count"], z["switch_share"] * 100,
                z["gap_s"]["min"], z["gap_s"]["median"], z["gap_s"]["max"],
                z["longest_empty"]["s"], z["longest_empty"]["at"],
            )
        )
    print("-- 单动作基速窗口（s）")
    for zid, ws in out["windows_base"].items():
        print("  Z%s" % zid, ", ".join("%s %.3f" % (k, v["window_s"]) for k, v in ws.items()))
    print("-- 单动作 ×1.15 窗口（s）")
    for zid, ws in out["windows_boost"].items():
        print("  Z%s" % zid, ", ".join("%s %.3f" % (k, v["window_s"]) for k, v in ws.items()))
    print("-- 连招基速 / ×1.15（第一段 s，第二段 delay s）")
    for zid, cs in out["combo_base"].items():
        for c in cs:
            print("  Z%s %s first=%.3f delay=%s" % (zid, c["group"], c["first_stage_s"], c["delay_s"]))
    for g, cs in out["combo_boost"].items():
        for c in cs:
            print("  boost %s first=%.3f delay=%s" % (g, c["first_stage_s"], c["delay_s"]))


if __name__ == "__main__":
    main()
