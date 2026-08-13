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
import colorsys
import io
import math
import os
import random

from PIL import Image, ImageDraw

FRAME_W, FRAME_H = 64, 32
COLUMNS, ROWS = 12, 12
MODEL_COUNT = COLUMNS * ROWS
CENTER_Y = 15.5
OUT_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas.png")
OUTLINE_PATH = os.path.join("assets", "sprites", "fish", "fish_atlas_outline.png")
## A generated GDScript map from model name to atlas frame, so the catalog
## can ask for a sprite by name instead of hardcoding a frame number (see
## write_model_index).
INDEX_PATH = os.path.join("scripts", "fish_models.gd")

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

    # Second rank, added once 16 palettes were being stretched across 134
    # models — several hues were carrying a dozen species each, so whole
    # habitats read as one colour. Same 5-tone shape as above; picked to
    # fill the gaps the first rank left (no true mid-green, no strong
    # blue, no warm off-white, no deep red-purple).
    "jade": [(60, 160, 130), (36, 118, 96), (120, 206, 180), (48, 140, 114), (24, 84, 68)],
    "coral": [(232, 124, 96), (196, 86, 62), (250, 180, 158), (214, 104, 78), (150, 58, 40)],
    "rust": [(170, 84, 44), (132, 60, 30), (212, 134, 92), (150, 72, 36), (94, 40, 20)],
    "plum": [(152, 72, 116), (116, 48, 88), (204, 130, 172), (134, 60, 102), (82, 30, 62)],
    "cobalt": [(64, 104, 196), (40, 72, 156), (120, 160, 232), (52, 88, 174), (26, 48, 110)],
    "moss": [(104, 124, 60), (76, 94, 42), (152, 170, 104), (90, 110, 50), (52, 66, 28)],
    "bronze": [(176, 132, 72), (138, 100, 50), (220, 184, 124), (158, 116, 60), (100, 70, 32)],
    "ivory": [(238, 230, 206), (200, 190, 164), (252, 248, 236), (218, 208, 182), (166, 156, 130)],
    "charcoal": [(86, 82, 78), (58, 55, 52), (130, 126, 120), (72, 68, 64), (38, 36, 34)],
    "mint": [(150, 214, 182), (108, 178, 146), (204, 242, 222), (128, 196, 164), (76, 140, 112)],
    "salmon": [(232, 146, 124), (196, 108, 88), (250, 192, 174), (214, 126, 104), (152, 74, 56)],
    "indigo": [(92, 80, 168), (64, 54, 130), (146, 136, 214), (78, 66, 148), (44, 36, 92)],
    "ochre": [(198, 158, 72), (160, 122, 46), (234, 204, 136), (178, 138, 58), (116, 86, 30)],
    "wine": [(140, 48, 66), (104, 30, 46), (192, 96, 116), (122, 38, 54), (72, 18, 32)],
    "seafoam": [(128, 196, 196), (90, 158, 160), (184, 230, 228), (108, 176, 178), (60, 116, 118)],
    "obsidian": [(52, 54, 70), (32, 34, 48), (88, 92, 116), (42, 44, 58), (20, 20, 30)],
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

## Same reasoning as GLOW_COLOR: teeth/gums/the mouth crease read as
## anatomy, not a body marking, so all three stay fixed colours for every
## model rather than reusing "eye" (which flips dark/light per palette for
## its own contrast reasons and made the first version of teeth vanish
## entirely on some sharks).
TEETH_COLOR = (248, 246, 236)
GUM_COLOR = (196, 48, 48)
MOUTH_LINE_COLOR = (22, 22, 26)


def resolve_palette(name):
    values = PALETTES[name]
    palette = dict(zip(TONE_ORDER, values))
    # A dark eye vanishes on the dark palettes, so flip it to a light dot
    # rather than hand-picking an eye colour for every entry.
    palette["eye"] = (28, 30, 36) if _luminance(palette["body"]) > 110 else (232, 236, 244)
    palette["glow"] = GLOW_COLOR
    palette["teeth"] = TEETH_COLOR
    palette["gum"] = GUM_COLOR
    palette["mouthline"] = MOUTH_LINE_COLOR
    return palette


## How many shading steps a body column is divided into (see
## _add_gradient_tones/_gradient_tone_for). Purely a rendering-quality
## knob — doesn't touch a palette's actual colour data, just how many
## computed in-between steps get sampled from it.
GRADIENT_STEPS = 12


## Hue shifting — the single biggest quality lever in pixel-art shading,
## and what the first version of this gradient was missing. Interpolating a
## ramp straight through RGB only changes brightness, which is why the
## midtones came out grey and lifeless: real shading moves *hue* as well,
## with shadows picking up the ambient (underwater, that's blue) and
## highlights picking up the light source (warm). The shift is strongest at
## the two ends and fades to nothing in the middle, so a palette's own
## "body" colour still reads exactly as authored.
## Shadows steer toward *purple*, not blue. Hue travel takes the short way
## round, and from a warm gold (~0.11) the short way to blue (0.60) runs
## through green — which turned the gold and sand palettes olive and made
## the copper turtle look sunburnt. Purple (0.75) is reached from warm hues
## by going down through red instead, and from greens and blues by going up
## through cyan, so every family gets a plausible shadow. The amounts are
## also far smaller than they look like they should be: on a ramp only a
## dozen steps wide, a shift over ~0.06 reads as a colour change rather
## than as shading.
SHADOW_HUE, LIGHT_HUE = 0.75, 0.14
SHADOW_SHIFT, LIGHT_SHIFT = 0.06, 0.05
SHADOW_SAT, LIGHT_SAT = 1.12, 0.88
## A flat grey carries no hue to steer, yet greys are exactly where a cool
## shadow and a warm highlight read best, so seed just enough saturation
## for the shift to land. Without this the six near-neutral palettes
## (silver, slate, pearl, ink, charcoal, obsidian) would get no benefit.
GREY_SEED_SAT = 0.10


def _lerp_rgb(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def _hue_shift(color, target_hue, amount, sat_gain):
    """Steers a colour's hue toward `target_hue` by `amount` (0..1) and
    scales its saturation, leaving brightness alone."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in color))
    if s < 0.06:
        h = target_hue
        s = GREY_SEED_SAT * (amount / max(SHADOW_SHIFT, LIGHT_SHIFT))
    else:
        delta = ((target_hue - h + 0.5) % 1.0) - 0.5
        h = (h + delta * amount) % 1.0
        s = min(1.0, s * sat_gain)
    r, g, b = colorsys.hsv_to_rgb(h, min(1.0, max(0.0, s)), v)
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


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
            color = _lerp_rgb(palette["back"], palette["body"], i / float(half))
        else:
            color = _lerp_rgb(palette["body"], palette["belly"],
                              (i - half) / float(GRADIENT_STEPS - half - 1))
        # Steer the two ends apart in hue, hardest at the edges and not at
        # all in the middle (see the SHADOW_/LIGHT_ constants above).
        pos = i / float(GRADIENT_STEPS - 1)
        if pos < 0.5:
            k = (0.5 - pos) * 2.0
            color = _hue_shift(color, SHADOW_HUE, SHADOW_SHIFT * k,
                               1.0 + (SHADOW_SAT - 1.0) * k)
        else:
            k = (pos - 0.5) * 2.0
            color = _hue_shift(color, LIGHT_HUE, LIGHT_SHIFT * k,
                               1.0 - (1.0 - LIGHT_SAT) * k)
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


## _put() drops out-of-range writes silently — convenient while drawing,
## but it means a limb or fin that runs off the canvas simply disappears
## with no complaint. That cost real quality twice: both crabs had their
## claws chopped flat against the top edge for many review rounds without
## anyone noticing, and 10 of 134 models turned out to be losing pixels.
## So every dropped write is now recorded and build_atlases() refuses to
## write an atlas that has any, unless --allow-clipping says otherwise.
_clipped = []
_current_model = "?"


def _put(px, x, y, tone):
    if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
        px[(x, y)] = tone
    else:
        _clipped.append((_current_model, x, y))


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
        elif style == "crescent":
            # Flares outward much faster than a fan (sqrt rather than
            # linear), so by the time the notch below opens up there is
            # already a tall span for it to cut into.
            half = base_h + (tip_h - base_h) * math.sqrt(t)
        else:  # fan and fork share the same expanding outline
            half = base_h + (tip_h - base_h) * t
        top = int(round(CENTER_Y - half * bias_top))
        bottom = int(round(CENTER_Y + half * bias_bottom))
        # How far out from the centreline the tail is hollowed out in this
        # column. Zero for the solid styles, and computed exactly as before
        # for "fork" so those 30 models render unchanged.
        if style == "fork":
            notch = (half - 1.2) * t
        elif style == "crescent":
            # A lunate tail: the notch cuts almost to the tips, leaving two
            # thin swept blades instead of the chunky wedge "fork" leaves.
            # This is the tail every fast pelagic fish actually has.
            # The notch has to stay shut over the first third of the tail,
            # or it severs the lobes from the peduncle and the whole tail
            # reads as a separate "V" floating behind the fish.
            # Lobe thickness tapers along the tail so the tips come to a
            # point; a constant lobe leaves two blunt rectangles and the
            # whole tail reads as a bracket rather than a crescent.
            lobe = max(1.2, tip_h * (0.58 - 0.22 * t))
            notch = max(0.0, min(half - lobe,
                                 (tip_h + lobe) * max(0.0, (t - 0.35) / 0.65)))
        else:
            notch = 0.0
        for y in range(top, bottom + 1):
            if abs(y - CENTER_Y) < notch:
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


def _fin_profile(t, style):
    """Height multiplier in 0..1 across an edge fin's span.

    "sine" is the original symmetric bump every pre-existing model uses and
    stays the default, so adding this dispatch changed nothing for them.
    """
    if style == "swept":
        # The shark silhouette: a near-straight leading edge up to an early
        # apex, then a long concave trailing edge sweeping back down. A
        # symmetric sine simply cannot express this, which is most of why
        # the sharks read as generic torpedoes with a bump on top.
        apex = 0.34
        if t <= apex:
            return t / apex
        u = (t - apex) / (1.0 - apex)
        return max(0.0, (1.0 - u) ** 1.8)
    if style == "sail":
        # Rises fast and holds a plateau instead of peaking — a clipped
        # sine, for the tall squared-off fins (sailfish, lionfish).
        return min(1.0, math.sin(t * math.pi) * 1.6)
    return math.sin(t * math.pi)


def _draw_edge_fin(px, x0, bounds, body_len, span_spec, side, style="sine"):
    """Dorsal (side=-1) or anal (side=1) fin riding along the body edge.

    The height is shaped by _fin_profile across the whole span so the fin
    tapers back into the body at both ends.
    """
    start_frac, end_frac, height = span_spec
    a = int(body_len * start_frac)
    b = int(body_len * end_frac)
    span = max(1, b - a)
    for i in range(a, b + 1):
        if not (0 <= i < body_len):
            continue
        t = (i - a) / float(span)
        h = int(round(height * _fin_profile(t, style)))
        edge_y = bounds[i][0] if side < 0 else bounds[i][1]
        for k in range(1, h + 1):
            _put(px, x0 + i, edge_y + k * side, "fin")


def _draw_lure(px, spec, bounds, x0, body_len):
    """An anglerfish's illicium: a thin stalk arcing up and forward off the
    head with a glowing bulb on the end.

    The lure is the entire reason an anglerfish is recognisable and the
    models had no representation of it at all — they were just round fish
    with a "glow" belly row. The bulb uses the same fixed GLOW_COLOR the
    bioluminescence pattern does, so it reads as light rather than skin.
    """
    if not spec.get("lure"):
        return
    length = spec.get("lure_len", 7)
    anchor = max(0, min(body_len - 1, int(round(body_len * spec.get("lure_at", 0.10)))))
    sx = x0 + anchor
    sy = bounds[anchor][0]
    tip_x, tip_y = sx, sy
    for k in range(length):
        t = (k + 1) / float(length)
        # Rises fast, then leans forward over the mouth as it goes.
        tip_x = sx - int(round(t * t * length * 0.85))
        tip_y = sy - (k + 1)
        _put(px, tip_x, tip_y, "fin")
    for dx in (0, 1):
        for dy in (0, -1):
            _put(px, tip_x + dx - 1, tip_y + dy, "glow")


def _draw_finlets(px, spec, bounds, x0, body_len):
    """The sawtooth row of small finlets between the second dorsal and the
    tail on tuna, mackerel and wahoo — a family trait no other fish here
    has, and cheap to draw: one pixel proud of each edge, every other
    column, so they read as a serrated ridge rather than a solid fin.
    """
    count = int(spec.get("finlets", 0))
    if count <= 0:
        return
    start = int(round(body_len * spec.get("finlet_start", 0.62)))
    for f in range(count):
        i = start + f * 2
        if i >= body_len:
            break
        top, bottom = bounds[i]
        _put(px, x0 + i, top - 1, "fin")
        if spec.get("finlets_ventral", True):
            _put(px, x0 + i, bottom + 1, "fin")


def _draw_barbels(px, spec, bounds, x0, snout):
    """Catfish/sturgeon whiskers: strands trailing forward off the snout
    tip, drooping harder the further out the pair sits.
    """
    count = int(spec.get("barbels", 0))
    if count <= 0:
        return
    length = spec.get("barbel_len", 5)
    front_top, front_bottom = bounds[0]
    cy = (front_top + front_bottom) / 2.0
    ox = x0 - snout
    for b in range(count):
        sign = 1 if b % 2 == 0 else -1
        pair = b // 2
        droop = 0.5 + 0.4 * pair
        for k in range(length):
            t = (k + 1) / float(length)
            # Every strand leaves from the snout tip itself and only then
            # fans apart. Starting them already offset vertically (the
            # first attempt) left a diagonal gap between head and whiskers,
            # so they read as a detached starburst floating off the face.
            offset = t * (1 + pair) + t * t * length * droop
            _put(px, ox - 1 - k, int(round(cy + sign * offset)), "fin")


def _hammer_span(spec, bounds):
    """Centre and half-height of a hammerhead's cephalofoil bar.

    Shared by the drawing pass and the eye placement so the eyes can't
    drift off the ends of the bar if one side is retuned.
    """
    front_top, front_bottom = bounds[0]
    cy = (front_top + front_bottom) / 2.0
    half = (front_bottom - front_top) / 2.0 * spec.get("hammer_spread", 1.5)
    return cy, half


def _draw_gills(px, spec, bounds, x0, body_len):
    """The row of short vertical slits behind a shark's head.

    Drawn in the "back" tone (the body's own darker shade) rather than
    "pattern" (the darkest in the palette), and kept short — a slit is a
    crease in the skin just behind the head, and at full "pattern" darkness
    running most of the body height they read as prison bars instead.
    Spaced two columns apart so they stay separate slits, not a block.
    """
    count = int(spec.get("gills", 0))
    if count <= 0:
        return
    start_i = max(2, int(round(body_len * spec.get("gill_start", 0.11))))
    for g in range(count):
        i = start_i + g * 2
        if i >= body_len:
            break
        top, bottom = bounds[i]
        h = bottom - top
        if h < 4:
            continue
        for y in range(top + max(1, int(round(h * 0.34))),
                       top + max(2, int(round(h * 0.60))) + 1):
            _put(px, x0 + i, y, "back")


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
    # Tag whatever _put() drops with the model that lost it (see _clipped).
    global _current_model
    _current_model = spec.get("name", "?")
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
    if spec.get("head_block") and neck_cols > 0:
        # Anchor the neck to the shell's own front-edge midpoint instead of
        # a fixed row, and interpolate down to head_y — a thin front edge
        # (low head_h) otherwise leaves the neck floating below the shell
        # with a visible gap rather than actually touching it.
        front_top, front_bottom = bounds[0]
        attach_y = (front_top + front_bottom) / 2.0
        neck_width = spec.get("neck_width", 3)
        for k in range(neck_cols):
            t = k / float(neck_cols - 1) if neck_cols > 1 else 1.0
            y = int(round(attach_y + (head_y - attach_y) * t))
            for w in range(neck_width):
                _put(px, x0 - 1 - k, y + w, "limb")
    elif spec.get("snout_style") == "cone":
        # A solid tapering wedge carrying the body's own gradient instead
        # of the default 1px whisker — a predator's conical snout rather
        # than a billfish's needle. The whisker is right for a swordfish
        # or a garfish and wrong for everything with an actual head, which
        # is why the sharks looked blunt-nosed with a spike glued on.
        front_top, front_bottom = bounds[0]
        cy = (front_top + front_bottom) / 2.0
        half0 = (front_bottom - front_top) / 2.0
        for k in range(neck_cols):
            t = (k + 1) / float(neck_cols)
            half = half0 * (1.0 - t) * spec.get("snout_taper", 0.9)
            top_y = int(round(cy - half))
            bot_y = int(round(cy + half))
            height = max(1, bot_y - top_y)
            for y in range(top_y, bot_y + 1):
                _put(px, x0 - 1 - k, y, _gradient_tone_for((y - top_y) / float(height)))
    elif spec.get("snout_style") == "hammer":
        # The cephalofoil: a vertical bar standing proud of the body on
        # both sides. The one feature that makes a hammerhead read as a
        # hammerhead rather than just another grey shark, and previously
        # not represented at all — the model only had a high head_h.
        cy, half = _hammer_span(spec, bounds)
        top_y = int(round(cy - half))
        bot_y = int(round(cy + half))
        height = max(1, bot_y - top_y)
        for k in range(neck_cols):
            for y in range(top_y, bot_y + 1):
                _put(px, x0 - 1 - k, y, _gradient_tone_for((y - top_y) / float(height)))
    else:
        for k in range(neck_cols):
            _put(px, x0 - 1 - k, head_y, "limb")
    if spec.get("head_block"):
        head_cx = x0 - snout
        r = head_radius
        for dy in range(-int(r) - 1, int(r) + 2):
            for dx in range(-int(r) - 1, int(r) + 2):
                if dx * dx + dy * dy <= r * r:
                    _put(px, head_cx + dx, head_y + dy, "limb")

    fin_style = spec.get("fin_style", "sine")
    if spec.get("dorsal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["dorsal"], -1, fin_style)
    # A small second dorsal sitting well back toward the tail. Optional and
    # separate from "dorsal" rather than a list, so the 100+ single-finned
    # models keep the exact spec shape they already had.
    if spec.get("dorsal2"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["dorsal2"], -1, fin_style)
    if spec.get("anal"):
        _draw_edge_fin(px, x0, bounds, body_len, spec["anal"], 1, fin_style)

    _draw_gills(px, spec, bounds, x0, body_len)
    _draw_finlets(px, spec, bounds, x0, body_len)
    _draw_barbels(px, spec, bounds, x0, snout)
    _draw_lure(px, spec, bounds, x0, body_len)

    pectoral = spec.get("pectoral", True)
    if pectoral:
        fracs = pectoral if isinstance(pectoral, list) else [0.32]
        style = spec.get("pectoral_style", "nub")
        for frac in fracs:
            i = max(1, min(body_len - 1, int(body_len * frac)))
            edge_y = bounds[i][1]
            if style == "blade":
                # A long swept-back pectoral: a solid wedge whose upper
                # edge stays welded to the belly for the first half and
                # then peels away to meet the lower edge in a point. Drawn
                # as a filled span per column rather than a fixed-thickness
                # strip, which is what made the first attempt read as a
                # detached wire trailing behind the fish instead of a fin.
                blade_len = spec.get("pectoral_len", 7)
                depth = max(2, int(round(blade_len * 0.8)))
                for k in range(blade_len):
                    t = k / float(max(1, blade_len - 1))
                    bot = 1 + int(round(depth * t))
                    top = 1 + int(round(depth * max(0.0, (t - 0.5) / 0.5) * 0.85))
                    for d in range(top, bot + 1):
                        _put(px, x0 + i + k, edge_y + d, "fin")
            elif style == "flipper":
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
    elif spec.get("snout_style") == "hammer":
        # A hammerhead's eyes are out on the tips of the bar, which is the
        # whole point of the shape — placing them on the body column like
        # every other fish would waste it.
        cy, half = _hammer_span(spec, bounds)
        _put(px, x0 - snout, int(round(cy - half)) + 1, "eye")
        _put(px, x0 - snout, int(round(cy + half)) - 1, "eye")
    else:
        eye_i = max(1, int(body_len * 0.14))
        top, bottom = bounds[eye_i]
        eye_y = int(round(CENTER_Y - (CENTER_Y - top) * 0.5))
        _put(px, x0 + eye_i, max(top, min(bottom, eye_y)), "eye")

    if spec.get("teeth"):
        # A real open jaw, not just marks floating on the belly: extends
        # the silhouette down a couple of pixels for a short run of
        # columns near the head (the lower jaw), with a dark mouthline
        # crease at the original belly edge and a red/white gum-and-tooth
        # checkerboard riding just inside it — modelled directly on a
        # reference image the user supplied of a hand-drawn pixel shark.
        jaw_len = max(4, int(round(body_len * 0.14)))
        start_i = max(1, int(round(body_len * 0.02)))
        for k in range(jaw_len):
            i = min(body_len - 1, start_i + k)
            mouth_y = bounds[i][1]
            _put(px, x0 + i, mouth_y, "mouthline")
            _put(px, x0 + i, mouth_y + 1, "teeth" if k % 2 == 0 else "gum")
            _put(px, x0 + i, mouth_y + 2, "belly")

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
    {"name": "trout", "palette": "salmon", "body_len": 38, "body_h": 6.8, "tail": "fan", "tail_len": 8, "dorsal": (0.35, 0.6, 3.6), "pattern": "spots"},
    # Deep-bodied and rounded.
    {"name": "perch", "palette": "emerald", "body_len": 32, "body_h": 8.8, "back_bias": 1.15, "belly_bias": 0.85, "tail": "fan", "tail_len": 8, "dorsal": (0.25, 0.55, 4), "pattern": "stripes"},
    {"name": "carp", "palette": "amber", "body_len": 36, "body_h": 9.2, "peak": 0.45, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.7, 3.2), "pattern": "stripes"},
    {"name": "sunfish", "palette": "violet", "body_len": 28, "body_h": 10, "head_h": 0.7, "tail_h": 0.4, "peak": 0.45, "tail": "round", "tail_len": 6, "tail_flare": 0.5, "dorsal": (0.2, 0.6, 2.8), "anal": (0.5, 0.8, 2.8)},
    {"name": "puffer", "palette": "sand", "body_len": 28, "body_h": 10.4, "head_h": 0.45, "tail_h": 0.38, "peak": 0.5, "tail": "point", "tail_len": 6, "pattern": "spots"},
    {"name": "bigeye", "palette": "crimson", "body_len": 30, "body_h": 9.2, "head_h": 0.8, "peak": 0.35, "tail": "fork", "tail_len": 8, "tail_flare": 0.6},
    {"name": "discus", "palette": "teal", "body_len": 28, "body_h": 10.8, "head_h": 0.75, "tail_h": 0.6, "peak": 0.5, "tail": "round", "tail_len": 6, "tail_flare": 0.55, "pattern": "stripes"},
    # Long predators.
    {"name": "pike", "palette": "olive", "body_len": 44, "body_h": 6, "head_h": 0.8, "peak": 0.55, "tail": "fork", "tail_len": 10, "dorsal": (0.65, 0.85, 3.6), "pattern": "spots", "teeth": True},
    {"name": "bass", "palette": "emerald", "body_len": 38, "body_h": 7.6, "tail": "fan", "tail_len": 10, "dorsal": (0.3, 0.6, 4), "pattern": "line"},
    {"name": "barracuda", "palette": "steel", "body_len": 44, "body_h": 5.2, "head_h": 0.75, "peak": 0.5, "tail": "fork", "tail_len": 10, "snout": 2, "teeth": True},
    {"name": "grayling", "palette": "violet", "body_len": 36, "body_h": 6, "tail": "fork", "tail_len": 10, "dorsal": (0.25, 0.6, 6)},
    # Eels and serpents.
    {"name": "eel", "palette": "ink", "body_len": 48, "body_h": 5.2, "head_h": 1.0, "tail_h": 0.38, "peak": 0.0, "tail": "point", "tail_len": 8, "pectoral": False, "taper": "linear"},
    {"name": "moray", "palette": "olive", "body_len": 48, "body_h": 5.6, "head_h": 1.0, "tail_h": 0.4, "peak": 0.0, "tail": "point", "tail_len": 8, "dorsal": (0.25, 0.9, 2.4), "pectoral": False, "taper": "linear", "teeth": True},
    {"name": "serpent", "palette": "abyss", "body_len": 46, "body_h": 6.8, "head_h": 0.95, "tail_h": 0.3, "peak": 0.05, "tail": "point", "tail_len": 10, "pattern": "spots", "pectoral": False, "taper": "linear"},
    {"name": "lamprey", "palette": "obsidian", "body_len": 50, "body_h": 4.8, "head_h": 1.0, "tail_h": 0.45, "peak": 0.0, "tail": "point", "tail_len": 8, "pectoral": False, "pattern": "line", "taper": "linear"},
    # Billed showpieces.
    {"name": "swordfish", "palette": "steel", "body_len": 36, "body_h": 6, "tail": "crescent", "tail_len": 10, "tail_flare": 1.1, "snout": 10, "dorsal": (0.2, 0.5, 5.2)},
    {"name": "marlin", "palette": "abyss", "body_len": 34, "body_h": 6.8, "tail": "crescent", "tail_len": 10, "tail_flare": 1.1, "snout": 10, "dorsal": (0.2, 0.6, 5.6)},
    {"name": "sailfish", "palette": "violet", "body_len": 34, "body_h": 6, "tail": "crescent", "tail_len": 10, "snout": 8, "dorsal": (0.15, 0.75, 6.8), "fin_style": "sail"},
    {"name": "needlefish", "palette": "pearl", "body_len": 42, "body_h": 3.6, "head_h": 0.9, "tail": "fork", "tail_len": 8, "snout": 8},
    # Sharks, rays and heavies.
    # The shark family all share the same anatomy kit (see the primitives
    # near the top): a swept first dorsal, a small second dorsal, an anal
    # fin, long blade pectorals, five gill slits and a conical snout.
    # What separates them is proportion and one signature trait each.
    {"name": "shark", "palette": "slate", "body_len": 40, "body_h": 7.6, "head_h": 0.7, "peak": 0.35, "back_bias": 1.1, "belly_bias": 0.9, "tail": "long", "tail_len": 12, "snout": 5, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.33, 0.70, 5.6), "dorsal2": (0.76, 0.92, 2.0), "anal": (0.72, 0.88, 1.8), "pectoral": [0.24], "pectoral_style": "blade", "pectoral_len": 8, "gills": 5, "teeth": True},
    # Signature: the cephalofoil, plus the unusually tall narrow first
    # dorsal real hammerheads carry.
    {"name": "hammerhead", "palette": "silver", "body_len": 40, "body_h": 6.4, "head_h": 0.8, "peak": 0.4, "tail": "long", "tail_len": 12, "snout": 3, "snout_style": "hammer", "hammer_spread": 1.5, "fin_style": "swept", "dorsal": (0.30, 0.62, 7.0), "dorsal2": (0.76, 0.92, 1.8), "anal": (0.72, 0.88, 1.6), "pectoral": [0.26], "pectoral_style": "blade", "pectoral_len": 7, "gills": 5, "teeth": True},
    {"name": "ray", "palette": "sand", "body_len": 24, "body_h": 12, "head_h": 0.12, "tail_h": 0.06, "peak": 0.55, "tail": "point", "tail_len": 18, "tail_flare": 0.2, "pectoral": False},
    {"name": "sturgeon", "palette": "ink", "body_len": 44, "body_h": 6, "head_h": 0.8, "peak": 0.5, "tail": "long", "tail_len": 10, "snout": 4, "pattern": "stripes", "snout_style": "cone", "snout_taper": 0.6, "barbels": 2, "barbel_len": 3},
    {"name": "catfish", "palette": "copper", "body_len": 40, "body_h": 7.6, "head_h": 1.0, "peak": 0.3, "tail": "round", "tail_len": 10, "snout": 6, "pattern": "spots", "snout_style": "cone", "barbels": 4, "barbel_len": 4},
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
    {"name": "angler", "palette": "ink", "body_len": 24, "body_h": 10, "head_h": 0.95, "tail_h": 0.3, "peak": 0.15, "tail": "round", "tail_len": 6, "tail_flare": 0.4, "snout": 4, "dorsal": (0.05, 0.2, 2.4), "lure": True, "lure_len": 5, "lure_at": 0.14, "teeth": True},
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
    # Signature: the heaviest build of the ordinary sharks, with the
    # tallest dorsal and the biggest pectorals to match.
    {"name": "greatwhite", "palette": "steel", "body_len": 42, "body_h": 8.4, "head_h": 0.6, "tail_h": 0.3, "peak": 0.32, "back_bias": 1.05, "belly_bias": 0.95, "tail": "long", "tail_len": 12, "snout": 5, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.30, 0.68, 6.4), "dorsal2": (0.76, 0.92, 2.2), "anal": (0.72, 0.88, 2.0), "pectoral": [0.24], "pectoral_style": "blade", "pectoral_len": 9, "gills": 5, "teeth": True},
    # Signature: the tail, which on a real thresher is as long as the rest
    # of the animal — so everything else stays deliberately modest.
    # tail_flare 0.35 made this a plain rectangular bar, not a scythe:
    # _draw_tail clamps tip_h up to base_h, so any flare that works out
    # smaller than the peduncle's own half-height silently produces a
    # uniform-width tail. It has to exceed base_h/body_h to flare at all.
    {"name": "thresher", "palette": "cobalt", "body_len": 32, "body_h": 6.8, "head_h": 0.6, "tail_h": 0.35, "peak": 0.35, "tail": "long", "tail_len": 22, "tail_flare": 1.25, "snout": 4, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.28, 0.62, 4.6), "dorsal2": (0.74, 0.90, 1.6), "anal": (0.70, 0.86, 1.4), "pectoral": [0.24], "pectoral_style": "blade", "pectoral_len": 7, "gills": 5, "teeth": True},
    # Non-fish sea life. Both still fit the head-to-tail silhouette system;
    # starfish and octopus don't (radial/many-armed body plans) and are
    # deliberately not attempted here — see the project notes.
    {"name": "seahorse", "palette": "plum", "body_len": 18, "body_h": 5.2, "head_h": 0.65, "tail_h": 0.1, "peak": 0.3, "back_bias": 1.3, "belly_bias": 0.7, "tail": "point", "tail_len": 16, "tail_flare": 0.1, "snout": 8, "dorsal": (0.15, 0.5, 3.2), "pectoral": False},
    # Was a lateral-profile model: a cone with a single straight bar for a
    # tail, which is about as far from a jellyfish as the silhouette system
    # can get. A jellyfish has no head-to-tail axis at all, so it belongs
    # on the radial engine like the starfish and octopus — a wide shallow
    # bell (core_w well over core_h reads as a dome, not a ball) with two
    # ranks of trailing parts: short thick oral arms just under the rim,
    # and long thin stinging tentacles streaming past them.
    {
        "name": "jellyfish", "shape": "radial", "palette": "seafoam",
        # NOTE on limb "width": _draw_radial_limb stamps -span..+span around
        # the centreline, where span = round(half_w) — so width 2.0 renders
        # *five* pixels across, not two. Anything above ~1.0 makes adjacent
        # limbs merge into one slab, which is exactly what the first version
        # of this bell did (a mushroom on a fat solid stem).
        "cy": 10, "core_w": 9.0, "core_h": 4.6,
        "limbs": [
            {"angle": 55, "length": 7, "width": 1.0, "tone": "back", "curl": 24},
            {"angle": 73, "length": 9, "width": 1.0, "tone": "back", "curl": 10},
            {"angle": 107, "length": 9, "width": 1.0, "tone": "back", "curl": -10},
            {"angle": 125, "length": 7, "width": 1.0, "tone": "back", "curl": -24},
            {"angle": 66, "length": 14, "width": 0.45, "tone": "belly", "curl": 16},
            {"angle": 82, "length": 17, "width": 0.45, "tone": "pattern", "curl": -12},
            {"angle": 98, "length": 17, "width": 0.45, "tone": "pattern", "curl": 12},
            {"angle": 114, "length": 14, "width": 0.45, "tone": "belly", "curl": -16},
        ],
    },
    # River Mouth spot: a real-world-heavy batch (mullet/catfish/sheepshead/
    # redfish/snook/tarpon/mudskipper/flounder-family are genuine estuary
    # and tidal-flat species), mixed with a few invented ones rather than
    # sorted apart from them by rarity. Shared with several existing models
    # where a real species is a close enough family match (goby -> gudgeon,
    # eel -> the existing eel model, flounder/sole/toad -> the existing
    # flounder model) instead of drawing a near-duplicate silhouette.
    {"name": "mullet", "palette": "olive", "body_len": 28, "body_h": 6, "head_h": 0.5, "tail_h": 0.3, "peak": 0.4, "tail": "fork", "tail_len": 10, "dorsal": (0.35, 0.55, 3.2)},
    {"name": "brackcat", "palette": "slate", "body_len": 30, "body_h": 6.8, "head_h": 0.85, "tail_h": 0.35, "peak": 0.25, "taper": "linear", "tail": "round", "tail_len": 8, "snout": 6, "snout_style": "cone", "barbels": 4, "barbel_len": 5},
    {"name": "sheepshead", "palette": "silver", "body_len": 26, "body_h": 8.8, "head_h": 0.6, "tail_h": 0.35, "peak": 0.35, "back_bias": 1.1, "tail": "fork", "tail_len": 8, "dorsal": (0.25, 0.7, 4.4), "pattern": "stripes"},
    # The eyespot near the tail mirrors the real fish's own dark spot.
    {"name": "redfish", "palette": "rust", "body_len": 30, "body_h": 7.2, "head_h": 0.55, "tail_h": 0.3, "peak": 0.38, "tail": "fan", "tail_len": 8, "tail_flare": 0.7, "dorsal": (0.3, 0.6, 3.6), "pattern": "eyespot"},
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
    {"name": "voidangler", "palette": "ink", "body_len": 28, "body_h": 7.6, "head_h": 0.85, "peak": 0.3, "tail": "point", "tail_len": 6, "snout": 4, "pattern": "glow", "lure": True, "lure_len": 7, "lure_at": 0.12, "teeth": True},
    {"name": "hadalmaw", "palette": "abyss", "body_len": 40, "body_h": 8.8, "head_h": 0.9, "peak": 0.25, "tail": "long", "tail_len": 12, "snout": 2, "pattern": "glow", "teeth": True},
    {"name": "coelacanth", "palette": "slate", "body_len": 34, "body_h": 8, "peak": 0.45, "tail": "round", "tail_len": 10, "tail_flare": 0.6, "dorsal": (0.3, 0.65, 4), "anal": (0.5, 0.8, 3.2), "pattern": "glow"},
    # Real-world species added to existing habitats — dedicated models only
    # for the ones distinctive enough to earn one; plainer real fish reuse
    # an existing family-appropriate model instead (see fish_catalog.gd's
    # comments on which species share which of the models below with
    # earlier entries).
    {"name": "zander", "palette": "slate", "body_len": 38, "body_h": 6, "head_h": 0.7, "peak": 0.45, "tail": "fork", "tail_len": 10, "dorsal": (0.3, 0.6, 4.4), "pattern": "spots"},
    {"name": "garibaldi", "palette": "amber", "body_len": 26, "body_h": 9.2, "head_h": 0.6, "peak": 0.45, "tail": "fan", "tail_len": 8, "dorsal": (0.3, 0.6, 3.2)},
    {"name": "lingcod", "palette": "olive", "body_len": 40, "body_h": 6.8, "head_h": 0.75, "peak": 0.35, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.25, 0.85, 3.6), "pattern": "spots", "teeth": True},
    {"name": "wolfeel", "palette": "charcoal", "body_len": 42, "body_h": 5.2, "head_h": 0.9, "taper": "linear", "tail": "point", "tail_len": 8, "snout": 2, "pattern": "spots", "teeth": True},
    {"name": "californiasheephead", "palette": "crimson", "body_len": 30, "body_h": 7.6, "head_h": 0.7, "peak": 0.4, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.3, 0.7, 3.2)},
    {"name": "clownfish", "palette": "coral", "body_len": 20, "body_h": 6.8, "head_h": 0.65, "peak": 0.4, "tail": "fan", "tail_len": 6, "pattern": "bars"},
    {"name": "parrotfish", "palette": "jade", "body_len": 32, "body_h": 8.4, "head_h": 0.55, "peak": 0.4, "tail": "round", "tail_len": 8, "snout": 2, "dorsal": (0.3, 0.75, 3.6)},
    {"name": "picassotriggerfish", "palette": "gold", "body_len": 26, "body_h": 8, "head_h": 0.6, "tail_h": 0.5, "peak": 0.4, "tail": "round", "tail_len": 6, "dorsal": (0.15, 0.4, 3.2), "pattern": "bars"},
    {"name": "biggrouper", "palette": "teal", "body_len": 38, "body_h": 10, "head_h": 0.95, "peak": 0.25, "tail": "round", "tail_len": 8, "dorsal": (0.3, 0.85, 4)},
    {"name": "mahimahi", "palette": "gold", "body_len": 36, "body_h": 7.2, "head_h": 0.85, "peak": 0.2, "tail": "crescent", "tail_len": 10, "dorsal": (0.05, 0.95, 4.8), "pattern": "spots"},
    {"name": "wahoo", "palette": "indigo", "body_len": 44, "body_h": 5.2, "head_h": 0.6, "peak": 0.4, "tail": "crescent", "tail_len": 10, "snout": 2, "pattern": "bars", "finlets": 6, "finlet_start": 0.58},
    # Signature: almost no dorsal at all. A real Greenland shark's fins are
    # famously stubby for its bulk, so the tiny fins are the trait here.
    {"name": "greenlandshark", "palette": "charcoal", "body_len": 44, "body_h": 9.0, "head_h": 0.6, "peak": 0.32, "tail": "long", "tail_len": 12, "snout": 4, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.40, 0.66, 3.2), "dorsal2": (0.76, 0.90, 1.4), "anal": (0.72, 0.86, 1.2), "pectoral": [0.24], "pectoral_style": "blade", "pectoral_len": 5, "gills": 5, "teeth": True},
    {"name": "viperfish", "palette": "ink", "body_len": 36, "body_h": 3.6, "taper": "linear", "tail": "point", "tail_len": 10, "snout": 6, "dorsal": (0.1, 0.3, 4.8), "teeth": True},
    {"name": "fangtooth", "palette": "abyss", "body_len": 18, "body_h": 6.4, "head_h": 0.95, "peak": 0.25, "tail": "point", "tail_len": 6, "snout": 2, "teeth": True},
    {"name": "oarfish", "palette": "silver", "body_len": 48, "body_h": 4, "taper": "linear", "tail": "point", "tail_len": 6, "dorsal": (0.0, 1.0, 6)},
    # Signature: the long flattened blade of a snout. Kept at 8 columns and
    # given a low taper so it stays a long wedge rather than closing to a
    # point straight away.
    {"name": "goblinshark", "palette": "rose", "body_len": 36, "body_h": 6.4, "head_h": 0.6, "peak": 0.42, "tail": "long", "tail_len": 12, "snout": 9, "snout_style": "cone", "snout_taper": 0.55, "fin_style": "swept", "dorsal": (0.34, 0.68, 3.6), "dorsal2": (0.76, 0.92, 1.6), "anal": (0.72, 0.88, 1.4), "pectoral": [0.26], "pectoral_style": "blade", "pectoral_len": 6, "gills": 5, "teeth": True},
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
    {"name": "turtle", "palette": "copper", "accent_palette": "emerald", "body_len": 22, "body_h": 6.2, "head_h": 0.2, "tail_h": 0.15, "peak": 0.5, "back_bias": 1.12, "belly_bias": 0.68, "taper": "linear", "tail": "round", "tail_len": 3, "tail_flare": 0.4, "snout": 6, "head_block": True, "head_offset": 2, "head_radius": 3.2, "pectoral": [0.18, 0.82], "pectoral_style": "flipper", "dorsal": False, "pattern": "scutes"},
    {"name": "dolphin", "palette": "steel", "body_len": 30, "body_h": 6.8, "head_h": 0.55, "tail_h": 0.3, "peak": 0.38, "tail": "fan", "tail_len": 12, "tail_flare": 0.55, "snout": 4, "dorsal": (0.42, 0.62, 3.6), "pectoral": [0.34], "pectoral_style": "flipper"},
    # The tall dorsal fin is the one silhouette trait everyone recognizes;
    # kept the palette dark and plain rather than fighting the fixed
    # per-palette pattern colour for a true black/white patch look.
    # "ink" (near-black) body with "pearl" (near-white) accent patches —
    # a real orca's colouring is the single most recognisable thing about
    # it, more than the silhouette alone.
    {"name": "orca", "palette": "ink", "accent_palette": "pearl", "body_len": 34, "body_h": 8.4, "head_h": 0.6, "tail_h": 0.35, "peak": 0.4, "tail": "fan", "tail_len": 12, "tail_flare": 0.7, "dorsal": (0.4, 0.62, 6.8), "pattern": "patches", "pectoral": [0.34], "pectoral_style": "flipper"},
    # Broad, flat "round"-style tail (a real fluke, not a fish's fan/fork)
    # plus paddle-shaped "flipper" pectorals (real humpback flippers are
    # enormous) rather than the generic small fin nub every fish uses —
    # both were the two biggest reasons this read as "just a big fish".
    {"name": "whale", "palette": "steel", "body_len": 38, "body_h": 10, "head_h": 0.55, "tail_h": 0.3, "peak": 0.35, "back_bias": 1.05, "belly_bias": 1.1, "tail": "round", "tail_len": 14, "tail_flare": 1.3, "dorsal": (0.55, 0.68, 1.8), "pectoral": [0.3], "pectoral_style": "flipper", "pattern": "spots"},
    {"name": "shrimp", "palette": "rose", "body_len": 12, "body_h": 3.6, "head_h": 0.6, "tail_h": 0.25, "peak": 0.35, "tail": "fan", "tail_len": 6, "tail_flare": 0.6, "snout": 4, "dorsal": False, "pectoral": False, "pattern": "bars"},
    {"name": "flyingfish", "palette": "silver", "body_len": 20, "body_h": 4.4, "head_h": 0.5, "tail_h": 0.35, "peak": 0.3, "tail": "long", "tail_len": 10, "tail_flare": 0.3, "snout": 2, "dorsal": (0.3, 0.55, 2.4)},
    {"name": "beluga", "palette": "ivory", "body_len": 26, "body_h": 7.2, "head_h": 0.7, "tail_h": 0.25, "peak": 0.45, "back_bias": 1.05, "tail": "fan", "tail_len": 10, "tail_flare": 0.5, "dorsal": False, "pectoral": [0.36], "pectoral_style": "flipper"},
    {"name": "narwhal", "palette": "silver", "body_len": 26, "body_h": 6.4, "head_h": 0.55, "tail_h": 0.25, "peak": 0.4, "tail": "fan", "tail_len": 10, "tail_flare": 0.45, "snout": 8, "dorsal": False, "pattern": "spots", "pectoral": [0.36], "pectoral_style": "flipper"},
    {"name": "manatee", "palette": "slate", "body_len": 24, "body_h": 8.8, "head_h": 0.55, "tail_h": 0.3, "peak": 0.55, "back_bias": 0.95, "belly_bias": 1.15, "taper": "linear", "tail": "round", "tail_len": 8, "tail_flare": 0.4, "snout": 2, "dorsal": False},
    {"name": "leopardseal", "palette": "slate", "body_len": 26, "body_h": 5.6, "head_h": 0.55, "tail_h": 0.2, "peak": 0.35, "tail": "point", "tail_len": 6, "snout": 4, "dorsal": False, "pattern": "spots"},
    {"name": "seadragon", "palette": "moss", "body_len": 20, "body_h": 5.6, "head_h": 0.6, "tail_h": 0.15, "peak": 0.35, "back_bias": 1.2, "tail": "point", "tail_len": 14, "tail_flare": 0.2, "snout": 6, "dorsal": (0.2, 0.55, 4), "anal": (0.5, 0.8, 3.2), "pectoral": False, "pattern": "line"},
    {"name": "sawfish", "palette": "sand", "body_len": 32, "body_h": 6, "head_h": 0.45, "tail_h": 0.3, "peak": 0.3, "tail": "long", "tail_len": 12, "snout": 8, "dorsal": (0.55, 0.75, 3.2)},
    {"name": "walrus", "palette": "copper", "body_len": 26, "body_h": 8.8, "head_h": 0.6, "tail_h": 0.3, "peak": 0.5, "back_bias": 1.0, "belly_bias": 1.1, "taper": "linear", "tail": "round", "tail_len": 6, "snout": 8, "dorsal": False},
    {"name": "whaleshark", "palette": "abyss", "body_len": 40, "body_h": 10, "head_h": 0.7, "tail_h": 0.4, "peak": 0.42, "back_bias": 1.1, "tail": "long", "tail_len": 16, "tail_flare": 0.5, "snout": 2, "dorsal": (0.45, 0.65, 4.4), "pattern": "spots"},
    {"name": "elephantseal", "palette": "sand", "body_len": 30, "body_h": 9.2, "head_h": 0.55, "tail_h": 0.25, "peak": 0.5, "back_bias": 1.0, "belly_bias": 1.15, "taper": "linear", "tail": "round", "tail_len": 6, "snout": 6, "dorsal": False},
    # The near-absent tail is the point: a real ocean sunfish looks "cut
    # off" right behind its huge mirrored dorsal/anal fins.
    {"name": "molamola", "palette": "ivory", "body_len": 18, "body_h": 10.4, "head_h": 0.5, "tail_h": 0.2, "peak": 0.55, "tail": "round", "tail_len": 2, "tail_flare": 0.2, "dorsal": (0.35, 0.55, 5.8), "anal": (0.35, 0.55, 5.2), "pattern": "spots"},
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
        "cy": 13, "core_w": 6.4, "core_h": 5.2,
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
            {"angle": 249, "length": 5, "width": 2.4,
             "bend": {"angle": 200, "length": 5, "width": 2.2, "tone": "belly", "flare": True}},
            {"angle": 291, "length": 5, "width": 2.4,
             "bend": {"angle": 340, "length": 5, "width": 2.2, "tone": "belly", "flare": True}},
            {"angle": 25, "length": 6, "width": 2.4, "bend": {"angle": 45, "length": 6, "width": 1.8}},
            {"angle": 50, "length": 6, "width": 2.4, "bend": {"angle": 70, "length": 6, "width": 1.8}},
            {"angle": 75, "length": 6, "width": 2.4, "bend": {"angle": 95, "length": 6, "width": 1.8}},
            {"angle": 105, "length": 6, "width": 2.4, "bend": {"angle": 85, "length": 6, "width": 1.8}},
            {"angle": 130, "length": 6, "width": 2.4, "bend": {"angle": 110, "length": 6, "width": 1.8}},
            {"angle": 155, "length": 6, "width": 2.4, "bend": {"angle": 135, "length": 6, "width": 1.8}},
        ],
        "eyes": [(-2, -4), (2, -4)],
    },
    {
        "name": "octopus", "shape": "radial", "palette": "violet",
        # Rebuilt: the arms used to radiate a full circle (95 deg round to
        # 270), so half of them climbed back over the mantle and punched
        # holes in it — the silhouette read as a torn purple blob rather
        # than an animal. Now every arm hangs in a downward fan from the
        # mantle's lower half, splayed wider and curling harder the further
        # out it sits, which is both what an octopus at rest looks like and
        # the only arrangement that keeps the mantle a clean solid shape.
        # Arm width stays at 1.0 (3px stamped, see the note on the
        # jellyfish): eight arms fanned across ~130 degrees are only about
        # four pixels apart at arm's length, so anything wider fuses them
        # into a solid slab with no readable arms at all.
        "cy": 9, "core_w": 5.6, "core_h": 6.0,
        "limbs": [
            {"angle": 26, "length": 12, "width": 1.0, "tone": "back", "curl": 52},
            {"angle": 44, "length": 14, "width": 1.0, "tone": "body", "curl": 36},
            {"angle": 62, "length": 15, "width": 1.0, "tone": "back", "curl": 20},
            {"angle": 80, "length": 16, "width": 1.0, "tone": "body", "curl": 8},
            {"angle": 100, "length": 16, "width": 1.0, "tone": "back", "curl": -8},
            {"angle": 118, "length": 15, "width": 1.0, "tone": "body", "curl": -20},
            {"angle": 136, "length": 14, "width": 1.0, "tone": "back", "curl": -36},
            {"angle": 154, "length": 12, "width": 1.0, "tone": "body", "curl": -52},
        ],
        "eyes": [(-2, -2), (2, -2)],
    },

    # --- Batch: backfilling under-populated habitats + de-recycling the
    # most-reused models (2026-08-13). Two of the 10 species reassigned to
    # a dedicated look this round point at *existing* models instead
    # (Galewing Ray -> the existing "manta", already an unused-since-built
    # wide-wing shape; Riptide Barracuda -> the existing "barracuda",
    # genuine real-family reuse) rather than authoring a near-duplicate,
    # so only 21 new SPECS entries are needed for 22 improved species.
    {"name": "eagleray", "shape": "radial", "palette": "teal",
     "core_w": 4.6, "core_h": 3.0,
     "limbs": [
         {"angle": 200, "length": 12, "width": 5.5},
         {"angle": 340, "length": 12, "width": 5.5},
         {"angle": 90, "length": 13, "width": 1.4},
     ],
     "eyes": [(-1, -3), (1, -3)]},
    {"name": "stingray", "shape": "radial", "palette": "ochre",
     "core_w": 7.0, "core_h": 6.0,
     # Toned "belly" (not the default "body") so the whip reads as its own
     # part instead of blending into the disc at the same colour, with a
     # slight curl so it trails rather than running dead straight.
     "limbs": [{"angle": 100, "length": 11, "width": 1.3, "tone": "belly", "curl": 20}],
     "pattern": "spots", "eyes": [(-1, -4), (1, -4)]},
    {"name": "sole", "palette": "ochre", "body_len": 22, "body_h": 8.5, "head_h": 0.3, "tail_h": 0.25, "peak": 0.5, "tail": "round", "tail_len": 5, "tail_flare": 0.3, "pectoral": False, "pattern": "spots"},
    {"name": "toadfish", "palette": "olive", "body_len": 24, "body_h": 8.0, "head_h": 0.9, "tail_h": 0.3, "peak": 0.2, "back_bias": 1.0, "belly_bias": 1.1, "tail": "round", "tail_len": 5, "tail_flare": 0.4, "snout": 2, "pattern": "bars"},
    {"name": "driftfish", "palette": "mint", "body_len": 34, "body_h": 2.6, "head_h": 0.6, "tail_h": 0.3, "peak": 0.5, "taper": "linear", "tail": "point", "tail_len": 6, "pectoral": False, "pattern": "line"},
    {"name": "pinfish", "palette": "silver", "body_len": 22, "body_h": 6.6, "head_h": 0.5, "peak": 0.4, "tail": "fork", "tail_len": 6, "dorsal": (0.2, 0.55, 3.0), "pattern": "bars"},
    {"name": "sandgoby", "palette": "bronze", "body_len": 20, "body_h": 4.8, "head_h": 0.9, "tail_h": 0.25, "peak": 0.15, "taper": "linear", "tail": "round", "tail_len": 5, "pattern": "spots"},
    {"name": "stormfish", "palette": "abyss", "body_len": 30, "body_h": 5.6, "head_h": 0.55, "peak": 0.4, "tail": "fork", "tail_len": 9, "tail_flare": 0.9, "dorsal": (0.2, 0.7, 4.6), "pattern": "line"},
    {"name": "titan", "palette": "abyss", "body_len": 46, "body_h": 8.4, "head_h": 0.8, "tail_h": 0.3, "peak": 0.3, "back_bias": 1.1, "taper": "linear", "tail": "long", "tail_len": 12, "dorsal": (0.15, 0.85, 5.6), "pattern": "bars"},
    {"name": "ballastcrab", "shape": "radial", "palette": "copper",
     # Rebuilt directly on the Shore Crab's proven frontal claws-up-and-out
     # pose (same core proportions, same up-then-swing-outward claw
     # geometry, same two-fan leg layout) rather than the original
     # freehand attempt, which read as a spiky insect rather than a crab.
     # The one deliberate difference is scale: the left claw is roughly
     # 2x the right one -- a fiddler crab's single oversized display claw
     # -- so it's still a distinct silhouette from the Shore Crab's
     # matched pair at a glance.
     "cy": 15, "core_w": 6.0, "core_h": 4.8,
     "limbs": [
         {"angle": 250, "length": 7, "width": 2.8,
          "bend": {"angle": 195, "length": 7, "width": 2.4, "tone": "belly", "flare": True}},
         {"angle": 285, "length": 4, "width": 1.8,
          "bend": {"angle": 340, "length": 4, "width": 2.2, "tone": "belly", "flare": True}},
         {"angle": 25, "length": 6, "width": 2.2, "bend": {"angle": 45, "length": 7, "width": 1.6}},
         {"angle": 50, "length": 6, "width": 2.2, "bend": {"angle": 70, "length": 7, "width": 1.6}},
         {"angle": 75, "length": 6, "width": 2.2, "bend": {"angle": 95, "length": 7, "width": 1.6}},
         {"angle": 105, "length": 6, "width": 2.2, "bend": {"angle": 85, "length": 7, "width": 1.6}},
         {"angle": 130, "length": 6, "width": 2.2, "bend": {"angle": 110, "length": 7, "width": 1.6}},
         {"angle": 155, "length": 6, "width": 2.2, "bend": {"angle": 135, "length": 7, "width": 1.6}},
     ],
     "eyes": [(-2, -4), (2, -4)]},
    {"name": "wreckwarden", "palette": "slate", "body_len": 32, "body_h": 8.2, "head_h": 0.7, "peak": 0.4, "back_bias": 1.1, "tail": "round", "tail_len": 7, "tail_flare": 0.4, "dorsal": (0.25, 0.65, 3.6), "pattern": "bars"},
    {"name": "rustedpike", "palette": "amber", "body_len": 38, "body_h": 5.4, "head_h": 0.6, "peak": 0.3, "taper": "linear", "snout": 4, "tail": "fork", "tail_len": 8, "dorsal": (0.55, 0.85, 3.2), "pattern": "spots"},
    {"name": "hullbreaker", "palette": "steel", "body_len": 44, "body_h": 6.0, "head_h": 1.0, "tail_h": 0.4, "peak": 0.0, "taper": "linear", "tail": "point", "tail_len": 8, "dorsal": (0.1, 0.95, 3.0), "pectoral": False, "pattern": "bars"},
    {"name": "baypipefish", "palette": "teal", "body_len": 30, "body_h": 2.0, "head_h": 0.8, "tail_h": 0.15, "peak": 0.65, "taper": "linear", "snout": 10, "tail": "point", "tail_len": 4, "pectoral": False, "pattern": "spots"},
    {"name": "seahare", "shape": "radial", "palette": "rose",
     "cy": 12, "core_w": 5.0, "core_h": 4.2,
     "limbs": [
         {"angle": 250, "length": 5, "width": 3.2, "flare": True, "tone": "back"},
         {"angle": 290, "length": 5, "width": 3.2, "flare": True, "tone": "back"},
         {"angle": 90, "length": 4, "width": 2.0},
     ],
     "pattern": "spots", "eyes": [(-1, -3), (1, -3)]},
    {"name": "conch", "shape": "radial", "palette": "gold",
     # A single thick limb spiralled almost a full turn (curl=340) with
     # flare widening toward the outer whorl -- the generator's first
     # genuinely spiral silhouette, for a mollusc rather than anything
     # with a head/limb body plan.
     "core_w": 3.4, "core_h": 3.4,
     "limbs": [{"angle": 0, "length": 14, "width": 3.4, "curl": 340, "flare": True}]},
    {"name": "bluefish", "palette": "cobalt", "body_len": 32, "body_h": 5.4, "head_h": 0.6, "peak": 0.4, "tail": "fork", "tail_len": 9, "dorsal": (0.3, 0.6, 3.0), "pattern": "line"},
    {"name": "waterspout", "palette": "indigo", "body_len": 40, "body_h": 5.0, "head_h": 0.9, "tail_h": 0.35, "peak": 0.1, "taper": "linear", "tail": "point", "tail_len": 7, "dorsal": (0.1, 0.9, 2.6), "pectoral": False, "pattern": "bars"},
    {"name": "dragonfish", "palette": "ink", "body_len": 26, "body_h": 3.6, "head_h": 0.8, "tail_h": 0.3, "peak": 0.25, "taper": "linear", "snout": 3, "tail": "point", "tail_len": 6, "pectoral": False, "pattern": "glow"},
    {"name": "vampiresquid", "shape": "radial", "palette": "wine",
     "cy": 13, "core_w": 4.6, "core_h": 5.2,
     "limbs": [
         {"angle": 100, "length": 9, "width": 2.6, "tone": "body", "curl": -40},
         {"angle": 130, "length": 9, "width": 2.6, "tone": "back", "curl": 40},
         {"angle": 160, "length": 9, "width": 2.6, "tone": "body", "curl": -40},
         {"angle": 200, "length": 9, "width": 2.6, "tone": "back", "curl": 40},
         {"angle": 230, "length": 9, "width": 2.6, "tone": "body", "curl": -40},
         {"angle": 260, "length": 9, "width": 2.6, "tone": "back", "curl": 40},
     ],
     "eyes": [(-2, -2), (2, -2)]},
    {"name": "isopod", "shape": "radial", "palette": "slate",
     # A plain oval core read as a flat pebble with no legs at all; small
     # stub limbs down both sides (no bend, no curl -- just short and
     # numerous), toned "back" so they actually contrast against the
     # "body"-toned core instead of blending invisibly into it (a radial
     # limb defaults to "body" tone if none is given), give it the
     # segmented, many-legged pillbug silhouette a blob alone can't.
     # "bars" is a linear-only pattern style with no effect on a radial
     # fish -- "spots" is the one the radial path actually supports.
     "cy": 12, "core_w": 6.0, "core_h": 4.6,
     "limbs": [{"angle": a, "length": 3, "width": 1.3, "tone": "back"} for a in (100, 125, 150, 175, 185, 210, 235, 260)],
     "pattern": "spots"},

    # --- Batch 2: de-recycling Harbour's especially heavy reuse (sardine,
    # moray, bigeye all had 4+ users sharing that one spot alone), plus a
    # few visually distinctive real species elsewhere that were sitting on
    # a generic stand-in (2026-08-13, same session as batch 1).
    {"name": "mackerel", "palette": "cobalt", "body_len": 28, "body_h": 4.4, "head_h": 0.5, "peak": 0.4, "tail": "crescent", "tail_len": 9, "dorsal": (0.25, 0.6, 2.4), "pattern": "bars", "finlets": 4, "finlet_start": 0.62},
    {"name": "napoleonwrasse", "palette": "jade", "body_len": 30, "body_h": 7.2, "head_h": 0.6, "peak": 0.35, "snout": 4,
     # head_block (previously turtle-only) doubles here as the wrasse's
     # real bulging forehead hump -- negative head_offset lifts it above
     # the body's own centreline instead of the turtle's downward droop.
     "head_block": True, "head_radius": 3.6, "head_offset": -1,
     "tail": "round", "tail_len": 6, "tail_flare": 0.3, "pattern": "spots"},
    {"name": "capelin", "palette": "silver", "body_len": 16, "body_h": 3.0, "tail": "fork", "tail_len": 6},
    {"name": "haddock", "palette": "slate", "body_len": 26, "body_h": 5.2, "head_h": 0.5, "peak": 0.35, "tail": "fork", "tail_len": 7, "dorsal": (0.25, 0.55, 2.2), "pattern": "eyespot"},
    {"name": "conger", "palette": "obsidian", "body_len": 40, "body_h": 6.4, "head_h": 0.9, "tail_h": 0.35, "peak": 0.05, "taper": "linear", "tail": "point", "tail_len": 7, "dorsal": (0.35, 0.95, 2.2), "pectoral": False, "teeth": True},
    {"name": "grouper", "palette": "olive", "body_len": 28, "body_h": 8.6, "head_h": 0.75, "peak": 0.3, "tail": "round", "tail_len": 6, "tail_flare": 0.3, "dorsal": (0.2, 0.7, 2.4), "pattern": "bars"},
    {"name": "tuna", "palette": "cobalt", "body_len": 34, "body_h": 6.8, "head_h": 0.55, "peak": 0.4, "tail": "crescent", "tail_len": 11, "tail_flare": 1.0, "dorsal": (0.2, 0.5, 2.6), "pattern": "line", "finlets": 5, "finlet_start": 0.60},
    {"name": "croaker", "palette": "ivory", "body_len": 22, "body_h": 5.4, "head_h": 0.6, "peak": 0.35, "tail": "round", "tail_len": 5, "tail_flare": 0.25, "pattern": "spots"},
    {"name": "seatrout", "palette": "silver", "body_len": 26, "body_h": 5.0, "head_h": 0.55, "peak": 0.35, "tail": "fan", "tail_len": 7, "dorsal": (0.3, 0.6, 2.2), "pattern": "spots"},
    {"name": "blackdrum", "palette": "ink", "body_len": 24, "body_h": 8.0, "head_h": 0.7, "peak": 0.3, "tail": "round", "tail_len": 6, "tail_flare": 0.3, "dorsal": (0.25, 0.6, 2.6), "pattern": "bars"},
    {"name": "giantsquid", "shape": "radial", "palette": "crimson",
     # Bigger and more dramatic than the octopus/vampiresquid pair: a
     # tall mantle up top, with all 8 arms bunched into a narrow
     # downward cone (not spread a full half-circle like octopus/
     # vampiresquid, whose arms radiate all the way around a squat
     # core) so they read as one trailing cluster, plus 2 much longer
     # "belly"-toned feeding tentacles reaching further past them.
     "cy": 11, "core_w": 4.2, "core_h": 7.5,
     "limbs": [
         {"angle": 155, "length": 8, "width": 1.8, "tone": "body", "curl": -15},
         {"angle": 165, "length": 8, "width": 1.8, "tone": "back", "curl": 10},
         {"angle": 172, "length": 8, "width": 1.8, "tone": "body", "curl": -10},
         {"angle": 179, "length": 8, "width": 1.8, "tone": "back", "curl": 5},
         {"angle": 186, "length": 8, "width": 1.8, "tone": "body", "curl": -5},
         {"angle": 193, "length": 8, "width": 1.8, "tone": "back", "curl": 10},
         {"angle": 200, "length": 8, "width": 1.8, "tone": "body", "curl": -10},
         {"angle": 208, "length": 8, "width": 1.8, "tone": "back", "curl": 15},
         {"angle": 178, "length": 18, "width": 1.1, "tone": "belly", "curl": 6},
         {"angle": 184, "length": 18, "width": 1.1, "tone": "belly", "curl": -6},
     ],
     "eyes": [(-2, -6), (2, -6)]},
    {"name": "cownose", "shape": "radial", "palette": "sand",
     # Smaller wings than eagleray plus two short flared "nose lobe" nubs
     # between them -- the real cownose ray's distinctive notched
     # forehead, not just another pair of pointed wings.
     "core_w": 5.5, "core_h": 3.4,
     "limbs": [
         {"angle": 200, "length": 10, "width": 4.5},
         {"angle": 340, "length": 10, "width": 4.5},
         {"angle": 255, "length": 2.5, "width": 1.8, "tone": "belly", "flare": True},
         {"angle": 285, "length": 2.5, "width": 1.8, "tone": "belly", "flare": True},
         {"angle": 90, "length": 12, "width": 1.3},
     ],
     "eyes": [(-1, -2), (1, -2)]},

    # --- Batch 3: the shark lineup, requested by name (2026-08-13).
    # Hammerhead/Broadbill Swordfish/Great White already had dedicated
    # models (27/22/46) and needed no changes -- only Tiger Shark (wants
    # visible stripes, which no existing shark-shaped model has) and
    # Megalodon (a Secret-tier apex predator deserving its own scale, not
    # a hand-me-down from an unrelated giant like colossus/leviathan)
    # were actually missing.
    # Signature: the stripes (see "stripes" in _draw_pattern), plus the
    # blunter, broader head a real tiger shark carries.
    {"name": "tigershark", "palette": "sand", "body_len": 38, "body_h": 7.2, "head_h": 0.75, "peak": 0.35, "back_bias": 1.05, "belly_bias": 0.95, "tail": "long", "tail_len": 11, "snout": 4, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.32, 0.68, 5.0), "dorsal2": (0.76, 0.92, 1.8), "anal": (0.72, 0.88, 1.6), "pectoral": [0.24], "pectoral_style": "blade", "pectoral_len": 7, "gills": 5, "pattern": "stripes", "teeth": True},
    # Signature: sheer scale. Longest body in the file, biggest fins, and
    # deliberately sized so body_h*back_bias + the dorsal still clears the
    # top of the frame — the previous 12.5/7.5 pair clipped straight off
    # the canvas, which is most of why it rendered as a shapeless slab.
    {"name": "megalodon", "palette": "ink", "body_len": 43, "body_h": 9.4, "head_h": 0.62, "peak": 0.36, "back_bias": 1.05, "belly_bias": 0.95, "tail": "long", "tail_len": 13, "snout": 5, "snout_style": "cone", "fin_style": "swept", "dorsal": (0.30, 0.68, 5.4), "dorsal2": (0.76, 0.92, 2.4), "anal": (0.72, 0.88, 2.2), "pectoral": [0.23], "pectoral_style": "blade", "pectoral_len": 8, "gills": 5, "teeth": True},
]


# --- Spec validation ---------------------------------------------------
#
# Every mistake in this file used to be silent. A probe of six realistic
# typos -- "tail": "forked", "pattern": "stipes", "gils": 5 and friends --
# found that all six rendered without a word of complaint: an unknown tail
# style just falls through to the "fan" branch, an unknown key is never
# read by anyone. With 45 spec keys and eight separate style vocabularies
# that is a lot of rope. Nothing below changes a single pixel; it only
# refuses to build when a spec says something the engine cannot honour.

_COMMON_KEYS = {"name", "palette", "accent_palette", "pattern"}
_LINEAR_KEYS = {
    "body_len", "body_h", "head_h", "tail_h", "peak", "taper", "back_bias", "belly_bias",
    "tail", "tail_len", "tail_flare", "tail_strand_count",
    "snout", "snout_style", "snout_taper", "head_block", "head_offset", "head_radius",
    "neck_width", "hammer_spread",
    "dorsal", "dorsal2", "anal", "fin_style",
    "pectoral", "pectoral_style", "pectoral_len",
    "gills", "gill_start", "teeth",
    "finlets", "finlet_start", "finlets_ventral",
    "barbels", "barbel_len", "lure", "lure_len", "lure_at",
}
_RADIAL_KEYS = {"shape", "cx", "cy", "core_w", "core_h", "limbs", "eyes"}
_LIMB_KEYS = {"angle", "length", "width", "tone", "curl", "flare", "bend"}

_TAIL_STYLES = {"point", "round", "long", "fan", "fork", "crescent", "tentacles"}
_TAPERS = {"sin", "linear"}
_FIN_STYLES = {"sine", "swept", "sail"}
_PECTORAL_STYLES = {"nub", "flipper", "blade"}
_SNOUT_STYLES = {"cone", "hammer"}
_LINEAR_PATTERNS = {"stripes", "line", "spots", "bars", "eyespot", "glow", "scutes", "patches"}
## The radial path only ever checks for "spots" -- every other pattern name
## on a radial model is a no-op, which is exactly how the isopod and conch
## shipped with a "bars" pattern that drew nothing at all.
_RADIAL_PATTERNS = {"spots"}
_LIMB_TONES = set(TONE_ORDER)


def validate_specs(specs=None):
    """Returns a list of human-readable problems; empty means the file is
    internally consistent. Never raises, so callers can print everything
    that is wrong in one go rather than one error per run."""
    specs = SPECS if specs is None else specs
    problems = []
    seen = {}

    def bad(spec, msg):
        problems.append("%s: %s" % (spec.get("name", "<unnamed>"), msg))

    for spec in specs:
        name = spec.get("name")
        if not name:
            problems.append("<unnamed>: every spec needs a \"name\"")
            continue
        if name in seen:
            bad(spec, "duplicate model name (already used at index %d)" % seen[name])
        seen[name] = len(seen)

        radial = spec.get("shape") == "radial"
        allowed = _COMMON_KEYS | (_RADIAL_KEYS if radial else _LINEAR_KEYS)
        for key in spec:
            if key not in allowed:
                hint = " (radial spec)" if radial else " (linear spec)"
                bad(spec, "unknown key %r%s" % (key, hint))

        for key in ("palette", "accent_palette"):
            value = spec.get(key)
            if value is not None and value not in PALETTES:
                bad(spec, "%s %r is not defined in PALETTES" % (key, value))

        pattern = spec.get("pattern")
        if pattern is not None:
            valid = _RADIAL_PATTERNS if radial else _LINEAR_PATTERNS
            if pattern not in valid:
                bad(spec, "pattern %r does nothing on a %s model (valid: %s)"
                    % (pattern, "radial" if radial else "linear", ", ".join(sorted(valid))))

        if radial:
            for key in ("core_w", "core_h", "limbs"):
                if key not in spec:
                    bad(spec, "radial spec is missing required %r" % key)
            for i, limb in enumerate(spec.get("limbs", [])):
                _validate_limb(limb, "limbs[%d]" % i, bad, spec)
            for i, eye in enumerate(spec.get("eyes", [])):
                if not (isinstance(eye, (tuple, list)) and len(eye) == 2):
                    bad(spec, "eyes[%d] must be an (dx, dy) pair" % i)
        else:
            for key in ("body_len", "body_h"):
                if key not in spec:
                    bad(spec, "linear spec is missing required %r" % key)
            _check_choice(spec, "tail", _TAIL_STYLES, bad)
            _check_choice(spec, "taper", _TAPERS, bad)
            _check_choice(spec, "fin_style", _FIN_STYLES, bad)
            _check_choice(spec, "pectoral_style", _PECTORAL_STYLES, bad)
            _check_choice(spec, "snout_style", _SNOUT_STYLES, bad)
            for key in ("dorsal", "dorsal2", "anal"):
                span = spec.get(key)
                if span and not (isinstance(span, (tuple, list)) and len(span) == 3):
                    bad(spec, "%s must be a (start_frac, end_frac, height) triple" % key)
            if spec.get("snout_style") and not spec.get("snout"):
                bad(spec, "snout_style is set but snout is 0, so nothing is drawn")
            if spec.get("pectoral_style") and spec.get("pectoral") is False:
                bad(spec, "pectoral_style is set but pectoral is disabled")

    return problems


def _check_choice(spec, key, valid, bad):
    value = spec.get(key)
    if value is not None and value not in valid:
        bad(spec, "%s %r is not a known style (valid: %s)" % (key, value, ", ".join(sorted(valid))))


def _validate_limb(limb, where, bad, spec):
    if not isinstance(limb, dict):
        bad(spec, "%s must be a dict" % where)
        return
    for key in limb:
        if key not in _LIMB_KEYS:
            bad(spec, "%s has unknown key %r" % (where, key))
    for key in ("angle", "length", "width"):
        if key not in limb:
            bad(spec, "%s is missing required %r" % (where, key))
    tone = limb.get("tone")
    if tone is not None and tone not in _LIMB_TONES:
        bad(spec, "%s tone %r is not a palette tone (valid: %s)"
            % (where, tone, ", ".join(sorted(_LIMB_TONES))))
    if "bend" in limb:
        _validate_limb(limb["bend"], where + ".bend", bad, spec)


def build_atlases(allow_clipping=False):
    # <=, not != : COLUMNS/ROWS only need to be big enough to hold every
    # spec, not an exact fit -- trailing unused cells stay fully
    # transparent and are never selected by a valid model index, so a few
    # spare slots cost nothing. Lets grid dimensions be picked for a
    # sane, eyeball-able shape (e.g. a round 12x12) instead of chasing
    # whatever COLUMNS*ROWS happens to factor len(SPECS) exactly each
    # batch -- a real recurring friction point once len(SPECS) stopped
    # landing on convenient numbers like 99 or 120.
    if len(SPECS) > MODEL_COUNT:
        raise ValueError("expected at most %d specs for a %dx%d grid, got %d" % (MODEL_COUNT, COLUMNS, ROWS, len(SPECS)))

    problems = validate_specs()
    if problems:
        raise ValueError("%d spec problem(s):\n  %s" % (len(problems), "\n  ".join(problems)))

    del _clipped[:]
    size = (FRAME_W * COLUMNS, FRAME_H * ROWS)
    body_atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    outline_atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    for index, spec in enumerate(SPECS):
        body, outline = draw_fish(spec, index)
        at = ((index % COLUMNS) * FRAME_W, (index // COLUMNS) * FRAME_H)
        body_atlas.paste(body, at)
        outline_atlas.paste(outline, at)

    if _clipped and not allow_clipping:
        per_model = {}
        for name, x, y in _clipped:
            lost = per_model.setdefault(name, [0, set()])
            lost[0] += 1
            if x < 0:
                lost[1].add("left")
            if x >= FRAME_W:
                lost[1].add("right")
            if y < 0:
                lost[1].add("top")
            if y >= FRAME_H:
                lost[1].add("bottom")
        lines = ["%s: %d px off the %s" % (n, c, "/".join(sorted(s)))
                 for n, (c, s) in sorted(per_model.items(), key=lambda kv: -kv[1][0])]
        raise ValueError(
            "%d model(s) draw outside the %dx%d frame and would lose those pixels "
            "silently:\n  %s\n(pass --allow-clipping to build anyway)"
            % (len(per_model), FRAME_W, FRAME_H, "\n  ".join(lines)))

    return body_atlas, outline_atlas


def _compose_cell(body_atlas, outline_atlas, index, background=(40, 42, 48, 255)):
    """One model lifted out of the atlases with its outline drawn in black,
    which is how the sprites actually read in the Album."""
    col, row = index % COLUMNS, index // COLUMNS
    box = (col * FRAME_W, row * FRAME_H, col * FRAME_W + FRAME_W, row * FRAME_H + FRAME_H)
    cell = Image.new("RGBA", (FRAME_W, FRAME_H), background)
    cell.alpha_composite(body_atlas.crop(box))
    ring = outline_atlas.crop(box)
    dark = Image.new("RGBA", ring.size, (0, 0, 0, 0))
    dark.paste((0, 0, 0, 255), (0, 0), ring)
    cell.alpha_composite(dark)
    return cell


def write_sheet(body_atlas, outline_atlas, names, path, zoom=6, columns=3):
    """A labelled, zoomed sheet of just the models you name.

    This exists because reviewing a change always means looking closely at
    a handful of specific models, and the full contact sheet is useless for
    that — every review round in this file's history has otherwise meant
    hand-writing the same throwaway crop-and-label script again.
    """
    index_of = {spec["name"]: i for i, spec in enumerate(SPECS)}
    unknown = [n for n in names if n not in index_of]
    if unknown:
        raise ValueError("unknown model name(s): %s" % ", ".join(unknown))

    pad, label_h = 6, 14
    cell_w, cell_h = FRAME_W * zoom + pad, FRAME_H * zoom + pad + label_h
    rows = (len(names) + columns - 1) // columns
    sheet = Image.new("RGBA", (cell_w * min(columns, len(names)), cell_h * rows), (28, 30, 34, 255))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        cell = _compose_cell(body_atlas, outline_atlas, index_of[name])
        x, y = (i % columns) * cell_w, (i // columns) * cell_h
        sheet.paste(cell.resize((FRAME_W * zoom, FRAME_H * zoom), Image.NEAREST), (x + pad // 2, y + label_h))
        draw.text((x + pad // 2, y + 2), "%s  #%d" % (name, index_of[name]), fill=(235, 235, 240, 255))
    sheet.save(path)
    return path


def write_model_index(path=INDEX_PATH):
    """Emits the name -> atlas frame map that fish_catalog.gd looks models
    up in, plus the grid constants fish_icon.gd needs.

    Model indices are *positional* in SPECS. Before this existed the
    catalog hardcoded them as raw integers in 238 places with nothing
    recording which model each one meant, so inserting a single spec
    mid-list would silently repoint every one of them at the wrong fish —
    and the grid size was hand-copied into fish_icon.gd with no check that
    the two agreed.
    """
    lines = [
        "class_name FishModels",
        "extends RefCounted",
        "",
        "## GENERATED FILE — do not edit by hand.",
        "## Written by tools/generate_fish_sprites.py; rerun it after changing SPECS.",
        "##",
        "## Lets the catalog name the sprite it wants (\"m\": \"tigershark\") instead of",
        "## hardcoding a frame number, and gives fish_icon.gd one source of truth for",
        "## the atlas grid rather than a hand-copied duplicate.",
        "",
        "const COLUMNS := %d" % COLUMNS,
        "const ROWS := %d" % ROWS,
        "const MODEL_COUNT := COLUMNS * ROWS",
        "",
        "const MODEL := {",
    ]
    for index, spec in enumerate(SPECS):
        lines.append("\t\"%s\": %d," % (spec["name"], index))
    lines += ["}", ""]
    with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    return path


def changed_models(old_atlas, new_atlas):
    """Names of the models whose pixels differ between two atlases.

    Reports by *name* rather than frame index, since an index means nothing
    when you are trying to work out whether a change did what you intended.
    """
    if old_atlas.size != new_atlas.size:
        return None
    old_atlas, new_atlas = old_atlas.convert("RGBA"), new_atlas.convert("RGBA")
    changed = []
    for index, spec in enumerate(SPECS):
        col, row = index % COLUMNS, index // COLUMNS
        box = (col * FRAME_W, row * FRAME_H, col * FRAME_W + FRAME_W, row * FRAME_H + FRAME_H)
        if list(old_atlas.crop(box).getdata()) != list(new_atlas.crop(box).getdata()):
            changed.append(spec["name"])
    return changed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", help="also write a scaled contact sheet")
    parser.add_argument("--show", metavar="NAMES",
                        help="comma-separated model names to write as a labelled zoomed sheet")
    parser.add_argument("--show-out", default="fish_show.png", help="where --show writes to")
    parser.add_argument("--zoom", type=int, default=6, help="zoom factor for --show (default 6)")
    parser.add_argument("--diff", action="store_true",
                        help="report which models changed against the atlas already on disk")
    parser.add_argument("--check", action="store_true",
                        help="validate the specs and exit without writing anything")
    parser.add_argument("--allow-clipping", action="store_true",
                        help="build even if some model draws outside its frame")
    args = parser.parse_args()

    if args.check:
        problems = validate_specs()
        for problem in problems:
            print("  %s" % problem)
        print("%d spec problem(s) across %d models" % (len(problems), len(SPECS)))
        raise SystemExit(1 if problems else 0)

    previous = None
    if args.diff and os.path.exists(OUT_PATH):
        previous = Image.open(OUT_PATH).copy()

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    body_atlas, outline_atlas = build_atlases(allow_clipping=args.allow_clipping)
    body_atlas.save(OUT_PATH)
    outline_atlas.save(OUTLINE_PATH)
    print("wrote %s and %s (%d models, %d grid slots)" % (OUT_PATH, OUTLINE_PATH, len(SPECS), MODEL_COUNT))
    # Always rewritten alongside the atlas so the two cannot drift apart.
    write_model_index()
    print("wrote %s" % INDEX_PATH)

    if args.diff:
        if previous is None:
            print("--diff: no previous atlas on disk to compare against")
        else:
            changed = changed_models(previous, body_atlas)
            if changed is None:
                print("--diff: atlas dimensions changed, per-model comparison not meaningful")
            elif changed:
                print("--diff: %d model(s) changed: %s" % (len(changed), ", ".join(changed)))
            else:
                print("--diff: no model changed")

    if args.show:
        names = [n.strip() for n in args.show.split(",") if n.strip()]
        path = write_sheet(body_atlas, outline_atlas, names, args.show_out, zoom=args.zoom)
        print("wrote %s (%d models)" % (path, len(names)))

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
