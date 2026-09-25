# unbound-dns-with-blocklist-container

Using a [Red Hat hardened Unbound](https://images.redhat.com/?name=unbound) image with [Hagezi Blocklist](https://github.com/hagezi/dns-blocklists/tree/main)

## Using podman

```
podman run --detach \
  --name unbound \
  --restart=unless-stopped \
  --publish 5335:5335/udp \
  --publish 5335:5335/tcp \
  --volume ./unbound-custom.conf:/etc/unbound/conf.d/unbound-custom.conf:ro,Z \
  --volume ./responsepolicyzone/hagezi-rpz.txt:/etc/unbound/responsepolicyzone/hagezi-rpz.txt:ro,Z \
  --volume ./responsepolicyzone/allowlist-rpz.txt:/etc/unbound/responsepolicyzone/allowlist-rpz.txt:ro,Z \
  --volume ./responsepolicyzone/homelab-rpz.txt:/etc/unbound/responsepolicyzone/homelab-rpz.txt:ro,Z \
  registry.access.redhat.com/hi/unbound:latest
```