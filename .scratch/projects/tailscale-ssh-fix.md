# Tailscale SSH: eliminating the recurring browser-auth prompt (server ↔ framework)

**Date:** 2026-07-11
**Author:** investigation captured via Claude Code session on `server`
**Scope:** unattended SSH between two personally-owned tailnet nodes — `server` (Dell Precision 5820, headless tower) and `framework` (laptop) — both owned by `andrew.laureijs@`.
**Status:** root cause confirmed; fix documented (ACL change pending in the Tailscale admin console).

---

## 1. TL;DR

Connecting from `server → framework` over SSH kept popping a one-time browser
approval URL:

```
# Tailscale SSH requires an additional check.
# To authenticate, visit: https://login.tailscale.com/a/<token>
```

This is **Tailscale SSH `check` mode**, enforced by the tailnet ACL policy — not
by NixOS, keys, or `sshd`. For two machines you own and want to automate between,
switch the matching `ssh` rule from `action: "check"` to `action: "accept"`,
scoped to `autogroup:self`:

```json
"ssh": [
  {
    "action": "accept",
    "src":    ["autogroup:member"],
    "dst":    ["autogroup:self"],
    "users":  ["autogroup:nonroot", "andrew"]
  }
]
```

Edit at **https://login.tailscale.com/admin/acls**. After this, `ssh andrew@framework`
from `server` works unattended, with no keys to manage (tailnet identity is the auth).

---

## 2. Symptom (what was observed)

- `ssh andrew@framework` (and to the tailnet IP `100.64.36.58`) from `server`
  **hung indefinitely** instead of connecting or failing.
- `-o BatchMode=yes` did **not** make it fail fast — it still hung.
- A verbose run (`ssh -v`) showed the SSH transport fully establishing — key
  exchange, host-key accepted, `SSH2_MSG_SERVICE_ACCEPT` — and *then* stalling on:

  ```
  debug1: SSH2_MSG_SERVICE_ACCEPT received
  # Tailscale SSH requires an additional check.
  # To authenticate, visit: https://login.tailscale.com/a/l1011f6ca3a80f2
  ```

- Approving a link that had been generated earlier (or authenticating on
  `framework` itself) did **not** unblock the pending connection.
- Once the *current* live URL was approved in a browser, the connection completed
  instantly and printed `# Authentication checked with Tailscale SSH.`

---

## 3. Root cause

`framework` runs **Tailscale SSH** (its `tailscaled` was brought up with `--ssh`,
so it intercepts SSH on the tailnet interface). Whether a given connection is
allowed — and whether it needs an interactive check — is decided by the
**tailnet ACL policy's `ssh` rules**, which live centrally in the Tailscale admin
console (account-level), *not* in either machine's NixOS config.

The rule matching `server → framework` had **`action: "check"`**. `check` mode
requires the connecting user to re-authenticate through their identity provider
in a **web browser**, on a recurring cadence (the *check period*, default 12h).

### Why the earlier confusion ("I already did this")

- **Check approval is scoped to a specific source identity + time window.**
  `server` is a *distinct source device* from the laptop; an approval performed
  on/from another device does not transfer to a connection originating on `server`.
- **Each connection attempt mints its own one-time URL.** Every killed/timed-out
  attempt in this investigation generated a fresh token, so approving a stale link
  did nothing for the live pending session.
- **The check happens *below* SSH's own auth layer.** That's why `BatchMode=yes`
  didn't help: `BatchMode` suppresses OpenSSH's interactive prompts (passwords,
  passphrases), but the Tailscale check is enforced by `tailscaled` after the SSH
  service is accepted — OpenSSH has nothing to suppress, so it just waits.

### Why `check` is the wrong mode for regular automation

`check` **requires a human at a browser** by design. Any unattended,
scheduled, or agent-driven interaction between the two boxes will block on it
forever. Automation needs `accept`.

---

## 4. Connection topology (for reference)

| Node        | Tailnet IP       | Owner              | Type          | Tailscale SSH |
|-------------|------------------|--------------------|---------------|---------------|
| `server`    | `100.124.67.32`  | `andrew.laureijs@` | user-owned    | initiator     |
| `framework` | `100.64.36.58`   | `andrew.laureijs@` | user-owned    | destination (`--ssh`) |

Both are **user-owned** (not tagged). Contrast with tailnet nodes like `agents`,
`forge`, `remora-server`, which show as `tagged-devices`. This distinction matters
for the fix: `autogroup:self` applies to **owner-matched, user-owned** devices and
does **not** match tagged devices.

---

## 5. The fix (recommended): `accept` for your own devices

In the tailnet policy at **https://login.tailscale.com/admin/acls**, set the
`ssh` block to:

```json
"ssh": [
  {
    "action": "accept",
    "src":    ["autogroup:member"],
    "dst":    ["autogroup:self"],
    "users":  ["autogroup:nonroot", "andrew"]
  }
]
```

Field-by-field:

- **`action: "accept"`** — allow with no browser check. Auth is the tailnet
  (WireGuard) identity itself.
- **`src: ["autogroup:member"]`** — any human member of the tailnet may initiate.
  (Tighten to a specific identity or tag if you want a narrower blast radius.)
- **`dst: ["autogroup:self"]`** — destination must be a device **owned by the same
  user who is connecting**, logging in as that same user. This is the key scoping
  primitive: it cleanly covers `server ↔ framework` (both `andrew`'s) and **only**
  your own devices — it will not grant access to tagged/shared nodes.
- **`users: ["autogroup:nonroot", "andrew"]`** — which local Unix accounts you may
  log in as. `autogroup:nonroot` allows any non-root user; `andrew` is listed
  explicitly for clarity. **Note:** `root` is deliberately excluded by
  `autogroup:nonroot` — add `"root"` here only if you intend to allow it.

With this in place, from `server`:

```bash
ssh andrew@framework 'hostname'   # → framework, immediately, unattended
```

No SSH keys are involved — Tailscale SSH supplies the identity. This is what makes
it suitable for scheduled jobs and agent-driven interaction.

### Caveat — tagging changes the match

`autogroup:self` matches because both nodes are user-owned. If you later **tag**
either machine (e.g. `tag:server`), it stops having an "owner," `autogroup:self`
no longer matches it, and you must switch to an explicit tag-based rule, e.g.:

```json
{ "action": "accept", "src": ["tag:server"], "dst": ["tag:framework"], "users": ["autogroup:nonroot"] }
```

---

## 6. Alternatives

### 6a. Keep `check`, but re-prompt less often (`checkPeriod`)

If you want to retain the human-in-the-loop confirmation but stop the frequent
prompts, extend the window instead of removing the check:

```json
{ "action": "check", "checkPeriod": "168h", "src": ["autogroup:member"], "dst": ["autogroup:self"], "users": ["autogroup:nonroot", "andrew"] }
```

`checkPeriod: "168h"` re-prompts weekly (default is `12h`). **This still cannot run
truly unattended** — it only reduces frequency. Not recommended for "these two
interact regularly."

### 6b. Bypass Tailscale SSH entirely with key-based `sshd`

Decouple SSH auth from your tailnet identity:

1. Add `server`'s public key to `framework`'s `authorized_keys`:
   - `server` key (from `~/.ssh/id_ed25519.pub`):
     `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMA9tjAsNE1M8xYXx6bpSNS8ZyEX5HDfYE4iEwOXZNZ4 server-box-github`
2. **Do not** enable `--ssh` on `framework` (or you'll have ambiguity about which
   layer handles port 22 on the tailnet interface).
3. Connect to `framework` over the tailnet IP using the key.

Use this only if you specifically want SSH auth independent of Tailscale identity.
Given Tailscale SSH is already set up, flipping the ACL to `accept` (§5) is far
less operational overhead than maintaining a key path.

---

## 7. The NixOS half (don't forget)

The ACL decides **policy**; the destination node must still **offer** Tailscale
SSH. Roles:

- **`framework` (destination)** must run Tailscale SSH:

  ```nix
  services.tailscale.enable = true;
  # bring the node up with SSH, e.g.:
  services.tailscale.extraUpFlags = [ "--ssh" ];
  # (equivalently: `tailscale up --ssh` once on the box)
  ```

- **`server` (initiator)** needs nothing beyond a running `tailscaled` — outbound
  connections don't require `--ssh`. In this fleet, `services.tailscale` is owned by
  the `nixos-core.base` tier (`nixos-core.base.tailscale.enable`, default `true`),
  so the daemon is already up.

Net: **framework offers `--ssh` + ACL says `accept` → done.**

---

## 8. Security tradeoff

`check` exists to add a human confirmation step even for already-authorized
devices — useful if a device is lost or compromised. Moving to `accept` for
`autogroup:self` means **anyone who controls one of your authenticated devices can
SSH to your others without that extra confirmation**. For two boxes you own and
want to automate between, that is the normal, reasonable posture — but it is a real
reduction in defense-in-depth, so make the choice deliberately. Options to claw
some back if desired: scope `src` to a single device/tag rather than
`autogroup:member`, or enable Tailscale SSH **session recording** on the rule.

---

## 9. Verification

After applying the ACL change, from `server`:

```bash
ssh -o BatchMode=yes andrew@framework 'hostname'
```

- `BatchMode=yes` forbids any interactive fallback, so a successful, immediate
  `framework` print proves clean **unattended** access.
- If it hangs or errors, the `accept` rule isn't matching — re-check that both nodes
  are user-owned (not tagged), that `src`/`dst`/`users` cover this path, and that
  `framework` is actually running `--ssh`.

Diagnostic (shows exactly where a connection stalls):

```bash
ssh -v andrew@framework 'true' 2>&1 | tail -20
```

A healthy `accept` connection shows **no** `# Tailscale SSH requires an additional
check.` line.

---

## 10. Rollback

Tailnet ACL edits are versioned in the admin console. To revert, restore the prior
`ssh` block (change `accept` back to `check`, or remove the added rule). No
machine-side change is needed to roll back — the policy is central.

---

## 11. References

- Tailscale SSH overview: https://tailscale.com/kb/1193/tailscale-ssh
- ACL `ssh` rule syntax (`action`, `src`, `dst`, `users`, `checkPeriod`):
  https://tailscale.com/kb/1337/acl-syntax#ssh
- Autogroups (`autogroup:self`, `autogroup:member`, `autogroup:nonroot`):
  https://tailscale.com/kb/1396/targets#autogroups
- Admin ACL editor: https://login.tailscale.com/admin/acls
