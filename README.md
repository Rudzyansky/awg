# AmnesiaWG Images

### Running locally

Just run `docker compose up`

Make sure to create a `awg` folder with the `wg0.conf` file.

Example `wg0.conf`:

```
[Interface]
PrivateKey = gG...Y3s=
Address = 10.0.0.1/32
ListenPort = 51820
# Jc лучше брать в интервале [3,10], Jmin = 100, Jmax = 1000,
Jc = 3
Jmin = 100
Jmax = 1000
# Parameters below will not work with the existing WireGuarg implementation.
# Use if your peer running Amnesia-WG
# S1 = 324
# S2 = 452
# H1 = 25

# IP masquerading
PreUp = iptables -t nat -A POSTROUTING ! -o %i -j MASQUERADE
# Firewall wg peers from other hosts
PreUp = iptables -A FORWARD -o %i -m state --state ESTABLISHED,RELATED -j ACCEPT
PreUp = iptables -A FORWARD -o %i -j REJECT

# Remote settings for my workstation
[Peer]
PublicKey = wx...U=
AllowedIPs = 10.0.0.2/32
# An IP address to check peer connectivity (specific to this repo)
TestIP = 10.0.0.2
# Your existing Wireguard server
Endpoint=xx.xx.xx.xx:51820
PersistentKeepalive = 25

```

### Mikrotik Configuration

Set up interface and IP address for the containers

```
/interface bridge
add name=containers

/interface veth
add address=172.17.0.2/24 gateway=172.17.0.1 gateway6="" name=veth1

/interface bridge port
add bridge=containers interface=veth1

/ip address
add address=172.17.0.1/24 interface=containers network=172.17.0.0
```

Set up masquerading for the outgoing traffic and dstnat

```
/ip firewall nat
add action=masquerade chain=srcnat comment="Outgoing NAT for containers" src-address=172.17.0.0/24
/ip firewall nat
add action=dst-nat chain=dstnat comment=amnezia-wg dst-port=51820 protocol=udp to-addresses=172.17.0.2 to-ports=51820
```

Set up mount with the Wireguard configuration

```
/container mounts
add dst=/etc/amnezia/amneziawg/ name=awg_config src=/awg

/container/add cmd=/sbin/init hostname=amnezia interface=veth1 logging=yes mounts=awg_config file=docker-awg-arm7.tar
```

To start the container run

```
/container/start 0
```

To get the container shell

```
/container/shell 0
```

## Credits

- https://github.com/yury-sannikov/amnezia-wg-docker
- https://github.com/amnezia-vpn
