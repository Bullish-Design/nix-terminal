# Self-host an Atuin sync server over Tailscale

This guide deploys the Atuin sync server on this NixOS machine and exposes it
**only** to devices in the tailnet. The server remains bound to loopback;
Tailscale Serve supplies the tailnet-only HTTPS endpoint. Nothing is opened on
the LAN or public Internet.

Atuin synchronizes encrypted history blobs. The server stores the blobs and
account metadata, but cannot read command history. Treat the client encryption
key as a secret: anyone with it can decrypt that user's synced history.

## What this will create

```text
Atuin client on any tailnet device
  └─ HTTPS: https://<server>.{tailnet}.ts.net
       └─ Tailscale Serve (TLS termination; tailnet ACLs apply)
            └─ http://127.0.0.1:8888 on this NixOS host
                 └─ Atuin server → local PostgreSQL database
```

This approach deliberately does not use `networking.firewall.allowedTCPPorts`
or `services.atuin.openFirewall`: port 8888 is not reachable outside this host.

## Prerequisites

1. Choose a host that stays online and has persistent NixOS state.
2. Ensure Tailscale is enabled and this host is logged into the intended
   tailnet. Run:

   ```sh
   tailscale status
   ```

3. On the Tailscale admin console, enable MagicDNS and HTTPS certificates. The
   first `tailscale serve` command may also guide an administrator through this.
   The HTTPS certificate is for the host's `*.ts.net` name; do not substitute a
   LAN address or a public domain.
4. Ensure the host has `jq` available for the hostname command below. If it does
   not, inspect `tailscale status --json` manually instead.
5. Make sure no other service already uses local TCP port 8888:

   ```sh
   sudo ss -lntp 'sport = :8888'
   ```

## 1. Add the NixOS configuration

Add the following to the NixOS host configuration that is rebuilt on this
machine (not to this repository's Home Manager module). It uses the packaged
PostgreSQL service and keeps Atuin loopback-only.

```nix
{ lib, pkgs, ... }:

{
  services.atuin = {
    enable = true;
    host = "127.0.0.1";
    port = 8888;
    openRegistration = true; # temporary: turn this off in step 5
    openFirewall = false;
  };

  # Atuin >= 18.12 moved the server to a separate executable. The NixOS module
  # currently available on this host invokes the older `atuin server start`.
  # Keep the module's PostgreSQL, hardening, and environment configuration, but
  # replace only the command.
  systemd.services.atuin.serviceConfig.ExecStart = lib.mkForce
    "${pkgs.atuin}/bin/atuin-server start";
}
```

`services.atuin` creates a local PostgreSQL database and database role named
`atuin` by default. Do not put a database password or an Atuin encryption key
in the Nix store. If this host already has a managed PostgreSQL instance or the
database needs to be remote, set `services.atuin.database.createLocally = false`
and provide a secret database URI through a systemd `EnvironmentFile` instead.

Before deploying, check that the installed package includes the separate server
binary:

```sh
command -v atuin-server
atuin-server --help
```

If it does not, do not apply the override above. Pin or update `pkgs.atuin`
until it provides `bin/atuin-server`.

## 2. Rebuild and verify the local server

Use the rebuild command normally used by the host's configuration. For a
standard flake-based host it is typically:

```sh
sudo nixos-rebuild switch --flake /path/to/nixos-config#<hostname>
```

Then verify the service and its listener:

```sh
sudo systemctl status atuin --no-pager
sudo systemctl is-active atuin
sudo ss -lntp 'sport = :8888'
sudo journalctl -u atuin -b --no-pager
```

The listener must be `127.0.0.1:8888` (and may also be `[::1]:8888`), never
`0.0.0.0:8888`. If it fails to start, the most likely cause is leaving the old
`atuin server start` command in place; confirm the override in step 1 and read
the journal before changing any firewall rules.

## 3. Publish the local server through Tailscale Serve

Get the exact MagicDNS fully-qualified name. Remove only its trailing dot:

```sh
SERVER_FQDN="$(tailscale status --json | jq -r '.Self.DNSName | rtrimstr(".")')"
printf '%s\n' "$SERVER_FQDN"
```

Configure a persistent, private HTTPS reverse proxy to the loopback service:

```sh
sudo tailscale serve --bg --https=443 http://127.0.0.1:8888
sudo tailscale serve status
```

Use `serve`, not `funnel`: Funnel would make the endpoint publicly reachable.
Tailscale Serve persists its configuration and restores it when Tailscale
restarts. Verify it after every Tailscale upgrade with `tailscale serve status`.

From another device that is connected to the same tailnet, confirm that the
HTTPS endpoint is reachable. A response (including an application 404) proves
the proxy path is reachable; a TLS or connection failure does not:

```sh
curl -i "https://$SERVER_FQDN/"
```

Access is still controlled by the tailnet's Tailscale ACL/grant policy. Restrict
the policy so only the intended people and devices can reach this host on TCP
443. Do not rely on Atuin account passwords as the network boundary.

## 4. Point this machine's Home Manager Atuin client at the server

In the Home Manager consumer configuration that imports this repository, set:

```nix
programs.nix-terminal.atuin = {
  syncAddress = "https://<server>.<tailnet>.ts.net";
  autoSync = true;
};
```

Replace the placeholder with the value printed in step 3, then apply the Home
Manager generation. This repository already maps those options to Atuin's
`sync_address` and `auto_sync` settings.

For a one-off test without rebuilding Home Manager, set the equivalent address
in `~/.config/atuin/config.toml`:

```toml
sync_address = "https://<server>.<tailnet>.ts.net"
auto_sync = true
```

The declarative Home Manager configuration is preferred because it will not be
overwritten by the next switch. Before changing accounts or endpoints, back up
the local Atuin state, which includes the encryption key:

```sh
umask 077
tar -C "$HOME/.local/share" -czf "$HOME/atuin-backup-$(date +%F).tar.gz" atuin
```

Keep that archive in encrypted storage; it contains sensitive history metadata
and key material.

## 5. Create the first account and close registration

On this machine, after the client points at the new endpoint, create an Atuin
account. Omit `-p` so the password is read interactively rather than appearing
in shell history:

```sh
atuin register -u <username> -e <email-address>
atuin sync
atuin key
```

Store the value printed by `atuin key` in a password manager. It is required to
log into additional devices and must never be shared with other users.

Immediately change the NixOS setting from `openRegistration = true;` to:

```nix
openRegistration = false;
```

Rebuild the host again, then confirm the service is still healthy:

```sh
sudo nixos-rebuild switch --flake /path/to/nixos-config#<hostname>
sudo systemctl is-active atuin
```

Leave registration closed. Temporarily reopen it only when deliberately adding
a new Atuin account, then rebuild again to close it.

## 6. Add another tailnet device

On each additional device:

1. Install Atuin and connect the device to the same tailnet.
2. Set its `sync_address` to the exact HTTPS URL from step 3 (in its Home
   Manager configuration or `~/.config/atuin/config.toml`).
3. Log in interactively so neither password nor key enters shell history:

   ```sh
   atuin login -u <username>
   # Enter the account password and encryption key when prompted.
   atuin sync
   ```

4. Test the history UI with `Ctrl-R` in a newly opened shell.

Do not create a separate account for every device when the goal is one shared
personal history. Use the same username and encryption key on each of your
devices. Create separate accounts only for separate people.

## Operations and recovery

Useful checks:

```sh
sudo systemctl status atuin --no-pager
sudo journalctl -u atuin -f
sudo systemctl status postgresql --no-pager
tailscale serve status
atuin sync
```

Back up PostgreSQL regularly; that is the server-side source of synced blobs.
A simple local backup (adjust the destination to protected backup storage) is:

```sh
sudo -u postgres pg_dump atuin | gzip > /var/backup/atuin-$(date +%F).sql.gz
```

Test a restore procedure before relying on the backup. A database restore alone
is not enough to recover readable history: clients also need their encryption
keys. Keep the database backup and client-key backup separately protected.

To disable the proxy without removing the local Atuin service:

```sh
sudo tailscale serve --https=443 off
sudo tailscale serve status
```

To completely remove the server later, first disable `services.atuin`, rebuild,
and only then remove its PostgreSQL database after verifying backups. Do not
delete the database as a troubleshooting step.

## References

- [Atuin server setup](https://docs.atuin.sh/cli/self-hosting/server-setup/)
- [Atuin self-hosted client setup](https://docs.atuin.sh/cli/self-hosting/usage/)
- [Atuin sync and key handling](https://docs.atuin.sh/cli/reference/sync/)
- [Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
- [Tailscale HTTPS certificates](https://tailscale.com/docs/how-to/set-up-https-certificates)
