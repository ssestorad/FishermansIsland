"""Generates the fish model atlas from parametric shape specs.

All 32 models are baked into one 256x64 atlas laid out as an 8x4 grid of
32x16 frames, which Sprite2D reads through hframes/vframes/frame.

A fish is composed rather than hand-drawn: a body profile (per-column top
and bottom bounds derived from a head/peak/tail height curve) plus a tail,
optional dorsal/anal fins, a snout and a surface pattern, finished with a
palette and a dark outline grown from the silhouette. That keeps 32
distinct models maintainable, which 32 hand-authored ASCII maps would not
be, and lets shape, size and colour vary independently.

Because the models are now full colour, the Album shows them unmodulated —
rarity is carried by the card's tier label and the row swatches instead of
by tinting the sprite.

Run from the repo root:

    python tools/generate_fish_sprites.py

Add --preview to also write a scaled-up contact sheet for eyeballing.
"""

import argparse
import math
import os
import random

from PIL import Image

FRAME_W, FRAME_H = 32, 16
COLUMNS, ROWS = 10, 5
MODEL_COUNT = COLUMNS * ROWS
CENTER_Y = 7.5
OUT_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas.png")
OUTLINE_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas_outline.png")

# --- Palettes --------------------------------------------------------
#
# Each entry is body / back (upper edge) / belly (lower edge) / fin /
# pattern. Sixteen palettes across 32 models means every colour shows up
# on two clearly different silhouettes.

PALETTES = {
    "silver": [(196, 206, 216), (150, 163, 178), (232, 238, 244), (170, 182, 196), (120, 134, 150)],
    "steel": [(108, 142, 178), (74, 104, 138), (158, 188, 214), (88, 120, 156), (58, 84, 114)],
    "olive": [(126, 142, 86), (94, 108, 62), (176, 186, 132), (108, 122, 74), (72, 84, 48)],
    "gold": [(222, 178, 74), (182, 138, 48), (246, 220, 148), (200, 158, 60), (146, 106, 32)],
    "copper": [(198, 120, 66), (158, 88, 46), (232, 176, 124), (176, 102, 54), (122, 66, 34)],
    "crimson": [(186, 68, 66), (146, 44, 46), (226, 132, 118), (166, 54, 54), (110, 30, 32)],
    "violet": [(142, 102, 178), (108, 72, 142), (194, 166, 222), (124, 86, 158), (84, 54, 112)],
    "teal": [(78, 158, 156), (52, 120, 120), (140, 202, 198), (64, 138, 136), (38, 92, 92)],
    "slate": [(110, 116, 128), (78, 84, 96), (156, 162, 174), (94, 100, 112), (58, 64, 74)],
    "sand": [(206, 182, 138), (170, 144, 102), (236, 220, 186), (188, 162, 118), (134, 110, 74)],
    "abyss": [(62, 74, 116), (40, 50, 84), (104, 118, 166), (50, 60, 96), (28, 34, 60)],
    "pearl": [(226, 220, 208), (186, 178, 164), (250, 248, 242), (206, 198, 184), (156, 148, 134)],
    "emerald": [(72, 150, 96), (46, 112, 68), (132, 196, 148), (58, 130, 82), (34, 82, 50)],
    "rose": [(214, 132, 150), (178, 94, 114), (244, 186, 196), (196, 112, 132), (140, 68, 86)],
    "amber": [(226, 146, 58), (188, 110, 34), (248, 196, 122), (206, 126, 44), (150, 84, 24)],
    "ink": [(74, 78, 92), (48, 52, 64), (118, 124, 142), (62, 66, 80), (32, 34, 42)],
}

TONE_ORDER = ["body", "back", "belly", "fin", "pattern"]


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def _luminance(color):
    return 0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]


def resolve_palette(name):
    values = PALETTES[name]
    palette = dict(zip(TONE_ORDER, values))
    # A dark eye vanishes on the dark palettes, so flip it to a light dot
    # rather than hand-picking an eye colour for every entry.
    palette["eye"] = (28, 30, 36) if _luminance(palette["body"]) > 110 else (232, 236, 244)
    return palette


def _profile(t, head_h, tail_h, peak, taper="sin"):
    """Body half-height at 0..1 along the fish, as a fraction of body_h.

    Rises from the head to a peak, then falls away to the tail. The fall
    is sine-eased by default, which gives ordinary fish a full belly that
    only narrows late. Eel-like bodies pass taper="linear" instead: the
    sine ease drops almost all of its height in the first third, leaving
    the rest of a long body as a constant-width bar.
    """
    if t <= peak:
        u = t / peak if peak > 0.0 else 1.0
        return head_h + (1.0 - head_h) * math.sin(u * math.pi / 2.0)
    u = (t - peak) / (1.0 - peak) if peak < 1.0 else 1.0
    fall = u if taper == "linear" else math.sin(u * math.pi / 2.0)
    return 1.0 + (tail_h - 1.0) * fall


def _body_bounds(spec):
    """Per-column (top_y, bottom_y) for the body, keyed by column index."""
    body_len = spec["body_len"]
    body_h = spec["body_h"]
    back = spec.get("back_bias", 1.0)
    belly = spec.get("belly_bias", 1.0)
    bounds = {}
    for i in range(body_len):
        t = i / float(body_len - 1) if body_len > 1 else 0.0
        h = body_h * _profile(
            t, spec.get("head_h", 0.55), spec.get("tail_h", 0.28),
            spec.get("peak", 0.4), spec.get("taper", "sin")
        )
        top = int(round(CENTER_Y - h * back))
        bottom = int(round(CENTER_Y + h * belly))
        if bottom < top:
            bottom = top
        bounds[i] = (top, bottom)
    return bounds


def _put(px, x, y, tone):
    if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
        px[(x, y)] = tone


def _draw_tail(px, spec, x0, base_h, body_h):
    """Draws the caudal fin starting at column x0, flush with the body.

    Every style interpolates from the body's own peduncle height to a tip
    height derived from body_h, so the tail stays in proportion instead of
    growing off the frame on the taller fish.
    """
    style = spec.get("tail", "fan")
    length = spec.get("tail_len", 5)
    # Cap how fast the tail may open up. Without this the deep-bodied fish
    # grow trumpet-shaped tails, since their tip height scales with a much
    # larger body_h than the peduncle they actually attach to.
    tip_h = min(body_h * spec.get("tail_flare", 0.8), base_h + length * 0.85)
    tip_h = max(tip_h, base_h)
    # A shark-style tail is asymmetric: the upper lobe overhangs the lower.
    bias_top, bias_bottom = (1.45, 0.7) if style == "long" else (1.0, 1.0)
    for k in range(length):
        x = x0 + k
        t = (k + 1) / float(length)
        if style == "point":
            half = max(0.5, base_h * (1.0 - t) + 0.5)
        elif style == "round":
            half = base_h + (tip_h - base_h) * math.sin(t * math.pi / 2.0)
        elif style == "long":
            # A thin stalk that only flares into a lobe at the very end.
            half = base_h if t < 0.55 else base_h + (tip_h - base_h) * ((t - 0.55) / 0.45)
        else:  # fan and fork share the same expanding outline
            half = base_h + (tip_h - base_h) * t
        top = int(round(CENTER_Y - half * bias_top))
        bottom = int(round(CENTER_Y + half * bias_bottom))
        for y in range(top, bottom + 1):
            # A fork is a fan with the centre eaten away toward the tip,
            # stopping short so both lobes keep some thickness.
            if style == "fork" and abs(y - CENTER_Y) < (half - 1.2) * t:
                continue
            _put(px, x, y, "fin")


def _draw_edge_fin(px, x0, bounds, body_len, span_spec, side):
    """Dorsal (side=-1) or anal (side=1) fin riding along the body edge.

    The height is shaped by a sine across the whole span so the fin peaks
    in the middle and tapers back into the body at both ends.
    """
    start_frac, end_frac, height = span_spec
    a = int(body_len * start_frac)
    b = int(body_len * end_frac)
    span = max(1, b - a)
    for i in range(a, b + 1):
        if not (0 <= i < body_len):
            continue
        t = (i - a) / float(span)
        h = int(round(height * math.sin(t * math.pi)))
        edge_y = bounds[i][0] if side < 0 else bounds[i][1]
        for k in range(1, h + 1):
            _put(px, x0 + i, edge_y + k * side, "fin")


def _draw_pattern(px, spec, bounds, x0, rng):
    style = spec.get("pattern", "none")
    if style == "none":
        return
    for i in range(spec["body_len"]):
        top, bottom = bounds[i]
        x = x0 + i
        if style == "stripes":
            if i >= 3 and (i - 3) % 4 == 0 and bottom - top >= 2:
                for y in range(top + 1, bottom):
                    _put(px, x, y, "pattern")
        elif style == "line":
            if i >= 3 and bottom - top >= 2:
                _put(px, x, int(round(CENTER_Y)), "pattern")
        elif style == "spots":
            if bottom - top >= 3 and i >= 3 and rng.random() < 0.35:
                _put(px, x, rng.randint(top + 1, bottom - 1), "pattern")
        elif style == "bars":
            # Two lateral bands riding just inside the back/belly edges,
            # the horizontal counterpart to "stripes"' vertical bands.
            if bottom - top >= 3 and i >= 2:
                _put(px, x, top + 1, "pattern")
                _put(px, x, bottom - 1, "pattern")
        elif style == "eyespot":
            # A false eye near the tail, like a butterflyfish's — a small
            # dark mark placed well clear of the real eye up at the head.
            if i == int(round(spec["body_len"] * 0.78)) and bottom - top >= 3:
                mid = int(round((top + bottom) / 2.0))
                _put(px, x, mid, "pattern")
                _put(px, x, mid - 1, "pattern")


def _outline_positions(filled):
    """The 1px ring just outside the silhouette.

    Emitted as a separate white mask rather than baked into the body, so
    the game can tint it with the fish's rarity colour at runtime.
    """
    edge = set()
    for (x, y) in filled:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < FRAME_W and 0 <= ny < FRAME_H):
                continue
            if (nx, ny) in filled:
                continue
            edge.add((nx, ny))
    return edge


def draw_fish(spec, seed):
    rng = random.Random(seed)
    px = {}
    bounds = _body_bounds(spec)
    body_len = spec["body_len"]
    snout = spec.get("snout", 0)
    tail_len = spec.get("tail_len", 5)

    total = snout + body_len + tail_len
    x0 = max(1, (FRAME_W - total) // 2) + snout

    for i in range(body_len):
        top, bottom = bounds[i]
        x = x0 + i
        for y in range(top, bottom + 1):
            if y == top and bottom - top >= 2:
                tone = "back"
            elif y == bottom and bottom - top >= 2:
                tone = "belly"
            else:
                tone = "body"
            _put(px, x, y, tone)

    _draw_pattern(px, spec, bounds, x0, rng)

    # Snout/bill, drawn along the centreline out in front of the head.
    for k in range(snout):
        _put(px, x0 - 1 - k, int(round(CENTER_Y)), "fin")

    if spec.get("dorsal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["dorsal"], -1)
    if spec.get("anal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["anal"], 1)

    if spec.get("pectoral", True):
        i = max(1, int(body_len * 0.32))
        _put(px, x0 + i, bounds[i][1] + 1, "fin")
        _put(px, x0 + i + 1, bounds[i][1] + 1, "fin")

    eye_i = max(1, int(body_len * 0.14))
    top, bottom = bounds[eye_i]
    eye_y = int(round(CENTER_Y - (CENTER_Y - top) * 0.5))
    _put(px, x0 + eye_i, max(top, min(bottom, eye_y)), "eye")

    peduncle = bounds[body_len - 1]
    _draw_tail(px, spec, x0 + body_len, max(0.5, (peduncle[1] - peduncle[0]) / 2.0), spec["body_h"])

    palette = resolve_palette(spec["palette"])
    body = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    for (x, y), tone in px.items():
        body.putpixel((x, y), palette[tone] + (255,))

    outline = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    for (x, y) in _outline_positions(set(px.keys())):
        outline.putpixel((x, y), (255, 255, 255, 255))
    return body, outline


# --- The roster ------------------------------------------------------
#
# Grouped by silhouette family, with size deliberately spread across the
# set (tiny 11px minnows up to 24px leviathans) so the models differ in
# bulk as well as in outline and colour.

SPECS = [
    # Small everyday fish.
    {"name": "minnow", "palette": "silver", "body_len": 11, "body_h": 2.4, "tail": "fan", "tail_len": 4},
    {"name": "roach", "palette": "olive", "body_len": 13, "body_h": 2.8, "tail": "fork", "tail_len": 4, "pattern": "line"},
    {"name": "sardine", "palette": "steel", "body_len": 15, "body_h": 2.4, "tail": "fork", "tail_len": 4, "pattern": "line"},
    {"name": "gudgeon", "palette": "sand", "body_len": 13, "body_h": 2.8, "tail": "fan", "tail_len": 4, "pattern": "spots"},
    # Mid-size, plainer builds.
    {"name": "bream", "palette": "pearl", "body_len": 15, "body_h": 4.2, "peak": 0.42, "tail": "fork", "tail_len": 5, "dorsal": (0.3, 0.6, 2.0)},
    {"name": "rudd", "palette": "gold", "body_len": 15, "body_h": 3.8, "tail": "fork", "tail_len": 5, "anal": (0.55, 0.85, 2.0)},
    {"name": "chub", "palette": "slate", "body_len": 18, "body_h": 3.4, "tail": "fan", "tail_len": 4, "pattern": "line"},
    {"name": "trout", "palette": "rose", "body_len": 19, "body_h": 3.4, "tail": "fan", "tail_len": 4, "dorsal": (0.35, 0.6, 1.8), "pattern": "spots"},
    # Deep-bodied and rounded.
    {"name": "perch", "palette": "emerald", "body_len": 16, "body_h": 4.4, "back_bias": 1.15, "belly_bias": 0.85, "tail": "fan", "tail_len": 4, "dorsal": (0.25, 0.55, 2.0), "pattern": "stripes"},
    {"name": "carp", "palette": "amber", "body_len": 18, "body_h": 4.6, "peak": 0.45, "tail": "fork", "tail_len": 5, "dorsal": (0.3, 0.7, 1.6), "pattern": "stripes"},
    {"name": "sunfish", "palette": "violet", "body_len": 14, "body_h": 5.0, "head_h": 0.7, "tail_h": 0.4, "peak": 0.45, "tail": "round", "tail_len": 3, "tail_flare": 0.5, "dorsal": (0.2, 0.6, 1.4), "anal": (0.5, 0.8, 1.4)},
    {"name": "puffer", "palette": "sand", "body_len": 14, "body_h": 5.2, "head_h": 0.45, "tail_h": 0.38, "peak": 0.5, "tail": "point", "tail_len": 3, "pattern": "spots"},
    {"name": "bigeye", "palette": "crimson", "body_len": 15, "body_h": 4.6, "head_h": 0.8, "peak": 0.35, "tail": "fork", "tail_len": 4, "tail_flare": 0.6},
    {"name": "discus", "palette": "teal", "body_len": 14, "body_h": 5.4, "head_h": 0.75, "tail_h": 0.6, "peak": 0.5, "tail": "round", "tail_len": 3, "tail_flare": 0.55, "pattern": "stripes"},
    # Long predators.
    {"name": "pike", "palette": "olive", "body_len": 22, "body_h": 3.0, "head_h": 0.8, "peak": 0.55, "tail": "fork", "tail_len": 5, "dorsal": (0.65, 0.85, 1.8), "pattern": "spots"},
    {"name": "bass", "palette": "emerald", "body_len": 19, "body_h": 3.8, "tail": "fan", "tail_len": 5, "dorsal": (0.3, 0.6, 2.0), "pattern": "line"},
    {"name": "barracuda", "palette": "steel", "body_len": 22, "body_h": 2.6, "head_h": 0.75, "peak": 0.5, "tail": "fork", "tail_len": 5, "snout": 1},
    {"name": "grayling", "palette": "violet", "body_len": 18, "body_h": 3.0, "tail": "fork", "tail_len": 5, "dorsal": (0.25, 0.6, 3.0)},
    # Eels and serpents.
    {"name": "eel", "palette": "ink", "body_len": 24, "body_h": 2.6, "head_h": 1.0, "tail_h": 0.38, "peak": 0.0, "tail": "point", "tail_len": 4, "pectoral": False, "taper": "linear"},
    {"name": "moray", "palette": "olive", "body_len": 24, "body_h": 2.8, "head_h": 1.0, "tail_h": 0.4, "peak": 0.0, "tail": "point", "tail_len": 4, "dorsal": (0.25, 0.9, 1.2), "pectoral": False, "taper": "linear"},
    {"name": "serpent", "palette": "abyss", "body_len": 23, "body_h": 3.4, "head_h": 0.95, "tail_h": 0.3, "peak": 0.05, "tail": "point", "tail_len": 5, "pattern": "spots", "pectoral": False, "taper": "linear"},
    {"name": "lamprey", "palette": "copper", "body_len": 25, "body_h": 2.4, "head_h": 1.0, "tail_h": 0.45, "peak": 0.0, "tail": "point", "tail_len": 4, "pectoral": False, "pattern": "line", "taper": "linear"},
    # Billed showpieces.
    {"name": "swordfish", "palette": "steel", "body_len": 18, "body_h": 3.0, "tail": "fork", "tail_len": 5, "tail_flare": 1.1, "snout": 5, "dorsal": (0.2, 0.5, 2.6)},
    {"name": "marlin", "palette": "abyss", "body_len": 17, "body_h": 3.4, "tail": "fork", "tail_len": 5, "tail_flare": 1.1, "snout": 5, "dorsal": (0.2, 0.6, 2.8)},
    {"name": "sailfish", "palette": "violet", "body_len": 17, "body_h": 3.0, "tail": "fork", "tail_len": 5, "snout": 4, "dorsal": (0.15, 0.75, 3.4)},
    {"name": "needlefish", "palette": "pearl", "body_len": 21, "body_h": 1.8, "head_h": 0.9, "tail": "fork", "tail_len": 4, "snout": 4},
    # Sharks, rays and heavies.
    {"name": "shark", "palette": "slate", "body_len": 20, "body_h": 3.8, "head_h": 0.7, "peak": 0.35, "back_bias": 1.1, "belly_bias": 0.9, "tail": "long", "tail_len": 6, "dorsal": (0.35, 0.6, 2.6)},
    {"name": "hammerhead", "palette": "silver", "body_len": 20, "body_h": 3.4, "head_h": 0.95, "peak": 0.4, "tail": "long", "tail_len": 6, "dorsal": (0.4, 0.6, 2.4)},
    {"name": "ray", "palette": "sand", "body_len": 12, "body_h": 6.0, "head_h": 0.12, "tail_h": 0.06, "peak": 0.55, "tail": "point", "tail_len": 9, "tail_flare": 0.2, "pectoral": False},
    {"name": "sturgeon", "palette": "ink", "body_len": 22, "body_h": 3.0, "head_h": 0.8, "peak": 0.5, "tail": "long", "tail_len": 5, "snout": 2, "pattern": "stripes"},
    {"name": "catfish", "palette": "copper", "body_len": 20, "body_h": 3.8, "head_h": 1.0, "peak": 0.3, "tail": "round", "tail_len": 5, "snout": 3, "pattern": "spots"},
    {"name": "leviathan", "palette": "crimson", "body_len": 21, "body_h": 4.6, "head_h": 0.85, "peak": 0.45, "back_bias": 1.1, "belly_bias": 0.9, "tail": "fan", "tail_len": 5, "tail_flare": 1.0, "dorsal": (0.35, 0.75, 1.8), "pattern": "stripes"},
    # Exotics — one-off silhouettes for named species that used to share a
    # model with six-plus other fish (Lamp Squid/Anglerfish/Hadal Chimaera/
    # Manta of the Shallows/the flatfish pair all rode on "serpent"/
    # "bigeye"/"eel"/"ray"), plus dedicated shapes for the Kraken/Wyrm/
    # Behemoth-and-Colossus mythic tier, which used to be three more
    # "serpent"/"leviathan" repaints.
    {"name": "squid", "palette": "violet", "body_len": 10, "body_h": 4.0, "head_h": 0.85, "tail_h": 0.15, "peak": 0.3, "tail": "point", "tail_len": 7, "tail_flare": 0.3, "pectoral": False, "pattern": "spots"},
    {"name": "angler", "palette": "ink", "body_len": 12, "body_h": 5.0, "head_h": 0.95, "tail_h": 0.3, "peak": 0.15, "tail": "round", "tail_len": 3, "tail_flare": 0.4, "snout": 2, "dorsal": (0.05, 0.2, 1.2)},
    {"name": "chimaera", "palette": "slate", "body_len": 14, "body_h": 3.2, "head_h": 0.75, "tail_h": 0.15, "peak": 0.3, "tail": "point", "tail_len": 8, "tail_flare": 0.25, "dorsal": (0.08, 0.3, 2.2)},
    {"name": "manta", "palette": "steel", "body_len": 13, "body_h": 6.5, "head_h": 0.15, "tail_h": 0.05, "peak": 0.5, "tail": "point", "tail_len": 8, "tail_flare": 0.15, "snout": 2, "pectoral": False},
    {"name": "flounder", "palette": "sand", "body_len": 13, "body_h": 5.5, "head_h": 0.25, "tail_h": 0.2, "peak": 0.5, "tail": "round", "tail_len": 3, "tail_flare": 0.35, "pectoral": False, "pattern": "eyespot"},
    {"name": "kraken", "palette": "abyss", "body_len": 13, "body_h": 5.2, "head_h": 0.85, "tail_h": 0.2, "peak": 0.2, "tail": "point", "tail_len": 9, "tail_flare": 0.5, "dorsal": (0.1, 0.85, 2.6), "anal": (0.1, 0.85, 2.6), "pectoral": False},
    {"name": "wyrm", "palette": "teal", "body_len": 23, "body_h": 3.2, "head_h": 0.9, "tail_h": 0.35, "peak": 0.03, "taper": "linear", "tail": "point", "tail_len": 5, "dorsal": (0.05, 0.95, 1.8), "pectoral": False},
    {"name": "colossus", "palette": "copper", "body_len": 22, "body_h": 5.2, "head_h": 0.85, "tail_h": 0.35, "peak": 0.45, "back_bias": 1.15, "belly_bias": 0.95, "tail": "fan", "tail_len": 5, "tail_flare": 0.6, "dorsal": (0.3, 0.8, 2.2), "pattern": "bars"},
    # Secret tier gets its own faces. All six Secret species used to share
    # a model with an ordinary same-tier fish (Sunlit Mirage/Nightglass
    # Siren both rode "sailfish", Glassfin Wraith rode "needlefish", all
    # three Deep/Storm/Ruins heavies rode "leviathan") — a discovery this
    # rare deserves a silhouette nothing else in the catalog has.
    {"name": "mirage", "palette": "pearl", "body_len": 18, "body_h": 3.2, "head_h": 0.6, "tail_h": 0.3, "peak": 0.42, "tail": "fork", "tail_len": 5, "dorsal": (0.12, 0.85, 3.2), "pattern": "line"},
    {"name": "drownedking", "palette": "abyss", "body_len": 20, "body_h": 4.2, "head_h": 0.85, "tail_h": 0.3, "peak": 0.4, "tail": "long", "tail_len": 6, "dorsal": (0.05, 0.3, 3.2), "snout": 1},
    {"name": "wraith", "palette": "silver", "body_len": 20, "body_h": 2.2, "head_h": 0.6, "tail_h": 0.25, "peak": 0.1, "taper": "linear", "tail": "point", "tail_len": 7, "pectoral": False},
    {"name": "siren", "palette": "violet", "body_len": 19, "body_h": 3.6, "head_h": 0.55, "tail_h": 0.35, "peak": 0.35, "tail": "fan", "tail_len": 6, "tail_flare": 1.1, "dorsal": (0.3, 0.9, 2.4), "anal": (0.5, 0.9, 2.0)},
    {"name": "longdark", "palette": "ink", "body_len": 21, "body_h": 5.6, "head_h": 0.5, "tail_h": 0.4, "peak": 0.55, "back_bias": 1.2, "belly_bias": 1.2, "tail": "fan", "tail_len": 5, "tail_flare": 0.7, "pectoral": False},
    {"name": "keeper", "palette": "sand", "body_len": 20, "body_h": 4.8, "head_h": 0.75, "tail_h": 0.3, "peak": 0.42, "back_bias": 1.1, "belly_bias": 0.9, "tail": "round", "tail_len": 4, "tail_flare": 0.5, "dorsal": (0.1, 0.85, 2.4), "pattern": "stripes", "snout": 1},
    # The "shark" model alone covered four species spanning Epic to
    # Legendary; Great White and Thresher are both distinctive enough by
    # name/lore (thresher tails run as long as the body) to earn their own.
    {"name": "greatwhite", "palette": "steel", "body_len": 21, "body_h": 4.4, "head_h": 0.65, "tail_h": 0.3, "peak": 0.32, "tail": "long", "tail_len": 6, "dorsal": (0.32, 0.55, 3.0), "snout": 1},
    {"name": "thresher", "palette": "slate", "body_len": 16, "body_h": 3.4, "head_h": 0.6, "tail_h": 0.35, "peak": 0.35, "tail": "long", "tail_len": 12, "tail_flare": 0.35, "dorsal": (0.3, 0.5, 1.8)},
    # Non-fish sea life. Both still fit the head-to-tail silhouette system;
    # starfish and octopus don't (radial/many-armed body plans) and are
    # deliberately not attempted here — see the project notes.
    {"name": "seahorse", "palette": "rose", "body_len": 9, "body_h": 2.6, "head_h": 0.65, "tail_h": 0.1, "peak": 0.3, "back_bias": 1.3, "belly_bias": 0.7, "tail": "point", "tail_len": 8, "tail_flare": 0.1, "snout": 4, "dorsal": (0.15, 0.5, 1.6), "pectoral": False},
    {"name": "jellyfish", "palette": "pearl", "body_len": 9, "body_h": 4.2, "head_h": 0.35, "tail_h": 0.1, "peak": 0.55, "tail": "point", "tail_len": 9, "tail_flare": 0.15, "pectoral": False},
]


def build_atlases():
    if len(SPECS) != MODEL_COUNT:
        raise ValueError("expected %d specs, got %d" % (MODEL_COUNT, len(SPECS)))
    size = (FRAME_W * COLUMNS, FRAME_H * ROWS)
    body_atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    outline_atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    for index, spec in enumerate(SPECS):
        body, outline = draw_fish(spec, index)
        at = ((index % COLUMNS) * FRAME_W, (index // COLUMNS) * FRAME_H)
        body_atlas.paste(body, at)
        outline_atlas.paste(outline, at)
    return body_atlas, outline_atlas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", help="also write a scaled contact sheet")
    args = parser.parse_args()

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    body_atlas, outline_atlas = build_atlases()
    body_atlas.save(OUT_PATH)
    outline_atlas.save(OUTLINE_PATH)
    print("wrote %s and %s (%d models)" % (OUT_PATH, OUTLINE_PATH, MODEL_COUNT))

    if args.preview:
        # Stand in a few rarity colours for the outline so the preview
        # shows roughly what the Album renders.
        rarity_cycle = [(178, 178, 178), (102, 191, 102), (76, 128, 230), (153, 89, 217),
                        (230, 166, 38), (217, 51, 64), (31, 20, 51)]
        tinted = Image.new("RGBA", outline_atlas.size, (0, 0, 0, 0))
        for index in range(MODEL_COUNT):
            col, row = index % COLUMNS, index // COLUMNS
            box = (col * FRAME_W, row * FRAME_H, (col + 1) * FRAME_W, (row + 1) * FRAME_H)
            cell = outline_atlas.crop(box)
            tint = rarity_cycle[index % len(rarity_cycle)]
            solid = Image.new("RGBA", cell.size, tint + (255,))
            tinted.paste(solid, (box[0], box[1]), cell)
        composed = tinted.copy()
        composed.alpha_composite(body_atlas)
        scale = 5
        big = composed.resize((composed.width * scale, composed.height * scale), Image.NEAREST)
        backdrop = Image.new("RGBA", big.size, (245, 232, 199, 255))
        backdrop.alpha_composite(big)
        backdrop.save("fish_preview.png")
        print("wrote fish_preview.png")


if __name__ == "__main__":
    main()
