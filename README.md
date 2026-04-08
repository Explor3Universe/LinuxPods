# LinuxPods

RPM-пакет [LibrePods](https://github.com/kavishdevar/librepods) для Fedora/RHEL.

LibrePods — нативное Linux-приложение, которое разблокирует фичи Apple AirPods на не-Apple устройствах через reverse-engineered Apple Accessory Protocol (AAP) поверх L2CAP. Этот репозиторий упаковывает upstream-проект в готовый RPM, который ставится одной командой `dnf install`.

## Возможности

- Заряд батареи (левый, правый наушник, кейс)
- ANC / Transparency / Adaptive / Off режимы
- Ear detection (автопауза при вынимании)
- Conversational Awareness
- Уведомления при подключении
- Tray-иконка в KDE Plasma

Протестировано на **AirPods Pro 2 USB-C (2024)** на Fedora 43 + KDE Plasma 6.

## Установка готового RPM

Скачай `.rpm` из [Releases](https://github.com/Puerh0x1/LinuxPods/releases) и поставь:

```bash
sudo dnf install ./linuxpods-0.1.0-*.rpm
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

Нужны: Fedora 39+ или совместимый дистрибутив с rpm-build.

```bash
git clone git@github.com:Puerh0x1/LinuxPods.git
cd LinuxPods
./build.sh
```

Готовый RPM окажется в `./out/`.

## Автозапуск

Для запуска при логине положи `.desktop` файл в `~/.config/autostart/`:

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

GPL-3.0-or-later — наследуется от upstream LibrePods.

## Upstream

Этот пакет — лишь обёртка. Все копирайты, разработка и поддержка кода принадлежат [kavishdevar/librepods](https://github.com/kavishdevar/librepods).
