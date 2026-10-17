"""Writes docs/layouts.md: layouts.template.md with each {{name}} replaced by that diagram from diagrams.py.

Edit the template (text) or diagrams.py (pictures), never docs/layouts.md itself. Run: python3 -I scripts/docs/fill.py
"""
import re, subprocess, sys, pathlib
here = pathlib.Path(__file__).parent
out = subprocess.run([sys.executable, "-I", str(here / "diagrams.py")], capture_output=True, text=True, check=True).stdout
blocks = dict(re.findall(r"## (\S+)\n(```\n.*?\n```)", out, re.S))
template = (here / "layouts.template.md").read_text()
used = set(re.findall(r"\{\{(\S+?)\}\}", template))
missing = used - blocks.keys()
assert not missing, missing
doc = re.sub(r"\{\{(\S+?)\}\}", lambda m: blocks[m.group(1)], template)
(here.parent.parent / "docs" / "layouts.md").write_text(doc)
print("unused:", sorted(blocks.keys() - used))
