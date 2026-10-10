#!/usr/bin/env python3
"""Otter Raid music compiler.

Turns the human readable sources in music/ into 6502 data for the
SID player in c64/sound/sound.asm:

    music/instruments.txt   instruments, wave programs, filters
    music/<tune>.txt        one file per tune (MML style patterns)
    music/sfx.txt           sound effect programs

    -> c64/sound/music_data.asm   (song table, orders, patterns,
                                   instruments, wave table, filters,
                                   PAL + NTSC frequency tables)
    -> c64/sound/sfx_data.asm     (sfx priorities and programs)

Tune and sfx numbers come from c64/sound/sound_ids.asm.
The source formats are described in docs/c64-sound.md.

Usage:  python3 tools/music.py            regenerate both files
        python3 tools/music.py --check    fail if files are stale
        python3 tools/music.py --dump T   print tune T as a grid
"""
import argparse
import math
import os
import re
import sys
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(ROOT, 'music')
SOUND_DIR = os.path.join(ROOT, 'c64', 'sound')
IDS_FILE = os.path.join(SOUND_DIR, 'sound_ids.asm')
OUT_MUSIC = os.path.join(SOUND_DIR, 'music_data.asm')
OUT_SFX = os.path.join(SOUND_DIR, 'sfx_data.asm')

PAL_CLOCK = 985248.0
NTSC_CLOCK = 1022727.0
FRAME_HZ = 50.0

MAX_NOTE = 95            # B-7 (A#7 is the highest PAL can play)
MIN_EVENT = 5            # frames; shorter events defeat the staggered
                         # pattern reads (sound_update cycle budget)
MAX_PATTERNS = 128
MAX_INSTRUMENTS = 48
DATA_BUDGET = 6144       # bytes of music + sfx data allowed

SEMI = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11}
NOTE_NAMES = ['c-', 'c#', 'd-', 'd#', 'e-', 'f-', 'f#', 'g-', 'g#',
              'a-', 'a#', 'b-']

EV_REST = 0x60
EV_TIE = 0x61


class CompileError(Exception):
    pass


def fail(where, msg):
    raise CompileError('%s: %s' % (where, msg))


# ===================================================================
# helpers
# ===================================================================

def freq_reg(note, clock):
    hz = 440.0 * 2.0 ** ((note - 57) / 12.0)
    return min(0xFFFF, int(round(hz * 16777216.0 / clock)))


def parse_int(tok, where):
    t = tok.strip()
    neg = t.startswith('-')
    if t[:1] in '+-':
        t = t[1:]
    try:
        if t.startswith('$'):
            v = int(t[1:], 16)
        elif t.lower().startswith('0x'):
            v = int(t[2:], 16)
        else:
            v = int(t, 10)
    except ValueError:
        fail(where, 'bad number %r' % tok)
    return -v if neg else v


def parse_hex(tok, where):
    t = tok.strip().lstrip('$')
    try:
        return int(t, 16)
    except ValueError:
        fail(where, 'bad hex number %r' % tok)


def parse_note_name(tok, where):
    """'c#5', 'b-3', 'f4' or a plain number -> note number."""
    m = re.fullmatch(r'([a-gA-G])([#+-]?)(\d)', tok)
    if m:
        n = SEMI[m.group(1).lower()] + 12 * int(m.group(3))
        n += {'#': 1, '+': 1, '-': -1, '': 0}[m.group(2)]
    else:
        n = parse_int(tok, where)
    if not 0 <= n <= MAX_NOTE:
        fail(where, 'note %r out of range' % tok)
    return n


def note_str(n):
    return '%s%d' % (NOTE_NAMES[n % 12], n // 12)


def strip_comment(line):
    for c in ('#', ';'):
        i = line.find(c)
        # '#' may be a sharp inside a note name (c#4): only treat it as
        # a comment when it starts the line or follows whitespace
        while i >= 0:
            if c == ';' or i == 0 or line[i - 1] in ' \t':
                line = line[:i]
                break
            i = line.find(c, i + 1)
    return line.rstrip()


def read_lines(path):
    with open(path) as f:
        for num, raw in enumerate(f, 1):
            yield '%s:%d' % (os.path.relpath(path, ROOT), num), \
                strip_comment(raw)


def byte_lines(values, per_line=16):
    """'.byte' lines of at most per_line values and 79 columns."""
    out = []
    cur = []
    width = 8 + len('.byte ')
    for v in values:
        txt = v if isinstance(v, str) else '$%02x' % v
        if cur and (len(cur) >= per_line or
                    width + 1 + len(txt) > 79):
            out.append('\t.byte ' + ','.join(cur))
            cur = []
            width = 8 + len('.byte ')
        width += len(txt) + (1 if cur else 0)
        cur.append(txt)
    if cur:
        out.append('\t.byte ' + ','.join(cur))
    if not out:
        out.append('\t; (empty)')
    return out


# ===================================================================
# sound ids
# ===================================================================

def read_ids():
    ids = {}
    for where, line in read_lines(IDS_FILE):
        m = re.match(r'\s*([A-Z0-9_]+)\s*=\s*(\S+)', line)
        if m:
            ids[m.group(1)] = parse_int(m.group(2), where)
    return ids


# ===================================================================
# instruments, wave programs, filters
# ===================================================================

class Instrument:
    def __init__(self, name, where):
        self.name = name
        self.where = where
        self.ad = 0x09
        self.sr = 0x00
        self.wave = None          # list of (wave, notebyte), loop idx
        self.pulse = (0x800, 0, 0x02, 0x0E)
        self.vib = (0, 0, 0)
        self.filter = None
        self.keeppw = False
        self.rel_range = (0, 0)   # min/max relative note offsets


class FilterDef:
    def __init__(self, name, where):
        self.name = name
        self.where = where
        self.mode = 0x10
        self.res = 0
        self.cut = (0x40, 0x40, 0)


def parse_wave(toks, where):
    entries = []
    loop = None
    rels = [0]
    for t in toks:
        if t == '/':
            loop = len(entries)
            continue
        m = re.fullmatch(r'([0-9a-fA-F]{2}|--):(.+)', t)
        if not m:
            fail(where, 'bad wave entry %r' % t)
        w = 0 if m.group(1) == '--' else int(m.group(1), 16)
        w &= 0xFE
        if w == 0xFE:
            fail(where, 'waveform $FE/$FF is reserved')
        nt = m.group(2)
        if nt.startswith('='):
            nb = 0x80 | parse_note_name(nt[1:], where)
        else:
            k = parse_int(nt, where)
            if not -64 <= k <= 63:
                fail(where, 'relative note %d out of range' % k)
            rels.append(k)
            nb = k & 0x7F
        entries.append((w, nb))
    if not entries:
        fail(where, 'empty wave program')
    if loop is None or loop >= len(entries):
        loop = len(entries) - 1     # hold the last entry
    return entries, loop, (min(rels), max(rels))


def parse_instruments(path):
    insts = {}
    filters = {}
    order = []
    cur = None
    for where, line in read_lines(path):
        toks = line.split()
        if not toks:
            continue
        key = toks[0].lower()
        if key in ('inst', 'filter') and cur is None:
            if len(toks) != 2:
                fail(where, 'expected "%s NAME"' % key)
            name = toks[1]
            if name in insts or name in filters:
                fail(where, 'duplicate name %s' % name)
            if key == 'inst':
                cur = Instrument(name, where)
                insts[name] = cur
                order.append(name)
            else:
                cur = FilterDef(name, where)
                filters[name] = cur
            continue
        if cur is None:
            fail(where, 'statement outside inst/filter block')
        if key == 'end':
            if isinstance(cur, Instrument) and cur.wave is None:
                fail(cur.where, 'instrument %s has no wave' % cur.name)
            cur = None
            continue
        args = toks[1:]
        if isinstance(cur, Instrument):
            if key == 'adsr':
                if len(args) != 4:
                    fail(where, 'adsr needs 4 nibbles')
                a, d, s, r = (parse_hex(x, where) & 15 for x in args)
                cur.ad = a << 4 | d
                cur.sr = s << 4 | r
            elif key == 'wave':
                ent, loop, rr = parse_wave(args, where)
                cur.wave = (ent, loop)
                cur.rel_range = rr
            elif key == 'pulse':
                if len(args) != 4:
                    fail(where, 'pulse START SPEED MIN MAX')
                start = parse_int(args[0], where)
                spd = parse_int(args[1], where)
                lo = parse_int(args[2], where)
                hi = parse_int(args[3], where)
                if not (0 <= start <= 0xFFF and -127 <= spd <= 127 and
                        1 <= lo < hi <= 0x0E):
                    fail(where, 'pulse values out of range')
                if spd and not lo <= start >> 8 <= hi:
                    fail(where, 'pulse start outside min/max')
                cur.pulse = (start, spd, lo, hi)
            elif key == 'vib':
                if len(args) != 3:
                    fail(where, 'vib DELAY SPEED DEPTH')
                d, s, dep = (parse_int(x, where) for x in args)
                if not (0 <= d <= 255 and 0 <= s <= 127 and
                        0 <= dep <= 8):
                    fail(where, 'vib values out of range')
                cur.vib = (max(1, d), s, dep)
            elif key == 'filter':
                cur.filter = args[0]
            elif key == 'keeppw':
                cur.keeppw = True
            else:
                fail(where, 'unknown instrument field %r' % key)
        else:
            if key == 'mode':
                mode = 0
                for part in args[0].lower().split('+'):
                    bits = {'lp': 0x10, 'bp': 0x20, 'hp': 0x40}
                    if part not in bits:
                        fail(where, 'filter mode lp/bp/hp')
                    mode |= bits[part]
                cur.mode = mode
            elif key == 'res':
                cur.res = parse_int(args[0], where) & 15
            elif key == 'cut':
                if len(args) != 3:
                    fail(where, 'cut START LIMIT SPEED')
                st = parse_int(args[0], where)
                lim = parse_int(args[1], where)
                spd = parse_int(args[2], where)
                if not (0 <= st <= 255 and 0 <= lim <= 255 and
                        -127 <= spd <= 127):
                    fail(where, 'cut values out of range')
                if spd > 0 and (lim < st or lim + spd > 255):
                    fail(where, 'rising cutoff: need START<=LIMIT, '
                         'LIMIT+SPEED<=255')
                if spd < 0 and (lim > st or lim + spd < 0):
                    fail(where, 'falling cutoff: need START>=LIMIT, '
                         'LIMIT>=|SPEED|')
                cur.cut = (st, lim, spd)
            else:
                fail(where, 'unknown filter field %r' % key)
    if cur is not None:
        fail(cur.where, 'missing end')
    for ins in insts.values():
        if ins.filter is not None and ins.filter not in filters:
            fail(ins.where, 'unknown filter %s' % ins.filter)
    return insts, order, filters


# ===================================================================
# tunes
# ===================================================================

TOKEN_RE = re.compile(r'''
    (?P<ins>@[A-Za-z_][A-Za-z0-9_]*)
  | (?P<oct>o\d)
  | (?P<shift>[<>])
  | (?P<deflen>l(?:\d+\.*|:\d+))
  | (?P<note>_?[a-g][+\#-]?(?:\d+\.*|:\d+)?)
  | (?P<rest>r(?:\d+\.*|:\d+)?)
  | (?P<tie>\^(?:\d+\.*|:\d+)?)
  | (?P<slide>s[+-]?\d+(?:\.\d+)?,\d+)
  | (?P<ropen>\[)
  | (?P<rclose>\](?:\d+)?)
  | (?P<bar>\|)
  | (?P<space>\s+)
''', re.X)


class Event:
    __slots__ = ('kind', 'note', 'frames', 'ins', 'legato', 'slide',
                 'where')

    def __init__(self, kind, note, frames, ins, legato, slide, where):
        self.kind = kind          # 'note', 'rest', 'tie'
        self.note = note
        self.frames = frames
        self.ins = ins
        self.legato = legato
        self.slide = slide        # (semitones, frames) or None
        self.where = where


class Pattern:
    def __init__(self, tune, name, where):
        self.tune = tune
        self.name = name
        self.where = where
        self.text = []            # (where, text)
        self.events = []
        self.frames = 0
        self.data = None
        self.index = None
        self.upbeat = 0           # frames before the first bar line


class Tune:
    def __init__(self, path):
        self.path = path
        self.name = None
        self.tempo = 6
        self.bar = 16
        self.patterns = {}
        self.voices = {1: [], 2: [], 3: []}
        self.number = None


def length_frames(spec, whole, where, default):
    if spec is None or spec == '':
        return default
    if spec.startswith(':'):
        return parse_int(spec[1:], where)
    m = re.fullmatch(r'(\d+)(\.*)', spec)
    den = int(m.group(1))
    if den == 0:
        fail(where, 'zero length')
    f = whole / den
    add = f
    for _ in m.group(2):
        add /= 2
        f += add
    if abs(f - round(f)) > 1e-9:
        fail(where, 'length %s is %.2f frames, not whole frames' %
             (spec, f))
    return int(round(f))


def tokenize(text, where):
    pos = 0
    out = []
    while pos < len(text):
        m = TOKEN_RE.match(text, pos)
        if not m:
            fail(where, 'cannot parse %r' % text[pos:pos + 12])
        pos = m.end()
        if m.lastgroup != 'space':
            out.append((m.lastgroup, m.group(m.lastgroup)))
    return out


def expand_repeats(toks, where):
    out = []
    stack = [out]
    for kind, val in toks:
        if kind == 'ropen':
            stack.append([])
        elif kind == 'rclose':
            if len(stack) < 2:
                fail(where, 'unbalanced ]')
            body = stack.pop()
            n = int(val[1:]) if len(val) > 1 else 2
            stack[-1].extend(body * n)
        else:
            stack[-1].append((kind, val))
    if len(stack) != 1:
        fail(where, 'unbalanced [')
    return out


def parse_pattern(pat, tune):
    whole = 16 * tune.tempo
    octave = 4
    deflen = 4 * tune.tempo
    ins = None
    legato_next = False
    slide_next = None
    events = []
    t = 0
    bar_frames = tune.bar * tune.tempo
    toks = []
    for where, text in pat.text:
        for tk in tokenize(text, where):
            toks.append((tk, where))
    # repeats need the plain token list; keep 'where' of the first
    flat = expand_repeats([tk for tk, _ in toks],
                          pat.text[0][0] if pat.text else pat.where)
    wheres = [w for _, w in toks]
    w = wheres[0] if wheres else pat.where
    for kind, val in flat:
        if kind == 'ins':
            ins = val[1:]
        elif kind == 'oct':
            octave = int(val[1:])
        elif kind == 'shift':
            octave += 1 if val == '>' else -1
        elif kind == 'deflen':
            deflen = length_frames(val[1:], whole, w, deflen)
        elif kind == 'bar':
            if (t - pat.upbeat) % bar_frames:
                fail(pat.where, 'pattern %s: bar line at frame %d is '
                     'not on a bar boundary (%d frames/bar)' %
                     (pat.name, t, bar_frames))
        elif kind == 'slide':
            a, b = val[1:].split(',')
            slide_next = (float(a), int(b))
        elif kind == 'note':
            leg = val.startswith('_')
            if leg:
                val = val[1:]
            m = re.fullmatch(r'([a-g])([+#-]?)(.*)', val)
            n = SEMI[m.group(1)] + 12 * octave
            n += {'#': 1, '+': 1, '-': -1, '': 0}[m.group(2)]
            fr = length_frames(m.group(3), whole, w, deflen)
            if not 1 <= n <= MAX_NOTE:
                fail(pat.where, 'pattern %s: note %s out of range' %
                     (pat.name, val))
            events.append(Event('note', n, fr, ins, leg or legato_next,
                                slide_next, pat.where))
            legato_next = False
            slide_next = None
            t += fr
        elif kind == 'rest':
            fr = length_frames(val[1:], whole, w, deflen)
            events.append(Event('rest', None, fr, None, False, None,
                                pat.where))
            t += fr
        elif kind == 'tie':
            fr = length_frames(val[1:], whole, w, deflen)
            events.append(Event('tie', None, fr, None, False, None,
                                pat.where))
            t += fr
    if not events:
        fail(pat.where, 'pattern %s is empty' % pat.name)
    pat.events = events
    pat.frames = t


def encode_pattern(pat, insts_index, tune):
    data = []
    cur_ins = None
    cur_dur = None
    # merge ties / rests into the previous event where possible
    merged = []
    for ev in pat.events:
        if merged and ev.kind == 'tie' and \
                merged[-1].frames + ev.frames <= 255:
            merged[-1].frames += ev.frames
            continue
        if merged and ev.kind == 'rest' and merged[-1].kind == 'rest' \
                and merged[-1].frames + ev.frames <= 255:
            merged[-1].frames += ev.frames
            continue
        merged.append(Event(ev.kind, ev.note, ev.frames, ev.ins,
                            ev.legato, ev.slide, ev.where))
    for ev in merged:
        frames = ev.frames
        first = True
        if frames < MIN_EVENT:
            fail(pat.where, 'pattern %s: event of %d frames; events '
                 'shorter than %d frames break the sound_update cycle '
                 'budget' % (pat.name, frames, MIN_EVENT))
        while frames > 0:
            chunk = min(frames, 255)
            if 0 < frames - chunk < MIN_EVENT:
                chunk -= MIN_EVENT
            frames -= chunk
            if first:
                if ev.kind == 'note':
                    if ev.ins is not None and ev.ins != cur_ins:
                        if ev.ins not in insts_index:
                            fail(pat.where, 'unknown instrument %s' %
                                 ev.ins)
                        data.append(0xC0 + insts_index[ev.ins])
                        cur_ins = ev.ins
                    if ev.slide is not None:
                        semis, sfr = ev.slide
                        f0 = freq_reg(ev.note, PAL_CLOCK)
                        f1 = 440.0 * 2.0 ** ((ev.note + semis - 57) / 12)
                        f1 = f1 * 16777216.0 / PAL_CLOCK
                        d = int(round((f1 - f0) / sfr))
                        d = max(-32768, min(32767, d))
                        data += [0xF1, d & 0xFF, (d >> 8) & 0xFF]
                    if ev.legato:
                        data.append(0xF0)
                if chunk != cur_dur:
                    if chunk <= 64:
                        data.append(0x80 + chunk - 1)
                    else:
                        data += [0x7F, chunk]
                    cur_dur = chunk
                if ev.kind == 'note':
                    data.append(ev.note)
                elif ev.kind == 'rest':
                    data.append(EV_REST)
                else:
                    data.append(EV_TIE)
                first = False
            else:
                if chunk != cur_dur:
                    if chunk <= 64:
                        data.append(0x80 + chunk - 1)
                    else:
                        data += [0x7F, chunk]
                    cur_dur = chunk
                data.append(EV_TIE)
    data.append(0)
    if len(data) > 255:
        fail(pat.where, 'pattern %s is %d bytes (max 255)' %
             (pat.name, len(data)))
    return data


def parse_tune(path):
    tune = Tune(path)
    cur = None
    for where, line in read_lines(path):
        s = line.strip()
        if not s:
            continue
        toks = s.split()
        key = toks[0].lower()
        m = re.match(r'v([123])\s*:(.*)', s)
        if m:
            cur = None
            tune.voices[int(m.group(1))].append((where, m.group(2)))
            continue
        if key == 'tune':
            tune.name = toks[1].upper()
            cur = None
        elif key == 'tempo':
            tune.tempo = parse_int(toks[1], where)
            cur = None
        elif key == 'bar':
            tune.bar = parse_int(toks[1], where)
            cur = None
        elif key == 'pat':
            if len(toks) not in (2, 4) or (len(toks) == 4 and
                                           toks[2] != 'upbeat'):
                fail(where, 'expected "pat NAME [upbeat N16THS]"')
            name = toks[1]
            if name in tune.patterns:
                fail(where, 'duplicate pattern %s' % name)
            cur = Pattern(tune, name, where)
            if len(toks) == 4:
                cur.upbeat = parse_int(toks[3], where) * tune.tempo
            tune.patterns[name] = cur
        elif cur is not None:
            cur.text.append((where, s))
        else:
            fail(where, 'unexpected %r' % s)
    if tune.name is None:
        fail(path, 'missing "tune NAME"')
    for pat in tune.patterns.values():
        parse_pattern(pat, tune)
    return tune


def parse_order(tune, voice):
    """-> list of items: ('pat', name, transpose) / ('loop',) / ('end',)"""
    items = []
    for where, text in tune.voices[voice]:
        for tok in text.split():
            if tok.startswith('@'):
                items.append(('ins', tok[1:], where))
                continue
            if tok.upper() == 'LOOP':
                items.append(('loop', where))
                continue
            if tok.upper() == 'END':
                items.append(('end', where))
                continue
            m = re.fullmatch(r'([A-Za-z_][A-Za-z0-9_]*)([+-]\d+)?'
                             r'(?:\*(\d+))?', tok)
            if not m:
                fail(where, 'bad order item %r' % tok)
            name = m.group(1)
            if name not in tune.patterns:
                fail(where, 'unknown pattern %s' % name)
            tr = int(m.group(2)) if m.group(2) else 0
            if not -32 <= tr <= 31:
                fail(where, 'transpose out of range')
            for _ in range(int(m.group(3) or 1)):
                items.append(('pat', name, tr, where))
    if not items:
        fail(tune.path, 'voice %d has no order list' % voice)
    return items


# ===================================================================
# sound effects
# ===================================================================

SFX_CMDS = {'end': 0, 'wait': 1, 'ctrl': 2, 'adsr': 3, 'note': 4,
            'freq': 5, 'slide': 6, 'pw': 7, 'pwspd': 8, 'lset': 9,
            'loop': 10, 'notew': 11, 'setup': 12, 'sweep': 13,
            'cnote': 14}


class Sfx:
    def __init__(self, name, prio, where):
        self.name = name
        self.prio = prio
        self.where = where
        self.data = []
        self.frames = 0


def parse_sfx(path):
    sfxs = {}
    cur = None
    loop_start = None
    loop_wait = False
    loop_frames = 0
    loop_count = 0
    last_ctrl = None          # byte index of a mergeable 'ctrl'
    for where, line in read_lines(path):
        toks = line.split()
        if not toks:
            continue
        key = toks[0].lower()
        args = toks[1:]
        if key == 'sfx':
            if cur is not None:
                fail(where, 'missing end')
            if len(toks) != 4 or toks[2].lower() != 'prio':
                fail(where, 'expected "sfx NAME prio N"')
            cur = Sfx(toks[1].upper(), parse_int(toks[3], where), where)
            if cur.name in sfxs:
                fail(where, 'duplicate sfx %s' % cur.name)
            sfxs[cur.name] = cur
            continue
        if cur is None:
            fail(where, 'statement outside sfx block')
        d = cur.data
        prev_ctrl = last_ctrl
        last_ctrl = None

        def wait(n):
            nonlocal loop_wait, loop_frames
            if not 1 <= n <= 255:
                fail(where, 'wait must be 1..255')
            if loop_start is not None:
                loop_wait = True
                loop_frames += n
            else:
                cur.frames += n
            return n
        if key == 'end':
            if loop_start is not None:
                fail(where, 'loop without next')
            d.append(SFX_CMDS['end'])
            cur = None
        elif key == 'wait':
            d += [SFX_CMDS['wait'], wait(parse_int(args[0], where))]
        elif key == 'ctrl':
            last_ctrl = len(d)
            d += [SFX_CMDS['ctrl'], parse_hex(args[0], where)]
        elif key == 'adsr':
            a, dd, s, r = (parse_hex(x, where) & 15 for x in args)
            d += [SFX_CMDS['adsr'], a << 4 | dd, s << 4 | r]
        elif key == 'note':
            n = parse_note_name(args[0], where)
            if len(args) > 1 and prev_ctrl is not None and \
                    prev_ctrl == len(d) - 2 and \
                    (loop_start is None or prev_ctrl >= loop_start):
                c = d[-1]           # ctrl + note + wait -> cnote
                del d[-2:]
                d += [SFX_CMDS['cnote'], c, n,
                      wait(parse_int(args[1], where))]
            elif len(args) > 1:
                d += [SFX_CMDS['notew'], n,
                      wait(parse_int(args[1], where))]
            else:
                d += [SFX_CMDS['note'], n]
        elif key == 'setup':
            # setup A D S R PW PWSPD CTRL
            if len(args) != 7:
                fail(where, 'setup A D S R PW PWSPD CTRL')
            a, dd, s_, r = (parse_hex(x, where) & 15 for x in args[:4])
            pw = parse_int(args[4], where)
            if not 0 <= pw <= 0xFFF:
                fail(where, 'pw out of range')
            ps = parse_int(args[5], where) & 0xFF
            d += [SFX_CMDS['setup'], a << 4 | dd, s_ << 4 | r,
                  pw & 0xFF, pw >> 8, ps, parse_hex(args[6], where)]
        elif key == 'freq':
            v = parse_int(args[0], where) & 0xFFFF
            d += [SFX_CMDS['freq'], v & 0xFF, v >> 8]
        elif key == 'slide':
            v = parse_int(args[0], where)
            if not -32768 <= v <= 32767:
                fail(where, 'slide out of range')
            v &= 0xFFFF
            d += [SFX_CMDS['slide'], v & 0xFF, v >> 8]
        elif key == 'sweep':
            # sweep NOTE1 NOTE2 FRAMES [keep]
            n1 = parse_note_name(args[0], where)
            n2 = parse_note_name(args[1], where)
            fr = parse_int(args[2], where)
            f1 = freq_reg(n1, PAL_CLOCK)
            f2 = freq_reg(n2, PAL_CLOCK)
            sl = int(round((f2 - f1) / fr))
            v = sl & 0xFFFF
            d += [SFX_CMDS['sweep'], f1 & 0xFF, f1 >> 8,
                  v & 0xFF, v >> 8, wait(fr)]
            if not (len(args) > 3 and args[3] == 'keep'):
                d += [SFX_CMDS['slide'], 0, 0]
        elif key == 'pw':
            v = parse_int(args[0], where)
            if not 0 <= v <= 0xFFF:
                fail(where, 'pw out of range')
            d += [SFX_CMDS['pw'], v & 0xFF, v >> 8]
        elif key == 'pwspd':
            v = parse_int(args[0], where)
            d += [SFX_CMDS['pwspd'], v & 0xFF]
        elif key == 'loop':
            if loop_start is not None:
                fail(where, 'nested loop')
            loop_count = parse_int(args[0], where)
            if not 2 <= loop_count <= 255:
                fail(where, 'loop count 2..255')
            d += [SFX_CMDS['lset'], loop_count]
            loop_start = len(d)
            loop_wait = False
            loop_frames = 0
        elif key == 'next':
            if loop_start is None:
                fail(where, 'next without loop')
            if not loop_wait:
                fail(where, 'loop body needs a wait')
            d += [SFX_CMDS['loop'], 0]
            back = len(d) - loop_start
            if back > 255:
                fail(where, 'loop body too long')
            d[-1] = back
            cur.frames += loop_frames * loop_count
            loop_start = None
        else:
            fail(where, 'unknown sfx command %r' % key)
    if cur is not None:
        fail(cur.where, 'missing end')
    return sfxs


# ===================================================================
# build
# ===================================================================

class Build:
    def __init__(self):
        self.ids = read_ids()
        self.insts, self.ins_order, self.filters = parse_instruments(
            os.path.join(MUSIC_DIR, 'instruments.txt'))
        self.tunes = []
        for fn in sorted(os.listdir(MUSIC_DIR)):
            if fn.endswith('.txt') and fn not in ('instruments.txt',
                                                  'sfx.txt'):
                self.tunes.append(parse_tune(os.path.join(MUSIC_DIR,
                                                          fn)))
        self.sfx = parse_sfx(os.path.join(MUSIC_DIR, 'sfx.txt'))
        self.report = []

    # ----- instruments / wave table -----
    def build_instruments(self):
        used = set()
        for tune in self.tunes:
            for pat in tune.patterns.values():
                for ev in pat.events:
                    if ev.ins:
                        used.add(ev.ins)
            for v in (1, 2, 3):
                for where, text in tune.voices[v]:
                    for tok in text.split():
                        if tok.startswith('@'):
                            used.add(tok[1:])
        for name in used:
            if name not in self.insts:
                fail('instruments', 'unknown instrument %s' % name)
        names = [n for n in self.ins_order if n in used]
        if len(names) + 1 > MAX_INSTRUMENTS:
            fail('instruments', 'too many instruments')
        self.ins_index = {n: i + 1 for i, n in enumerate(names)}
        self.ins_list = [None] + [self.insts[n] for n in names]
        # wave table: entry 0/1 = silent program for "no instrument"
        wt = [(0x00, 0x00), (0xFF, 0x00)]
        progs = {}
        self.ins_wave = [0]
        for ins in self.ins_list[1:]:
            ent, loop = ins.wave
            key = (tuple(ent), loop)
            if key not in progs:
                start = len(wt)
                wt += ent
                wt.append((0xFF, start + loop))
                progs[key] = start
            self.ins_wave.append(progs[key])
        if len(wt) > 256:
            fail('instruments', 'wave table too long (%d)' % len(wt))
        self.wt = wt
        fnames = sorted({i.filter for i in self.ins_list[1:]
                         if i.filter})
        self.flt_index = {n: i + 1 for i, n in enumerate(fnames)}
        self.flt_list = [None] + [self.filters[n] for n in fnames]

    # ----- tunes -----
    def build_tunes(self):
        self.patterns = []          # unique byte strings
        pat_ids = {}
        self.orders = {}
        by_number = {}
        for tune in self.tunes:
            key = 'MUS_' + tune.name
            if key not in self.ids:
                fail(tune.path, 'no %s in sound_ids.asm' % key)
            tune.number = self.ids[key]
            if tune.number in by_number:
                fail(tune.path, 'tune number used twice')
            by_number[tune.number] = tune
            for pat in tune.patterns.values():
                pat.data = encode_pattern(pat, self.ins_index, tune)
            tune.orders = {}
            lengths = {}
            for v in (1, 2, 3):
                items = parse_order(tune, v)
                obytes, info = self.encode_order(tune, v, items,
                                                 pat_ids)
                tune.orders[v] = obytes
                lengths[v] = info
            intro = {v: lengths[v][0] for v in lengths}
            loop = {v: lengths[v][1] for v in lengths}
            looping = [v for v in lengths if lengths[v][2]]
            if looping and len(looping) != 3:
                fail(tune.path, 'either all voices loop or none')
            if looping:
                if len(set(loop.values())) != 1 or \
                        len(set(intro.values())) != 1:
                    fail(tune.path, 'voice lengths differ: intro %r '
                         'loop %r (frames)' % (intro, loop))
            tune.intro_frames = intro[1]
            tune.loop_frames = loop[1] if looping else 0
            tune.total_frames = max(intro[v] + loop[v] for v in loop)
            tune.loops = bool(looping)
            self.check_ranges(tune)
        count = self.ids.get('MUS_COUNT', 0)
        for n in range(1, count + 1):
            if n not in by_number:
                fail('music', 'tune %d missing' % n)
        self.by_number = by_number

    def encode_order(self, tune, voice, items, pat_ids):
        out = []
        trans = 0
        loop_at = None
        frames_intro = 0
        frames_loop = 0
        ended = False
        force_trans = False
        for it in items:
            if it[0] == 'loop':
                loop_at = len(out)
                force_trans = True
                continue
            if it[0] == 'end':
                ended = True
                break
            if it[0] == 'ins':
                if it[1] not in self.ins_index:
                    fail(it[2], 'unknown instrument %s' % it[1])
                k = items.index(it) + 1
                nxt = items[k] if k < len(items) else None
                if nxt is None or nxt[0] != 'pat' or \
                        tune.patterns[nxt[1]].events[0].kind != 'note' or \
                        tune.patterns[nxt[1]].events[0].legato:
                    fail(it[2], '@%s must be followed by a pattern that '
                         'starts with a plain note' % it[1])
                out.append(0xC0 + self.ins_index[it[1]])
                continue
            _, name, tr, where = it
            pat = tune.patterns[name]
            if tr != trans or force_trans:
                out.append((tr + 0xA0) & 0xFF)
                trans = tr
                force_trans = False
            key = bytes(pat.data)
            if key not in pat_ids:
                pat_ids[key] = len(self.patterns)
                self.patterns.append((key, ['%s.%s' % (tune.name.lower(),
                                                       name)]))
            else:
                lbl = '%s.%s' % (tune.name.lower(), name)
                names = self.patterns[pat_ids[key]][1]
                if lbl not in names:
                    names.append(lbl)
            out.append(pat_ids[key])
            if loop_at is None:
                frames_intro += pat.frames
            else:
                frames_loop += pat.frames
        looping = loop_at is not None and not ended
        if looping:
            if frames_loop == 0:
                fail(tune.path, 'voice %d: empty loop' % voice)
            out += [0xFE, loop_at]
        else:
            out.append(0xFF)
            frames_intro += frames_loop
            frames_loop = 0
        if len(out) > 255:
            fail(tune.path, 'voice %d order list too long' % voice)
        return out, (frames_intro, frames_loop, looping)

    def check_ranges(self, tune):
        for v in (1, 2, 3):
            cur_ins = None
            for it in parse_order(tune, v):
                if it[0] == 'ins':
                    cur_ins = it[1]
                if it[0] != 'pat':
                    continue
                _, name, tr, where = it
                for ev in tune.patterns[name].events:
                    if ev.kind != 'note':
                        continue
                    if ev.ins:
                        cur_ins = ev.ins
                    n = ev.note + tr
                    lo, hi = (0, 0)
                    if cur_ins and cur_ins in self.insts:
                        lo, hi = self.insts[cur_ins].rel_range
                    if n + lo < 0 or n + hi > MAX_NOTE or n < 1:
                        fail(where, '%s voice %d: note %s%+d out of '
                             'range with instrument arpeggio' %
                             (name, v, note_str(ev.note), tr))
        if len(self.patterns) > MAX_PATTERNS:
            fail(tune.path, 'too many patterns')

    # ----- output -----
    def music_asm(self):
        L = []
        L.append('; GENERATED FILE - do not edit by hand.')
        L.append('; Source: music/*.txt   Generator: tools/music.py')
        L.append('; Regenerate with:  python3 tools/music.py')
        L.append('')
        L.append('; ===== song table: order lists for voices 1-3 =====')
        L.append('mus_song_tbl:')
        for n in sorted(self.by_number):
            t = self.by_number[n]
            base = 'mus_ord_%s' % t.name.lower()
            L.append('\t.word %s_1,%s_2,%s_3' % (base, base, base))
        L.append('')
        L.append('; ===== order lists =====')
        for n in sorted(self.by_number):
            t = self.by_number[n]
            loop = ('loops after %.1f s intro, %.1f s loop' %
                    (t.intro_frames / FRAME_HZ, t.loop_frames / FRAME_HZ)
                    if t.loops else 'plays once, %.1f s' %
                    (t.total_frames / FRAME_HZ))
            L.append('; %s (MUS_%s = %d): %s' % (t.name.lower(), t.name,
                                                n, loop))
            for v in (1, 2, 3):
                L.append('mus_ord_%s_%d:' % (t.name.lower(), v))
                L += byte_lines(t.orders[v])
        L.append('')
        L.append('; ===== patterns =====')
        L.append('mus_pat_lo:')
        L += byte_lines(['<mus_pat_%03d' % i
                         for i in range(len(self.patterns))], 8)
        L.append('mus_pat_hi:')
        L += byte_lines(['>mus_pat_%03d' % i
                         for i in range(len(self.patterns))], 8)
        for i, (data, names) in enumerate(self.patterns):
            line = 'mus_pat_%03d:\t\t; %s' % (i, ' '.join(names))
            if len(line.expandtabs(8)) > 80:
                line = 'mus_pat_%03d:\t\t; %s ...' % (i, names[0])
            L.append(line)
            L += byte_lines(list(data))
        L.append('')
        L.append('; ===== instruments (index 0 = silent) =====')
        cols = [
            ('ad', lambda i: i.ad), ('sr', lambda i: i.sr),
            ('wave', None),
            ('pwlo', lambda i: i.pulse[0] & 0xFF),
            ('pwhi', lambda i: i.pulse[0] >> 8),
            ('pwspd', lambda i: i.pulse[1] & 0xFF),
            ('pwmin', lambda i: i.pulse[2]),
            ('pwmax', lambda i: i.pulse[3]),
            ('vdly', lambda i: i.vib[0]),
            ('vspd', lambda i: i.vib[1]),
            ('vdep', lambda i: i.vib[2]),
            ('filt', lambda i: self.flt_index.get(i.filter, 0)),
            ('flags', lambda i: 1 if i.keeppw else 0),
        ]
        names = ' '.join('%d=%s' % (k, i.name) for k, i in
                         enumerate(self.ins_list) if i)
        for line in textwrap.wrap(names, 76):
            L.append('; ' + line)
        for col, fn in cols:
            L.append('mus_ins_%s:' % col)
            if col == 'wave':
                vals = self.ins_wave
            else:
                vals = [0] + [fn(i) for i in self.ins_list[1:]]
            L += byte_lines(vals)
        L.append('')
        L.append('; ===== wave table ($FF in wave: jump to note column) =====')
        L.append('mus_wt_wave:')
        L += byte_lines([w for w, _ in self.wt])
        L.append('mus_wt_note:')
        L += byte_lines([n for _, n in self.wt])
        L.append('')
        L.append('; ===== filter programs (index 0 unused) =====')
        fcols = [('cut', lambda f: f.cut[0]), ('lim', lambda f: f.cut[1]),
                 ('spd', lambda f: f.cut[2] & 0xFF),
                 ('res', lambda f: f.res << 4),
                 ('mode', lambda f: f.mode | 0x0F)]
        for col, fn in fcols:
            L.append('mus_flt_%s:' % col)
            L += byte_lines([0x0F if col == 'mode' else 0] +
                            [fn(f) for f in self.flt_list[1:]])
        L.append('')
        L.append('; ===== note frequencies, C-0..C-8 =====')
        for nm, clock in (('freq', PAL_CLOCK), ('freqn', NTSC_CLOCK)):
            regs = [freq_reg(n, clock) for n in range(MAX_NOTE + 2)]
            L.append('mus_%s_lo:\t\t; %s' % (nm, 'PAL' if nm == 'freq'
                                               else 'NTSC'))
            L += byte_lines([r & 0xFF for r in regs])
            L.append('mus_%s_hi:' % nm)
            L += byte_lines([r >> 8 for r in regs])
        L.append('')
        return '\n'.join(L)

    def sfx_asm(self):
        count = self.ids.get('SFX_COUNT', 0)
        by_num = {}
        for name, s in self.sfx.items():
            key = 'SFX_' + name
            if key not in self.ids:
                fail(s.where, 'no %s in sound_ids.asm' % key)
            by_num[self.ids[key]] = s
        for n in range(1, count + 1):
            if n not in by_num:
                fail('sfx', 'sfx %d missing' % n)
        self.sfx_by_num = by_num
        L = []
        L.append('; GENERATED FILE - do not edit by hand.')
        L.append('; Source: music/sfx.txt   Generator: tools/music.py')
        L.append('; Regenerate with:  python3 tools/music.py')
        L.append('')
        L.append('; ===== priority (higher wins, equal restarts) =====')
        L.append('sfx_prio_tbl:')
        L += byte_lines([0] + [by_num[n].prio
                               for n in range(1, count + 1)])
        L.append('sfx_ptr_lo:')
        L += byte_lines(['0'] + ['<sfx_prg_%s' % by_num[n].name.lower()
                                 for n in range(1, count + 1)], 4)
        L.append('sfx_ptr_hi:')
        L += byte_lines(['0'] + ['>sfx_prg_%s' % by_num[n].name.lower()
                                 for n in range(1, count + 1)], 4)
        L.append('')
        L.append('; ===== programs (see sfx_update in sound.asm) =====')
        for n in range(1, count + 1):
            s = by_num[n]
            L.append('sfx_prg_%s:\t; %d, prio %d, %.2f s' %
                     (s.name.lower(), n, s.prio, s.frames / FRAME_HZ))
            L += byte_lines(s.data)
        L.append('')
        return '\n'.join(L)

    def sizes(self):
        pat = sum(len(d) for d, _ in self.patterns) + 2 * len(self.patterns)
        orders = sum(len(t.orders[v]) for t in self.tunes for v in (1, 2, 3))
        ins = len(self.ins_list) * 13
        wt = 2 * len(self.wt)
        flt = 5 * len(self.flt_list)
        freq = 4 * (MAX_NOTE + 2)
        song = 6 * len(self.tunes)
        sfx = sum(len(s.data) for s in self.sfx.values()) + \
            3 * (len(self.sfx) + 1)
        return dict(patterns=pat, orders=orders, instruments=ins,
                    wavetable=wt, filters=flt, freq=freq, song=song,
                    sfx=sfx)


def dump_tune(b, name):
    tune = None
    for t in b.tunes:
        if t.name.lower() == name.lower():
            tune = t
    if tune is None:
        sys.exit('no tune %s' % name)
    step = tune.tempo
    cols = {}
    for v in (1, 2, 3):
        t = 0
        grid = {}
        for it in parse_order(tune, v):
            if it[0] != 'pat':
                continue
            _, pname, tr, _ = it
            for ev in tune.patterns[pname].events:
                if ev.kind == 'note':
                    grid[t] = note_str(ev.note + tr)
                elif ev.kind == 'rest':
                    grid[t] = ' . '
                t += ev.frames
        cols[v] = grid
    end = max(max(g) if g else 0 for g in cols.values()) + 1
    bar = tune.bar * tune.tempo
    for t in range(0, end, step):
        if t % bar == 0:
            print('---- bar %d' % (t // bar + 1))
        row = ['%-4s' % cols[v].get(t, '') for v in (1, 2, 3)]
        if any(r.strip() for r in row):
            print('%5d  %s' % (t, '  '.join(row)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--check', action='store_true',
                    help='only check that generated files are current')
    ap.add_argument('--dump', metavar='TUNE',
                    help='print a note grid of a tune')
    ap.add_argument('-q', '--quiet', action='store_true')
    args = ap.parse_args()
    try:
        b = Build()
        b.build_instruments()
        b.build_tunes()
        music = b.music_asm()
        sfx = b.sfx_asm()
    except CompileError as e:
        sys.exit('music.py: error: %s' % e)
    if args.dump:
        dump_tune(b, args.dump)
        return
    sz = b.sizes()
    total = sum(sz.values())
    if not args.quiet:
        for n in sorted(b.by_number):
            t = b.by_number[n]
            if t.loops:
                desc = 'intro %5.1f s + loop %5.1f s' % (
                    t.intro_frames / FRAME_HZ, t.loop_frames / FRAME_HZ)
            else:
                desc = 'once  %5.1f s' % (t.total_frames / FRAME_HZ)
            print('tune %d %-11s %s' % (n, t.name, desc))
        for n in sorted(b.sfx_by_num):
            s = b.sfx_by_num[n]
            print('sfx %2d %-16s prio %d  %.2f s  %d bytes' % (
                n, s.name, s.prio, s.frames / FRAME_HZ, len(s.data)))
        print('data bytes: ' + ', '.join('%s %d' % kv for kv in sz.items())
              + ' = %d total' % total)
        print('patterns %d, instruments %d, wave table %d entries' % (
            len(b.patterns), len(b.ins_list) - 1, len(b.wt)))
    if total > DATA_BUDGET:
        sys.exit('music.py: error: data %d bytes exceeds budget %d' %
                 (total, DATA_BUDGET))
    outputs = ((OUT_MUSIC, music), (OUT_SFX, sfx))
    if args.check:
        stale = [p for p, txt in outputs
                 if not os.path.exists(p) or open(p).read() != txt]
        if stale:
            sys.exit('music.py: stale: %s' % ', '.join(
                os.path.relpath(p, ROOT) for p in stale))
        return
    for path, txt in outputs:
        with open(path, 'w') as f:
            f.write(txt)


if __name__ == '__main__':
    main()
