"""Copies the single board source (docs/design/board/board_map.json) into the
Godot project (res://data/board_map.json). Godot cannot read files outside
res:// in an exported app, so the client ships a byte-identical copy; the test
tests/unit/test_board_geometry.gd fails if the copy drifts.

    python client/tools/sync_board_map.py
"""
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
src = ROOT / "docs" / "design" / "board" / "board_map.json"
dst = ROOT / "client" / "data" / "board_map.json"
shutil.copyfile(src, dst)
print(f"copied {src.relative_to(ROOT)} -> {dst.relative_to(ROOT)}")
