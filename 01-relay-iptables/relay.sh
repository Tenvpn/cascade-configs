#!/usr/bin/env bash
# Схема 1 — труба: всё, что приходит на порт моста, улетает на выход как есть.
# Запускать на РОССИЙСКОМ сервере от root.
#   EXIT_IP=1.2.3.4 PORT=443 bash relay.sh
# На телефоне меняешь только адрес сервера: <EXIT_IP> → <BRIDGE_IP>. Ключи, SNI и всё остальное — как было.
set -euo pipefail

EXIT_IP="${EXIT_IP:?укажи EXIT_IP — адрес зарубежного сервера}"
PORT="${PORT:-443}"
WAN="${WAN:-$(ip route show default | awk '{print $5; exit}')}"

# 1. Включить пересылку пакетов (и сохранить после перезагрузки).
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

# 2. Направить порт на выход (TCP и UDP — UDP нужен Hysteria2/QUIC).
iptables -t nat -A PREROUTING -i "$WAN" -p tcp --dport "$PORT" -j DNAT --to-destination "$EXIT_IP:$PORT"
iptables -t nat -A PREROUTING -i "$WAN" -p udp --dport "$PORT" -j DNAT --to-destination "$EXIT_IP:$PORT"

# 3. Подменить отправителя, чтобы ответ вернулся через мост.
iptables -t nat -A POSTROUTING -d "$EXIT_IP" -j MASQUERADE

# Разрешить пересылку, если политика FORWARD = DROP.
iptables -A FORWARD -d "$EXIT_IP" -j ACCEPT
iptables -A FORWARD -s "$EXIT_IP" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "Готово: $WAN:$PORT → $EXIT_IP:$PORT"
echo "Сохранить правила после перезагрузки: apt install iptables-persistent && netfilter-persistent save"
