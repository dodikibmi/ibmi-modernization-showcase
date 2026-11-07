"""Render the PNG images in docs/ from files of this repository (no screen capture).
  report-before-after.png : spooled report of the legacy run and of stage 3 (SYSTOOLS.SPOOLED_FILE_DATA)
  code-before-after.png   : the payment posting routine in legacy ARR200 and in stage 3 ARR230
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15)
BOLD = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 16)
CW, LH = 8.25, 19
BG, GREEN, WHITE, YELLOW, RED, GREY = (12, 12, 12), (80, 230, 110), (230, 230, 230), (255, 214, 64), (255, 110, 110), (140, 140, 140)


def spool(name):
    lines = (ROOT / "test" / "out" / name).read_text(encoding="utf-8").splitlines()
    out = lines[lines.index("== SPOOL") + 1:]
    return [l for l in out if "pub400.com" not in l]


def panel(draw, x, y, title, lines, color, marks=None, width=None):
    draw.text((x, y), title, font=BOLD, fill=WHITE)
    y += LH + 8
    for i, line in enumerate(lines):
        c = (marks or {}).get(i, color)
        draw.text((x, y), line, font=FONT, fill=c)
        y += LH
    return y


# --- report before / after ---------------------------------------------------
legacy, stage3 = spool("legacy.txt"), spool("stage3.txt")
diff = {i for i, (a, b) in enumerate(zip(legacy, stage3)) if a != b}
w = int(134 * CW) + 40
h = (len(legacy) + len(stage3)) * LH + 4 * LH + 90
img = Image.new("RGB", (w, h), BG)
d = ImageDraw.Draw(img)
y = panel(d, 20, 15, "Legacy ARR300 (RPG cycle, O-specs) - spooled output", legacy, GREEN, {i: RED for i in diff})
y = panel(d, 20, y + 20, "Stage 3 ARR330 (fully free, service program) - same data, defect fixed", stage3, GREEN,
          {i: YELLOW for i in diff})
d.text((20, y + 8), "Rendered from the spooled files read with SYSTOOLS.SPOOLED_FILE_DATA on PUB400. "
       "The only difference is the line of the missing customer.", font=FONT, fill=GREY)
img.save(ROOT / "docs" / "report-before-after.png")


# --- code before / after ----------------------------------------------------
def block(path, start, end):
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    s = next(i for i, l in enumerate(lines) if start in l)
    e = next(i for i, l in enumerate(lines) if i > s and end in l)
    return [l[:96] for l in lines[s:e + 1]]


left = block("00-legacy/qrpglesrc/arr200.rpgle", "POSTPY        BEGSR", "ENDSR")
right = block("03-srvpgm/qrpglesrc/arr230.rpgle", "dcl-proc postPayment;", "end-proc;")
colw = int(98 * CW)
rows = max(len(left), len(right))
img = Image.new("RGB", (colw * 2 + 60, rows * LH + 90), BG)
d = ImageDraw.Draw(img)
panel(d, 20, 15, "Before: ARR200 subroutine POSTPY (fixed format, indicators, GOTO)", left, GREEN)
panel(d, colw + 40, 15, "After: ARR230 procedure postPayment (free, rules in ARSRV)", right, (120, 200, 255))
img.save(ROOT / "docs" / "code-before-after.png")
print("ok")
