# Git identity and signing key. Tracked in git with placeholder content; the
# real values live only on disk via `git update-index --skip-worktree` (see
# CLAUDE.md "Private files"). Consumed by modules/git.nix.
#
# The identity belongs to whoever runs this config, not to whoever wrote it, so
# the placeholder is null rather than a working default: a fresh clone gets
# "Author identity unknown" from git until it is filled in, instead of silently
# authoring commits as someone else.
#
# null, not "": modules/git.nix drops null keys, leaving user.name/user.email
# absent. An empty user.email would instead override git's EMAIL fallback and
# record commits with no author email at all.
#
# `signingKey` is a GPG key id; null disables signing. A trailing `!` forces
# that exact (sub)key.
{
  name = null;
  email = null;
  signingKey = null;
}
