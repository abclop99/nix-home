"""Print a ramp of foregrounds at known lightness deltas, for eyeball calibration.

The audit reports OKLCH lightness delta because the WCAG ratio does not predict
what is readable here.  But ΔL only ranks pairs -- it says nothing about where
the line is, and the reserve literature says there is no single line: reading a
number off a gutter needs far less contrast than reading prose at speed.  Nor
does ΔL account for chroma, though the Helmholtz-Kohlrausch effect means a
saturated colour looks lighter than its luminance and so loses contrast against
a light background that a grey at the same ΔL keeps.

Both gaps are measurable rather than modelable.  This prints ramps at matched
ΔL -- one neutral, four at accent chroma -- and you mark where each stops being
readable.  The spread between the grey column and the others IS the chroma
penalty, for this display and these eyes, which beats importing coefficients
measured on 1990s CRTs under a different adapting luminance.

Deliberately a terminal programme and not an HTML page: it is calibrating
terminal text, and stroke rendering at low contrast depends on the font, the
size, the gamma and the compositor.  A browser at a nominally equal pixel size
would measure something else.
"""
from __future__ import annotations

import argparse
import os
import random
import sys
import textwrap
from pathlib import Path

from contrast_audit import shader
from contrast_audit.candidate import oklch_to_rgb, rgb_to_oklch
from contrast_audit.palette import (
    RGB,
    _scan,
    contrast_ratio,
    hex_to_rgb,
    lightness_delta,
    load_palette,
    oklab_lightness,
    rgb_to_hex,
)

# Larger than sRGB can hold anywhere, so oklch_to_rgb's gamut bisection returns
# the most saturated version of each hue available at that lightness.  Asking
# for a fixed accent chroma instead was the first design and it was useless at
# the end that matters: close to a light background every colour is close to
# white, and white has no chroma, so red and blue arrived at 0.037 against a
# requested 0.17 and the low-ΔL rows were five shades of grey.  Taking the
# maximum makes the comparison as sensitive as the display can be -- if a hue
# reads no worse than grey even at full available chroma, chroma does not
# matter here.
MAX_CHROMA = 0.4

# Hue angles in radians, picked for what they say about H-K rather than for
# palette fidelity: the effect peaks in blue and red-magenta and nearly
# vanishes in yellow, so a flat result across these four falsifies it.
HUES = (
    ("grey", 0.0, 0.0),
    ("red", 0.52, MAX_CHROMA),
    ("yellow", 1.66, MAX_CHROMA),
    ("green", 2.55, MAX_CHROMA),
    ("blue", 4.35, MAX_CHROMA),
)

STEPS = (0.03, 0.05, 0.07, 0.09, 0.11, 0.13, 0.16,
         0.19, 0.22, 0.26, 0.30, 0.35)

# Every cell gets its own unpredictable sample, because a fixed one measures
# the wrong thing.  Printing "1042 readable" twelve times down a column means
# that by the third row you are no longer reading it -- you are recognising a
# shape you already know, and recognition survives to far lower contrast than
# reading does.  It also rides on chroma more than reading does, so a fixed
# sample systematically flatters the saturated columns and reports a detection
# threshold under the name of a reading one.
#
# Five letters rather than a mix, so the columns stay aligned and no cell is
# easier by being shorter.  Concrete words with distinct silhouettes: the point
# is to make the wrong guess visibly wrong, not to be hard.
WORDS = (
    "amber", "anvil", "apple", "argue", "badge", "baker", "beach", "beard",
    "began", "bench", "berry", "birch", "blade", "blank", "blaze", "blind",
    "block", "blunt", "brace", "brain", "brass", "bread", "brick", "brief",
    "brisk", "broad", "brook", "brush", "cabin", "cable", "candy", "cargo",
    "carve", "chalk", "charm", "chase", "cheap", "chess", "chief", "chord",
    "cider", "civic", "claim", "clamp", "clash", "clean", "clerk", "cliff",
    "climb", "cloak", "clock", "cloud", "coast", "comet", "coral", "couch",
    "cough", "crane", "crash", "creek", "crisp", "crown", "crumb", "curve",
    "dairy", "dance", "delta", "dense", "depth", "diver", "dodge", "draft",
    "drain", "drape", "dream", "drift", "drink", "drove", "dwell", "eagle",
    "early", "earth", "elbow", "ember", "empty", "equal", "exact", "extra",
    "fable", "faint", "fancy", "fault", "feast", "fence", "fetch", "fever",
    "field", "fifth", "fight", "flame", "flask", "fleet", "flint", "flock",
    "flour", "fluid", "focus", "forge", "found", "frame", "fresh", "frost",
    "fruit", "gauge", "ghost", "giant", "glass", "gleam", "globe", "glove",
    "grain", "grand", "grasp", "grave", "green", "grill", "grove", "guard",
    "guest", "habit", "harsh", "haunt", "heard", "heart", "heavy", "hedge",
    "hinge", "hobby", "honey", "horse", "hotel", "house", "human", "humid",
    "ideal", "index", "inlet", "ivory", "joint", "judge", "knife", "known",
    "label", "lance", "large", "laugh", "layer", "leaky", "learn", "ledge",
    "lemon", "level", "light", "limit", "linen", "liver", "loyal", "lucky",
    "lunar", "magic", "major", "maple", "march", "marsh", "match", "medal",
    "melon", "mercy", "merit", "metal", "meter", "midst", "mimic", "miner",
    "mixed", "model", "moist", "money", "month", "moral", "motor", "mound",
    "mouth", "movie", "music", "naval", "nerve", "newly", "night", "noble",
    "noise", "north", "novel", "nurse", "ocean", "offer", "olive", "onion",
    "orbit", "order", "organ", "otter", "ought", "ounce", "paint", "panel",
    "paper", "party", "patch", "pause", "peach", "pearl", "pedal", "penny",
    "perch", "phase", "phone", "photo", "piano", "piece", "pilot", "pitch",
    "plain", "plane", "plant", "plate", "plaza", "plumb", "point", "porch",
    "pouch", "pound", "power", "press", "price", "pride", "prime", "print",
    "prize", "probe", "prone", "proof", "proud", "prove", "pulse", "punch",
    "pupil", "purse", "quart", "queen", "query", "quest", "quick", "quiet",
    "quilt", "quote", "radar", "radio", "raise", "ranch", "range", "rapid",
    "ratio", "reach", "ready", "realm", "rebel", "refer", "relax", "reply",
    "resin", "ridge", "rifle", "right", "rigid", "rinse", "risky", "river",
    "roast", "robot", "rocky", "rogue", "roman", "rough", "round", "route",
    "royal", "rugby", "rural", "saint", "salad", "sandy", "sauce", "scale",
    "scarf", "scene", "scope", "score", "scout", "scrap", "sedan", "seize",
    "sense", "serve", "seven", "shade", "shaft", "shape", "share", "shark",
    "sharp", "sheep", "sheet", "shelf", "shell", "shift", "shine", "shirt",
    "shock", "shore", "short", "shrug", "sight", "silly", "siren", "sixth",
    "skate", "skill", "slate", "sleep", "slice", "slide", "slope", "small",
    "smart", "smell", "smile", "smoke", "snake", "sneak", "solar", "solid",
    "sorry", "sound", "south", "space", "spare", "spark", "speak", "speed",
    "spell", "spend", "spice", "spike", "spine", "spite", "split", "spoke",
    "spoon", "sport", "spray", "squad", "stack", "staff", "stage", "stain",
    "stake", "stall", "stamp", "stand", "stare", "start", "steam", "steel",
    "steep", "steer", "stern", "stick", "stiff", "still", "sting", "stock",
    "stone", "stool", "storm", "story", "stove", "strap", "straw", "strip",
    "study", "stuff", "sugar", "suite", "sunny", "super", "surge", "swamp",
    "swear", "sweat", "sweep", "sweet", "swift", "swing", "sword", "table",
    "taken", "tally", "tango", "taste", "teach", "tempo", "tenth", "thank",
    "theft", "theme", "thick", "thigh", "thing", "think", "third", "thorn",
    "three", "throw", "thumb", "tiger", "tight", "timer", "title", "toast",
    "today", "token", "tooth", "topic", "torch", "total", "touch", "tough",
    "tower", "trace", "track", "trade", "trail", "train", "trait", "tramp",
    "trash", "treat", "trend", "trial", "tribe", "trick", "troop", "trout",
    "truck", "truly", "trunk", "trust", "truth", "tulip", "tunic", "twice",
    "twist", "ultra", "uncle", "under", "union", "unite", "upper", "urban",
    "usage", "usual", "vague", "valid", "value", "valve", "vapor", "vault",
    "venue", "verse", "video", "vigil", "vinyl", "viral", "virus", "visit",
    "vital", "vivid", "vocal", "vodka", "voice", "vowel", "wafer", "wagon",
    "waist", "waste", "watch", "water", "weary", "weave", "wedge", "whale",
    "wharf", "wheat", "wheel", "where", "which", "while", "whirl", "white",
    "whole", "widen", "width", "wince", "windy", "wiper", "witch", "woman",
    "world", "worry", "worth", "would", "wound", "woven", "wrist", "write",
    "wrong", "yacht", "yeast", "yield", "young", "youth", "zebra",
)

# Four digits and two words, because the two reading tasks have different
# requirements and different failure modes: a digit run has no word shape to
# fall back on, so it is the honest test, while prose can be half-guessed from
# letter silhouettes -- which is what you are actually doing when you read code.
CELL = 18


def sample(rng: random.Random) -> str:
    return f"{rng.randrange(1000, 10000)} {rng.choice(WORDS)} {rng.choice(WORDS)}"


def at_delta(bg: RGB, target: float, chroma: float, hue: float,
             lighter: bool | None = None,
             mul: shader.Multipliers = shader.NEUTRAL) -> RGB:
    """A colour `target` lightness away from bg, on the readable side.

    Away from the background means darker on a light one and lighter on a dark
    one -- the direction that raises contrast rather than the direction that
    happens to be down.  `lighter` overrides that, which matters for a mid
    background like fzf's selected row: text lands on both sides of it there,
    and the two sides need not have the same threshold.  Polarity is the whole
    reason the ratio misleads, so it has to be testable rather than inferred.

    `mul` makes the delta hold after a screen filter rather than before it.
    The colour returned is still what the terminal is told to draw -- the
    filter is applied by the compositor, not here -- but it is chosen so that
    what lands on the glass is `target` away from the filtered background.
    Solving it this way round is the point: label a row 0.03 and show
    something the filter has moved to 0.10 and the reading is worthless.
    """
    filtered_bg = shader.apply(bg, mul)
    bg_l = oklab_lightness(filtered_bg)
    up = bg_l < 0.5 if lighter is None else lighter

    def delta(nominal: float) -> float:
        return lightness_delta(shader.apply(oklch_to_rgb(nominal, chroma, hue), mul),
                               filtered_bg)

    # Where the ramp starts -- the drawable lightness that lands level with the
    # background once filtered.  Unfiltered that is the background's own
    # lightness, but a filter moves it, by different amounts per hue, and to
    # the *dark* side on Frappe: starting the search at the nominal lightness
    # put the level point outside the interval, so the first two rows could not
    # be reached and rendered at 0.063 under a label saying 0.03.
    if mul == shader.NEUTRAL:
        base = oklab_lightness(bg)
    else:
        base = min((i / 256 for i in range(257)), key=delta)

    far = 1.0 if up else 0.0
    if delta(far) < target:
        return oklch_to_rgb(far, chroma, hue)   # unreachable even at the extreme
    lo, hi = (base, far) if up else (far, base)
    for _ in range(24):
        mid = (lo + hi) / 2
        if delta(mid) < target:
            if up:
                lo = mid
            else:
                hi = mid
        elif up:
            hi = mid
        else:
            lo = mid
    return oklch_to_rgb((lo + hi) / 2, chroma, hue)


def _cell(fg: RGB, bg: RGB, text: str) -> str:
    r, g, b = fg
    br, bg_, bb = bg
    return f"\x1b[38;2;{r};{g};{b}m\x1b[48;2;{br};{bg_};{bb}m{text}\x1b[0m"


WIDTH = 8 + CELL * len(HUES)


def grid(seed: int) -> list[list[str]]:
    """The samples, one per cell, drawn from the seed and nothing else.

    Separated from rendering so the answer key is the same draw rather than a
    second one that happens to agree -- a key that can drift from the grid it
    checks is worse than no key, since it would read as a failed reading.
    """
    rng = random.Random(seed)
    return [[sample(rng) for _ in HUES] for _ in STEPS]


def rows(seed: int, descend: bool = False) -> list[tuple[float, list[str]]]:
    """Rows in the order they are shown, so the key cannot disagree with them.

    Drawing is always in STEPS order regardless, so a seed names the same grid
    whichever way it is read; only the presentation reverses.
    """
    pairs = list(zip(STEPS, grid(seed)))
    return pairs[::-1] if descend else pairs


def render(bg: RGB, label: str, anchors: list[tuple[str, RGB]],
           seed: int, lighter: bool | None = None,
           descend: bool = False,
           mul: shader.Multipliers = shader.NEUTRAL) -> str:
    ink = _readable_on(shader.apply(bg, mul))
    side = ("away from the background" if lighter is None
            else "lighter than the background" if lighter
            else "darker than the background")
    seen = shader.apply(bg, mul)
    ground = (rgb_to_hex(bg) if mul == shader.NEUTRAL
              else f"{rgb_to_hex(bg)} seen as {rgb_to_hex(seen)}")
    out = [f"\n  background {ground}  ({label}; ramping {side}; "
           f"seed {seed}; "
           f"{'contrast falls downward' if descend else 'contrast rises downward'})\n",
           _cell(ink, bg,
                 f"{'   ΔL   ' + ''.join(f'{n:<{CELL}}' for n, _, _ in HUES):<{WIDTH}}")]

    for target, texts in rows(seed, descend):
        row = _cell(ink, bg, f"  {target:.2f}  ")
        for (_, hue, chroma), text in zip(HUES, texts):
            row += _cell(at_delta(bg, target, chroma, hue, lighter, mul), bg,
                         f"{text:<{CELL}}")
        out.append(row)

    if anchors:
        rng = random.Random(seed + 1)
        out.append(_cell(ink, bg, " " * WIDTH))
        out.append(_cell(ink, bg,
                         f"{'  anchors -- live pairs, and the mark each one has to clear':<{WIDTH}}"))
        for name, fg in anchors:
            # Reported as seen, so an anchor is comparable to the rows above it
            # rather than to a number the filter has since moved.
            text = (f"  {sample(rng)}   {name} "
                    f"(ΔL {lightness_delta(shader.apply(fg, mul), seen):.3f}, "
                    f"ratio {contrast_ratio(shader.apply(fg, mul), seen):.2f})")
            out.append(_cell(fg, bg, f"{text:<{WIDTH}}"))
    return "\n".join(out)


def key(seed: int, descend: bool = False) -> str:
    """What the grid actually says, for checking a mark rather than trusting it.

    Reading and believing you read are different, and the gap between them is
    exactly where a threshold gets set too low.  Printed on a separate run so
    it cannot be glanced at while marking.
    """
    lines = [f"\n  answer key, seed {seed}",
             "   ΔL   " + "".join(f"{n:<{CELL}}" for n, _, _ in HUES)]
    for target, texts in rows(seed, descend):
        lines.append(f"  {target:.2f}  " + "".join(f"{t:<{CELL}}" for t in texts))
    return "\n".join(lines)


def live_flavor(conf: Path | None = None) -> str:
    """Which flavour the terminal is showing right now.

    Read from the live config rather than assumed, because the ramp is drawn
    over whatever background the terminal actually has: build Latte's colours
    while darkman is on Frappé and every cell is measured against the wrong
    ground, silently, with a plausible-looking result.
    """
    conf = conf or (Path(os.environ.get("XDG_CONFIG_HOME",
                                        Path.home() / ".config"))
                    / "kitty/kitty.conf")
    if not conf.exists():
        return "latte"
    # Only the background is wanted, so scan for it rather than going through
    # load_palette, which insists on all sixteen ANSI keys being present.
    # Includes still have to be followed: the flavour file sets the background,
    # the top-level conf only overrides a couple of slots.
    found: dict[str, str] = {}
    _scan(conf, found, [])
    if "background" not in found:
        return "latte"
    return ("frappe" if oklab_lightness(hex_to_rgb(found["background"])) < 0.5
            else "latte")


def _readable_on(bg: RGB) -> RGB:
    """High-contrast ink for the labels, so they never become the thing tested."""
    return (0, 0, 0) if oklab_lightness(bg) > 0.5 else (255, 255, 255)


def _achieved(bg: RGB, lighter: bool | None = None,
              descend: bool = False,
              mul: shader.Multipliers = shader.NEUTRAL) -> str:
    """What the ramp actually renders, since sRGB cannot hold chroma everywhere.

    Reported rather than silently clipped: at the pale end oklch_to_rgb reduces
    chroma to fit the gamut, so a column labelled 0.17 may be delivering half
    that, and a flat-looking result there would otherwise be misread as
    evidence against the chroma penalty.
    """
    lines = ["\n  chroma actually delivered (the sRGB maximum at each "
             "lightness, not a fixed request)",
             "   ΔL   " + "".join(f"{n:<{CELL}}" for n, _, _ in HUES)]
    for target in (STEPS[::-1] if descend else STEPS):
        row = [f"  {target:.2f}  "]
        for _, hue, chroma in HUES:
            cell = at_delta(bg, target, chroma, hue, lighter, mul)
            got = rgb_to_oklch(shader.apply(cell, mul))[1]
            row.append(f"{got:<{CELL}.3f}")
        lines.append("".join(row))
    return "\n".join(lines)


PROMPT = """
  {order}

  Every cell says something different, so you have to actually read it. Two
  marks per column, and they are different questions -- "can read it" sits a
  long way below "would read it", and both ends are load-bearing:

      body     the smallest ΔL you would read a screenful of without
               noticing the contrast
      glance   the smallest ΔL where you can still pull all three tokens
               off correctly when you look at it, even though you would
               not want to read anything at it

      body    grey 0.19   red 0.26   yellow 0.19   green 0.22   blue 0.30
      glance  grey 0.11   red 0.16   yellow 0.13   green 0.13   blue 0.19

  The gap between them is the useful part. Prose, code and anything you read
  has to clear the body mark. Line numbers, separators, brackets and box
  drawing only have to clear the glance mark, and are meant to sit below
  body: quiet structure that stays out of the way is the design goal there,
  not a defect to be fixed. Below the glance mark is decoration, and the
  audit should say so.

  Say the marks out loud or jot them down before checking, then run the same
  command with --key --seed {seed} and compare. If a row you marked turns out
  wrong, your real threshold is the next one up. Guessing right by luck and
  guessing wrong both matter here: the mark is only worth what it was checked
  against.

  Approaching a threshold from below and from above give different answers --
  coming down from legible you tend to insist you can still read a row you
  have already lost, and the bias is the other way going up. {other} The
  truth is between the two marks, so run it both ways if the number matters.

  {filter}

  Read at your normal distance and lighting. Fullscreen the terminal first:
  Hyprland composites non-fullscreen windows at 0.95 over the wallpaper,
  which moves every colour here slightly.
"""

FILTERED = ("{name} is running, and the rows above are corrected for it: each "
            "one is the stated ΔL as it lands on the glass, not as the "
            "terminal was told to draw it. Mark it as you see it. Measure "
            "each flavour under the filter state it is actually used in -- a "
            "day theme measured at night is a measurement of a combination "
            "that never occurs.")

UNFILTERED = ("No screen shader is running, so the rows are what the terminal "
              "draws. If one comes on mid-session the numbers stop meaning "
              "what they say, so finish the pass or start it again.")

ASCENDING = ("Contrast RISES as you go down: the top row is ΔL 0.03 and "
             "should be illegible, the bottom row is 0.35 and should be "
             "easy. So start at the top and come down until it resolves.")

DESCENDING = ("Contrast FALLS as you go down: the top row is ΔL 0.35 and "
              "should be easy, the bottom row is 0.03 and should be "
              "illegible. So start at the top and come down until it fails.")


def _wrap(text: str) -> str:
    """Re-flow the prose after substitution, leaving the examples alone.

    The direction blurb and the --descend pointer are both substituted in as
    single long strings, so wrapping has to happen after formatting rather
    than in the literal.  Lines indented deeper than the body are the worked
    examples and the role definitions, where the line breaks are the layout.
    """
    out: list[str] = []
    para: list[str] = []

    def flush() -> None:
        if para:
            out.append(textwrap.fill(" ".join(para), 78,
                                     initial_indent="  ", subsequent_indent="  "))
            para.clear()

    for line in text.splitlines():
        if line.startswith("      ") or not line.strip():
            flush()
            out.append(line)
        else:
            para.append(line.strip())
    flush()
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="contrast-calibrate",
        description="Ramps at known lightness delta, for eyeball calibration.")
    p.add_argument("--flavor", choices=("latte", "frappe"), default=None,
                   help="default: whichever the terminal is actually showing")
    p.add_argument("--repo", type=Path,
                   default=Path("/home/abclop99/.config/home-manager"))
    p.add_argument("--on", metavar="HEX", default=None,
                   help="calibrate against this background instead of the "
                        "palette's, e.g. '#6c6f85' for fzf's selected row")
    p.add_argument("--chroma-table", action="store_true",
                   help="also print the chroma each cell actually delivers")
    p.add_argument("--direction", choices=("auto", "lighter", "darker"),
                   default="auto",
                   help="which way to ramp. auto goes away from the "
                        "background; name a side to test a mid background "
                        "like fzf's selected row, which carries text on both")
    p.add_argument("--seed", type=int, default=None,
                   help="which samples to draw. default: a fresh one, printed "
                        "in the header so --key can reproduce it")
    p.add_argument("--key", action="store_true",
                   help="print what the grid says instead of drawing it, to "
                        "check a mark against what was actually there")
    p.add_argument("--descend", action="store_true",
                   help="put the highest contrast at the top, so the threshold "
                        "is approached from above. the two directions bias "
                        "opposite ways; the answer is between them")
    p.add_argument("--filter", default="auto", metavar="AUTO|OFF|KELVIN",
                   help="screen shader to correct for. auto follows whatever "
                        "hyprland is running; off ignores it; a number forces "
                        "that temperature, which is how to measure the night "
                        "condition during the day")
    args = p.parse_args(argv)
    lighter = {"auto": None, "lighter": True, "darker": False}[args.direction]
    seed = args.seed if args.seed is not None else random.randrange(1000, 10000)

    if args.key:
        if args.seed is None:
            raise SystemExit("--key needs the --seed the grid was drawn with; "
                             "it is printed in that run's header")
        print(key(seed, args.descend))
        return 0

    flavor = args.flavor or live_flavor()
    variant = {"latte": "light", "frappe": "dark"}[flavor]
    conf = (args.repo / "result/specialisation" / variant
            / "home-files/.config/kitty/kitty.conf")
    if not conf.exists():
        raise SystemExit(f"{conf} missing -- run hm-build first")
    palette = load_palette(conf, flavor=flavor)

    if args.flavor and live_flavor() != args.flavor:
        print(f"  WARNING: this terminal is showing {live_flavor()}, but the "
              f"ramp is built from {args.flavor}'s palette.\n"
              "  The colours below will be drawn over the wrong background "
              "and the reading is worthless.\n"
              "  Switch darkman, or drop --flavor to follow the terminal.\n",
              file=sys.stderr)

    mul, shader_name = shader.NEUTRAL, None
    if args.filter == "auto":
        found = shader.active()
        if found:
            mul, shader_name = found
    elif args.filter != "off":
        try:
            kelvin = float(args.filter)
        except ValueError:
            raise SystemExit(f"--filter wants auto, off or a temperature in "
                             f"kelvin, not {args.filter!r}")
        mul, shader_name = shader.multipliers(kelvin), f"a forced {kelvin:.0f}K"

    bg = hex_to_rgb(args.on) if args.on else palette.background
    label = flavor if not args.on else f"{flavor}, on {args.on}"
    if shader_name:
        label += f"; through {shader_name}"

    # Named with the mark each is meant to clear, because the anchors are how
    # the two marks get checked against something already in use: body text
    # failing the body mark would be a real defect, whereas line numbers
    # sitting below it is the intended design and only the glance mark applies.
    anchors = [("body text (body)", palette.foreground)]
    for name, token in (("helix line numbers (glance)", "surface1"),
                        ("comments (glance)", "overlay0")):
        if token in palette.tokens:
            anchors.append((name, palette.tokens[token]))

    print(render(bg, label, anchors, seed, lighter, args.descend, mul))
    if args.chroma_table:
        print(_achieved(bg, lighter, args.descend, mul))
    print(_wrap(PROMPT.format(
        seed=seed,
        order=DESCENDING if args.descend else ASCENDING,
        filter=(FILTERED.format(name=shader_name) if shader_name
                else UNFILTERED),
        other=("Run it again without --descend for the other direction."
               if args.descend else
               "Run it again with --descend for the other direction."))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
