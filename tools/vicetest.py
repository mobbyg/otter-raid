#!/usr/bin/env python3
"""Drive one VICE (x64sc) session through its remote monitor.

Used for automated checks of the C64 build: set breakpoints,
step frames, take screenshots and read/poke memory, all in a
single emulator run.

    from vicetest import Vice, load_symbols
    sym = load_symbols("build/otter_raid.lst")
    with Vice("build/otter_raid.prg") as v:
        v.connect()                  # attach; pauses the C64
        v.break_at(sym["irq_vblank"])
        for i in range(8):
            v.cont()                 # run to the next breakpoint
            v.screenshot(f"f{i}.png")
            print(v.mem(0x20, 16))
"""
import os
import re
import socket
import subprocess
import time

PROMPT = re.compile(rb"\(C:\$[0-9a-f]{4}\) $")


def load_symbols(listing):
    """Parse the vasm listing's symbol table into {name: value}."""
    syms = {}
    in_table = False
    for line in open(listing, errors="replace"):
        if line.startswith("Symbols by name"):
            in_table = True
            continue
        if in_table:
            m = re.match(r"^(\S+)\s+([AES]):([0-9A-F]+)$", line.strip())
            if m:
                syms[m.group(1)] = int(m.group(3), 16)
            elif line.strip() and syms:
                break
    return syms


class Vice:
    def __init__(self, prg, port=6510, warp=True, extra=(), headless=True,
                 log=None):
        self.port = port
        self.xvfb = None
        env = dict(os.environ)
        if headless:
            # private virtual X display so no window appears
            # (Xvfb picks a free display number and reports it)
            rfd, wfd = os.pipe()
            self.xvfb = subprocess.Popen(
                ["Xvfb", "-displayfd", str(wfd), "-screen", "0",
                 "1024x768x24", "-nolisten", "tcp"],
                pass_fds=(wfd,), stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL)
            os.close(wfd)
            num = b""
            while not num.endswith(b"\n"):
                chunk = os.read(rfd, 16)
                if not chunk:
                    break
                num += chunk
            os.close(rfd)
            env["DISPLAY"] = ":" + num.decode().strip()
            env.pop("WAYLAND_DISPLAY", None)
        args = ["x64sc", "-default", "-sounddev", "dummy",
                "-autostartprgmode", "1", "-remotemonitor",
                "-remotemonitoraddress", f"ip4://127.0.0.1:{port}"]
        if warp:
            args.append("-warp")
        args += list(extra)
        if prg:
            args += ["-autostart", prg]
        out = open(log, "w") if log else subprocess.DEVNULL
        self.proc = subprocess.Popen(args, stdout=out,
                                     stderr=subprocess.STDOUT, env=env)
        self.sock = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def close(self):
        try:
            if self.sock:
                self.sock.sendall(b"quit\n")
                self.sock.close()
        except OSError:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        if self.xvfb:
            self.xvfb.terminate()
            self.xvfb.wait(timeout=5)

    def connect(self, boot_wait=3.0):
        """Wait for boot/autostart, then attach (pauses the C64)."""
        time.sleep(boot_wait)
        for _ in range(100):
            try:
                self.sock = socket.create_connection(
                    ("127.0.0.1", self.port), timeout=30)
                break
            except OSError:
                time.sleep(0.1)
        if self.sock is None:
            raise RuntimeError("VICE remote monitor did not come up")
        # resynchronise: discard stray prompts until a marker
        # command's own output comes back
        time.sleep(0.3)
        self._drain()
        self.sock.sendall(b"m $fff0 $fff0\n")
        buf = b""
        self.sock.settimeout(30)
        while not (b">C:fff0" in buf and PROMPT.search(buf)):
            buf += self.sock.recv(65536)
        self._drain(0.1)
        return ""

    def _drain(self, quiet=0.15):
        """Discard any pending output (stray prompts)."""
        self.sock.settimeout(quiet)
        try:
            while self.sock.recv(65536):
                pass
        except (socket.timeout, BlockingIOError):
            pass

    def _read_prompt(self, timeout=30):
        buf = b""
        self.sock.settimeout(timeout)
        while not PROMPT.search(buf):
            data = self.sock.recv(65536)
            if not data:
                break
            buf += data
        return buf.decode(errors="replace")

    def cmd(self, text, timeout=30):
        self._drain(0.02)
        self.sock.sendall(text.encode() + b"\n")
        return self._read_prompt(timeout)

    def break_at(self, addr):
        return self.cmd(f"break ${addr:04x}")

    def delete_breaks(self):
        return self.cmd("delete")

    def run_frames(self, n, timeout=60):
        """Continue through n breakpoint hits (one per frame when
        the breakpoint is on a per-frame routine). VICE's
        `ignore` count is unreliable, so this steps hit by hit."""
        out = ""
        for _ in range(n):
            out = self.cont(timeout)
        return out

    def cont(self, timeout=30):
        """Resume and block until the next breakpoint stops the CPU."""
        return self.cmd("x", timeout)

    def screenshot(self, path):
        path = os.path.abspath(path)
        return self.cmd(f'screenshot "{path}" 2')

    def mem(self, addr, length):
        out = self.cmd(f"m ${addr:04x} ${addr + length - 1:04x}")
        data = []
        for line in out.splitlines():
            # the first line may still carry the prompt prefix
            m = re.search(r">C:([0-9a-f]{4})((?:\s{1,2}[0-9a-f]{2}){1,16})",
                          line)
            if m:
                data += [int(b, 16) for b in m.group(2).split()]
        return data[:length]

    def poke(self, addr, *values):
        vals = " ".join(f"${v:02x}" for v in values)
        return self.cmd(f">C:${addr:04x} {vals}")

    def load_and_go(self, prg, addr=0x080D, timeout=30):
        """Load a PRG into RAM from the monitor and jump to addr.
        Use with Vice(None) to set breakpoints before the program
        runs. Returns when the next breakpoint stops the CPU."""
        prg = os.path.abspath(prg)
        self.cmd(f'l "{prg}" 0')
        return self.cmd(f"g ${addr:04x}", timeout)

    def regs(self):
        return self.cmd("r")
