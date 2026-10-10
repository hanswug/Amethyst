#!/usr/bin/env python3
"""Summarise an xctrace time-profile XML export.

Usage: analyze-time-profile.py <time-profile.xml> [potential-hangs.xml]
"""
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict


def load(path):
    tree = ET.parse(path)
    ids = {}
    for el in tree.iter():
        if "id" in el.attrib:
            ids[el.attrib["id"]] = el
    return tree, ids


def resolve(el, ids):
    if el is not None and "ref" in el.attrib:
        return ids[el.attrib["ref"]]
    return el


def frames_of(row, ids):
    bt = None
    for child in row:
        if child.tag in ("tagged-backtrace", "backtrace"):
            bt = resolve(child, ids)
            break
    if bt is None:
        return []
    if bt.tag == "tagged-backtrace" and bt.find("backtrace") is not None:
        bt = resolve(bt.find("backtrace"), ids)
    out = []
    for fr in bt.findall("frame"):
        fr = resolve(fr, ids)
        name = fr.attrib.get("name", fr.attrib.get("addr", "?"))
        binary = resolve(fr.find("binary"), ids)
        bname = binary.attrib.get("name", "?") if binary is not None else "?"
        out.append((name, bname))
    return out  # leaf first


def main():
    tree, ids = load(sys.argv[1])
    rows = tree.findall(".//row")
    total = 0
    by_thread = Counter()
    by_state = Counter()
    self_time = Counter()
    incl_app = Counter()
    incl_any = Counter()
    by_minute = Counter()
    first_ns = None
    for row in rows:
        w = resolve(row.find("weight"), ids)
        ns = int(w.text) if w is not None and w.text else 1_000_000
        total += ns
        th = resolve(row.find("thread"), ids)
        tname = th.attrib.get("fmt", "?") if th is not None else "?"
        by_thread["Main Thread" if tname.startswith("Main Thread") else tname.split(" 0x")[0]] += ns
        st = resolve(row.find("thread-state"), ids)
        if st is not None:
            by_state[st.attrib.get("fmt", st.text)] += ns
        t = resolve(row.find("sample-time"), ids)
        if t is not None and t.text:
            tns = int(t.text)
            first_ns = tns if first_ns is None else min(first_ns, tns)
            by_minute[tns] += ns
        frames = frames_of(row, ids)
        if frames:
            self_time[f"{frames[0][0]}  [{frames[0][1]}]"] += ns
        seen = set()
        for name, binary in frames:
            if name in seen:
                continue
            seen.add(name)
            incl_any[name] += ns
            if binary == "Amethyst":
                incl_app[name] += ns

    ms = lambda ns: ns / 1e6
    print(f"samples: {len(rows)}  total CPU: {ms(total):.0f} ms")
    print("\n== CPU by thread ==")
    for k, v in by_thread.most_common(10):
        print(f"{ms(v):9.0f} ms  {100*v/total:5.1f}%  {k}")
    if by_state:
        print("\n== by thread state ==")
        for k, v in by_state.most_common():
            print(f"{ms(v):9.0f} ms  {k}")
    print("\n== CPU per minute of recording ==")
    per_min = Counter()
    for tns, v in by_minute.items():
        per_min[(tns - first_ns) // 60_000_000_000] += v
    for m in sorted(per_min):
        print(f"min {m:2d}: {ms(per_min[m]):7.0f} ms")
    print("\n== top self time (leaf frames) ==")
    for k, v in self_time.most_common(25):
        print(f"{ms(v):9.0f} ms  {100*v/total:5.1f}%  {k[:150]}")
    print("\n== top inclusive, Amethyst code ==")
    for k, v in incl_app.most_common(40):
        print(f"{ms(v):9.0f} ms  {100*v/total:5.1f}%  {k[:150]}")
    print("\n== top inclusive, any frame ==")
    for k, v in incl_any.most_common(25):
        print(f"{ms(v):9.0f} ms  {100*v/total:5.1f}%  {k[:150]}")

    if len(sys.argv) > 2:
        htree, hids = load(sys.argv[2])
        hrows = htree.findall(".//row")
        print(f"\n== potential hangs: {len(hrows)} ==")
        for row in hrows[:30]:
            print("  " + " | ".join(
                (resolve(c, hids).attrib.get("fmt") or resolve(c, hids).text or "")
                for c in row)[:200])


if __name__ == "__main__":
    main()
