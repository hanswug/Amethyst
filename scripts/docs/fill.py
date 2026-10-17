"""Writes docs/layouts.md and docs/my-setup.md from their templates, each {{name}} replaced by that diagram from diagrams.py.

Edit the templates (text) or diagrams.py (pictures), never the pages themselves. Run: python3 -I scripts/docs/fill.py
"""
import re, subprocess, sys, pathlib
here = pathlib.Path(__file__).parent
out = subprocess.run([sys.executable, "-I", str(here / "diagrams.py")], capture_output=True, text=True, check=True).stdout
blocks = dict(re.findall(r"## (\S+)\n(```\n.*?\n```)", out, re.S))
used = set()
for template_name, page in [("layouts.template.md", "layouts.md"), ("my-setup.template.md", "my-setup.md")]:
    template = (here / template_name).read_text()
    names = set(re.findall(r"\{\{(\S+?)\}\}", template))
    missing = names - blocks.keys()
    assert not missing, missing
    used |= names
    doc = re.sub(r"\{\{(\S+?)\}\}", lambda m: blocks[m.group(1)], template)
    (here.parent.parent / "docs" / page).write_text(doc)
print("unused:", sorted(blocks.keys() - used))
