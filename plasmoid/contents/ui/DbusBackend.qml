import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: backend

    // ── Connection ──────────────────────────────────────────────────
    readonly property bool connected: _get("Connected", false)
    readonly property string deviceName: _get("DeviceName", "")

    // ── Battery ─────────────────────────────────────────────────────
    readonly property int leftLevel: _get("LeftBatteryLevel", 0)
    readonly property bool leftCharging: _get("LeftBatteryCharging", false)
    readonly property bool leftAvailable: _get("LeftBatteryAvailable", false)
    readonly property int rightLevel: _get("RightBatteryLevel", 0)
    readonly property bool rightCharging: _get("RightBatteryCharging", false)
    readonly property bool rightAvailable: _get("RightBatteryAvailable", false)
    readonly property int caseLevel: _get("CaseBatteryLevel", 0)
    readonly property bool caseCharging: _get("CaseBatteryCharging", false)
    readonly property bool caseAvailable: _get("CaseBatteryAvailable", false)
    readonly property int headsetLevel: _get("HeadsetBatteryLevel", 0)
    readonly property bool headsetCharging: _get("HeadsetBatteryCharging", false)
    readonly property bool headsetAvailable: _get("HeadsetBatteryAvailable", false)

    // ── Ear detection ───────────────────────────────────────────────
    readonly property bool leftInEar: _get("LeftPodInEar", false)
    readonly property bool rightInEar: _get("RightPodInEar", false)

    // ── Noise control ───────────────────────────────────────────────
    readonly property int noiseMode: _get("NoiseControlMode", 0)
    readonly property int adaptiveLevel: _get("AdaptiveNoiseLevel", 50)

    // ── Toggles ─────────────────────────────────────────────────────
    readonly property bool conversationalAwareness: _get("ConversationalAwareness", false)
    readonly property bool hearingAid: _get("HearingAidEnabled", false)
    readonly property bool oneBudANC: _get("OneBudANCMode", false)

    // ── Settings ────────────────────────────────────────────────────
    readonly property int earBehavior: _get("EarDetectionBehavior", 0)
    readonly property bool notifications: _get("NotificationsEnabled", true)
    readonly property bool autoStart: _get("AutoStartEnabled", false)
    readonly property int retries: _get("RetryAttempts", 3)
    readonly property bool crossDevice: _get("CrossDeviceEnabled", false)

    // ── Convenience ─────────────────────────────────────────────────
    readonly property bool available: _ok
    readonly property int minBattery: {
        if (leftAvailable && rightAvailable)
            return Math.min(leftLevel, rightLevel);
        if (leftAvailable) return leftLevel;
        if (rightAvailable) return rightLevel;
        if (headsetAvailable) return headsetLevel;
        return 0;
    }

    // ── Commands (gdbus uses plain values, NOT dbus-send int32: syntax) ──
    function setNoise(m)    { _call("SetNoiseControlMode", m); }
    function setAdaptive(l) { _call("SetAdaptiveNoiseLevel", l); }
    function setCA(b)       { _call("SetConversationalAwareness", b); }
    function setHA(b)       { _call("SetHearingAidEnabled", b); }
    function set1Bud(b)     { _call("SetOneBudANCMode", b); }
    function setEarBeh(i)   { _call("SetEarDetectionBehavior", i); }
    function setNotif(b)    { _call("SetNotificationsEnabled", b); }
    function setAutoSt(b)   { _call("SetAutoStartEnabled", b); }
    function setRetry(n)    { _call("SetRetryAttempts", n); }
    function setCross(b)    { _call("SetCrossDeviceEnabled", b); }

    // ═══════════════════════════════════════════════════════════════
    property var _d: ({})
    property bool _ok: false
    property int _seq: 0

    function _get(k, fb) { return (k in _d) ? _d[k] : fb; }

    readonly property string _base: "gdbus call --session"
        + " -d me.kavishdevar.linuxpods"
        + " -o /me/kavishdevar/linuxpods"
        + " -m me.kavishdevar.linuxpods.Manager."

    function _call(method, arg) {
        _seq++;
        let cmd = _base + method + " " + arg + " #" + _seq;
        console.log("[LinuxPods] CMD: " + cmd);
        cmdDs.connectSource(cmd);
    }

    function _poll() {
        _seq++;
        let cmd = "gdbus call --session"
            + " -d me.kavishdevar.linuxpods"
            + " -o /me/kavishdevar/linuxpods"
            + " -m org.freedesktop.DBus.Properties.GetAll"
            + " me.kavishdevar.linuxpods.Manager"
            + " #" + _seq;
        pollDs.connectSource(cmd);
    }

    P5Support.DataSource {
        id: pollDs
        engine: "executable"
        connectedSources: []
        onNewData: function(src, data) {
            disconnectSource(src);
            let out = data["stdout"] || "";
            let code = data["exit code"];
            if (code !== undefined && code !== 0) {
                backend._ok = false;
                return;
            }
            let newData = backend._parse(out);
            // Only replace _d if values actually changed (avoids re-firing all bindings)
            let changed = Object.keys(newData).length !== Object.keys(backend._d).length;
            if (!changed) {
                for (let k in newData) {
                    if (backend._d[k] !== newData[k]) { changed = true; break; }
                }
            }
            if (changed) backend._d = newData;
            backend._ok = Object.keys(newData).length > 0;
        }
    }

    P5Support.DataSource {
        id: cmdDs
        engine: "executable"
        connectedSources: []
        onNewData: function(src, data) {
            disconnectSource(src);
            let stderr = data["stderr"] || "";
            if (stderr) console.log("[LinuxPods] CMD ERROR: " + stderr);
            // Refresh after command
            backend._poll();
        }
    }

    function _parse(text) {
        let r = {};
        let re = /'([^']+)':\s*<([^>]*)>/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            let k = m[1], v = m[2].trim();
            if (v === "true") r[k] = true;
            else if (v === "false") r[k] = false;
            else if (v.startsWith("'")) r[k] = v.slice(1, -1);
            else if (v.startsWith("byte 0x")) r[k] = parseInt(v.substring(5), 16);
            else if (v.startsWith("byte ")) r[k] = parseInt(v.substring(5));
            else if (v.startsWith("int32 ")) r[k] = parseInt(v.substring(6));
            else { let n = Number(v); r[k] = isNaN(n) ? v : n; }
        }
        return r;
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: backend._poll()
    }
}
