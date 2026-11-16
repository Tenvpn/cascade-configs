#!/usr/bin/env bash
# Схема 1 — труба: всё, что приходит на порт моста, улетает на выход как есть.
# Запускать на РОССИЙСКОМ сервере от root.
#   EXIT_IP=203.0.113.10 PORT=443 bash relay.sh
# На телефоне меняешь только адрес сервера: <EXIT_IP> → <BRIDGE_IP>. Ключи, SNI и всё остальное — как было.
# Повторный запуск безопасен: уже добавленные правила второй раз не добавляются.
set -euo pipefail

EXIT_IP="${EXIT_IP:?укажи EXIT_IP — адрес зарубежного сервера}"
PORT="${PORT:-443}"
WAN="${WAN:-$(ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); exit}}')}"
[ -n "$WAN" ] || { echo "Не нашёл внешний интерфейс, укажи WAN=eth0" >&2; exit 1; }

# Добавить правило, только если такого ещё нет.
add() { local t="$1" c="$2"; shift 2; iptables -t "$t" -C "$c" "$@" 2>/dev/null || iptables -t "$t" -I "$c" "$@"; }

# 1. Включить пересылку пакетов (и сохранить после перезагрузки).
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-relay.conf

# 2. Направить порт на выход (TCP и UDP — UDP нужен Hysteria2/QUIC).
add nat PREROUTING -i "$WAN" -p tcp --dport "$PORT" -j DNAT --to-destination "$EXIT_IP:$PORT"
add nat PREROUTING -i "$WAN" -p udp --dport "$PORT" -j DNAT --to-destination "$EXIT_IP:$PORT"

# 3. Подменить отправителя, чтобы ответ вернулся через мост.
add nat POSTROUTING -o "$WAN" -d "$EXIT_IP" -j MASQUERADE

# 4. Разрешить пересылку, даже если политика FORWARD = DROP или в конце цепочки стоит REJECT.
add filter FORWARD -d "$EXIT_IP" -p tcp --dport "$PORT" -j ACCEPT
add filter FORWARD -d "$EXIT_IP" -p udp --dport "$PORT" -j ACCEPT
add filter FORWARD -s "$EXIT_IP" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "Готово: $WAN:$PORT → $EXIT_IP:$PORT"
echo "Сохранить правила после перезагрузки: apt install iptables-persistent && netfilter-persistent save"
