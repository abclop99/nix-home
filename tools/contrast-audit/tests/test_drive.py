import re
import subprocess
import time

import pytest

from contrast_audit.drive import (
    SEAM_BYTES,
    DriveError,
    drive,
    terminal_replies,
)


def test_captures_simple_output():
    assert b"hello" in drive(["echo", "hello"])


def test_window_size_is_applied():
    out = drive(["sh", "-c", "tput cols; tput lines"], cols=77, rows=23)
    assert b"77" in out and b"23" in out


def test_environment_is_passed():
    assert b"marker" in drive(["sh", "-c", "echo $CT"], env={"CT": "marker"})


def test_term_is_set_for_colour():
    assert b"xterm-256color" in drive(["sh", "-c", "echo $TERM"])


def test_keys_are_delivered():
    assert b"typed" in drive(["cat"], keys=[(50, b"typed\r")])


def test_child_gets_a_controlling_terminal():
    """setsid detaches from the old controlling tty but acquires no new one;
    that needs TIOCSCTTY. Without it interactive shells refuse to start
    ("No TTY for interactive shell") and full-screen TUIs never draw.
    Opening /dev/tty succeeds only when a controlling terminal exists.
    """
    out = drive(["sh", "-c",
                 "if : < /dev/tty 2>/dev/null; then echo HASCTTY; "
                 "else echo NOCTTY; fi"])
    assert b"HASCTTY" in out
    assert b"NOCTTY" not in out


def test_interactive_shell_starts_without_tty_warnings():
    out = drive(["fish", "-i"], keys=[(500, b"echo marker")], timeout_s=8)
    assert b"No TTY" not in out
    assert b"Inappropriate ioctl" not in out


def test_replies_to_primary_device_attributes():
    assert terminal_replies(b"\x1b[c") == b"\x1b[?62;22c"
    assert terminal_replies(b"\x1b[0c") == b"\x1b[?62;22c"


def test_replies_to_status_and_cursor_reports():
    assert terminal_replies(b"\x1b[5n") == b"\x1b[0n"
    assert terminal_replies(b"\x1b[6n") == b"\x1b[1;1R"


def test_replies_to_xtgettcap_with_the_unsupported_form():
    """fish sends this at startup; unanswered it stalls and the raw payload
    renders as text, since pyte implements no DCS handler."""
    query = b"\x1bP+q696e646e\x1b\\"
    assert terminal_replies(query) == b"\x1bP0+r\x1b\\"


def test_replies_to_xtversion():
    assert terminal_replies(b"\x1b[>q").startswith(b"\x1bP>|")


def test_replies_to_background_colour_query():
    reply = terminal_replies(b"\x1b]11;?\x07", background=(239, 241, 245))
    assert reply == b"\x1b]11;rgb:efef/f1f1/f5f5\x07"


def test_no_reply_when_nothing_was_asked():
    assert terminal_replies(b"just some output\n") == b""


def test_after_suppresses_queries_already_answered_in_the_previous_read():
    # The seam bytes were scanned once already; answering them again would
    # push a stray reply into the programme's input.
    assert terminal_replies(b"\x1b[6n", after=4) == b""


def test_a_query_split_across_the_read_boundary_is_still_answered():
    # os.read can cut anywhere. Neither half matches alone, so without the
    # carried seam the programme waits for a reply that never comes and the
    # capture is whatever it had drawn by the timeout.
    first, second = b"padding\x1b[", b"6n"
    assert terminal_replies(first) == b""
    assert terminal_replies(second) == b""
    probe = first + second
    assert terminal_replies(probe, after=len(first)) == b"\x1b[1;1R"


def test_the_seam_is_longer_than_the_longest_query_answered():
    # XTGETTCAP is the variable-length one; fish's runs to about 60 bytes.
    assert SEAM_BYTES > 64


def test_capability_query_does_not_render_as_text():
    """The observable symptom of the unanswered query, seen in the first fish
    capture: the hex payload displayed on screen.

    Asserted against the emulated grid, not the raw bytes -- the raw stream
    legitimately contains fish's own outgoing query; what must not happen is
    that it reaches the screen.
    """
    from contrast_audit.emulate import emulate

    out = drive(["fish", "-i"], keys=[(600, b"echo hi")], timeout_s=8)
    grid = emulate(out, cols=100, rows=12)
    screen = "".join(c.char for row in grid for c in row)
    assert "696e646e" not in screen
    assert "+q" not in screen


def test_interactive_shell_actually_highlights():
    """Colour SGR on the typed line proves fish got far enough to syntax
    highlight, rather than merely starting.

    Asserted as basic ANSI rather than truecolour, and truecolour is asserted
    ABSENT: fish is deliberately left on its built-in defaults so its colours
    are palette indices the terminal resolves. If truecolour reappears here,
    something has re-themed fish with baked hex, which brings back both the
    stale-across-darkman-switch bug and permanent scrollback.
    """
    out = drive(["fish", "-i"], keys=[(600, b'echo "hi" --flag')], timeout_s=8)
    assert re.search(rb"\x1b\[(3[0-7]|9[0-7])m", out), "no ANSI colour emitted"
    assert b"\x1b[38;2;" not in out, "fish emitted truecolour; it should not"


def test_key_resets_the_quiet_timer():
    """The trap: a TUI is silent between its first draw and the keystroke, so
    a quiet timer that only advances on reads fires the instant the last key
    is dispatched and returns the frame BEFORE the key.

    `stty -echo` is essential -- with echo on, the tty line discipline echoes
    the injected bytes and resets the timer incidentally, so a cat-based test
    passes even when the mechanism is broken.
    """
    out = drive(
        ["sh", "-c", "stty -echo; printf FRAME1; read x; printf FRAME2"],
        keys=[(800, b"\r")], quiet_ms=300, timeout_s=6,
    )
    assert b"FRAME1" in out
    assert b"FRAME2" in out


def test_key_delays_are_relative_to_the_previous_key():
    """Absolute-from-start semantics would fire both keys in one iteration."""
    out = drive(
        ["sh", "-c",
         "stty -echo; read a; printf FIRST; read b; printf SECOND"],
        keys=[(200, b"\r"), (600, b"\r")], quiet_ms=300, timeout_s=8,
    )
    assert b"FIRST" in out and b"SECOND" in out


def test_missing_binary_raises_rather_than_returning_blank():
    with pytest.raises(DriveError, match="cannot exec"):
        drive(["definitely-not-a-real-binary-xyz"])


def test_silent_command_raises():
    with pytest.raises(DriveError, match="no output"):
        drive(["true"], timeout_s=3)


def test_output_is_bounded():
    out = drive(["yes", "spam"], timeout_s=5, max_bytes=100_000)
    assert len(out) < 1_000_000


def test_grandchildren_are_reaped():
    drive(["sh", "-c", "sleep 47 & echo started; wait"], timeout_s=2)
    time.sleep(0.4)
    running = subprocess.run(["ps", "-eo", "args"], capture_output=True).stdout
    assert b"sleep 47" not in running


def test_cwd_is_honoured(tmp_path):
    (tmp_path / "marker.txt").write_text("x")
    assert b"marker.txt" in drive(["ls"], cwd=str(tmp_path))
