#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later

"""Exercise the packaged CLI and daemon on an isolated session bus, without hardware."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def run(command, env, expected=0):
    result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=10)
    if result.returncode != expected:
        raise RuntimeError(f"{command}: exit {result.returncode}\n{result.stdout}{result.stderr}")
    return result


def main():
    binaries = Path(sys.argv[1]).resolve()
    cli = str(binaries / "linuxpods")
    daemon = str(binaries / "linuxpods-daemon")
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise RuntimeError("Run this check with dbus-run-session")

    with tempfile.TemporaryDirectory(prefix="linuxpods-check-") as directory:
        home = Path(directory)
        runtime = home / "runtime"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
                   XDG_CONFIG_HOME=str(home / "config"), XDG_DATA_HOME=str(home / "data"),
                   XDG_CACHE_HOME=str(home / "cache"))
        # Never connect the test daemon to a host Bluetooth or audio service.
        env["DBUS_SYSTEM_BUS_ADDRESS"] = f"unix:path={home}/no-system-bus"
        env["PULSE_SERVER"] = f"unix:{home}/no-pulse-server"

        help_output = run([cli, "--help"], env).stdout
        assert "noise:anc" in help_output and "ca:off" in help_output
        assert run([cli, "-h"], env).stdout == help_output
        assert "Usage:" in run([cli], env, expected=1).stderr
        assert "Could not connect" in run([cli, "noise:anc"], env, expected=1).stderr

        with (home / "daemon.log").open("w+") as log:
            process = subprocess.Popen([daemon], env=env, stdout=log, stderr=log)
            try:
                query = ["gdbus", "call", "--session", "--dest", "io.github.Explor3Universe.LinuxPods",
                         "--object-path", "/io/github/Explor3Universe/LinuxPods",
                         "--method", "org.freedesktop.DBus.Properties.Get",
                         "io.github.Explor3Universe.LinuxPods.Manager", "Connected"]
                owner_query = ["gdbus", "call", "--session", "--dest", "org.freedesktop.DBus",
                               "--object-path", "/org/freedesktop/DBus",
                               "--method", "org.freedesktop.DBus.NameHasOwner",
                               "io.github.Explor3Universe.LinuxPods"]
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline:
                    if process.poll() is not None:
                        raise RuntimeError("daemon exited during startup")
                    # Checking the bus itself cannot auto-activate a second daemon.
                    result = run(owner_query, env)
                    if result.stdout.strip() == "(true,)" and (runtime / "linuxpods-daemon").exists():
                        break
                    time.sleep(0.1)
                else:
                    raise RuntimeError("daemon did not expose its D-Bus interface and CLI socket")
                assert run(query, env).stdout.strip() == "(<false>,)"
                # Observe local daemon state over D-Bus; this is not a hardware acknowledgement.
                ca_query = query[:-1] + ["ConversationalAwareness"]
                for command, expected in [("ca:on", "(<true>,)"), ("ca:off", "(<false>,)")]:
                    run([cli, command], env)
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        if run(ca_query, env).stdout.strip() == expected:
                            break
                        time.sleep(0.1)
                    else:
                        raise RuntimeError(f"daemon did not process {command}")
                assert process.poll() is None
                assert run(query, env).stdout.strip() == "(<false>,)"
            except Exception:
                log.seek(0)
                sys.stderr.write(log.read())
                raise
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    print("PASS: CLI help, missing daemon, daemon startup, D-Bus state and CLI transport")


if __name__ == "__main__":
    main()
