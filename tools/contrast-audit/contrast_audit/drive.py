"""Run a command under a pty and capture what it draws."""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import termios
import time

# Programmes interrogate the terminal at startup and wait for answers. pyte is
# an emulator, not a terminal, so it never replies -- fish stalls on XTGETTCAP
# and prints the raw payload, and full-screen TUIs hang before drawing. drive()
# answers the common queries itself.
_DCS_QUERY = re.compile(rb"\x1bP\+q[0-9A-Fa-f;]*\x1b\\")
_XTVERSION = re.compile(rb"\x1b\[>0?q")
_DA1 = re.compile(rb"\x1b\[0?c")
_DA2 = re.compile(rb"\x1b\[>0?c")
_DSR_STATUS = re.compile(rb"\x1b\[5n")
_DSR_CURSOR = re.compile(rb"\x1b\[6n")
_OSC_COLOUR = re.compile(rb"\x1b\](1[01]);\?(?:\x07|\x1b\\)")

_FIXED_QUERIES = (
    (_DA1, b"\x1b[?62;22c"),
    (_DA2, b"\x1b[>1;95;0c"),
    (_DSR_STATUS, b"\x1b[0n"),
    (_DSR_CURSOR, b"\x1b[1;1R"),
    (_XTVERSION, b"\x1bP>|contrast-audit(1)\x1b\\"),
    (_DCS_QUERY, b"\x1bP0+r\x1b\\"),
)

# How much of the previous read to re-scan, so a query straddling the boundary
# is still seen whole.  Longer than any query above: the variable-length one is
# XTGETTCAP, and fish's is around 60 bytes.
SEAM_BYTES = 256


def _osc_reply(index: bytes, rgb: tuple[int, int, int]) -> bytes:
    r, g, b = rgb
    return b"\x1b]%s;rgb:%04x/%04x/%04x\x07" % (index, r * 257, g * 257, b * 257)


def terminal_replies(
    data: bytes,
    foreground: tuple[int, int, int] | None = None,
    background: tuple[int, int, int] | None = None,
    after: int = 0,
) -> bytes:
    """What a real terminal would send back in response to `data`.

    Deliberately minimal: enough for programmes to stop waiting and draw.
    XTGETTCAP is answered with the "unsupported" form rather than real
    capability strings, which is a valid response and is what matters.

    `after` skips matches ending at or before that index.  The caller prepends
    a tail of the previous read so a query split across the boundary is still
    matched; those bytes have already been scanned once, and answering them
    twice would send a stray reply into the programme's input.
    """
    out = bytearray()
    for pattern, reply in _FIXED_QUERIES:
        for match in pattern.finditer(data):
            if match.end() > after:
                out += reply
    for match in _OSC_COLOUR.finditer(data):
        if match.end() <= after:
            continue
        rgb = foreground if match.group(1) == b"10" else background
        if rgb is not None:
            out += _osc_reply(match.group(1), rgb)
    return bytes(out)


class DriveError(RuntimeError):
    """The driven programme could not be started, or died without drawing."""


def _set_winsize(fd: int, cols: int, rows: int) -> None:
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def drive(
    argv: list[str],
    keys: list[tuple[int, bytes]] | None = None,
    cols: int = 100,
    rows: int = 30,
    env: dict[str, str] | None = None,
    cwd: str | None = None,
    quiet_ms: int = 300,
    timeout_s: float = 15.0,
    max_bytes: int = 4_000_000,
    foreground: tuple[int, int, int] | None = None,
    background: tuple[int, int, int] | None = None,
) -> bytes:
    """Spawn argv on a pty of the given size and capture its output.

    `keys` entries are (delay_ms_after_the_previous_key, bytes); the first
    delay is measured from start.  Returns once output has been quiet for
    quiet_ms with no keys outstanding, or timeout_s elapses, or max_bytes is
    reached.
    """
    full_env = {**os.environ, "TERM": "xterm-256color",
                "COLORTERM": "truecolor", **(env or {})}

    master, slave = pty.openpty()
    # Size the tty before the child exists.  Doing it on the master after
    # forking races the child's startup read, and a child that loses sees 0x0
    # and falls back to 80x24 while we emulate at cols x rows -- a silently
    # mis-shaped grid with no error anywhere.
    _set_winsize(slave, cols, rows)

    def _child_setup() -> None:
        # Make the pty the child's CONTROLLING terminal, not merely its stdio.
        # start_new_session alone calls setsid, which detaches from any old
        # controlling tty but acquires no new one -- that needs TIOCSCTTY,
        # which os.login_tty does along with setsid and the stdio dups.
        # Without it interactive shells fail with "No TTY for interactive
        # shell (tcgetpgrp failed)" and full-screen TUIs will not draw.
        os.login_tty(slave)

    try:
        proc = subprocess.Popen(
            argv, stdin=slave, stdout=slave, stderr=slave,
            env=full_env, cwd=cwd, close_fds=True, preexec_fn=_child_setup,
        )
    except (FileNotFoundError, PermissionError) as exc:
        os.close(master)
        os.close(slave)
        raise DriveError(f"cannot exec {argv[0]!r}: {exc}") from exc
    os.close(slave)

    pending = list(keys or [])
    now = time.monotonic()
    next_key_at = now + (pending[0][0] / 1000 if pending else 0.0)
    last_output = now
    deadline = now + timeout_s
    chunks: list[bytes] = []
    total = 0
    seam = b""      # tail of the previous read, re-scanned with the next one

    try:
        while True:
            now = time.monotonic()
            if now > deadline or total >= max_bytes:
                break

            while pending and now >= next_key_at:
                os.write(master, pending.pop(0)[1])
                # Reset the quiet timer.  A TUI is silent between its first
                # draw and the keystroke, so without this the quiet condition
                # is already satisfied the moment the last key is dispatched
                # and the capture returns the frame BEFORE the key.
                last_output = now
                if pending:
                    next_key_at = now + pending[0][0] / 1000

            if chunks and not pending and (now - last_output) * 1000 > quiet_ms:
                break

            ready, _, _ = select.select([master], [], [], 0.05)
            if not ready:
                continue
            try:
                data = os.read(master, 65536)
            except OSError:
                break  # EIO on Linux once the child closes its end
            if not data:
                break
            chunks.append(data)
            total += len(data)
            last_output = time.monotonic()

            # Answer any terminal interrogation in this chunk, or the
            # programme sits waiting for a reply and never finishes drawing.
            # Scanned together with the previous read's tail: a query that
            # straddles a 64 KiB boundary matches neither half on its own, and
            # the programme then blocks until timeout_s while drive() scores
            # the half-drawn frame as an ordinary capture.
            probe = seam + data
            reply = terminal_replies(probe, foreground, background,
                                     after=len(seam))
            seam = probe[-SEAM_BYTES:]
            if reply:
                os.write(master, reply)
    finally:
        try:
            os.close(master)
        except OSError:
            pass
        try:
            # The whole group, not just the child: `sh -c "a | b"` leaves
            # grandchildren behind. start_new_session made proc the leader.
            os.killpg(proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass

    if not chunks:
        # A missing binary otherwise yields a blank grid that reports as a
        # clean pass -- the most dangerous possible failure mode here.
        raise DriveError(
            f"{argv[0]!r} produced no output (exit {proc.returncode})"
        )
    return b"".join(chunks)
