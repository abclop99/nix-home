from contrast_audit.emulate import Cell, emulate


def test_plain_text():
    grid = emulate(b"hi", cols=4, rows=1)
    assert [c.char for c in grid[0][:2]] == ["h", "i"]
    assert grid[0][0].fg == "default"
    assert grid[0][0].bg == "default"


def test_grid_dimensions():
    grid = emulate(b"", cols=7, rows=3)
    assert len(grid) == 3
    assert all(len(row) == 7 for row in grid)
    assert all(isinstance(c, Cell) for row in grid for c in row)


def test_ansi_named_colour_preserved():
    assert emulate(b"\x1b[31mX", cols=4, rows=1)[0][0].fg == "red"


def test_ansi_index_3_is_brown_not_yellow():
    # pyte's own naming; the resolver's table must match it exactly
    assert emulate(b"\x1b[33mX", cols=4, rows=1)[0][0].fg == "brown"


def test_bright_ansi_name():
    assert emulate(b"\x1b[91mX", cols=4, rows=1)[0][0].fg == "brightred"


def test_pyte_082_background_typo_is_observable():
    # Documents the upstream defect the resolver has to absorb
    assert emulate(b"\x1b[105mX", cols=4, rows=1)[0][0].bg == "bfightmagenta"


def test_index_colour_becomes_sentinel():
    assert emulate(b"\x1b[38;5;7mX", cols=4, rows=1)[0][0].fg == "idx07"


def test_cube_colour_becomes_sentinel():
    assert emulate(b"\x1b[38;5;208mX", cols=4, rows=1)[0][0].fg == "c208"


def test_cube_and_equivalent_truecolor_are_distinguishable():
    """Without cube sentinels pyte flattens both to the same hex, and an
    application's fixed xterm colour would be misfiled as truecolour."""
    cube = emulate(b"\x1b[38;5;208mX", cols=4, rows=1)[0][0].fg
    true = emulate(b"\x1b[38;2;255;135;0mX", cols=4, rows=1)[0][0].fg
    assert cube == "c208"
    assert true == "ff8700"
    assert cube != true


def test_truecolor_preserved():
    assert emulate(b"\x1b[38;2;18;52;86mX", cols=4, rows=1)[0][0].fg == "123456"


def test_background_sentinel():
    assert emulate(b"\x1b[48;5;4mX", cols=4, rows=1)[0][0].bg == "idx04"


def test_bold():
    assert emulate(b"\x1b[1mX", cols=4, rows=1)[0][0].bold is True


def test_reverse():
    assert emulate(b"\x1b[7mX", cols=4, rows=1)[0][0].reverse is True


def test_dim_is_recovered():
    """pyte 0.8.2 drops SGR 2; the patch restores it, else dim text is
    measured at full colour and its contrast overstated."""
    assert emulate(b"\x1b[2mX", cols=4, rows=1)[0][0].dim is True
    assert emulate(b"X", cols=4, rows=1)[0][0].dim is False


def test_dim_combines_with_colour():
    cell = emulate(b"\x1b[2;31mX", cols=4, rows=1)[0][0]
    assert cell.dim is True
    assert cell.fg == "red"


def test_dim_cleared_by_full_reset():
    assert emulate(b"\x1b[2m\x1b[0mX", cols=4, rows=1)[0][0].dim is False


def test_dim_cleared_by_normal_intensity():
    # SGR 22 cancels faint as well as bold; pyte's table only knows "-bold".
    assert emulate(b"\x1b[2m\x1b[22mX", cols=4, rows=1)[0][0].dim is False


def test_normal_intensity_does_not_latch_dim_across_the_rest_of_the_row():
    grid = emulate(b"\x1b[2mab\x1b[22mcd", cols=4, rows=1)
    assert [c.dim for c in grid[0]] == [True, True, False, False]


def test_normal_intensity_still_clears_bold():
    assert emulate(b"\x1b[1m\x1b[22mX", cols=4, rows=1)[0][0].bold is False


def test_wide_glyph_stub_is_empty_not_space():
    grid = emulate("中".encode(), cols=4, rows=1)
    assert grid[0][0].char == "中"
    assert grid[0][1].char == ""


def test_cursor_addressing():
    # proves full-screen TUIs, which paint by absolute position, will work
    assert emulate(b"\x1b[2;3HZ", cols=5, rows=3)[1][2].char == "Z"


def test_erase_and_repaint():
    grid = emulate(b"garbage\x1b[2J\x1b[1;1Hclean", cols=10, rows=1)
    assert "".join(c.char for c in grid[0]).strip() == "clean"


def test_patches_are_idempotent():
    for _ in range(3):
        assert emulate(b"\x1b[38;5;7mX", cols=2, rows=1)[0][0].fg == "idx07"
