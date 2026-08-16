import json

from contrast_audit.cli import _merge_summary


def entry(fixture, worst=5.0, palette="catppuccin-latte", lens="as specified"):
    return {"fixture": fixture, "worst": worst, "palette": palette,
            "lens": lens}


def write(tmp_path, entries):
    (tmp_path / "summary.json").write_text(json.dumps(entries))
    return tmp_path


def test_a_full_run_with_no_previous_summary_is_kept_as_is(tmp_path):
    fresh = [entry("rg-matches"), entry("bat-nix")]
    assert _merge_summary(tmp_path, fresh) == fresh


def test_rerunning_one_fixture_keeps_the_others_in_the_index(tmp_path):
    out = write(tmp_path, [entry("rg-matches"), entry("bat-nix")])
    merged = _merge_summary(out, [entry("bat-nix", worst=2.0)])
    assert {e["fixture"] for e in merged} == {"rg-matches", "bat-nix"}


def test_the_rerun_entry_wins_over_the_stored_one(tmp_path):
    out = write(tmp_path, [entry("bat-nix", worst=5.0)])
    merged = _merge_summary(out, [entry("bat-nix", worst=2.0)])
    assert [e["worst"] for e in merged] == [2.0]


def test_entries_measured_under_another_lens_are_dropped(tmp_path):
    # Two lenses in one table would give the reader no way to tell the rows
    # apart, so the stale one goes rather than being merged.
    out = write(tmp_path, [entry("rg-matches", lens="over #101010")])
    merged = _merge_summary(out, [entry("bat-nix")])
    assert [e["fixture"] for e in merged] == ["bat-nix"]


def test_entries_measured_under_another_palette_are_dropped(tmp_path):
    out = write(tmp_path, [entry("rg-matches", palette="catppuccin-frappe")])
    merged = _merge_summary(out, [entry("bat-nix")])
    assert [e["fixture"] for e in merged] == ["bat-nix"]


def test_merged_entries_follow_the_fixture_order(tmp_path):
    # Not insertion order: the index reads as a fixed list of programmes.
    out = write(tmp_path, [entry("bat-nix")])
    merged = _merge_summary(out, [entry("rg-matches")])
    assert [e["fixture"] for e in merged] == ["rg-matches", "bat-nix"]


def test_a_run_where_every_fixture_failed_does_not_wipe_the_summary(tmp_path):
    out = write(tmp_path, [entry("rg-matches")])
    assert [e["fixture"] for e in _merge_summary(out, [])] == ["rg-matches"]
