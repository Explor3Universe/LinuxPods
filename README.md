# LinuxPods

Форк [LibrePods](https://github.com/kavishdevar/librepods) с локально вендоренными исходниками и RPM-пакетом для Fedora/RHEL.

LibrePods — нативное Linux-приложение, которое разблокирует фичи Apple AirPods на не-Apple устройствах через reverse-engineered Apple Accessory Protocol (AAP) поверх L2CAP. **LinuxPods** держит исходники upstream проекта прямо в репозитории под `src/`, что позволяет легко модифицировать UI/QML и core логику без зависимости от удалённого snapshot.

## Возможности

- Заряд батареи (левый, правый наушник, кейс)
- ANC / Transparency / Adaptive / Off режимы
- Ear detection (автопауза при вынимании)
- Conversational Awareness
- Уведомления при подключении
- Tray-иконка в KDE Plasma

Протестировано на **AirPods Pro 2 USB-C (2024)** на Fedora 43 + KDE Plasma 6.

## Структура репозитория

```
LinuxPods/
├── src/                ← вендоренные исходники librepods/linux (C++ + QML)
│   ├── CMakeLists.txt
│   ├── main.cpp
│   ├── BluetoothMonitor.{cpp,h}
│   ├── ble/            ← BLE manager и утилиты
│   ├── media/          ← MPRIS и PulseAudio контроллеры
│   ├── thirdparty/     ← QR-Code-generator
│   ├── translations/   ← .ts файлы переводов
│   ├── assets/         ← иконки и ресурсы (компилируются в бинарь)
│   ├── Main.qml        ← главное окно
│   ├── BatteryIndicator.qml
│   ├── PodColumn.qml
│   ├── SegmentedControl.qml
│   ├── Icon.qml
│   └── KeysQRDialog.qml
├── docs/               ← документация AAP протокола (для reference)
│   ├── AAP Definitions.md
│   ├── Proximity Pairing Message.md
│   └── proximity_keys.py
├── linuxpods.spec      ← RPM spec
├── build.sh            ← билдер: src/ → tarball → rpmbuild → out/
├── LICENSE             ← GPL-3.0
└── out/                ← собранные .rpm (gitignore)
```

## Установка готового RPM

Скачай `.rpm` из [Releases](https://github.com/Puerh0x1/LinuxPods/releases) (или собери сам, см. ниже) и поставь:

```bash
sudo dnf install ./linuxpods-0.1.0-1.fc43.x86_64.rpm
```

Запусти из меню KDE (`LibrePods`) или из терминала:

```bash
librepods --hide   # стартует свёрнутым в трей
```

CLI:

```bash
librepods-ctl noise:anc           # включить ANC
librepods-ctl noise:transparency  # transparency
librepods-ctl noise:adaptive      # adaptive
librepods-ctl noise:off           # выключить
```

## Сборка из исходников

Требования: Fedora 39+ (или совместимый дистрибутив с rpm-build).

```bash
git clone git@github.com:Puerh0x1/LinuxPods.git
cd LinuxPods
./build.sh                # ставит BuildRequires через sudo dnf builddep, потом rpmbuild
# или, если deps уже стоят:
./build.sh --skip-deps
sudo dnf install ./out/linuxpods-0.1.0-1.fc43.x86_64.rpm
```

Готовые RPM в `./out/`. Промежуточный rpmbuild tree — в `~/.cache/linuxpods-rpmbuild/` (т.к. rpmbuild не дружит с пробелами в путях, а корень репо может лежать на «Рабочем столе»).

## Разработка / модификация

Это **самое важное** ради чего нужен этот форк: можно прямо менять файлы в `src/`, и `./build.sh` пересобирает RPM из локальной копии.

### Дизайн (QML)

UI собран на Qt6 Quick + Qt Quick Controls. Основные точки:

- **`src/Main.qml`** — главное окно (то что открывается при клике на трей)
- **`src/BatteryIndicator.qml`** — индикатор батареи (тот самый bar fill для каждого наушника)
- **`src/PodColumn.qml`** — колонка с одним подом (картинка + battery + label)
- **`src/SegmentedControl.qml`** — переключатель ANC режимов
- **`src/Icon.qml`** — обёртка над иконками
- **`src/KeysQRDialog.qml`** — диалог QR-кода для cross-device handoff

QML — декларативный, легко менять цвета, размеры, layouts через property binding. Не требует пересборки C++ кода.

### Core логика (C++)

- **`src/main.cpp`** — точка входа, инициализация Qt, регистрация QML типов, signal/slot wiring
- **`src/BluetoothMonitor.{cpp,h}`** — мониторинг bluez D-Bus событий
- **`src/ble/blemanager.{cpp,h}`** — BLE сканирование (для proximity adverts)
- **`src/airpods_packets.h`** — определения AAP пакетов и опкодов
- **`src/battery.hpp`** — battery state модель
- **`src/eardetection.hpp`** — ear detection логика
- **`src/trayiconmanager.{cpp,h}`** — KDE/Qt system tray интеграция
- **`src/media/`** — media controls (MPRIS) и PulseAudio контроллер для switch sink при ear detection
- **`src/librepods-ctl.cpp`** — отдельный CLI бинарь, общающийся с основным через QLocalSocket

### AAP протокол

Документация AAP (Apple Accessory Protocol) — в `docs/AAP Definitions.md` (опкоды, payload форматы) и `docs/Proximity Pairing Message.md` (зашифрованные BLE adverts).

## Автозапуск

Для запуска при логине положи `.desktop` в `~/.config/autostart/`:

```bash
cat > ~/.config/autostart/linuxpods.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=LinuxPods
Exec=librepods --hide
Icon=librepods
Terminal=false
X-KDE-autostart-after=panel
StartupNotify=false
EOF
```

## Лицензия

**GPL-3.0-or-later** — наследуется от upstream LibrePods. Все модификации и форки этого репозитория обязаны оставаться под GPL-3.0.

## Upstream

Все копирайты и оригинальная разработка кода принадлежат [kavishdevar/librepods](https://github.com/kavishdevar/librepods). LinuxPods — независимый форк, поддерживаемый локально для удобства модификации и упаковки.

Базовая копия исходников снята с upstream commit `1f2d707` (2026-04-06).
