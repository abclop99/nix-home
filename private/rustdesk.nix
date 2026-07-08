# Machine-local RustDesk server coordinates. Tracked in git with placeholder
# content; the real values live only on disk via `git update-index
# --skip-worktree` (see CLAUDE.md "Private files"). Consumed by
# modules/rustdesk.nix. `key` is the base64 contents of the server's
# hbbs `id_ed25519.pub` (public — not secret; the address is kept private).
{
  rendezvousServer = "";
  relayServer = "";
  key = "";
}
