from pathlib import Path
import re

ROOT = Path('omc_app/lib')
OUT = Path('/tmp/uiux-final-source-scan.txt')
files = sorted(ROOT.rglob('*.dart'))

patterns = [
    ('FLOATING_LABEL', re.compile(r'\blabelText\s*:')),
    ('ELLIPSIS', re.compile(r'TextOverflow\.ellipsis')),
    ('ONE_LINE_CLAMP', re.compile(r'\bmaxLines\s*:\s*1\b')),
    ('SMALL_FONT', re.compile(r'\bfontSize\s*:\s*(?:8(?:\.0)?|9(?:\.0)?|10(?:\.0)?|11(?:\.0)?|12(?:\.0|\.5)?|13(?:\.0)?)\b')),
    ('TINY_TARGET', re.compile(r'(?:minimumSize\s*:\s*(?:const\s+)?Size(?:\.zero|\([^,]+,\s*(?:[0-4]?\d(?:\.0)?)\))|MaterialTapTargetSize\.shrinkWrap|VisualDensity\.compact|fixedSize\s*:)')),
    ('NO_OP_CALLBACK', re.compile(r'\b(?:onPressed|onTap|onSelected)\s*:\s*\(\)\s*\{\s*\}')),
    ('NUMERIC_RADIUS', re.compile(r'BorderRadius\.circular\((?:8|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|30|32|999)(?:\.0)?\)')),
    ('BOX_SHADOW', re.compile(r'\bBoxShadow\s*\(')),
    ('FIXED_20_INSET', re.compile(r'EdgeInsets\.(?:fromLTRB\(20\b|all\(20\b|symmetric\(horizontal:\s*20\b)')),
    ('FIXED_TEXT_HEIGHT', re.compile(r'\bheight\s*:\s*(?:3[0-9]|4[0-9]|5[0-2])(?:\.0)?\b')),
    ('SHEET', re.compile(r'\bshowModalBottomSheet\b')),
    ('DRAG_HANDLE', re.compile(r'\bshowDragHandle\s*:|drag handle|dragHandle', re.IGNORECASE)),
]

lines_out = []
for name, regex in patterns:
    lines_out.append(f'===== {name} =====')
    count = 0
    for path in files:
        rel = path.as_posix()
        for lineno, line in enumerate(path.read_text().splitlines(), 1):
            if regex.search(line):
                count += 1
                lines_out.append(f'{rel}:{lineno}: {line.strip()}')
    lines_out.append(f'-- {name} TOTAL: {count}')
    lines_out.append('')

# Also list current routed owner construction tokens so reachability decisions
# are made from the exact checkout rather than remembered source.
router = Path('omc_app/lib/app/router.dart').read_text().splitlines()
lines_out.append('===== ROUTER SCREEN CONSTRUCTIONS =====')
for lineno, line in enumerate(router, 1):
    if re.search(r'\b(?:Screen|View)\s*\(', line) and not line.lstrip().startswith('//'):
        lines_out.append(f'omc_app/lib/app/router.dart:{lineno}: {line.strip()}')

OUT.write_text('\n'.join(lines_out) + '\n')
print(OUT.read_text())
