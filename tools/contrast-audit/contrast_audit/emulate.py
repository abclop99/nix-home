"""Terminal emulation: raw pty bytes to a grid of cells.

Two things pyte 0.8.2 gets in our way, both verified against its source and
patched here before any Screen is constructed:

1. It converts 256-indexed colours through its own xterm table, flattening
   them to hex.  That destroys the palette slot for indices 0-15, and makes a
   cube colour indistinguishable from an identical truecolour value -- exactly
   the provenance the report needs.  So the whole table is replaced with
   markers: 5 characters for 0-15, 4 for 16-255, neither of which can collide
   with a 6-hex-digit truecolour string.

2. It drops SGR 2 (dim) entirely.  That matters because kitty here sets
   dim_opacity 0.75 precisely because dim text was hard to read, so measuring
   dim cells at full colour would overstate their contrast.  Char is a
   NamedTuple and select_graphic_rendition maps TEXT entries straight onto
   field names via _replace, so adding a field plus a TEXT entry is enough --
   for setting it.  Clearing it needs the Screen subclass below.
"""
import re
from dataclasses import dataclass
from typing import NamedTuple

import pyte
import pyte.graphics
import pyte.screens

# pyte 0.8.2 implements no DCS handler, so a device-control string lands on
# screen as literal text -- fish's XTGETTCAP query renders as
# "+q696e646e+q71756572792d6f732d6e616d65". These carry no display content,
# so drop them before emulating. (drive() separately *answers* them, which is
# what stops the programme waiting.)
_DCS = re.compile(rb"\x1bP.*?(?:\x1b\\|\x07)", re.S)


class _DimChar(NamedTuple):
    """pyte's Char, plus the dim attribute it otherwise discards."""

    data: str
    fg: str = "default"
    bg: str = "default"
    bold: bool = False
    italics: bool = False
    underscore: bool = False
    strikethrough: bool = False
    reverse: bool = False
    blink: bool = False
    dim: bool = False


class _Screen(pyte.Screen):
    """pyte's Screen, with SGR 22 clearing dim as well as bold.

    ECMA-48 22 is "normal intensity" and cancels both bold (1) and faint (2),
    but pyte's TEXT table maps one SGR code onto exactly one attribute, so the
    22 entry can only say "-bold".  Left alone, `ESC[2m...ESC[22m` leaves dim
    latched until a full `ESC[0m`, and every later cell in the frame is blended
    toward the background at dim_opacity -- understating contrast for the rest
    of the capture and manufacturing findings the terminal never showed.  That
    exact pair is what chalk.dim() emits, i.e. the output dim_opacity was
    raised for in the first place.
    """

    def select_graphic_rendition(self, *attrs: int) -> None:
        super().select_graphic_rendition(*attrs)
        if 22 in attrs:
            self.cursor.attrs = self.cursor.attrs._replace(dim=False)


_PATCHED = False


def install_pyte_patches() -> None:
    """Make pyte preserve colour provenance and the dim attribute.

    Idempotent, and must run before any Screen is constructed.
    """
    global _PATCHED
    if _PATCHED:
        return

    for i in range(16):
        pyte.graphics.FG_BG_256[i] = f"idx{i:02d}"
    for i in range(16, 256):
        pyte.graphics.FG_BG_256[i] = f"c{i:03d}"

    pyte.screens.Char = _DimChar
    pyte.graphics.TEXT[2] = "+dim"
    # Screen.reset() does `self.cursor = Cursor(0, 0)`, and Cursor.__init__'s
    # default attrs was bound to the ORIGINAL Char at class-definition time --
    # so without this the cursor starts out lacking the field and the first
    # SGR raises "Got unexpected field names: ['dim']".
    pyte.screens.Cursor.__init__.__defaults__ = (_DimChar(" "),)

    _PATCHED = True


@dataclass(frozen=True)
class Cell:
    char: str
    fg: str
    bg: str
    bold: bool
    dim: bool
    reverse: bool


def emulate(data: bytes, cols: int, rows: int) -> list[list[Cell]]:
    """Feed captured pty bytes through a terminal emulator into a cell grid."""
    install_pyte_patches()
    screen = _Screen(cols, rows)
    pyte.ByteStream(screen).feed(_DCS.sub(b"", data))

    grid = []
    for y in range(rows):
        line = screen.buffer[y]
        grid.append([
            Cell(
                # NB: no `or " "`.  An empty string is pyte's double-width stub
                # marker; replacing it with a space would shift the whole row,
                # since the browser already advances two columns for the glyph.
                char=line[x].data,
                fg=line[x].fg,
                bg=line[x].bg,
                bold=line[x].bold,
                dim=getattr(line[x], "dim", False),
                reverse=line[x].reverse,
            )
            for x in range(cols)
        ])
    return grid
