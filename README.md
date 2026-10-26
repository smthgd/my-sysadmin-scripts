## Мониторинг ресурсов

Скрипт раз в N секунд снимает free -h, df -h, uptime и дописывает в monitor.log блок из этих трёх выводов с временной меткой в начале

# Пример 
--- 2026-08-15 14:03:00 ---, дальше сами выводы free -h/df -h/uptime построчно.  
N — захардкоженная константа в скрипте, интерактивный ввод не нужен.

## Запуск через Docker Compose

Из папки `my-sysadmin-scripts` выполните:

```bash
docker compose up --build
```

При последующих запусках достаточно `docker compose up`.
Журнал `monitor.log` сохраняется в папке проекта на компьютере.
Для остановки нажмите `Ctrl+C`, для удаления контейнера выполните `docker compose down`.

## HTTP-доступ к журналу (шаг 0 перед настройкой reverse proxy)

Контейнер одновременно запускает мониторинг в фоне и HTTP-сервер Python на порту 8080.
Сервер отдаёт содержимое `/var/www`, куда Compose подключает папку проекта.
Переменная окружения `LOG_FILE` направляет запись журнала в `/var/www/monitor.log`;
при запуске скрипта вне контейнера без этой переменной журнал остаётся рядом со скриптом.

После пересборки и запуска проверьте в другом терминале:

```bash
curl http://127.0.0.1:8080/monitor.log
```

Команда должна вернуть накопленные записи мониторинга; новые записи появляются каждые 5 секунд.
Сразу после запуска файл может быть ещё пустым — повторите запрос через несколько секунд.

## Запуск через systemd и Nginx в Ubuntu VM

Ниже приведён отдельный способ запуска для Ubuntu 22.04 с systemd и установленным
Docker Engine. Команды выполняются внутри ВМ из папки репозитория.
Если приложение уже запущено через Compose, сначала остановите его:

```bash
docker compose down
```

Соберите образ и создайте контейнер, который затем будет запускать systemd:

```bash
sudo docker build -t my-script -f dockerfile .
sudo docker create --name my-app -p 127.0.0.1:8080:8080 my-script
sudo cp systemd/my-app.service /etc/systemd/system/my-app.service
sudo systemctl daemon-reload
sudo systemctl enable --now my-app
sudo systemctl status my-app --no-pager
```

Команда `docker create` нужна один раз: если контейнер `my-app` уже существует,
повторять её не нужно. Unit запускает существующий контейнер через `docker start -a`;
он не создаёт контейнер и не пересобирает образ. После пересборки образа существующий
контейнер сам по себе не обновляется.
В этом способе запуска журнал хранится внутри контейнера в `/var/www/monitor.log`
и сохраняется при его остановке, но теряется при удалении контейнера.

Установите Nginx и OpenSSL, создайте учебный самоподписанный сертификат:

```bash
sudo apt-get update
sudo apt-get install -y nginx openssl
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/ssl/private/my-app.key \
  -out /etc/ssl/certs/my-app.crt \
  -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'
sudo chmod 600 /etc/ssl/private/my-app.key
```

Если сертификат уже создан по этим путям, повторно генерировать его не нужно.
Закрытый ключ остаётся на ВМ и в репозиторий не добавляется.

Подключите конфиг приложения. Стандартный сайт переносится из активных конфигов,
чтобы исключить конфликт с `default_server` приложения:

```bash
sudo cp nginx/my-app /etc/nginx/sites-available/my-app
sudo ln -sfn /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/my-app
sudo mkdir -p /etc/nginx/sites-disabled
if [ -e /etc/nginx/sites-enabled/default ]; then
    sudo mv /etc/nginx/sites-enabled/default /etc/nginx/sites-disabled/default
fi
sudo nginx -t && sudo systemctl enable --now nginx
sudo nginx -t && sudo systemctl reload nginx
```

Nginx перенаправляет HTTP с порта 80 на HTTPS и проксирует HTTPS-запросы
с порта 443 на HTTP-сервер контейнера по адресу `127.0.0.1:8080`.
Не запускайте Compose одновременно с этим контейнером: оба используют порт 8080.

## Проверка и просмотр логов

Внутри Ubuntu VM выполните:

```bash
curl -I http://127.0.0.1/
curl -kI https://127.0.0.1/monitor.log
systemctl is-enabled my-app
systemctl is-active my-app
sudo journalctl -u my-app -n 20 --no-pager
sudo tail -n 10 /var/log/nginx/access.log
sudo tail -n 10 /var/log/nginx/error.log
sudo docker exec my-app tail -n 18 /var/www/monitor.log
```

Ожидаются HTTP `301`, HTTPS `200`, состояния `enabled` и `active`.
Флаг `-k` используется для самоподписанного сертификата и отключает проверку доверия.
Журнал запросов HTTP-сервера контейнера поступает в journalctl через systemd;
замеры ресурсов находятся в `monitor.log`.

В учебной ВМ отдельно созданы RAID 1 (`/dev/md0`, `/mnt/raid`) и LVM
(`vg_data/lv_logs`, `/mnt/logs`). Они не создаются приведёнными командами,
и журнал приложения на них автоматически не переносится.
