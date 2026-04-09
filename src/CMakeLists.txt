cmake_minimum_required(VERSION 3.16)

project(linuxpods VERSION 0.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Widgets Bluetooth DBus LinguistTools)
find_package(KF6StatusNotifierItem REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PULSEAUDIO REQUIRED libpulse)

qt_standard_project_setup()

# Translation files
set(TS_FILES
    translations/librepods_tr.ts
)

qt_add_executable(librepods
    main.cpp
    logger.h
    service/linuxpodsservice.cpp
    service/linuxpodsservice.h
    dbus/linuxpodsdbusadaptor.h
    media/mediacontroller.cpp
    media/mediacontroller.h
    media/pulseaudiocontroller.cpp
    media/pulseaudiocontroller.h
    airpods_packets.h
    trayiconmanager.cpp
    trayiconmanager.h
    enums.h
    battery.hpp
    BluetoothMonitor.cpp
    BluetoothMonitor.h
    autostartmanager.hpp
    BasicControlCommand.hpp
    deviceinfo.hpp
    ble/bleutils.cpp
    ble/bleutils.h
    ble/blemanager.cpp
    ble/blemanager.h
    thirdparty/QR-Code-generator/qrcodegen.cpp
    thirdparty/QR-Code-generator/qrcodegen.hpp
    QRCodeImageProvider.hpp
    eardetection.hpp
    media/playerstatuswatcher.cpp
    media/playerstatuswatcher.h
    systemsleepmonitor.hpp
)

qt_add_qml_module(librepods
    URI linux
    VERSION 1.0
    QML_FILES
        Main.qml
        BatteryIndicator.qml
        SegmentedControl.qml
        PodColumn.qml
        Icon.qml
        KeysQRDialog.qml
        SettingsPage.qml
        HearingAidPage.qml
        SettingRow.qml
)

# Add the resource file
qt_add_resources(librepods "resources"
    PREFIX "/icons"
    FILES
        assets/airpods.png
        assets/pod.png
        assets/pod_case.png
        assets/pod3.png
        assets/pod3_case.png
        assets/pod4_case.png
        assets/podpro.png
        assets/podpro_case.png
        assets/podmax.png
        assets/fonts/SF-Symbols-6.ttf
)

target_link_libraries(librepods
    PRIVATE Qt6::Quick Qt6::Widgets Qt6::Bluetooth Qt6::DBus
            KF6::StatusNotifierItem
            OpenSSL::SSL OpenSSL::Crypto ${PULSEAUDIO_LIBRARIES}
)

qt_add_executable(librepods-ctl
    librepods-ctl.cpp
)
target_link_libraries(librepods-ctl
    PRIVATE Qt6::Core Qt6::Network
)
install(TARGETS librepods-ctl
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

target_include_directories(librepods PRIVATE ${PULSEAUDIO_INCLUDE_DIRS})

# ── Headless daemon (linuxpods-daemon) ───────────────────────────────
# Shares all backend sources with librepods but has no QML/GUI.
set(DAEMON_SOURCES
    daemon/main.cpp
    service/linuxpodsservice.cpp
    service/linuxpodsservice.h
    dbus/linuxpodsdbusadaptor.h
    media/mediacontroller.cpp
    media/mediacontroller.h
    media/pulseaudiocontroller.cpp
    media/pulseaudiocontroller.h
    airpods_packets.h
    enums.h
    battery.hpp
    BluetoothMonitor.cpp
    BluetoothMonitor.h
    autostartmanager.hpp
    BasicControlCommand.hpp
    deviceinfo.hpp
    ble/bleutils.cpp
    ble/bleutils.h
    ble/blemanager.cpp
    ble/blemanager.h
    thirdparty/QR-Code-generator/qrcodegen.cpp
    thirdparty/QR-Code-generator/qrcodegen.hpp
    eardetection.hpp
    media/playerstatuswatcher.cpp
    media/playerstatuswatcher.h
    systemsleepmonitor.hpp
)
qt_add_executable(linuxpods-daemon ${DAEMON_SOURCES})
target_include_directories(linuxpods-daemon PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${PULSEAUDIO_INCLUDE_DIRS})
target_link_libraries(linuxpods-daemon
    PRIVATE Qt6::Core Qt6::Bluetooth Qt6::DBus
            OpenSSL::SSL OpenSSL::Crypto ${PULSEAUDIO_LIBRARIES}
)

include(GNUInstallDirs)
install(TARGETS librepods linuxpods-daemon
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES assets/me.kavishdevar.librepods.desktop
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
install(FILES assets/librepods.svg
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")
install(FILES assets/me.kavishdevar.linuxpods.metainfo.xml
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

# Locate data/ and plasmoid/ directories.
# When building locally with `cmake -S src -B build`, they are at ../data.
# When building from RPM tarball, they are siblings: data/ and plasmoid/.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../data/me.kavishdevar.linuxpods.service")
    set(DATA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../data")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data/me.kavishdevar.linuxpods.service")
    set(DATA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/data")
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../plasmoid/metadata.json")
    set(PLASMOID_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../plasmoid")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid/metadata.json")
    set(PLASMOID_DIR "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid")
endif()

# D-Bus service file for auto-activation
if(DATA_DIR)
    install(FILES "${DATA_DIR}/me.kavishdevar.linuxpods.service"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/dbus-1/services")
    install(FILES "${DATA_DIR}/linuxpods-daemon.service"
        DESTINATION "/usr/lib/systemd/user")
    install(FILES "${DATA_DIR}/90-linuxpods.preset"
        DESTINATION "/usr/lib/systemd/user-preset")
endif()

# ── Plasma 6 plasmoid ───────────────────────────────────────────────
if(PLASMOID_DIR)
    install(DIRECTORY "${PLASMOID_DIR}/"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/plasma/plasmoids/me.kavishdevar.linuxpods"
        FILES_MATCHING
        PATTERN "*.json"
        PATTERN "*.qml"
    )
endif()

# Translation support
qt_add_translations(librepods
    TS_FILES ${TS_FILES}
    QM_FILES_OUTPUT_VARIABLE QM_FILES
)

# Install translation files
install(FILES ${QM_FILES}
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/librepods/translations")
