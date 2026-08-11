"""Generates the UI pixel font from readable glyph maps.

Outputs an AngelCode bitmap font pair that Godot imports as a FontFile:

    assets/fonts/pixel_font.png   white glyphs on transparent
    assets/fonts/pixel_font.fnt   glyph metrics

Glyphs are white so the theme can tint them per Label/Button variation
the same way the rarity outline atlas is tinted at runtime.

Metrics (all in pixels, native size 10):

    rows 0..6   above the baseline  -> caps/digits/ascenders are 7 tall
    rows 2..6   x-height            -> lowercase is 5 tall
    rows 7..8   below the baseline  -> descenders
    base = 7, lineHeight = 10 (1px leading)

Because it is a bitmap font it only looks right at its native size or an
exact integer multiple of it, so the theme uses 10 / 20 / 30 and nothing
in between.

Run from the repo root:

    python tools/generate_pixel_font.py

Add --preview to also write a scaled-up specimen sheet next to the
output for eyeballing the result.
"""

import argparse
import os

from PIL import Image

OUT_DIR = os.path.join("assets", "fonts")
FONT_NAME = "pixel_font"
FACE_NAME = "Fishermans Island Pixel"

BASELINE = 7       # rows above the baseline
GLYPH_ROWS = 9     # tallest possible glyph box (7 above + 2 descender)
LINE_HEIGHT = 10   # baseline-to-baseline
LETTER_SPACING = 1  # blank columns added after every glyph

# --- Glyph maps -------------------------------------------------------
#
# Each entry is (top_row, pattern). `top_row` is the row the block starts
# on, so an x-height lowercase letter says 2 and a descender says 2 while
# simply being taller. '#' is ink, '.' is transparent. Glyph width comes
# from the pattern itself, which is what makes the font proportional.


def _g(top, pattern):
    rows = [line for line in pattern.strip("\n").split("\n")]
    return (top, rows)


GLYPHS = {}

# Space is the one glyph with no ink -- it only carries an advance.
GLYPHS[" "] = (0, [])

# --- Uppercase --------------------------------------------------------

GLYPHS["A"] = _g(0, """
.###.
#...#
#...#
#...#
#####
#...#
#...#
""")
GLYPHS["B"] = _g(0, """
####.
#...#
#...#
####.
#...#
#...#
####.
""")
GLYPHS["C"] = _g(0, """
.###.
#...#
#....
#....
#....
#...#
.###.
""")
GLYPHS["D"] = _g(0, """
####.
#...#
#...#
#...#
#...#
#...#
####.
""")
GLYPHS["E"] = _g(0, """
#####
#....
#....
####.
#....
#....
#####
""")
GLYPHS["F"] = _g(0, """
#####
#....
#....
####.
#....
#....
#....
""")
GLYPHS["G"] = _g(0, """
.###.
#...#
#....
#.###
#...#
#...#
.###.
""")
GLYPHS["H"] = _g(0, """
#...#
#...#
#...#
#####
#...#
#...#
#...#
""")
GLYPHS["I"] = _g(0, """
###
.#.
.#.
.#.
.#.
.#.
###
""")
GLYPHS["J"] = _g(0, """
..###
...#.
...#.
...#.
...#.
#..#.
.##..
""")
GLYPHS["K"] = _g(0, """
#...#
#..#.
#.#..
##...
#.#..
#..#.
#...#
""")
GLYPHS["L"] = _g(0, """
#....
#....
#....
#....
#....
#....
#####
""")
GLYPHS["M"] = _g(0, """
#.....#
##...##
#.#.#.#
#..#..#
#.....#
#.....#
#.....#
""")
GLYPHS["N"] = _g(0, """
#...#
##..#
##..#
#.#.#
#..##
#..##
#...#
""")
GLYPHS["O"] = _g(0, """
.###.
#...#
#...#
#...#
#...#
#...#
.###.
""")
GLYPHS["P"] = _g(0, """
####.
#...#
#...#
####.
#....
#....
#....
""")
GLYPHS["Q"] = _g(0, """
.###.
#...#
#...#
#...#
#.#.#
#..#.
.##.#
""")
GLYPHS["R"] = _g(0, """
####.
#...#
#...#
####.
#.#..
#..#.
#...#
""")
GLYPHS["S"] = _g(0, """
.####
#....
#....
.###.
....#
....#
####.
""")
GLYPHS["T"] = _g(0, """
#####
..#..
..#..
..#..
..#..
..#..
..#..
""")
GLYPHS["U"] = _g(0, """
#...#
#...#
#...#
#...#
#...#
#...#
.###.
""")
GLYPHS["V"] = _g(0, """
#...#
#...#
#...#
#...#
#...#
.#.#.
..#..
""")
GLYPHS["W"] = _g(0, """
#.....#
#.....#
#.....#
#..#..#
#.#.#.#
##...##
#.....#
""")
GLYPHS["X"] = _g(0, """
#...#
#...#
.#.#.
..#..
.#.#.
#...#
#...#
""")
GLYPHS["Y"] = _g(0, """
#...#
#...#
.#.#.
..#..
..#..
..#..
..#..
""")
GLYPHS["Z"] = _g(0, """
#####
....#
...#.
..#..
.#...
#....
#####
""")

# --- Lowercase --------------------------------------------------------

GLYPHS["a"] = _g(2, """
.###.
....#
.####
#...#
.####
""")
GLYPHS["b"] = _g(0, """
#....
#....
####.
#...#
#...#
#...#
####.
""")
GLYPHS["c"] = _g(2, """
.###.
#...#
#....
#...#
.###.
""")
GLYPHS["d"] = _g(0, """
....#
....#
.####
#...#
#...#
#...#
.####
""")
GLYPHS["e"] = _g(2, """
.###.
#...#
#####
#....
.###.
""")
GLYPHS["f"] = _g(0, """
..##
.#..
####
.#..
.#..
.#..
.#..
""")
GLYPHS["g"] = _g(2, """
.####
#...#
#...#
.####
....#
#...#
.###.
""")
GLYPHS["h"] = _g(0, """
#....
#....
####.
#...#
#...#
#...#
#...#
""")
GLYPHS["i"] = _g(0, """
.#.
...
##.
.#.
.#.
.#.
###
""")
GLYPHS["j"] = _g(0, """
..#.
....
..#.
..#.
..#.
..#.
..#.
#.#.
.##.
""")
GLYPHS["k"] = _g(0, """
#....
#....
#..#.
#.#..
##...
#.#..
#..#.
""")
GLYPHS["l"] = _g(0, """
##.
.#.
.#.
.#.
.#.
.#.
.##
""")
GLYPHS["m"] = _g(2, """
#######
#..#..#
#..#..#
#..#..#
#..#..#
""")
GLYPHS["n"] = _g(2, """
####.
#...#
#...#
#...#
#...#
""")
GLYPHS["o"] = _g(2, """
.###.
#...#
#...#
#...#
.###.
""")
GLYPHS["p"] = _g(2, """
####.
#...#
#...#
#...#
####.
#....
#....
""")
GLYPHS["q"] = _g(2, """
.####
#...#
#...#
#...#
.####
....#
....#
""")
GLYPHS["r"] = _g(2, """
#.###
##...
#....
#....
#....
""")
GLYPHS["s"] = _g(2, """
.####
#....
.###.
....#
####.
""")
GLYPHS["t"] = _g(0, """
.#..
.#..
####
.#..
.#..
.#..
..##
""")
GLYPHS["u"] = _g(2, """
#...#
#...#
#...#
#...#
.####
""")
GLYPHS["v"] = _g(2, """
#...#
#...#
#...#
.#.#.
..#..
""")
GLYPHS["w"] = _g(2, """
#.....#
#..#..#
#..#..#
#.#.#.#
.#...#.
""")
GLYPHS["x"] = _g(2, """
#...#
.#.#.
..#..
.#.#.
#...#
""")
GLYPHS["y"] = _g(2, """
#...#
#...#
#...#
#...#
.####
....#
.###.
""")
GLYPHS["z"] = _g(2, """
#####
...#.
..#..
.#...
#####
""")

# --- Digits -----------------------------------------------------------

GLYPHS["0"] = _g(0, """
.###.
#...#
#..##
#.#.#
##..#
#...#
.###.
""")
GLYPHS["1"] = _g(0, """
..#..
.##..
..#..
..#..
..#..
..#..
.###.
""")
GLYPHS["2"] = _g(0, """
.###.
#...#
....#
...#.
..#..
.#...
#####
""")
GLYPHS["3"] = _g(0, """
####.
....#
....#
.###.
....#
....#
####.
""")
GLYPHS["4"] = _g(0, """
...#.
..##.
.#.#.
#..#.
#####
...#.
...#.
""")
GLYPHS["5"] = _g(0, """
#####
#....
####.
....#
....#
#...#
.###.
""")
GLYPHS["6"] = _g(0, """
.###.
#...#
#....
####.
#...#
#...#
.###.
""")
GLYPHS["7"] = _g(0, """
#####
....#
...#.
..#..
.#...
.#...
.#...
""")
GLYPHS["8"] = _g(0, """
.###.
#...#
#...#
.###.
#...#
#...#
.###.
""")
GLYPHS["9"] = _g(0, """
.###.
#...#
#...#
.####
....#
#...#
.###.
""")

# --- Punctuation and symbols -----------------------------------------

GLYPHS["!"] = _g(0, """
#
#
#
#
#
.
#
""")
GLYPHS['"'] = _g(0, """
#.#
#.#
""")
GLYPHS["#"] = _g(1, """
.#.#.
#####
.#.#.
#####
.#.#.
""")
GLYPHS["$"] = _g(0, """
..#..
.####
#.#..
.###.
..#.#
####.
..#..
""")
GLYPHS["%"] = _g(0, """
##..#
##.#.
...#.
..#..
.#...
#.##.
#..##
""")
GLYPHS["&"] = _g(0, """
.##..
#..#.
#..#.
.##..
#.#.#
#..#.
.##.#
""")
GLYPHS["'"] = _g(0, """
#
#
""")
GLYPHS["("] = _g(0, """
..#
.#.
#..
#..
#..
.#.
..#
""")
GLYPHS[")"] = _g(0, """
#..
.#.
..#
..#
..#
.#.
#..
""")
GLYPHS["*"] = _g(1, """
..#..
#.#.#
.###.
#.#.#
..#..
""")
GLYPHS["+"] = _g(1, """
..#..
..#..
#####
..#..
..#..
""")
GLYPHS[","] = _g(5, """
.#
.#
#.
""")
GLYPHS["-"] = _g(3, """
####
""")
GLYPHS["."] = _g(6, """
#
""")
GLYPHS["/"] = _g(0, """
....#
....#
...#.
..#..
.#...
#....
#....
""")
GLYPHS[":"] = _g(2, """
#
.
.
#
""")
GLYPHS[";"] = _g(2, """
.#
..
..
.#
#.
""")
GLYPHS["<"] = _g(0, """
...#
..#.
.#..
#...
.#..
..#.
...#
""")
GLYPHS["="] = _g(2, """
####
....
####
""")
GLYPHS[">"] = _g(0, """
#...
.#..
..#.
...#
..#.
.#..
#...
""")
GLYPHS["?"] = _g(0, """
.###.
#...#
....#
...#.
..#..
.....
..#..
""")
GLYPHS["@"] = _g(0, """
.###.
#...#
#.###
#.#.#
#.###
#....
.###.
""")
GLYPHS["["] = _g(0, """
###
#..
#..
#..
#..
#..
###
""")
GLYPHS["\\"] = _g(0, """
#....
#....
.#...
..#..
...#.
....#
....#
""")
GLYPHS["]"] = _g(0, """
###
..#
..#
..#
..#
..#
###
""")
GLYPHS["^"] = _g(0, """
..#..
.#.#.
#...#
""")
GLYPHS["_"] = _g(7, """
#####
""")
GLYPHS["`"] = _g(0, """
#.
.#
""")
GLYPHS["{"] = _g(0, """
..#
.#.
.#.
#..
.#.
.#.
..#
""")
GLYPHS["|"] = _g(0, """
#
#
#
#
#
#
#
""")
GLYPHS["}"] = _g(0, """
#..
.#.
.#.
..#
.#.
.#.
#..
""")
GLYPHS["~"] = _g(3, """
.#..#
#..#.
""")

# --- Non-ASCII glyphs the UI actually uses ----------------------------
#
# Every one of these appears in a .gd or .tscn today; without them the
# font would silently fall back to a notdef box. Keep this list in sync
# if new symbols get introduced.

GLYPHS["·"] = _g(3, """
.#.
""")
GLYPHS["–"] = _g(3, """
####
""")
GLYPHS["—"] = _g(3, """
######
""")
GLYPHS["‹"] = _g(2, """
..#
.#.
#..
.#.
..#
""")
GLYPHS["→"] = _g(2, """
...#...
....#..
#######
....#..
...#...
""")
GLYPHS["−"] = _g(3, """
#####
""")
GLYPHS["▲"] = _g(3, """
..#..
.###.
#####
""")
GLYPHS["▼"] = _g(3, """
#####
.###.
..#..
""")
GLYPHS["▶"] = _g(2, """
#..
##.
###
##.
#..
""")
GLYPHS["◀"] = _g(2, """
..#
.##
###
.##
..#
""")
GLYPHS["★"] = _g(0, """
...#...
..###..
#######
.#####.
..###..
.##.##.
##...##
""")
GLYPHS["☆"] = _g(0, """
...#...
..#.#..
###.###
.#...#.
..#.#..
.#...#.
##...##
""")
GLYPHS["✕"] = _g(1, """
#...#
.#.#.
..#..
.#.#.
#...#
""")

# Space has no ink, so its advance is set here rather than measured.
SPACE_ADVANCE = 4


# --- Atlas building ---------------------------------------------------


def glyph_width(rows):
    return max((len(row) for row in rows), default=0)


def build_atlas():
    """Packs every glyph into one texture, wrapping into rows."""
    ordered = sorted(GLYPHS.items(), key=lambda item: ord(item[0]))

    atlas_w = 128
    pad = 1
    placements = []
    pen_x, pen_y, row_h = pad, pad, 0
    for char, (top, rows) in ordered:
        w = glyph_width(rows)
        h = len(rows)
        if w == 0:
            placements.append((char, top, rows, 0, 0, 0, 0))
            continue
        if pen_x + w + pad > atlas_w:
            pen_x = pad
            pen_y += row_h + pad
            row_h = 0
        placements.append((char, top, rows, pen_x, pen_y, w, h))
        pen_x += w + pad
        row_h = max(row_h, h)
    atlas_h = pen_y + row_h + pad

    # Godot's importer wants power-of-two-ish pages; round up to 8px.
    atlas_h = ((atlas_h + 7) // 8) * 8

    image = Image.new("RGBA", (atlas_w, atlas_h), (255, 255, 255, 0))
    pixels = image.load()
    for _char, _top, rows, x, y, _w, _h in placements:
        for row_index, row in enumerate(rows):
            for col_index, cell in enumerate(row):
                if cell == "#":
                    pixels[x + col_index, y + row_index] = (255, 255, 255, 255)
    return image, placements


def build_fnt(placements, page_file, atlas_size):
    lines = []
    lines.append(
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1"
        % (FACE_NAME, LINE_HEIGHT)
    )
    lines.append(
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (LINE_HEIGHT, BASELINE, atlas_size[0], atlas_size[1])
    )
    lines.append('page id=0 file="%s"' % page_file)
    lines.append("chars count=%d" % len(placements))
    for char, top, rows, x, y, w, h in placements:
        advance = SPACE_ADVANCE if char == " " else w + LETTER_SPACING
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d "
            "xadvance=%d page=0 chnl=15"
            % (ord(char), x, y, w, h, top, advance)
        )
    return "\n".join(lines) + "\n"


SPECIMEN_LINES = [
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "abcdefghijklmnopqrstuvwxyz",
    "0123456789 .,:;!?'\"-+=/\\",
    "(){}[]<>@#$%&*_^`|~",
    "",
    "Fisherman's Island",
    "Master Angler  Lvl 20  1,240 kg",
    "Global Luck +12%   Shop Discount -8%",
    "Hunger: Due   Thirst: OK   Rest: Handling...",
    "",
    "Legendary  Mythic  Secret  Epic",
    "Blindlight Kraken - 279.9 kg",
    "Dock (48/60)   Fish Album (73/120)",
    "",
    "star ★ ☆  close ✕  dash —  bullet ·",
    "arrows ▲ ▼ ◀ ▶ →  quote ‹  minus −",
]


def render_text(text):
    """Draws one line with the same metrics the .fnt declares."""
    width = 0
    for char in text:
        top, rows = GLYPHS.get(char, GLYPHS["?"])
        width += SPACE_ADVANCE if char == " " else glyph_width(rows) + LETTER_SPACING
    line = Image.new("RGBA", (max(width, 1), LINE_HEIGHT), (255, 255, 255, 0))
    pixels = line.load()
    pen = 0
    for char in text:
        top, rows = GLYPHS.get(char, GLYPHS["?"])
        for row_index, row in enumerate(rows):
            for col_index, cell in enumerate(row):
                if cell == "#":
                    pixels[pen + col_index, top + row_index] = (255, 255, 255, 255)
        pen += SPACE_ADVANCE if char == " " else glyph_width(rows) + LETTER_SPACING
    return line


def write_preview(path, scale=3):
    """Specimen sheet of real UI strings, so spacing and legibility are
    judged the way they will actually be read -- the packed atlas alone
    says nothing about how the font sets."""
    lines = [render_text(text) for text in SPECIMEN_LINES]
    margin = 6
    width = max(line.width for line in lines) + margin * 2
    height = len(lines) * LINE_HEIGHT + margin * 2
    sheet = Image.new("RGBA", (width, height), (28, 30, 38, 255))
    for index, line in enumerate(lines):
        sheet.alpha_composite(line, (margin, margin + index * LINE_HEIGHT))
    sheet = sheet.resize((width * scale, height * scale), Image.NEAREST)
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--preview",
        action="store_true",
        help="also write a scaled-up specimen sheet next to the output",
    )
    args = parser.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    image, placements = build_atlas()

    png_name = FONT_NAME + ".png"
    png_path = os.path.join(OUT_DIR, png_name)
    image.save(png_path)

    fnt_path = os.path.join(OUT_DIR, FONT_NAME + ".fnt")
    with open(fnt_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(build_fnt(placements, png_name, image.size))

    print("wrote %s (%dx%d, %d glyphs)" % (png_path, image.width, image.height, len(placements)))
    print("wrote %s" % fnt_path)

    if args.preview:
        # Repo root, matching the other generators -- the specimen is a
        # dev artifact, not a game asset, so it stays out of assets/.
        write_preview("font_preview.png")
        print("wrote font_preview.png")


if __name__ == "__main__":
    main()
