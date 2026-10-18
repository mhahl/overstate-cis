#!/usr/bin/env python3
"""Static lint for formula YAML: Jinja parse, YAML parse, duplicate-key
detection (PyYAML silently keeps the last duplicate, which once hid a
doubled top-level `command:` block from goss until CI).
Usage: check-yaml.py [paths...] (defaults to repo SLS + goss + pillar + workflow)
"""
import glob
import sys

import jinja2
import yaml


class DupError(Exception):
    pass


def check_duplicates(node, path="<root>"):
    if isinstance(node, dict):
        seen = set()
        for k, v in node.items():
            if k in seen:
                raise DupError(f"{path}: duplicate key {k!r}")
            seen.add(k)
            check_duplicates(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            check_duplicates(v, f"{path}[{i}]")


def jinja_neutralize(txt):
    import re

    txt = re.sub(r"\{%.*?%\}", "", txt, flags=re.DOTALL)
    # Unique placeholder per tag: loop-generated state IDs would otherwise
    # all collapse to one key and trip duplicate detection.
    counter = iter(range(1, 10**6))

    def _uniq(_m):
        return f"PLACEHOLDER_{next(counter)}"

    return re.sub(r"\{\{.*?\}\}", _uniq, txt, flags=re.DOTALL)


def main(paths):
    failures = 0
    for p in paths:
        txt = open(p).read()
        if p.endswith((".sls", ".jinja", ".j2")):
            try:
                jinja2.Environment().parse(txt)
            except jinja2.TemplateSyntaxError as e:
                print(f"JINJA FAIL {p}: {e}")
                failures += 1
                continue
            if p.endswith(".jinja") or "templates/" in p:
                # Config-file templates, not YAML — Jinja parse is the check.
                print(f"OK   {p} (jinja)")
                continue
        # SLS Jinja tags and goss skip: templates neutralize to placeholders
        # so the YAML structure (and duplicate keys) can still be checked.
        txt = jinja_neutralize(txt)
        try:
            data = yaml.safe_load(txt)
            check_duplicates(data)
            print(f"OK   {p}")
        except yaml.YAMLError as e:
            print(f"YAML FAIL {p}: {str(e).splitlines()[0]}")
            failures += 1
        except DupError as e:
            print(f"DUP FAIL {p}: {e}")
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    paths = sys.argv[1:] or (
        sorted(glob.glob("*.sls"))
        + sorted(glob.glob("*.jinja"))
        + sorted(glob.glob("templates/*.j2"))
        + ["pillar.example", ".github/workflows/goss.yml"]
        + sorted(glob.glob("tests/goss/*.yaml"))
    )
    sys.exit(main(paths))
