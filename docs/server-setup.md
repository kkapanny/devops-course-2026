# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- Средство виртуализации: UTM (QEMU)
- Операционная система: Ubuntu Server 24.04 LTS ARM64
- Архитектура: aarch64
- Оперативная память: 2048 МБ
- Процессор: 2 ядра
- Виртуальный диск: 25 ГБ (уточнить фактический размер в UTM)
- Имя виртуальной машины: devops-vm

## 2. Сетевые интерфейсы

**Адаптер 1 — Emulated VLAN**

- Тип сетевой карты: virtio-net-pci
- IP-адрес Ubuntu: 10.0.2.15
- Назначение: доступ в Интернет и перенаправление SSH-порта

**Адаптер 2 — macOS Host Only**

- Тип сетевой карты: virtio-net-pci
- IP-адрес Ubuntu: 192.168.128.2
- IP-адрес Mac: 192.168.128.1
- Назначение: прямое взаимодействие macOS и Ubuntu

## 3. Правило проброса портов

- Протокол: TCP
- Адрес хостовой системы: 127.0.0.1
- Порт хостовой системы: 2222
- Порт гостевой системы: 2222

Подключение с macOS:

`ssh devops`

Дополнительное подключение через Host-only:

`ssh -i ~/.ssh/devops_vm -p 2222 devops@devops.local`

В файл `/etc/hosts` macOS добавлена запись:

`192.168.128.2 devops.local`

## 4. Учётные записи

**student**

- Первоначальная учётная запись Ubuntu
- Использовалась для начальной настройки сервера
- Входит в группу sudo

**devops**

- Административная учётная запись
- Входит в группу sudo
- Использует аутентификацию по SSH-ключу ED25519
- Парольная аутентификация по SSH запрещена

Открытый SSH-ключ размещён в:

`/home/devops/.ssh/authorized_keys`

Закрытый ключ хранится на macOS:

`~/.ssh/devops_vm`

## 5. Служба SSH

Порт: 2222

Файл конфигурации:

`/etc/ssh/sshd_config.d/99-hardening.conf`

Настроенные директивы:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

Для исключения конфликта с настройками первичной инициализации в файле `/etc/ssh/sshd_config.d/50-cloud-init.conf` закомментирована директива `PasswordAuthentication yes`.

Активация через `ssh.socket` отключена. Используется `ssh.service`.

Команды проверки:

```bash
sudo sshd -t
sudo sshd -T
sudo ss -tlnp | grep sshd
```

## 6. Правила межсетевого экрана

Используется UFW.

Политики по умолчанию:

- Входящие соединения: deny
- Исходящие соединения: allow

Разрешённые порты:

- 2222/tcp — LIMIT, SSH
- 80/tcp — ALLOW, HTTP
- 443/tcp — ALLOW, HTTPS

Уровень журналирования: medium.

Проверка:

```bash
sudo ufw status verbose
```

Для проверки блокировки использовалось подключение к закрытому порту 8080. В журнале `/var/log/ufw.log` зафиксировано событие `UFW BLOCK`.

## 7. Снимки состояния

В UTM предусмотрены следующие снимки:

- `01-clean-install` — после установки и первоначальной настройки Ubuntu
- `02-keys-configured` — после создания пользователя devops и настройки SSH-ключей
- `03-ssh-hardened` — после усиления защиты SSH

Снимки позволяют восстановить предыдущие состояния виртуальной машины.

## 8. Дополнительные сведения

Полное доменное имя сервера:

`devops-vm.devops.local`

Проверка:

```bash
hostname -f
```

Скрипт аудита конфигурации:

`scripts/audit.sh`

Для проверки корректной конфигурации:

```bash
./scripts/audit.sh
echo $?
```

Ожидаемый код завершения: `0`.

При нарушении конфигурации ожидаемый код завершения: `1`.
