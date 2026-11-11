# Network

Two LANs and a mesh overlay. The mesh is NetBird, and a single container on `PG15` joins it
to the house LAN.

## Subnets

| Subnet | Where | Notes |
|---|---|---|
| `192.0.2.0/24` | The house LAN | `PG15` at `.10`, X99A at `.20`, the B860H at `.30` |
| `198.51.100.0/24` | The offsite LAN | dv6 at `.10` and its Incus guests from `.11` |
| `100.64.0.0/10` | NetBird's carrier-grade NAT space | Peers get addresses in it; four peers in use |
| `10.42.0.0/16` | dnsmasq on X99A, Incus bridges | Internal to those hosts |

The four mesh peers:

| Peer | Mesh address | Advertises |
|---|---|---|
| `PG15` CT 100 | `100.64.0.11` | `192.0.2.0/24` |
| B860H | `100.64.0.12` | nothing |
| X99A | `100.64.0.13` | nothing |
| dv6 | `100.64.1.11` | `198.51.100.0/24` |

## How the two directions work

### Mesh to LAN

Every peer installs `192.0.2.0/24 dev wt0 table 7120` because CT 100 advertises that
subnet, and a policy rule sends LAN destinations to that table. CT 100 forwards from `wt0`
to `eth0` and masquerades, so the LAN host sees `192.0.2.2` as the source rather than the
peer's mesh address. Nothing on the receiving host needs configuring.

### LAN to mesh

A host that needs to originate traffic into the overlay carries a static route. Only `PG15`
and CT 101 have it:

```ini
post-up   ip route replace 100.64.0.0/16 via 192.0.2.2
post-down ip route del     100.64.0.0/16 via 192.0.2.2
```

`compute` and the B860H do not, so they reach the SSH jump host and nothing else on the
mesh. Without the route a packet follows the default gateway, which has no path into the
overlay, and dies there.

The policy routing on CT 100 is written by the NetBird daemon: rule 105
(`main suppress_prefixlength 0`), rule 110 (`not from all fwmark 0x1bd00 lookup 7120`), and
table `7120` holding the routes they select. Manual routes added there fight the daemon.

## Interfaces

The block below is the host bridge. Of the containers, only CT 100, CT 101 and CT 102 differ
from stock; the other fourteen use a static `eth0` on `vmbr0` with no `post-up` lines.

`PG15` host:

```ini
auto vmbr0
iface vmbr0 inet static
        address 192.0.2.10/24
        gateway 192.0.2.1
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        post-up ip route replace 100.64.0.0/16 via 192.0.2.2
        post-up iptables -t nat -A POSTROUTING -d 192.0.2.20 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -d 192.0.2.20 -j MASQUERADE
```

CT 100 `netbird` is the router, on the plain LAN address `.2` with the stock gateway. It
carries no static route because it genuinely holds `100.64.0.0/16` on `wt0`.

CT 101 `nginxproxymanager` (`.3`) carries routes to both the overlay and the offsite LAN,
and CT 102 `cloudflared` (`.4`) carries only the route to the offsite LAN. Both files are
under [`configs/verbatim/`](../configs/verbatim/).

The host masquerades traffic to X99A, so anything sent there arrives with `192.0.2.10` as
its source and replies come back to the host instead of following a route X99A may not
have.

## DNS and TLS

Two Pi-hole plus unbound pairs, one on the B860H and one on dv6, resolve the private zone
internally over DNS-over-TLS. Public names live in a Cloudflare zone, where
`*.example.net` points at the proxy.

Certificates come from Cloudflare's DNS challenge, issued and renewed by Nginx Proxy
Manager on CT 101. NPM terminates TLS and forwards to the backend over plain HTTP, either
on the backend's own LAN address or at `192.0.2.10:<port>` for anything still published on
the host.

The tunnel is outbound only. No inbound port is opened at the edge for a proxied service:
CT 102 keeps a connection to Cloudflare and traffic arrives down it.

## Firewall

The live state on `PG15` is the Proxmox `PVEFW-*` chain set, and there is no Docker on the
host. A stricter input policy is written and committed but not applied. It binds the input
hook only, defaults to drop, and allows loopback, established traffic, the NetBird tunnel,
the LAN, the Docker bridge range, link-local, the WireGuard endpoint, DHCP, mDNS and ICMP
from the LAN. It never flushes the ruleset, which is what keeps Docker's and NetBird's
runtime tables intact.

That policy is in [`configs/pve/pg15-nftables.conf`](../configs/pve/pg15-nftables.conf) and
was not present in the live ruleset at the 2026-11-10 capture.
