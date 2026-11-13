"""从自动驾驶日志里抽出每个下沉门的通过数据（QC 标准 2 用）。

用法: python tools/parse_gates.py /tmp/pd.txt
输出: 每个门的 墙前换人点 y / 门内最深 y / 出墙 y / 出墙时乌龟计时 / 事故
"""
import re
import sys

SWITCH = re.compile(
    r"GATE\s+switch t=([\d.]+) x=(\d+) gate=(\d+)-(\d+) tur=([\d.]+) rab=([\d.]+) y=(\d+)")
STEP = re.compile(r"GATE\s+t=([\d.]+) x=(\d+) y=(\d+) daze=([\d.]+) ctl=(\w+) st=(\w+)")
EXIT = re.compile(r"GATE\s+exit t=([\d.]+) x=(\d+) daze=([\d.]+) y=(\d+) acc=(\w+)")
RET = re.compile(r"GATE\s+return t=([\d.]+) x=(\d+) tur=([\d.]+) y=(\d+)")


def main(path: str) -> None:
    cur = None
    rows = []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = SWITCH.search(line)
        if m:
            cur = {
                "switch_t": float(m.group(1)),
                "switch_x": int(m.group(2)), "wall": f"{m.group(3)}-{m.group(4)}",
                "tur0": float(m.group(5)), "rab0": float(m.group(6)),
                "y0": int(m.group(7)), "max_y": int(m.group(7)), "exit": None,
                "ret": None,
            }
            continue
        if cur is None:
            continue
        m = STEP.search(line)
        if m:
            cur["max_y"] = max(cur["max_y"], int(m.group(3)))
            continue
        m = EXIT.search(line)
        if m:
            cur["exit"] = {
                "t": float(m.group(1)), "x": int(m.group(2)),
                "daze": float(m.group(3)), "y": int(m.group(4)),
                "acc": m.group(5),
            }
            continue
        m = RET.search(line)
        if m:
            cur["ret"] = {"t": float(m.group(1)), "x": int(m.group(2)),
                          "tur": float(m.group(3)), "y": int(m.group(4))}
            rows.append(cur)
            cur = None
    print("n  wall            switch_t  switch_y  max_y  exit_y  exit_tur  return_t  acc")
    for i, r in enumerate(rows, 1):
        e = r["exit"] or {}
        rt = r["ret"] or {}
        print("%d  %-14s  %8.2f  %8d  %5d  %6s  %8s  %8s  %s" % (
            i, r["wall"], r["switch_t"], r["y0"], r["max_y"], e.get("y", "-"),
            e.get("daze", "-"), rt.get("t", "-"), e.get("acc", "NO_EXIT")))
    bad = [r for r in rows if not r["exit"] or r["exit"]["acc"] != "NONE"]
    print(f"\n{len(rows)} gates, {len(bad)} not clean")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/pd.txt")
