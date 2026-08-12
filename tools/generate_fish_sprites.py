"""Generates the fish model atlas from parametric shape specs.

Models are baked into one atlas, laid out as a COLUMNS x ROWS grid of
64x32 frames (see the constants below for the current count), which
Sprite2D reads through hframes/vframes/frame.

A fish is composed rather than hand-drawn: a body profile (per-column top
and bottom bounds derived from a head/peak/tail height curve) plus a tail,
optional dorsal/anal fins, a snout and a surface pattern, finished with a
palette and a dark outline grown from the silhouette. That keeps dozens of
distinct models maintainable, which as many hand-authored ASCII maps would
not be, and lets shape, size and colour vary independently. Shading across
a body column is a computed gradient (see GRADIENT_STEPS/_gradient_tones)
rather than three flat back/body/belly bands, so the same 5-tone palettes
read as genuinely shaded instead of flat-coloured with two accent lines.

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

FRAME_W, FRAME_H = 64, 32
COLUMNS, ROWS = 11, 9
MODEL_COUNT = COLUMNS * ROWS
CENTER_Y = 15.5
OUT_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas.png")
OUTLINE_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas_outline.png")

# --- Palettes --------------------------------------------------------
#
# Each entry is body / back (upper edge) / belly (lower edge) / fin /
# pattern. Sixteen palettes reused across every model means each colour
# shows up on several clearly different silhouettes rather than each
# model needing its own unique palette.

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


## Bioluminescence reads as the fish's own light, not a body marking, so it
## deliberately ignores the palette entirely rather than being a 17th
## per-palette tone — one fixed colour for every glowing model, the same
## way every palette's eye is auto-derived rather than hand-picked.
GLOW_COLOR = (190, 255, 210)


def resolve_palette(name):
    values = PALETTES[name]
    palette = dict(zip(TONE_ORDER, values))
    # A dark eye vanishes on the dark palettes, so flip it to a light dot
    # rather than hand-picking an eye colour for every entry.
    palette["eye"] = (28, 30, 36) if _luminance(palette["body"]) > 110 else (232, 236, 244)
    palette["glow"] = GLOW_COLOR
    return palette


## How many shading steps a body column is divided into (see
## _add_gradient_tones/_gradient_tone_for). Purely a rendering-quality
## knob — doesn't touch a palette's actual colour data, just how many
## computed in-between steps get sampled from it.
GRADIENT_STEPS = 8


def _lerp_rgb(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


## Every palette still only ever defines 5 hand-picked tones (see
## TONE_ORDER) — richer shading comes from computing intermediate steps
## between them, not from hand-picking more colours per palette. The
## first half of the gradient runs back->body, the second half
## body->belly, so a column's top edge still reads as the darkest/lightest
## extreme and the middle still reads as the palette's own "body" colour,
## exactly where they did under the old flat 3-band fill — this only adds
## the steps in between.
def _add_gradient_tones(palette):
    palette = dict(palette)
    half = GRADIENT_STEPS // 2
    for i in range(GRADIENT_STEPS):
        if i < half:
            t = i / float(half)
            color = _lerp_rgb(palette["back"], palette["body"], t)
        else:
            t = (i - half) / float(GRADIENT_STEPS - half - 1)
            color = _lerp_rgb(palette["body"], palette["belly"], t)
        palette["grad%d" % i] = color
    return palette


def _gradient_tone_for(frac):
    """Maps a column-relative position (0 = top/back edge, 1 = bottom/belly
    edge) to one of the GRADIENT_STEPS tone names _add_gradient_tones()
    added to a resolved palette."""
    index = int(round(frac * (GRADIENT_STEPS - 1)))
    return "grad%d" % max(0, min(GRADIENT_STEPS - 1, index))


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
    if style == "tentacles":
        _draw_tentacles(px, x0, base_h, length, spec.get("tail_strand_count", 6))
        return
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
            # "limb" instead of "fin": a tail is skin/body, not a fin, so
            # on a two-hue model (accent_palette set) it should match the
            # head/flippers' colour, not the shell/fin one. A no-op for
            # every other model — "limb" resolves back to "fin" whenever
            # there's no accent_palette (see _render).
            _put(px, x, y, "limb")


def _draw_tentacles(px, x0, base_h, length, count):
    """A squid/cuttlefish tail: separate trailing strands instead of one
    solid tapering shape, each with its own length, a slight wave, and
    real thickness that tapers toward the tip (like a radial limb) — the
    lateral-profile counterpart to the radial octopus model's individual
    limbs. The wave amplitude is derived from `base_h` rather than a fixed
    pixel constant, so it stays proportional to the model's own scale
    instead of reading as a thin, disconnected squiggle at a render
    resolution bigger than this was first tuned at.
    """
    wave_amp = max(1.5, base_h * 0.55)
    for c in range(count):
        frac = (c + 0.5) / count
        y0 = CENTER_Y - base_h + frac * (2.0 * base_h)
        strand_len = length * (0.65 + 0.35 * abs(math.sin(c * 2.1)))
        curl = 1 if c % 2 == 0 else -1
        steps = max(1, int(round(strand_len)))
        for k in range(steps):
            t = k / max(1.0, steps - 1.0)
            x = x0 + k
            y = y0 + curl * t * t * wave_amp
            half_w = max(0.5, base_h * 0.22 * (1.0 - t * 0.6))
            span = int(round(half_w))
            for o in range(-span, span + 1):
                _put(px, x, int(round(y + o)), "fin")


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
        elif style == "glow":
            # A row of photophores along the belly, evenly spaced — the
            # classic deep-sea trait. Uses the "glow" tone (a fixed bright
            # colour independent of the palette) rather than "pattern", so
            # it reads as the fish's own light rather than a body marking.
            if bottom - top >= 2 and i >= 2 and (i - 2) % 3 == 0:
                _put(px, x, bottom, "glow")
        elif style == "scutes":
            # Alternating full-height bands, two columns wide — bolder
            # and more legible at this resolution than a fine checker,
            # reading as a plated shell rather than a couple of stripes.
            if bottom - top >= 3 and (i // 2) % 2 == 0:
                for y in range(top + 1, bottom):
                    _put(px, x, y, "pattern")
        elif style == "patches":
            # Two fixed marks in the "limb" tone (see _render's
            # accent_palette) rather than a random scatter — real orca
            # markings sit in specific places (a postorbital eye patch, a
            # flank/belly patch), not scattered evenly like "spots".
            eye_patch_i = int(round(spec["body_len"] * 0.24))
            if i == eye_patch_i and bottom - top >= 2:
                _put(px, x, top + 1, "limb")
            flank_start = int(spec["body_len"] * 0.45)
            flank_end = int(spec["body_len"] * 0.72)
            if flank_start <= i <= flank_end and bottom - top >= 3:
                _put(px, x, bottom - 1, "limb")
                if bottom - top >= 5:
                    _put(px, x, bottom - 2, "limb")


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


def _render(px, spec):
    """Turns a {(x, y): tone} dict into the (body, outline) image pair every
    model ends up as, regardless of which drawing path built it.

    A model with `"accent_palette"` set gets a second, independent hue for
    everything drawn in the "limb" tone (head/snout/pectoral in the linear
    system) — the one way to get a genuinely two-hue model like a turtle's
    green head against its own brown shell, since every other tone still
    comes from one palette the way it always has.
    """
    palette = _add_gradient_tones(resolve_palette(spec["palette"]))
    if spec.get("accent_palette"):
        palette["limb"] = resolve_palette(spec["accent_palette"])["body"]
    else:
        palette["limb"] = palette["fin"]
    body = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    for (x, y), tone in px.items():
        body.putpixel((x, y), palette[tone] + (255,))

    outline = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    for (x, y) in _outline_positions(set(px.keys())):
        outline.putpixel((x, y), (255, 255, 255, 255))
    return body, outline


def draw_fish(spec, seed):
    if spec.get("shape") == "radial":
        return _draw_radial_fish(spec, seed)

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
        height = bottom - top
        for y in range(top, bottom + 1):
            # A smooth back->body->belly gradient (see _add_gradient_tones)
            # instead of the old flat fill with just the top/bottom row
            # picked out — every row in between now shades too, not just
            # the two edges.
            frac = (y - top) / float(height) if height > 0 else 0.5
            _put(px, x, y, _gradient_tone_for(frac))

    _draw_pattern(px, spec, bounds, x0, rng)

    # Snout/bill, drawn along the centreline out in front of the head. A
    # "head_block" spec instead draws an actual rounded head — a small
    # filled circle (same ellipse test _draw_radial_core uses) centred at
    # the tip of the snout — with a thin neck line connecting it back to
    # the body, instead of a whisker line the whole way out or (the
    # previous attempt) a hard-edged rectangle that read as a block
    # bolted on rather than a head. `head_radius` controls its size.
    head_y = int(round(CENTER_Y)) + spec.get("head_offset", 0)
    head_radius = spec.get("head_radius", 2.2)
    neck_cols = snout if not spec.get("head_block") else max(0, snout - int(round(head_radius * 0.8)))
    for k in range(neck_cols):
        _put(px, x0 - 1 - k, head_y, "limb")
    if spec.get("head_block"):
        head_cx = x0 - snout
        r = head_radius
        for dy in range(-int(r) - 1, int(r) + 2):
            for dx in range(-int(r) - 1, int(r) + 2):
                if dx * dx + dy * dy <= r * r:
                    _put(px, head_cx + dx, head_y + dy, "limb")

    if spec.get("dorsal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["dorsal"], -1)
    if spec.get("anal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["anal"], 1)

    pectoral = spec.get("pectoral", True)
    if pectoral:
        fracs = pectoral if isinstance(pectoral, list) else [0.32]
        style = spec.get("pectoral_style", "nub")
        for frac in fracs:
            i = max(1, min(body_len - 1, int(body_len * frac)))
            edge_y = bounds[i][1]
            if style == "flipper":
                _put(px, x0 + i, edge_y + 1, "limb")
                _put(px, x0 + i + 1, edge_y + 1, "limb")
                _put(px, x0 + i + 1, edge_y + 2, "limb")
                _put(px, x0 + i + 2, edge_y + 2, "limb")
                _put(px, x0 + i + 2, edge_y + 3, "limb")
            else:
                _put(px, x0 + i, edge_y + 1, "limb")
                _put(px, x0 + i + 1, edge_y + 1, "limb")

    if spec.get("head_block"):
        # The eye belongs on the head — now the outermost snout columns
        # (see above) — not on the body column formula below, since
        # head_block/head_offset can put the head well clear of the
        # body's own front edge (see the turtle).
        _put(px, x0 - snout, head_y - 1, "eye")
    else:
        eye_i = max(1, int(body_len * 0.14))
        top, bottom = bounds[eye_i]
        eye_y = int(round(CENTER_Y - (CENTER_Y - top) * 0.5))
        _put(px, x0 + eye_i, max(top, min(bottom, eye_y)), "eye")

    peduncle = bounds[body_len - 1]
    _draw_tail(px, spec, x0 + body_len, max(0.5, (peduncle[1] - peduncle[0]) / 2.0), spec["body_h"])

    return _render(px, spec)


# --- Radial body plan --------------------------------------------------
#
# For animals with no head-to-tail axis at all — starfish, crabs, an
# octopus's trailing tentacles. Drawn top-down (the only way this reads at
# 32x16) rather than as a stretched lateral profile: a small core blob plus
# explicit limbs radiating outward at their own angle/length/width, instead
# of the linear system's column-by-column body curve.

def _draw_radial_core(px, cx, cy, rw, rh, tone="body"):
    for y in range(int(math.floor(cy - rh)), int(math.ceil(cy + rh)) + 1):
        for x in range(int(math.floor(cx - rw)), int(math.ceil(cx + rw)) + 1):
            if ((x - cx) / rw) ** 2 + ((y - cy) / rh) ** 2 <= 1.0:
                _put(px, x, y, tone)


def _draw_radial_limb(px, bx, by, angle_deg, length, width, tone="body",
                       curl_deg=0.0, flare=False):
    """One straight (or curled) segment, stamped from the explicit start
    point (bx, by) — not the shared centre — for `length` pixels along
    angle_deg. Returns the segment's end point, so a second segment can
    continue from exactly where this one stopped (see the "bend" handling
    in _draw_radial_fish, for a jointed leg/claw instead of one straight
    ray from the body).

    `curl_deg`, if set, rotates the angle progressively as the segment
    extends (accelerating toward the tip via t**1.6), tracing a
    spiral/hook rather than a straight line — used for octopus tentacles.

    `flare` widens toward the tip instead of the default taper-to-a-point
    — a crab claw is wider at the pincer than at the base, the opposite
    of every other limb shape here.
    """
    steps = max(1, int(round(length)))
    end_x, end_y = bx, by
    for s in range(1, steps + 1):
        t = s / float(steps)
        if flare:
            half_w = max(0.5, width * (0.35 + t * 0.9))
        else:
            half_w = max(0.5, width * (1.0 - t * 0.7))
        cur_angle = angle_deg + curl_deg * (t ** 1.6)
        rad = math.radians(cur_angle)
        dx, dy = math.cos(rad), math.sin(rad)
        pdx, pdy = -dy, dx
        x = bx + dx * s
        y = by + dy * s
        span = int(round(half_w))
        for o in range(-span, span + 1):
            _put(px, int(round(x + pdx * o)), int(round(y + pdy * o)), tone)
        end_x, end_y = x, y
    return end_x, end_y


def _draw_radial_fish(spec, seed):
    rng = random.Random(seed)
    px = {}
    cx = spec.get("cx", FRAME_W / 2.0)
    cy = spec.get("cy", CENTER_Y)
    core_w = spec.get("core_w", 3.0)
    core_h = spec.get("core_h", 3.0)
    _draw_radial_core(px, cx, cy, core_w, core_h)
    for limb in spec.get("limbs", []):
        angle, length, width = limb["angle"], limb["length"], limb["width"]
        tone = limb.get("tone", "body")
        rad = math.radians(angle)
        dx, dy = math.cos(rad), math.sin(rad)
        # Distance from centre to the core's own ellipse boundary along
        # this angle, so the limb starts flush with the body instead of
        # burning most of its length just reaching daylight.
        denom = math.sqrt((dx / core_w) ** 2 + (dy / core_h) ** 2) if core_w and core_h else 0.0
        origin_r = max(0.0, (1.0 / denom) - 1.0) if denom > 0.0 else 0.0
        start_x, start_y = cx + dx * origin_r, cy + dy * origin_r
        end_x, end_y = _draw_radial_limb(px, start_x, start_y, angle, length, width, tone,
                                          limb.get("curl", 0.0), limb.get("flare", False))
        # An optional second segment continuing from wherever the first
        # one stopped, at its own angle/length/width — a real crab leg
        # bends at a joint partway out, it doesn't run dead straight from
        # the body to the tip.
        if "bend" in limb:
            b = limb["bend"]
            _draw_radial_limb(px, end_x, end_y, b["angle"], b["length"], b.get("width", width),
                               b.get("tone", tone), b.get("curl", 0.0), b.get("flare", False))
    if spec.get("pattern") == "spots":
        for pos in list(px.keys()):
            if px[pos] == "body" and rng.random() < 0.25:
                px[pos] = "pattern"
    # A single pixel reads as a dot; two stacked make an actual visible
    # eye at this scale, which matters more here than on a fish since a
    # radial creature has no other "face" cue at all.
    for (ex, ey) in spec.get("eyes", []):
        x, y = int(round(cx + ex)), int(round(cy + ey))
        _put(px, x, y, "eye")
        _put(px, x, y + 1, "eye")
    return _render(px, spec)


# --- The roster ------------------------------------------------------
#
# Grouped by silhouette family, with size deliberately spread across the
# set (tiny 11px minnows up to 24px leviathans) so the models differ in
# bulk as well as in outline and colour.

SPECS = [
    # Small everyday fish.
    {"name": "minnow", "palette": "silver", "body_len": 22, "body_h": 4.8, "tail": "fan", "tail_len": 8},
    {"name": "roach", "palette": "olive", "body_len": 26, "body_h": 5.6, "tail": "fork", "tail_len": 8, "pattern": "line"},
    {"name": "sardine", "palette": "steel", "body_len": 30, "body_h": 4.8, "tail": "fork", "tail_len": 8, "pattern": "line"},
    {"name": "gudgeon", "palette": "sand", "body_len": 26, "body_h": 5.6, "tail": "fan", "tail_len": 8, "pattern": "spots"},
    # Mid-size, plainer builds.
    {"name": "bream", "palette": "pearl", "body_len": 30, "body_h": 8.4, "peak": 0.42, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.6, 4)},
    {"name": "rudd", "palette": "gold", "body_len": 30, "body_h": 7.6, "tail": "fork", "tail_len": 10, "anal": (0.55, 0.85, 4)},
    {"name": "chub", "palette": "slate", "body_len": 36, "body_h": 6.8, "tail": "fan", "tail_len": 8, "pattern": "line"},
    {"name": "trout", "palette": "rose", "body_len": 38, "body_h": 6.8, "tail": "fan", "tail_len": 8, "dorsal": (0.35, 0.6, 3.6), "pattern": "spots"},
    # Deep-bodied and rounded.
    {"name": "perch", "palette": "emerald", "body_len": 32, "body_h": 8.8, "back_bias": 1.15, "belly_bias": 0.85, "tail": "fan", "tail_len": 8, "dorsal": (0.25, 0.55, 4), "pattern": "stripes"},
    {"name": "carp", "palette": "amber", "body_len": 36, "body_h": 9.2, "peak": 0.45, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.7, 3.2), "pattern": "stripes"},
    {"name": "sunfish", "palette": "violet", "body_len": 28, "body_h": 10, "head_h": 0.7, "tail_h": 0.4, "peak": 0.45, "tail": "round", "tail_len": 6, "tail_flare": 0.5, "dorsal": (0.2, 0.6, 2.8), "anal": (0.5, 0.8, 2.8)},
    {"name": "puffer", "palette": "sand", "body_len": 28, "body_h": 10.4, "head_h": 0.45, "tail_h": 0.38, "peak": 0.5, "tail": "point", "tail_len": 6, "pattern": "spots"},
    {"name": "bigeye", "palette": "crimson", "body_len": 30, "body_h": 9.2, "head_h": 0.8, "peak": 0.35, "tail": "fork", "tail_len": 8, "tail_flare": 0.6},
    {"name": "discus", "palette": "teal", "body_len": 28, "body_h": 10.8, "head_h": 0.75, "tail_h": 0.6, "peak": 0.5, "tail": "round", "tail_len": 6, "tail_flare": 0.55, "pattern": "stripes"},
    # Long predators.
    {"name": "pike", "palette": "olive", "body_len": 44, "body_h": 6, "head_h": 0.8, "peak": 0.55, "tail": "fork", "tail_len": 10, "dorsal": (0.65, 0.85, 3.6), "pattern": "spots"},
    {"name": "bass", "palette": "emerald", "body_len": 38, "body_h": 7.6, "tail": "fan", "tail_len": 10, "dorsal": (0.3, 0.6, 4), "pattern": "line"},
    {"name": "barracuda", "palette": "steel", "body_len": 44, "body_h": 5.2, "head_h": 0.75, "peak": 0.5, "tail": "fork", "tail_len": 10, "snout": 2},
    {"name": "grayling", "palette": "violet", "body_len": 36, "body_h": 6, "tail": "fork", "tail_len": 10, "dorsal": (0.25, 0.6, 6)},
    # Eels and serpents.
    {"name": "eel", "palette": "ink", "body_len": 48, "body_h": 5.2, "head_h": 1.0, "tail_h": 0.38, "peak": 0.0, "tail": "point", "tail_len": 8, "pectoral": False, "taper": "linear"},
    {"name": "moray", "palette": "olive", "body_len": 48, "body_h": 5.6, "head_h": 1.0, "tail_h": 0.4, "peak": 0.0, "tail": "point", "tail_len": 8, "dorsal": (0.25, 0.9, 2.4), "pectoral": False, "taper": "linear"},
    {"name": "serpent", "palette": "abyss", "body_len": 46, "body_h": 6.8, "head_h": 0.95, "tail_h": 0.3, "peak": 0.05, "tail": "point", "tail_len": 10, "pattern": "spots", "pectoral": False, "taper": "linear"},
    {"name": "lamprey", "palette": "copper", "body_len": 50, "body_h": 4.8, "head_h": 1.0, "tail_h": 0.45, "peak": 0.0, "tail": "point", "tail_len": 8, "pectoral": False, "pattern": "line", "taper": "linear"},
    # Billed showpieces.
    {"name": "swordfish", "palette": "steel", "body_len": 36, "body_h": 6, "tail": "fork", "tail_len": 10, "tail_flare": 1.1, "snout": 10, "dorsal": (0.2, 0.5, 5.2)},
    {"name": "marlin", "palette": "abyss", "body_len": 34, "body_h": 6.8, "tail": "fork", "tail_len": 10, "tail_flare": 1.1, "snout": 10, "dorsal": (0.2, 0.6, 5.6)},
    {"name": "sailfish", "palette": "violet", "body_len": 34, "body_h": 6, "tail": "fork", "tail_len": 10, "snout": 8, "dorsal": (0.15, 0.75, 6.8)},
    {"name": "needlefish", "palette": "pearl", "body_len": 42, "body_h": 3.6, "head_h": 0.9, "tail": "fork", "tail_len": 8, "snout": 8},
    # Sharks, rays and heavies.
    {"name": "shark", "palette": "slate", "body_len": 40, "body_h": 7.6, "head_h": 0.7, "peak": 0.35, "back_bias": 1.1, "belly_bias": 0.9, "tail": "long", "tail_len": 12, "dorsal": (0.35, 0.6, 5.2)},
    {"name": "hammerhead", "palette": "silver", "body_len": 40, "body_h": 6.8, "head_h": 0.95, "peak": 0.4, "tail": "long", "tail_len": 12, "dorsal": (0.4, 0.6, 4.8)},
    {"name": "ray", "palette": "sand", "body_len": 24, "body_h": 12, "head_h": 0.12, "tail_h": 0.06, "peak": 0.55, "tail": "point", "tail_len": 18, "tail_flare": 0.2, "pectoral": False},
    {"name": "sturgeon", "palette": "ink", "body_len": 44, "body_h": 6, "head_h": 0.8, "peak": 0.5, "tail": "long", "tail_len": 10, "snout": 4, "pattern": "stripes"},
    {"name": "catfish", "palette": "copper", "body_len": 40, "body_h": 7.6, "head_h": 1.0, "peak": 0.3, "tail": "round", "tail_len": 10, "snout": 6, "pattern": "spots"},
    {"name": "leviathan", "palette": "crimson", "body_len": 42, "body_h": 9.2, "head_h": 0.85, "peak": 0.45, "back_bias": 1.1, "belly_bias": 0.9, "tail": "fan", "tail_len": 10, "tail_flare": 1.0, "dorsal": (0.35, 0.75, 3.6), "pattern": "stripes"},
    # Exotics — one-off silhouettes for named species that used to share a
    # model with six-plus other fish (Lamp Squid/Anglerfish/Hadal Chimaera/
    # Manta of the Shallows/the flatfish pair all rode on "serpent"/
    # "bigeye"/"eel"/"ray"), plus dedicated shapes for the Kraken/Wyrm/
    # Behemoth-and-Colossus mythic tier, which used to be three more
    # "serpent"/"leviathan" repaints.
    # Reworked to trail separate tentacle strands (see _draw_tentacles)
    # instead of tapering to one solid point — the mantle stays a normal
    # linear body, only the tail treatment changes.
    {"name": "squid", "palette": "violet", "body_len": 22, "body_h": 7.2, "head_h": 0.85, "tail_h": 0.4, "peak": 0.35, "tail": "tentacles", "tail_len": 18, "tail_strand_count": 7, "pectoral": False, "pattern": "spots"},
    {"name": "angler", "palette": "ink", "body_len": 24, "body_h": 10, "head_h": 0.95, "tail_h": 0.3, "peak": 0.15, "tail": "round", "tail_len": 6, "tail_flare": 0.4, "snout": 4, "dorsal": (0.05, 0.2, 2.4)},
    {"name": "chimaera", "palette": "slate", "body_len": 28, "body_h": 6.4, "head_h": 0.75, "tail_h": 0.15, "peak": 0.3, "tail": "point", "tail_len": 16, "tail_flare": 0.25, "dorsal": (0.08, 0.3, 4.4)},
    {"name": "manta", "palette": "steel", "body_len": 26, "body_h": 13, "head_h": 0.15, "tail_h": 0.05, "peak": 0.5, "tail": "point", "tail_len": 16, "tail_flare": 0.15, "snout": 4, "pectoral": False},
    {"name": "flounder", "palette": "sand", "body_len": 26, "body_h": 11, "head_h": 0.25, "tail_h": 0.2, "peak": 0.5, "tail": "round", "tail_len": 6, "tail_flare": 0.35, "pectoral": False, "pattern": "eyespot"},
    {"name": "kraken", "palette": "abyss", "body_len": 26, "body_h": 10.4, "head_h": 0.85, "tail_h": 0.2, "peak": 0.2, "tail": "point", "tail_len": 18, "tail_flare": 0.5, "dorsal": (0.1, 0.85, 5.2), "anal": (0.1, 0.85, 5.2), "pectoral": False},
    {"name": "wyrm", "palette": "teal", "body_len": 46, "body_h": 6.4, "head_h": 0.9, "tail_h": 0.35, "peak": 0.03, "taper": "linear", "tail": "point", "tail_len": 10, "dorsal": (0.05, 0.95, 3.6), "pectoral": False},
    {"name": "colossus", "palette": "copper", "body_len": 44, "body_h": 10.4, "head_h": 0.85, "tail_h": 0.35, "peak": 0.45, "back_bias": 1.15, "belly_bias": 0.95, "tail": "fan", "tail_len": 10, "tail_flare": 0.6, "dorsal": (0.3, 0.8, 4.4), "pattern": "bars"},
    # Secret tier gets its own faces. All six Secret species used to share
    # a model with an ordinary same-tier fish (Sunlit Mirage/Nightglass
    # Siren both rode "sailfish", Glassfin Wraith rode "needlefish", all
    # three Deep/Storm/Ruins heavies rode "leviathan") — a discovery this
    # rare deserves a silhouette nothing else in the catalog has.
    {"name": "mirage", "palette": "pearl", "body_len": 36, "body_h": 6.4, "head_h": 0.6, "tail_h": 0.3, "peak": 0.42, "tail": "fork", "tail_len": 10, "dorsal": (0.12, 0.85, 6.4), "pattern": "line"},
    {"name": "drownedking", "palette": "abyss", "body_len": 40, "body_h": 8.4, "head_h": 0.85, "tail_h": 0.3, "peak": 0.4, "tail": "long", "tail_len": 12, "dorsal": (0.05, 0.3, 6.4), "snout": 2},
    {"name": "wraith", "palette": "silver", "body_len": 40, "body_h": 4.4, "head_h": 0.6, "tail_h": 0.25, "peak": 0.1, "taper": "linear", "tail": "point", "tail_len": 14, "pectoral": False},
    {"name": "siren", "palette": "violet", "body_len": 38, "body_h": 7.2, "head_h": 0.55, "tail_h": 0.35, "peak": 0.35, "tail": "fan", "tail_len": 12, "tail_flare": 1.1, "dorsal": (0.3, 0.9, 4.8), "anal": (0.5, 0.9, 4)},
    {"name": "longdark", "palette": "ink", "body_len": 42, "body_h": 11.2, "head_h": 0.5, "tail_h": 0.4, "peak": 0.55, "back_bias": 1.2, "belly_bias": 1.2, "tail": "fan", "tail_len": 10, "tail_flare": 0.7, "pectoral": False},
    {"name": "keeper", "palette": "sand", "body_len": 40, "body_h": 9.6, "head_h": 0.75, "tail_h": 0.3, "peak": 0.42, "back_bias": 1.1, "belly_bias": 0.9, "tail": "round", "tail_len": 8, "tail_flare": 0.5, "dorsal": (0.1, 0.85, 4.8), "pattern": "stripes", "snout": 2},
    # The "shark" model alone covered four species spanning Epic to
    # Legendary; Great White and Thresher are both distinctive enough by
    # name/lore (thresher tails run as long as the body) to earn their own.
    {"name": "greatwhite", "palette": "steel", "body_len": 42, "body_h": 8.8, "head_h": 0.65, "tail_h": 0.3, "peak": 0.32, "tail": "long", "tail_len": 12, "dorsal": (0.32, 0.55, 6), "snout": 2},
    {"name": "thresher", "palette": "slate", "body_len": 32, "body_h": 6.8, "head_h": 0.6, "tail_h": 0.35, "peak": 0.35, "tail": "long", "tail_len": 24, "tail_flare": 0.35, "dorsal": (0.3, 0.5, 3.6)},
    # Non-fish sea life. Both still fit the head-to-tail silhouette system;
    # starfish and octopus don't (radial/many-armed body plans) and are
    # deliberately not attempted here — see the project notes.
    {"name": "seahorse", "palette": "rose", "body_len": 18, "body_h": 5.2, "head_h": 0.65, "tail_h": 0.1, "peak": 0.3, "back_bias": 1.3, "belly_bias": 0.7, "tail": "point", "tail_len": 16, "tail_flare": 0.1, "snout": 8, "dorsal": (0.15, 0.5, 3.2), "pectoral": False},
    {"name": "jellyfish", "palette": "pearl", "body_len": 18, "body_h": 8.4, "head_h": 0.35, "tail_h": 0.1, "peak": 0.55, "tail": "point", "tail_len": 18, "tail_flare": 0.15, "pectoral": False},
    # River Mouth spot: a real-world-heavy batch (mullet/catfish/sheepshead/
    # redfish/snook/tarpon/mudskipper/flounder-family are genuine estuary
    # and tidal-flat species), mixed with a few invented ones rather than
    # sorted apart from them by rarity. Shared with several existing models
    # where a real species is a close enough family match (goby -> gudgeon,
    # eel -> the existing eel model, flounder/sole/toad -> the existing
    # flounder model) instead of drawing a near-duplicate silhouette.
    {"name": "mullet", "palette": "olive", "body_len": 28, "body_h": 6, "head_h": 0.5, "tail_h": 0.3, "peak": 0.4, "tail": "fork", "tail_len": 10, "dorsal": (0.35, 0.55, 3.2)},
    {"name": "brackcat", "palette": "slate", "body_len": 30, "body_h": 6.8, "head_h": 0.85, "tail_h": 0.35, "peak": 0.25, "taper": "linear", "tail": "round", "tail_len": 8, "snout": 6},
    {"name": "sheepshead", "palette": "silver", "body_len": 26, "body_h": 8.8, "head_h": 0.6, "tail_h": 0.35, "peak": 0.35, "back_bias": 1.1, "tail": "fork", "tail_len": 8, "dorsal": (0.25, 0.7, 4.4), "pattern": "stripes"},
    # The eyespot near the tail mirrors the real fish's own dark spot.
    {"name": "redfish", "palette": "copper", "body_len": 30, "body_h": 7.2, "head_h": 0.55, "tail_h": 0.3, "peak": 0.38, "tail": "fan", "tail_len": 8, "tail_flare": 0.7, "dorsal": (0.3, 0.6, 3.6), "pattern": "eyespot"},
    # Likewise the "line" pattern mirrors the real fish's own lateral line.
    {"name": "snook", "palette": "steel", "body_len": 34, "body_h": 6, "head_h": 0.5, "tail_h": 0.3, "peak": 0.42, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.55, 3.2), "pattern": "line"},
    {"name": "tarpon", "palette": "pearl", "body_len": 40, "body_h": 9.2, "head_h": 0.6, "tail_h": 0.35, "peak": 0.4, "tail": "fork", "tail_len": 12, "dorsal": (0.35, 0.55, 5.2), "snout": 2},
    # High head_h reads as the mudskipper's bulging top-mounted eyes; shared
    # by the Common and Epic ("giant") versions, same small/big-variant
    # -shares-a-model precedent as the existing behemoth/colossus models.
    {"name": "mudskipper", "palette": "olive", "body_len": 22, "body_h": 5.2, "head_h": 0.95, "tail_h": 0.25, "peak": 0.2, "taper": "linear", "tail": "point", "tail_len": 8, "dorsal": (0.15, 0.9, 3.6), "pattern": "spots"},
    {"name": "shrimpjaw", "palette": "sand", "body_len": 16, "body_h": 4, "head_h": 0.7, "tail_h": 0.2, "peak": 0.3, "tail": "point", "tail_len": 6, "snout": 4},
    {"name": "tidewalker", "palette": "amber", "body_len": 34, "body_h": 6.4, "head_h": 0.6, "tail_h": 0.4, "peak": 0.35, "back_bias": 1.2, "tail": "long", "tail_len": 16, "dorsal": (0.2, 0.6, 4), "pattern": "bars"},
    # Same tall-flat-round-tailed silhouette family as "flounder" (index
    # 36, reused by three Tidal Flats species already), just bigger and
    # darker — a Legendary deserves its own entry rather than only ever
    # appearing as a recolour, matching how the Secret tier got its own
    # dedicated models rather than continuing to share with common ones.
    {"name": "flatking", "palette": "abyss", "body_len": 40, "body_h": 12, "head_h": 0.25, "tail_h": 0.2, "peak": 0.5, "tail": "round", "tail_len": 8, "tail_flare": 0.35, "pectoral": False, "pattern": "spots"},
    # Abyssal Trench: expedition-only habitat, reachable by no fishing spot
    # (see FishCatalog.EXPEDITION_HABITATS) — deep enough that several of
    # its species carry their own light rather than relying on any.
    {"name": "trenchsmelt", "palette": "abyss", "body_len": 20, "body_h": 4.4, "tail": "fork", "tail_len": 8, "pattern": "glow"},
    {"name": "voidangler", "palette": "ink", "body_len": 28, "body_h": 7.6, "head_h": 0.85, "peak": 0.3, "tail": "point", "tail_len": 6, "snout": 4, "pattern": "glow"},
    {"name": "hadalmaw", "palette": "abyss", "body_len": 40, "body_h": 8.8, "head_h": 0.9, "peak": 0.25, "tail": "long", "tail_len": 12, "snout": 2, "pattern": "glow"},
    {"name": "coelacanth", "palette": "slate", "body_len": 34, "body_h": 8, "peak": 0.45, "tail": "round", "tail_len": 10, "tail_flare": 0.6, "dorsal": (0.3, 0.65, 4), "anal": (0.5, 0.8, 3.2), "pattern": "glow"},
    # Real-world species added to existing habitats — dedicated models only
    # for the ones distinctive enough to earn one; plainer real fish reuse
    # an existing family-appropriate model instead (see fish_catalog.gd's
    # comments on which species share which of the models below with
    # earlier entries).
    {"name": "zander", "palette": "slate", "body_len": 38, "body_h": 6, "head_h": 0.7, "peak": 0.45, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.6, 4.4), "pattern": "spots"},
    {"name": "garibaldi", "palette": "amber", "body_len": 26, "body_h": 9.2, "head_h": 0.6, "peak": 0.45, "tail": "fan", "tail_len": 8, "dorsal": (0.3, 0.6, 3.2)},
    {"name": "lingcod", "palette": "olive", "body_len": 40, "body_h": 6.8, "head_h": 0.75, "peak": 0.35, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.25, 0.85, 3.6), "pattern": "spots"},
    {"name": "wolfeel", "palette": "slate", "body_len": 42, "body_h": 5.2, "head_h": 0.9, "taper": "linear", "tail": "point", "tail_len": 8, "snout": 2, "pattern": "spots"},
    {"name": "californiasheephead", "palette": "crimson", "body_len": 30, "body_h": 7.6, "head_h": 0.7, "peak": 0.4, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.3, 0.7, 3.2)},
    {"name": "clownfish", "palette": "amber", "body_len": 20, "body_h": 6.8, "head_h": 0.65, "peak": 0.4, "tail": "fan", "tail_len": 6, "pattern": "bars"},
    {"name": "parrotfish", "palette": "teal", "body_len": 32, "body_h": 8.4, "head_h": 0.55, "peak": 0.4, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.3, 0.75, 3.6)},
    {"name": "picassotriggerfish", "palette": "gold", "body_len": 26, "body_h": 8, "head_h": 0.6, "tail_h": 0.5, "peak": 0.4, "tail": "round", "tail_len": 6, "dorsal": (0.15, 0.4, 3.2), "pattern": "bars"},
    {"name": "biggrouper", "palette": "teal", "body_len": 38, "body_h": 10, "head_h": 0.95, "peak": 0.25, "tail": "round", "tail_len": 8, "dorsal": (0.3, 0.85, 4)},
    {"name": "mahimahi", "palette": "gold", "body_len": 36, "body_h": 7.2, "head_h": 0.85, "peak": 0.2, "tail": "fork", "tail_len": 10, "dorsal": (0.05, 0.95, 4.8), "pattern": "spots"},
    {"name": "wahoo", "palette": "steel", "body_len": 44, "body_h": 5.2, "head_h": 0.6, "peak": 0.4, "tail": "fork", "tail_len": 10, "snout": 2, "pattern": "bars"},
    {"name": "greenlandshark", "palette": "slate", "body_len": 44, "body_h": 9.2, "head_h": 0.55, "peak": 0.3, "tail": "long", "tail_len": 12, "dorsal": (0.35, 0.5, 4)},
    {"name": "viperfish", "palette": "ink", "body_len": 36, "body_h": 3.6, "taper": "linear", "tail": "point", "tail_len": 10, "snout": 6, "dorsal": (0.1, 0.3, 4.8)},
    {"name": "fangtooth", "palette": "abyss", "body_len": 18, "body_h": 6.4, "head_h": 0.95, "peak": 0.25, "tail": "point", "tail_len": 6, "snout": 2},
    {"name": "oarfish", "palette": "silver", "body_len": 48, "body_h": 4, "taper": "linear", "tail": "point", "tail_len": 6, "dorsal": (0.0, 1.0, 6)},
    {"name": "goblinshark", "palette": "rose", "body_len": 38, "body_h": 6.4, "head_h": 0.6, "peak": 0.4, "tail": "long", "tail_len": 12, "snout": 8},
    # Marine reptiles and mammals: all still fit the head-to-tail silhouette
    # system (torpedo/oval body plans), unlike octopus and crab (radial,
    # limbs to the sides) which stay declined for the same reason starfish
    # was — see the "seahorse"/"jellyfish" comment above. Several of these
    # lean on `dorsal: False` for a real distinguishing trait: belugas,
    # narwhals, manatees, walruses and seals genuinely have no dorsal fin,
    # unlike every fish model above.
    # head_block widens the snout into a visible head instead of a
    # whisker, offset a couple pixels below the shell's dome (head_offset)
    # so it reads as hanging in front rather than fused to the shell; a
    # low head_h pinches the neck narrow first. Pectoral is now a
    # front-and-rear flipper pair (real turtles have four limbs, not one
    # fin) using the paddle-shaped "flipper" style rather than the
    # default nub.
    # Two-hue via accent_palette (see _render): the shell (body/back/belly)
    # stays "copper" brown, while the head/snout/flippers — anything drawn
    # in the "limb" tone — pull from "emerald" instead, for a real green
    # -head-on-brown-shell look rather than one palette doing both.
    # Full redo: the previous version's tall back_bias/peak made the shell
    # read as a round ball rather than a turtle — a real shell is wider
    # than it is tall, a flattened oval, not a dome. body_h pulled way
    # down relative to body_len and back_bias/belly_bias both eased off
    # for a low, elongated profile; "scutes" tried again now that there's
    # 4x the pixel area to actually resolve a tiled plate pattern in
    # (it read as noise at the old 32x16 resolution, see the earlier
    # comment on this style — worth another look at 64x32).
    # Tail shortened to a real stub (real turtles barely have a visible
    # one) rather than a long, barely-tapering plank; head_offset dropped
    # since head_block now sits at the outermost snout columns (see
    # draw_fish) so it no longer needs as much extra downward push to
    # read as separate from the shell.
    {"name": "turtle", "palette": "copper", "accent_palette": "emerald", "body_len": 22, "body_h": 6.2, "head_h": 0.2, "tail_h": 0.15, "peak": 0.5, "back_bias": 1.12, "belly_bias": 0.68, "taper": "linear", "tail": "round", "tail_len": 3, "tail_flare": 0.4, "snout": 6, "head_block": True, "head_offset": 2, "pectoral": [0.18, 0.82], "pectoral_style": "flipper", "dorsal": False, "pattern": "scutes"},
    {"name": "dolphin", "palette": "steel", "body_len": 30, "body_h": 6.8, "head_h": 0.55, "tail_h": 0.3, "peak": 0.38, "tail": "fan", "tail_len": 12, "tail_flare": 0.55, "snout": 4, "dorsal": (0.42, 0.62, 3.6)},
    # The tall dorsal fin is the one silhouette trait everyone recognizes;
    # kept the palette dark and plain rather than fighting the fixed
    # per-palette pattern colour for a true black/white patch look.
    # "ink" (near-black) body with "pearl" (near-white) accent patches —
    # a real orca's colouring is the single most recognisable thing about
    # it, more than the silhouette alone.
    {"name": "orca", "palette": "ink", "accent_palette": "pearl", "body_len": 34, "body_h": 8.4, "head_h": 0.6, "tail_h": 0.35, "peak": 0.4, "tail": "fan", "tail_len": 12, "tail_flare": 0.7, "dorsal": (0.4, 0.62, 6.8), "pattern": "patches"},
    # Broad, flat "round"-style tail (a real fluke, not a fish's fan/fork)
    # plus paddle-shaped "flipper" pectorals (real humpback flippers are
    # enormous) rather than the generic small fin nub every fish uses —
    # both were the two biggest reasons this read as "just a big fish".
    {"name": "whale", "palette": "steel", "body_len": 38, "body_h": 10, "head_h": 0.55, "tail_h": 0.3, "peak": 0.35, "back_bias": 1.05, "belly_bias": 1.1, "tail": "round", "tail_len": 14, "tail_flare": 1.3, "dorsal": (0.55, 0.68, 1.8), "pectoral": [0.3], "pectoral_style": "flipper", "pattern": "spots"},
    {"name": "shrimp", "palette": "rose", "body_len": 12, "body_h": 3.6, "head_h": 0.6, "tail_h": 0.25, "peak": 0.35, "tail": "fan", "tail_len": 6, "tail_flare": 0.6, "snout": 4, "dorsal": False, "pectoral": False, "pattern": "bars"},
    {"name": "flyingfish", "palette": "silver", "body_len": 20, "body_h": 4.4, "head_h": 0.5, "tail_h": 0.35, "peak": 0.3, "tail": "long", "tail_len": 10, "tail_flare": 0.3, "snout": 2, "dorsal": (0.3, 0.55, 2.4)},
    {"name": "beluga", "palette": "pearl", "body_len": 26, "body_h": 7.2, "head_h": 0.7, "tail_h": 0.25, "peak": 0.45, "back_bias": 1.05, "tail": "fan", "tail_len": 10, "tail_flare": 0.5, "dorsal": False},
    {"name": "narwhal", "palette": "silver", "body_len": 26, "body_h": 6.4, "head_h": 0.55, "tail_h": 0.25, "peak": 0.4, "tail": "fan", "tail_len": 10, "tail_flare": 0.45, "snout": 8, "dorsal": False, "pattern": "spots"},
    {"name": "manatee", "palette": "slate", "body_len": 24, "body_h": 8.8, "head_h": 0.55, "tail_h": 0.3, "peak": 0.55, "back_bias": 0.95, "belly_bias": 1.15, "taper": "linear", "tail": "round", "tail_len": 8, "tail_flare": 0.4, "snout": 2, "dorsal": False},
    {"name": "leopardseal", "palette": "slate", "body_len": 26, "body_h": 5.6, "head_h": 0.55, "tail_h": 0.2, "peak": 0.35, "tail": "point", "tail_len": 6, "snout": 4, "dorsal": False, "pattern": "spots"},
    {"name": "seadragon", "palette": "emerald", "body_len": 20, "body_h": 5.6, "head_h": 0.6, "tail_h": 0.15, "peak": 0.35, "back_bias": 1.2, "tail": "point", "tail_len": 14, "tail_flare": 0.2, "snout": 6, "dorsal": (0.2, 0.55, 4), "anal": (0.5, 0.8, 3.2), "pectoral": False, "pattern": "line"},
    {"name": "sawfish", "palette": "sand", "body_len": 32, "body_h": 6, "head_h": 0.45, "tail_h": 0.3, "peak": 0.3, "tail": "long", "tail_len": 12, "snout": 8, "dorsal": (0.55, 0.75, 3.2)},
    {"name": "walrus", "palette": "copper", "body_len": 26, "body_h": 8.8, "head_h": 0.6, "tail_h": 0.3, "peak": 0.5, "back_bias": 1.0, "belly_bias": 1.1, "taper": "linear", "tail": "round", "tail_len": 6, "snout": 8, "dorsal": False},
    {"name": "whaleshark", "palette": "abyss", "body_len": 40, "body_h": 10, "head_h": 0.7, "tail_h": 0.4, "peak": 0.42, "back_bias": 1.1, "tail": "long", "tail_len": 16, "tail_flare": 0.5, "snout": 2, "dorsal": (0.45, 0.65, 4.4), "pattern": "spots"},
    {"name": "elephantseal", "palette": "sand", "body_len": 30, "body_h": 9.2, "head_h": 0.55, "tail_h": 0.25, "peak": 0.5, "back_bias": 1.0, "belly_bias": 1.15, "taper": "linear", "tail": "round", "tail_len": 6, "snout": 6, "dorsal": False},
    # The near-absent tail is the point: a real ocean sunfish looks "cut
    # off" right behind its huge mirrored dorsal/anal fins.
    {"name": "molamola", "palette": "pearl", "body_len": 18, "body_h": 11.2, "head_h": 0.5, "tail_h": 0.2, "peak": 0.55, "tail": "round", "tail_len": 2, "tail_flare": 0.2, "dorsal": (0.35, 0.55, 6.8), "anal": (0.35, 0.55, 6), "pattern": "spots"},
    # Radial body plan (see _draw_radial_fish above) — animals with no
    # head-to-tail axis, drawn top-down instead of in lateral profile.
    # Angles: 0=right, 90=down, 180=left, 270=up.
    {
        "name": "starfish", "shape": "radial", "palette": "amber",
        "core_w": 4.4, "core_h": 4.4,
        "limbs": [
            {"angle": a, "length": 12, "width": 3.6}
            for a in (18, 90, 162, 234, 306)
        ],
        "pattern": "spots",
    },
    {
        "name": "crab", "shape": "radial", "palette": "crimson",
        "cy": 12, "core_w": 6.4, "core_h": 5.2,
        # Fully jointed rebuild: every limb bends once partway out (see
        # "bend" in _draw_radial_fish) instead of running dead straight
        # from the body — a real crab's claws and legs both have a visible
        # elbow, which is most of what makes the silhouette read as
        # articulated rather than spiky. Claws go up first, then the bend
        # swings outward into a flared, "belly"-toned pincer (the
        # lightest crimson tone, so it reads as a separate part from the
        # shell). Legs go down-and-out, then bend to angle further
        # outward for the lower leg, the same two-segment shape real crab
        # legs make.
        "limbs": [
            {"angle": 255, "length": 8, "width": 2.6,
             "bend": {"angle": 200, "length": 8, "width": 3.8, "tone": "belly", "flare": True}},
            {"angle": 285, "length": 8, "width": 2.6,
             "bend": {"angle": 340, "length": 8, "width": 3.8, "tone": "belly", "flare": True}},
            {"angle": 25, "length": 6, "width": 2.4, "bend": {"angle": 45, "length": 8, "width": 1.8}},
            {"angle": 50, "length": 6, "width": 2.4, "bend": {"angle": 70, "length": 8, "width": 1.8}},
            {"angle": 75, "length": 6, "width": 2.4, "bend": {"angle": 95, "length": 8, "width": 1.8}},
            {"angle": 105, "length": 6, "width": 2.4, "bend": {"angle": 85, "length": 8, "width": 1.8}},
            {"angle": 130, "length": 6, "width": 2.4, "bend": {"angle": 110, "length": 8, "width": 1.8}},
            {"angle": 155, "length": 6, "width": 2.4, "bend": {"angle": 135, "length": 8, "width": 1.8}},
        ],
        "eyes": [(-2, -4), (2, -4)],
    },
    {
        "name": "octopus", "shape": "radial", "palette": "violet",
        "cy": 12, "core_w": 5.2, "core_h": 6.8,
        # Alternating body/back tone bands the tentacles apart from each
        # other, not just from the mantle; curl hooks the outer half of
        # each one so the tips read as tentacles rather than spikes.
        "limbs": [
            {"angle": 95, "length": 12, "width": 2.8, "tone": "body", "curl": 55},
            {"angle": 120, "length": 10, "width": 2.6, "tone": "back", "curl": -50},
            {"angle": 145, "length": 12, "width": 2.6, "tone": "body", "curl": 55},
            {"angle": 170, "length": 10, "width": 2.4, "tone": "back", "curl": -45},
            {"angle": 195, "length": 10, "width": 2.4, "tone": "body", "curl": 45},
            {"angle": 220, "length": 12, "width": 2.6, "tone": "back", "curl": -55},
            {"angle": 245, "length": 10, "width": 2.6, "tone": "body", "curl": 50},
            {"angle": 270, "length": 12, "width": 2.8, "tone": "back", "curl": -55},
        ],
        "eyes": [(-2, -2), (2, -2)],
    },
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
