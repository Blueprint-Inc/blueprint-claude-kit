# GitHub setup

Required. The issue workflows, worktrees, and pull requests all run through the GitHub
CLI. Nothing in this guide is specific to any organization.

Placeholders look like `<this>` — replace the whole thing, brackets included.

---

## 1. Account

You need a GitHub account, and push access to at least one repository you want to work
in. A personal account on the free tier is enough to use every workflow in the kit.

If your work lives in an organization, you also need to be a member of it. Ask an owner
for an invitation; you cannot add yourself.

---

## 2. Authentication

Install the CLI:

```
brew install gh
```

Then authenticate. This opens a browser, so it cannot be scripted:

```
gh auth login --hostname github.com --git-protocol https --web
```

*(syntax verified, not executed — it requires an interactive browser login.)*

**Choose HTTPS, not SSH**, which the `--git-protocol https` flag above does for you. The
kit derives the clone protocol from this setting rather than hardcoding one, so picking
SSH here without an SSH key configured produces clone failures later that look unrelated.

Confirm which protocol you ended up with:

```
gh config get git_protocol
```

That should print `https`.

### Scopes

The workflows read and write issues, pull requests, and Actions. Check what your token
carries:

```
gh auth status
```

Look at the `Token scopes:` line. You need at least `repo` and `workflow`. If either is
missing, add them without starting over:

```
gh auth refresh --scopes repo,workflow
```

*(syntax verified, not executed — it requires an interactive confirmation.)*

`project` and `admin:org` are only needed if you manage GitHub Projects or organization
settings. The kit does not require them.

---

## 3. Minimum configuration

There is none. The kit reads your repository's own settings and writes nothing global.

Two optional conveniences:

**Default repository**, so commands run outside a checkout still know what you mean:

```
gh repo set-default <your-org>/<your-repo>
```

**Permission allowlist.** The issue workflows call `gh` constantly, and by default your
harness will ask permission each time. Adding `gh` command prefixes to your harness's
allowlist removes that friction. Add only read and write commands you are comfortable
running unattended — and never add a command whose text contains a token, because the
harness stores the full command string as a rule.

---

## 4. Verification

Run these three. All should succeed:

```
gh auth status
gh api user --jq .login
gh issue list --state open --limit 1 --repo <your-org>/<your-repo>
```

The first confirms you are authenticated and shows your scopes. The second proves the
token actually works against the API rather than merely existing. The third proves you
can reach the repository you intend to work in — which is the one that fails when you are
authenticated to the right account but lack access to the right org.

If the third fails with `Could not resolve to a Repository`, the usual causes are a typo
in the name, a repository you have not been granted access to, or being authenticated as
the wrong account. `gh auth status` lists every account you are logged into and marks the
active one.

### Then the harness gates

Authentication is only the first of the gates. Grant folder trust for your repository and
confirm your project instructions load — see [the four gates](README.md#the-four-gates-between-installed-and-working).

---

## Command provenance

| Command | Status |
|---|---|
| `gh --version` | executed |
| `gh auth status` | executed |
| `gh api user --jq .login` | executed |
| `gh config get git_protocol` | executed |
| `gh repo view <org>/<repo> --json name,visibility` | executed |
| `gh issue list --state open --limit 1 --repo <org>/<repo>` | executed |
| `gh pr list --state open --limit 2 --repo <org>/<repo>` | executed |
| `gh auth login …` | syntax verified — interactive browser login |
| `gh auth refresh --scopes …` | syntax verified — interactive confirmation |
| `gh repo set-default …` | syntax verified — writes repository config |
| `brew install gh` | not executed — already installed on the verifying machine |
