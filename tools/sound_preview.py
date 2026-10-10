#!/usr/bin/env python3
"""Record listenable WAV previews of the Otter Raid music and sfx.

    python3 tools/sound_preview.py                # 6581 and 8580
    python3 tools/sound_preview.py --sid 8580     # one SID model
    python3 tools/sound_preview.py --seconds 20   # shorter tune clips

Assembles build/sound_test.prg from c64/sound/sound_test.asm, runs it
in one headless VICE session (tools/vicetest.py, private Xvfb) that
records to a WAV, plays every tune and an sfx reel through the
harness mailbox, and cuts the recording into

    build/sound_preview/<n>_<tune>_<sid>.wav    every tune, long enough
                                                to hear the loop point
    build/sound_preview/sfx_reel_<sid>.wav      sfx 1-15, 2.2 s apart

The emulator runs in real time (warp mutes the SID), so both models
take about 10 minutes. Clips are cut at WAV file positions taken
while the emulator is stopped in the monitor; they can be off by a
few hundredths of a second.
"""
import argparse
import os
import struct
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from vicetest import Vice  # noqa: E402
import music  # noqa: E402

BUILD = os.path.join(ROOT, 'build')
PRG = os.path.join(BUILD, 'sound_test.prg')
OUT_DIR = os.path.join(BUILD, 'sound_preview')
RAW_WAV = os.path.join(OUT_DIR, 'session.raw.wav')

TST_CMD = 0x0340            # harness command mailbox
TST_SCRIPT_MEM = 0xC000     # harness script (cmd, wait lo, wait hi)
CMD_STOP = 0x08
CMD_SFX = 0x80              # harness: $80+n = sfx n
CMD_MASK = 0x40
CMD_SCRIPT = 0x50
SFX_GAP = 110               # frames between sfx in the reel
FRAME_S = 19656 / 985248.0  # PAL frame


def build_harness():
    os.makedirs(BUILD, exist_ok=True)
    subprocess.check_call(
        ['vasm6502_oldstyle', '-Fbin', '-cbm-prg', '-dotdir', '-quiet',
         '-o', PRG, 'c64/sound/sound_test.asm'], cwd=ROOT)


def tune_plan(max_seconds):
    """[(number, name, seconds)] from the music sources."""
    b = music.Build()
    b.build_instruments()
    b.build_tunes()
    plan = []
    for n in sorted(b.by_number):
        t = b.by_number[n]
        if t.loops:
            loops = 2 if t.loop_frames < 750 else 1
            frames = t.intro_frames + loops * t.loop_frames + 150
        else:
            frames = t.total_frames + 125       # let the release ring
        sec = frames / 50.0
        if max_seconds:
            sec = min(sec, max_seconds)
        plan.append((n, t.name.lower(), sec))
    return plan, b.ids.get('SFX_COUNT', 15)


class Recorder:
    """VICE session recording to RAW_WAV; positions in samples."""

    def __init__(self, port):
        if os.path.exists(RAW_WAV):
            os.remove(RAW_WAV)
        self.v = Vice(PRG, port=port, warp=False,
                      extra=['-sounddev', 'wav', '-soundarg', RAW_WAV,
                             '-soundoutput', '1'],
                      log=os.path.join(OUT_DIR, 'session.log'))
        self.v.connect(boot_wait=4.0)
        self.running = False

    def pos(self):
        """Samples written so far (call while stopped)."""
        return max(0, (os.path.getsize(RAW_WAV) - 44) // 2)

    def run(self, seconds):
        self.v.sock.sendall(b'x\n')
        time.sleep(seconds)
        self.v.cmd('r')             # stop the C64 in the monitor

    def command(self, cmd):
        self.v.poke(TST_CMD, cmd)

    def close(self):
        self.v.close()


def record(rec, cmd, seconds, tail=1.5):
    """Run one item: returns (start, end) sample positions."""
    start = rec.pos()
    rec.command(cmd)
    rec.run(seconds)
    rec.command(CMD_STOP)
    rec.run(tail)
    return start, rec.pos()


def read_samples(path):
    data = open(path, 'rb').read()
    i = data.find(b'data')
    if data[:4] != b'RIFF' or i < 0:
        raise RuntimeError('%s is not a WAV file' % path)
    channels = struct.unpack_from('<H', data, 22)[0]
    rate = struct.unpack_from('<I', data, 24)[0]
    if channels != 1:
        raise RuntimeError('expected a mono recording')
    return data[i + 8:], rate


def write_wav(path, pcm, rate):
    with open(path, 'wb') as f:
        f.write(b'RIFF' + struct.pack('<I', 36 + len(pcm)) + b'WAVE')
        f.write(b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, rate,
                                       rate * 2, 2, 16))
        f.write(b'data' + struct.pack('<I', len(pcm)) + pcm)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sid', choices=('6581', '8580', 'both'),
                    default='both')
    ap.add_argument('--seconds', type=float, default=0,
                    help='cap every tune clip at this length')
    ap.add_argument('--port', type=int, default=6545,
                    help='VICE remote monitor port')
    args = ap.parse_args()
    models = ['6581', '8580'] if args.sid == 'both' else [args.sid]
    os.makedirs(OUT_DIR, exist_ok=True)
    build_harness()
    plan, sfx_count = tune_plan(args.seconds)
    total = len(models) * (sum(s + 1.5 for _, _, s in plan) +
                           sfx_count * SFX_GAP * FRAME_S + 3)
    print('recording %d tunes + sfx reel on %s, about %.0f s' % (
        len(plan), ' and '.join(models), total), flush=True)

    # sfx reel as a harness script: sfx n, then SFX_GAP frames
    script = []
    for n in range(1, sfx_count + 1):
        script += [CMD_SFX + n, (SFX_GAP - 1) & 0xFF, (SFX_GAP - 1) >> 8]
    script += [0, 0, 0]

    cuts = []
    rec = Recorder(args.port)
    try:
        rec.command(CMD_MASK + 7)
        rec.run(0.5)
        for i in range(0, len(script), 16):
            rec.v.poke(TST_SCRIPT_MEM + i, *script[i:i + 16])
        for sid in models:
            rec.v.cmd('resourceset "SidModel" "%d"' %
                      (0 if sid == '6581' else 1))
            rec.run(0.5)            # the model switch clicks: skip it
            for n, name, sec in plan:
                print('  %s: %d %s (%.1f s)' % (sid, n, name, sec),
                      flush=True)
                a, b = record(rec, n, sec)
                cuts.append(('%d_%s_%s.wav' % (n, name, sid), a, b))
            print('  %s: sfx reel' % sid, flush=True)
            a, b = record(rec, CMD_SCRIPT,
                          sfx_count * SFX_GAP * FRAME_S + 0.5)
            cuts.append(('sfx_reel_%s.wav' % sid, a, b))
    finally:
        rec.close()

    pcm, rate = read_samples(RAW_WAV)
    for fname, a, b in cuts:
        write_wav(os.path.join(OUT_DIR, fname), pcm[2 * a:2 * b], rate)
        print('%-28s %6.1f s' % (fname, (b - a) / float(rate)))
    os.remove(RAW_WAV)
    os.remove(os.path.join(OUT_DIR, 'session.log'))
    print('previews in %s' % os.path.relpath(OUT_DIR, ROOT))


if __name__ == '__main__':
    main()
