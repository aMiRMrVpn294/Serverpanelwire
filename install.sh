#!/bin/bash

echo "🔧 نصب WireGuard و اجرای پنل..."

apt update && apt install wireguard qrencode nginx curl -y

# ساخت کلیدها
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key

# خواندن کلیدها
SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIV=$(cat /etc/wireguard/client_private.key)
CLIENT_PUB=$(cat /etc/wireguard/client_public.key)
SERVER_IP=$(curl -s ifconfig.me)

# ساخت کانفیگ سرور
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = 10.0.0.2/32
EOF

# فعال‌سازی WireGuard
sysctl -w net.ipv4.ip_forward=1
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# ساخت پنل تحت وب
mkdir -p /var/www/html/wgpanel
cat > /var/www/html/wgpanel/index.html <<EOF
<!DOCTYPE html>
<html lang="fa">
<head>
  <meta charset="UTF-8">
  <title>پنل WireGuard</title>
</head>
<body>
  <h2>🎉 کانفیگ کلاینت WireGuard</h2>
  <pre>
[Interface]
PrivateKey = $CLIENT_PRIV
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
  </pre>
</body>
</html>
EOF

systemctl restart nginx

echo "✅ نصب کامل شد! پنل در دسترسه در آدرس: http://$SERVER_IP/wgpanel"
