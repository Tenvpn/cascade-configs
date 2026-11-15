# 2. Цепочка Xray на 3X-UI

На обоих серверах Xray. Мост сам расшифровывает трафик и решает, куда его отправить: российское — напрямую,
остальное — на выход.

```
телефон ──VLESS Reality──► мост (3X-UI) ──┬── geoip:ru / category-ru ──► напрямую (банк видит РФ)
                                          └── всё остальное ──VLESS Reality──► выход ──► интернет
```

## Файлы

| Файл | Где | Что |
|---|---|---|
| `exit-full.json` | выход | полный конфиг выхода (голый Xray) |
| `bridge-outbound.json` | мост, 3X-UI → Настройки Xray → Исходящие | исходящее `to-exit` |
| `bridge-routing.json` | мост, 3X-UI → Настройки Xray → Маршрутизация | правила: РФ напрямую, остальное в `to-exit` |
| `bridge-full.json` | мост | то же целиком для голого Xray |

## Шаги

### Выход (за границей)

1. Свой сайт для маскировки на `127.0.0.1:8443` (selfsteal). Например Caddy:
   ```
   exit.<YOUR_DOMAIN>:8443 {
       bind 127.0.0.1
       root * /var/www/site
       file_server
   }
   ```
   Сертификат Caddy получит сам: A-запись `exit.<YOUR_DOMAIN>` → `<EXIT_IP>`.
2. Ключи: `xray x25519` → `<EXIT_REALITY_PRIVATE_KEY>` / `<EXIT_REALITY_PUBLIC_KEY>`; `xray uuid` → `<UUID_BRIDGE>`.
3. В 3X-UI: «Подключения» → «Добавить»: протокол VLESS, порт 443, безопасность Reality,
   Target `127.0.0.1:8443`, SNI `exit.<YOUR_DOMAIN>`, flow `xtls-rprx-vision`, клиент с `<UUID_BRIDGE>`.
   Или голый Xray с `exit-full.json`.
   Ключ от выхода знает только мост. Телефонам его не раздаём.

### Мост (Россия)

4. Тот же selfsteal, только `bridge.<YOUR_DOMAIN>` → `<BRIDGE_IP>`.
5. «Подключения» → «Добавить»: VLESS Reality для телефонов, тег `from-phones`, SNI `bridge.<YOUR_DOMAIN>`.
   Клиент — `<UUID_PHONE>`, по одному на устройство.
6. «Настройки Xray» → «Исходящие» → вставить `bridge-outbound.json`.
7. «Настройки Xray» → «Маршрутизация» → правила из `bridge-routing.json`. Порядок важен:
   приватные адреса в блок → российские домены напрямую → российские IP напрямую → телефоны в `to-exit`.
8. Сохранить, перезапустить Xray. Проверка с телефона: `ifconfig.me` показывает `<EXIT_IP>`,
   а `2ip.ru` и сайт банка — `<BRIDGE_IP>`.

### Ссылка для телефона

```
vless://<UUID_PHONE>@<BRIDGE_IP>:443?type=tcp&security=reality&sni=bridge.<YOUR_DOMAIN>&fp=firefox&pbk=<BRIDGE_REALITY_PUBLIC_KEY>&sid=<SHORT_ID>&flow=xtls-rprx-vision#Каскад
```

## Частые ошибки

- **Чужой SNI** (max.ru, apple.com) вместо своего домена. Российский хостер за это останавливает сервер.
- **`geosite:category-ru` не находится.** В 3X-UI обнови geo-файлы: «Обзор» → «Xray» → «Обновить geofiles».
- **Банк всё равно видит заграницу.** Правило `geoip:ru` стоит ниже правила для `from-phones`, а должно выше.
