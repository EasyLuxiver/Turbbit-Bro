#!/usr/bin/env python3
"""Phase Q / §七-6：食物遭遇“首次可见 → 碰撞”预警审计（最坏情况）。

读 `scripts/systems/level_data.gd` 的 GROUPS / BOOST_LANES / 池宽，按真实物理
（accel 420 / 300、1.15× 加速、60 Hz）积分，算每段遭遇的预警时间：
  - 巡航段：首次可见 → 食物
  - 加速段：食物 → 障碍
  - 若上一组障碍也是食物遭遇且相隔够近，前半段按上一段加速的尾巴继续算。
最坏抽法宽度取自 SNACK_DRAW_POOL 里各种类的自然宽。

用法：
  python docs/reports/longrun/phase-q-warning-audit.py

不是游戏运行时探针，是设计值核算；游戏内实测见 PHASE-P-ZONES.md。
"""
import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = (ROOT / "scripts/systems/level_data.gd").read_text(encoding="utf-8")

KIND_W = {
    "LOW_BIRD": 120, "LOW_BEAM": 170, "SURFACE_ROCK": 120,
    "SHARK": 70, "DIVE_GATE": 180, "FLOATING_LOG": 32, "HIGH_WALL": 30,
}
ZONE_V = {1: 220.0, 2: 240.0, 3: 260.0}
SNACK_LEAD = 450.0
BOOST_SCALE = 1.15
BOOST_TAIL = 180.0
SIGHT = 1100.0
STEP = 1.0 / 60.0


def parse_array(name):
    block = SRC.split("const %s := [" % name, 1)[1].split("\n]", 1)[0]
    out = []
    for line in block.splitlines():
        line = line.strip()
        if line.startswith("{"):
            out.append(ast.literal_eval(line.rstrip(",")))
    return out


def parse_lanes():
    block = SRC.split("const BOOST_LANES := [", 1)[1].split("\n]", 1)[0]
    return [tuple(float(p) for p in m.split(","))
            for m in re.findall(r"Rect2\(([-\d.,\s]+)\)", block)]


groups = parse_array("GROUPS")
# --legacy：把 Phase Q 移过的组放回旧坐标，复现“改前”的最坏预警（3.83 s）。
LEGACY_X = {"beam8": 54620.0, "rock10": 55800.0, "log7": 57270.0,
            "bird8": 58410.0, "shark9": 59540.0, "beam9": 60610.0,
            "rock11": 61780.0, "gate8": 62930.0, "log8": 64460.0}
if "--legacy" in sys.argv:
    for g in groups:
        if g["group"] in LEGACY_X:
            g["x"] = LEGACY_X[g["group"]]
lanes = parse_lanes()
pool_block = SRC.split("const SNACK_DRAW_POOL := {", 1)[1].split("\n}", 1)[0]
pools = {}
for z, kinds in re.findall(r"(\d+):\s*\[([^\]]*)\]", pool_block):
    pools[int(z)] = re.findall(r'"([A-Z_]+)"', kinds)

width = {}
for g in groups:
    width[g["group"]] = float(g.get("w", KIND_W[g["kind"]]))

encounters = []
for (lx, ly, lw, lh) in lanes:
    idx = next(i for i, g in enumerate(groups) if g["x"] > lx)
    g = groups[idx]
    food = min(max(g["x"] - SNACK_LEAD, lx), lx + lw)
    encounters.append({"index": idx, "group": g, "food": food,
                       "zone": g["zone"], "v": ZONE_V[g["zone"]]})


def simulate(start_x, obs_x, v, boosts):
    x, speed, t = float(start_x), float(v), 0.0
    while x < obs_x and t < 60.0:
        boosting = any(a <= x < u for a, u in boosts)
        target = v * BOOST_SCALE if boosting else v
        accel = 420.0 if target > speed else 300.0
        d = target - speed
        speed += max(-accel * STEP, min(accel * STEP, d))
        x += speed * STEP
        t += STEP
    return t


worst = []
for k, e in enumerate(encounters):
    g = e["group"]
    v = e["v"]
    vis = g["x"] - SIGHT
    # 本段自己的加速：食物 → 本组尾端 + 尾巴；最坏抽法宽度
    kinds = pools.get(int(e["zone"]), [g["kind"]])
    own_end = g["x"] + max(max(KIND_W[k2] for k2 in kinds), width[g["group"]])
    boosts = [(e["food"], own_end + BOOST_TAIL)]
    # 上一组就是上一段遭遇的障碍：它的加速尾巴可能还没结束
    if k > 0 and encounters[k - 1]["index"] == e["index"] - 1:
        p = encounters[k - 1]
        p_end = p["group"]["x"] + max(
            max(KIND_W[k2] for k2 in pools.get(int(p["zone"]), [])),
            width[p["group"]["group"]])
        boosts.append((p["food"], p_end + BOOST_TAIL))
    t = simulate(vis, g["x"], v, boosts)
    worst.append((k + 1, g["group"], v, t))

print("SEED-INDEPENDENT / design audit (worst-case drawn widths)")
print("id group      zone_v  warning_s  verdict")
bad = 0
for i, name, v, t in worst:
    ok = t >= 4.0
    bad += 0 if ok else 1
    print("%2d %-9s %5.0f   %.3f     %s" % (i, name, v, t, "PASS" if ok else "FAIL"))
print("MIN %.3f s   FAILS %d" % (min(t for _, _, _, t in worst), bad))
print("complex>=5s at Z3 ceiling: %.3f s (1100 px / 260 px/s)" % (SIGHT / 260.0))
sys.exit(0 if bad == 0 else 1)
