"""No Godot engine required: verify project packaging and basic GDScript structure.
Does NOT replace Godot parser or gameplay testing.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
scripts = sorted(ROOT.rglob('*.gd'))
errors = []
for path in scripts:
    text = path.read_text(encoding='utf-8')
    for ref in re.findall(r'res://([^"\n]+)', text):
        if not (ROOT / ref).is_file():
            errors.append(f'{path.name}: missing res://{ref}')
    if re.search(r'^const\s+\w+\s*:=', text, re.M):
        errors.append(f'{path.name}: invalid constant declaration')
    # Delimiter checker skipping strings, comments; not a GDScript grammar parser.
    stack = []
    quote = None
    escaped = False
    for lineno, line in enumerate(text.splitlines(), 1):
        for char in line:
            if quote:
                if escaped:
                    escaped = False
                elif char == '\\':
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char == '#':
                break
            if char in {'"', "'"}:
                quote = char
                continue
            if char in '([{':
                stack.append((char, lineno))
            elif char in ')]}':
                if not stack or {'(': ')', '[': ']', '{': '}'}[stack[-1][0]] != char:
                    errors.append(f'{path.name}:{lineno}: mismatched {char}')
                else:
                    stack.pop()
        if quote:
            errors.append(f'{path.name}:{lineno}: unterminated string')
            quote = None
    for delimiter, lineno in stack:
        errors.append(f'{path.name}:{lineno}: unclosed {delimiter}')
if not (ROOT / 'project.godot').is_file():
    errors.append('project.godot absent')
scene = ROOT / 'scenes/main.tscn'
if not scene.is_file() or 'res://scripts/game.gd' not in scene.read_text(encoding='utf-8'):
    errors.append('main scene not wired to game script')
if errors:
    for error in errors:
        print('FAIL', error)
    raise SystemExit(1)
print(f'STATIC CHECK PASSED: {len(scripts)} GDScript files, scene and preload paths, balanced delimiters.')
print('NOTE: Godot engine syntax, runtime and gameplay remain unverified.')
