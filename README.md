# unbound-dns-with-blocklist-container

Using a [Red Hat hardened Unbound](https://images.redhat.com/?name=unbound) image with [Hagezi Blocklist](https://github.com/hagezi/dns-blocklists/tree/main)

- [responsepolicyzone/hagezi-rpz.txt](responsepolicyzone/hagezi-rpz.txt) - block list, generated via [update-hagezi-blocklist.sh](update-hagezi-blocklist.sh)
- [responsepolicyzone/allowlist-rpz.txt](responsepolicyzone/allowlist-rpz.txt) -  Exempt domains from being blocked
- [responsepolicyzone/homelab-rpz.txt](responsepolicyzone/homelab-rpz.txt) - custom domain records


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
  registry.access.redhat.com/hi/unbound:1.26
```

### Enable automatic updates and reboot persistence


[bootstrap-podman-with-systemd.sh](bootstrap-podman-with-systemd.sh)

Usage
#### Rootless: host port 5335 -> container port 5335. With non-root user.
1. `./bootstrap-podman-with-systemd.sh rootless`
2. `sudo loginctl enable-linger "$USER"`

#### Root: host port 53 -> container port 5335. With root/sudo.
1. `sudo ./bootstrap-podman-with-systemd.sh root`

#### Remove the container and systemd resources
1. `sudo ./bootstrap-podman-with-systemd cleanup`
