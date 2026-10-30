"""Generates Swara's bundled demo tracks and their cover art.

Every track is synthesized from scratch (tanpura drone, tabla theka and a
melody instrument improvising on a raga), so the audio is original and is
released under CC0 together with this script.

Usage:
    python3 -m venv .venv && .venv/bin/pip install numpy pillow
    .venv/bin/python tool/generate_tracks.py

Requires ffmpeg on PATH for MP3 encoding.
"""

import json
import pathlib
import subprocess
import tempfile
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SR = 44100
ROOT = pathlib.Path(__file__).resolve().parent.parent
AUDIO_DIR = ROOT / "assets" / "audio"
COVER_DIR = ROOT / "assets" / "covers"

# id, title, raga, scale (semitones from Sa), tonic Hz, tempo bpm,
# instrument, tala, cover colours, seed
TRACKS = [
    ("mohanam_dawn", "Mohanam Dawn", "Mohanam", [0, 2, 4, 7, 9], 138.59, 84, "flute", "keherwa", ("#ff9a5a", "#7b2ff7"), 11),
    ("hamsadhwani_flight", "Hamsadhwani Flight", "Hamsadhwani", [0, 2, 4, 7, 11], 146.83, 100, "veena", "keherwa", ("#00c6ff", "#0072ff"), 23),
    ("kalyani_evening", "Kalyani Evening", "Kalyani", [0, 2, 4, 6, 7, 9, 11], 130.81, 72, "santoor", "dadra", ("#f7971e", "#ffd200"), 37),
    ("shivaranjani_rain", "Shivaranjani Rain", "Shivaranjani", [0, 2, 3, 7, 9], 138.59, 66, "flute", "dadra", ("#4b6cb7", "#182848"), 41),
    ("hindolam_moon", "Hindolam Moon", "Hindolam", [0, 3, 5, 8, 10], 123.47, 76, "veena", "keherwa", ("#614385", "#516395"), 53),
    ("bhairavi_river", "Bhairavi River", "Bhairavi", [0, 1, 3, 5, 7, 8, 10], 146.83, 88, "santoor", "keherwa", ("#11998e", "#38ef7d"), 67),
    ("abhogi_lanterns", "Abhogi Lanterns", "Abhogi", [0, 2, 3, 5, 9], 130.81, 96, "flute", "keherwa", ("#ee0979", "#ff6a00"), 71),
    ("madhyamavati_breeze", "Madhyamavati Breeze", "Madhyamavati", [0, 2, 5, 7, 10], 138.59, 80, "veena", "dadra", ("#56ab2f", "#a8e063"), 83),
    ("charukesi_dusk", "Charukesi Dusk", "Charukesi", [0, 2, 4, 5, 7, 8, 10], 123.47, 70, "santoor", "dadra", ("#c94b4b", "#4b134f"), 97),
    ("kharaharapriya_festival", "Kharaharapriya Festival", "Kharaharapriya", [0, 2, 3, 5, 7, 9, 10], 146.83, 112, "veena", "keherwa", ("#f12711", "#f5af19"), 101),
]

ARTIST = "Swara Ensemble"
ALBUM = "Swara Demo Sessions"
INTRO_SECONDS = 14.0
TOTAL_SECONDS = 96.0

TALAS = {
    # One bol per beat; each bol is a list of (offset in beats, stroke).
    "keherwa": [[(0, "dha")], [(0, "ge"), (0.5, "na")], [(0, "na")], [(0, "ti"), (0.5, "na")],
                [(0, "na")], [(0, "ka"), (0.5, "ge")], [(0, "dhi")], [(0, "na"), (0.5, "na")]],
    "dadra": [[(0, "dha")], [(0, "dhi"), (0.5, "na")], [(0, "na")], [(0, "dha")], [(0, "ti"), (0.5, "na")], [(0, "na")]],
}


def semis(f, s):
    return f * 2.0 ** (s / 12.0)


def render_note(freq, dur, instrument, glide_from, rng):
    """Renders one melody note, with a gamaka slide in from the previous pitch."""
    tail = {"flute": 0.15, "veena": 1.2, "santoor": 0.9}[instrument]
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    offset = 0.0 if glide_from is None else 12 * np.log2(glide_from / freq)
    pitch = offset * np.exp(-t / 0.045)
    if instrument == "flute":
        vib_depth = 0.12 * np.clip((t - 0.25) / 0.3, 0, 1)
        pitch = pitch + vib_depth * np.sin(2 * np.pi * 5.2 * t)
    f = freq * 2.0 ** (pitch / 12.0)
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros(n)

    if instrument == "flute":
        for k, a in enumerate([1.0, 0.35, 0.15, 0.06], start=1):
            out += a * np.sin(k * phase)
        breath = rng.standard_normal(n)
        breath = np.convolve(breath, np.ones(12) / 12, mode="same")
        out += 0.08 * breath
        env = np.clip(t / 0.06, 0, 1) * np.clip((dur + tail - t) / tail, 0, 1)
        out *= env * 0.55
    elif instrument == "veena":
        for k in range(1, 10):
            out += (1.0 / k) * np.exp(-t * (1.2 + 0.9 * k)) * np.sin(k * phase)
        out *= np.clip(t / 0.004, 0, 1) * 0.6
        release = np.clip((dur + tail - t) / 0.2, 0, 1)
        out *= release
    else:  # santoor: two slightly detuned strings, bright and fast decay
        phase2 = phase * 1.0025
        for k in range(1, 7):
            amp = (1.0 / k ** 1.2) * np.exp(-t * (2.2 + 1.3 * k))
            out += amp * (np.sin(k * phase) + np.sin(k * phase2))
        out *= np.clip(t / 0.002, 0, 1) * 0.35
    return out


def tanpura(tonic, seconds, rng):
    """Pa-Sa-Sa-Sa(low) drone cycle with jawari-like shimmering harmonics."""
    n = int(seconds * SR)
    out = np.zeros(n)
    strings = [semis(tonic, -5), tonic, tonic, tonic / 2]
    period = 3.4
    pluck_len = int(4.0 * SR)
    t = np.arange(pluck_len) / SR
    pos, i = 0.0, 0
    while pos < seconds:
        f = strings[i % 4] * (1 + rng.normal(0, 0.0004))
        note = np.zeros(pluck_len)
        for k in range(1, 14):
            shimmer = 0.6 + 0.4 * np.sin(2 * np.pi * (0.35 + 0.05 * k) * t + k)
            note += (1.0 / k ** 0.75) * shimmer * np.sin(2 * np.pi * k * f * t)
        note *= np.exp(-t * 0.7) * np.clip(t / 0.01, 0, 1)
        start = int(pos * SR)
        end = min(n, start + pluck_len)
        out[start:end] += note[: end - start]
        pos += period / 4
        i += 1
    return out * 0.05


def tabla_stroke(kind, tonic, rng):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    treble = tonic * 2
    if kind in ("dha", "ge", "dhi"):  # bayan: pitch-dropping bass
        f = 95 * (1 + 0.6 * np.exp(-t / 0.05))
        out += 0.9 * np.exp(-t * 5.5) * np.sin(2 * np.pi * np.cumsum(f) / SR)
    if kind in ("dha", "na", "dhi"):  # dayan: ringing treble tuned to Sa
        decay = 9 if kind != "dhi" else 14
        for k, a in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)]:
            out += 0.45 * a * np.exp(-t * decay * k ** 0.5) * np.sin(2 * np.pi * k * treble * t)
    if kind in ("ti", "ka"):  # damped strokes
        noise = rng.standard_normal(n) * np.exp(-t * 60)
        out += 0.35 * noise + 0.25 * np.exp(-t * 40) * np.sin(2 * np.pi * treble * 1.5 * t)
    out += 0.15 * rng.standard_normal(n) * np.exp(-t * 300)  # attack click
    return out


def tabla(tonic, tala, bpm, start, seconds, rng):
    n = int(seconds * SR)
    out = np.zeros(n)
    beat = 60.0 / bpm
    bols = TALAS[tala]
    strokes = {k: tabla_stroke(k, tonic, rng) for k in ("dha", "ge", "na", "ti", "ka", "dhi")}
    pos, b = start, 0
    while pos < seconds - 1:
        for off, kind in bols[b % len(bols)]:
            s = strokes[kind] * (0.9 + 0.2 * rng.random()) * (1.15 if b % len(bols) == 0 and off == 0 else 1.0)
            i0 = int((pos + off * beat + rng.normal(0, 0.004)) * SR)
            if 0 <= i0 < n:
                end = min(n, i0 + len(s))
                out[i0:end] += s[: end - i0]
        pos += beat
        b += 1
    return out * 0.32


def melody(tonic, scale, bpm, instrument, seconds, rng):
    n = int(seconds * SR)
    out = np.zeros(n)
    beat = 60.0 / bpm
    base = tonic * (4 if instrument == "flute" else 2)
    degrees = len(scale)
    lo, hi = -2, degrees + 4

    def freq_of(d):
        octave, idx = divmod(d, degrees)
        return semis(base, scale[idx] + 12 * octave)

    stable = {0, degrees, scale.index(7) if 7 in scale else 0}
    deg, pos, prev = 0, 1.0, None

    # Alaap: slow, free notes over the drone.
    while pos < INTRO_SECONDS - 2:
        dur = rng.uniform(1.4, 2.8)
        deg = int(np.clip(deg + rng.choice([-2, -1, 1, 1, 2]), lo, degrees + 1))
        f = freq_of(deg)
        note = render_note(f, dur, instrument, prev, rng) * 0.8
        i0 = int(pos * SR)
        out[i0:i0 + len(note)] += note[: max(0, n - i0)]
        prev, pos = f, pos + dur + rng.uniform(0.1, 0.6)

    # Gat: rhythmic phrases that settle on stable notes.
    pos = INTRO_SECONDS + 4 * beat
    rhythms = [[1, 1, 2], [0.5, 0.5, 1, 2], [1, 0.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2], [2, 1, 1], [1.5, 0.5, 2]]
    motif = None
    while pos < seconds - 6:
        rhythm = rhythms[rng.integers(len(rhythms))]
        steps = motif if motif is not None and rng.random() < 0.35 else [int(rng.choice([-2, -1, -1, 1, 1, 2, 3])) for _ in rhythm]
        motif = steps
        for i, (r, s) in enumerate(zip(rhythm, steps)):
            deg = int(np.clip(deg + s, lo, hi))
            if i == len(rhythm) - 1 and deg % degrees not in stable:
                deg += -1 if deg > 0 else 1
            dur = r * beat
            f = freq_of(deg)
            note = render_note(f, dur * 0.95, instrument, prev if r <= 1 else None, rng)
            i0 = int(pos * SR)
            if i0 < n:
                out[i0:i0 + len(note)] += note[: n - i0]
            prev, pos = f, pos + dur
        pos += beat * rng.choice([0, 0.5, 1, 2], p=[0.35, 0.25, 0.25, 0.15])
    return out * 0.5


def reverb(x, rng, seconds=1.8):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * 3.2)
    ir[0] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x)]


def mix_track(spec):
    _, _, _, scale, tonic, bpm, instrument, tala, _, seed = spec
    rng = np.random.default_rng(seed)
    drone = tanpura(tonic, TOTAL_SECONDS, rng)
    perc = tabla(tonic, tala, bpm, INTRO_SECONDS, TOTAL_SECONDS, rng)
    mel = melody(tonic, scale, bpm, instrument, TOTAL_SECONDS, rng)

    left = 0.9 * drone + 0.8 * perc + 1.0 * mel
    right = 1.0 * drone + 1.0 * perc + 0.85 * mel
    wet_l, wet_r = reverb(left, rng), reverb(right, rng)
    stereo = np.stack([left + 0.35 * wet_l, right + 0.35 * wet_r], axis=1)

    t = np.arange(len(stereo)) / SR
    fade = np.clip(t / 1.5, 0, 1) * np.clip((TOTAL_SECONDS - t) / 5.0, 0, 1)
    stereo *= fade[:, None]
    stereo /= np.max(np.abs(stereo)) / 0.89
    return stereo


def write_mp3(stereo, spec, path):
    track_id, title, raga, *_ = spec
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = pathlib.Path(tmp) / "track.wav"
        with wave.open(str(wav_path), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((stereo * 32767).astype("<i2").tobytes())
        subprocess.run([
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
            "-codec:a", "libmp3lame", "-b:a", "128k",
            "-metadata", f"title={title}", "-metadata", f"artist={ARTIST}",
            "-metadata", f"album={ALBUM}", "-metadata", f"genre=Indian Classical",
            "-metadata", f"comment=Raga {raga}. Synthesized by tool/generate_tracks.py. CC0.",
            str(path),
        ], check=True)


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def load_font(size):
    for name in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                 "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def write_cover(spec, path, size=512):
    _, title, raga, scale, *_ , colours, seed = spec
    c1, c2 = (np.array(hex_rgb(c)) for c in colours)
    yy, xx = np.mgrid[0:size, 0:size] / size
    mix = np.clip((xx + yy) / 2, 0, 1)[..., None]
    img = Image.fromarray((c1 * (1 - mix) + c2 * mix).astype(np.uint8))

    # Concentric "sound rings", one per note of the raga.
    rings = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(rings)
    rng = np.random.default_rng(seed)
    cx, cy = size * rng.uniform(0.55, 0.8), size * rng.uniform(0.2, 0.45)
    for i, s in enumerate(scale):
        r = size * (0.12 + 0.07 * i + s * 0.004)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 70 + 12 * i), width=3)
    rings = rings.filter(ImageFilter.GaussianBlur(0.6))
    img = Image.alpha_composite(img.convert("RGBA"), rings)

    d = ImageDraw.Draw(img)
    d.text((36, size - 150), raga.upper(), font=load_font(30), fill=(255, 255, 255, 200))
    words = title.split(" ", 1)
    d.text((36, size - 110), words[-1], font=load_font(64), fill=(255, 255, 255, 255))
    img.convert("RGB").save(path, quality=88)


def write_icon(path, size=1024):
    yy, xx = np.mgrid[0:size, 0:size] / size
    mix = np.clip((xx + yy) / 2, 0, 1)[..., None]
    c1, c2 = np.array(hex_rgb("#ff7a59")), np.array(hex_rgb("#6a1fd1"))
    img = Image.fromarray((c1 * (1 - mix) + c2 * mix).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    for i, h in enumerate([0.18, 0.34, 0.52, 0.34, 0.18]):  # waveform bars
        x = cx + (i - 2) * size * 0.12
        half = size * h / 2
        d.rounded_rectangle([x - size * 0.035, cy - half, x + size * 0.035, cy + half], radius=size * 0.035, fill=(255, 255, 255, 240))
    img.convert("RGB").save(path)


def main():
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    COVER_DIR.mkdir(parents=True, exist_ok=True)
    catalog = []
    for spec in TRACKS:
        track_id, title, raga, scale, tonic, bpm, instrument, tala, *_ = spec
        print(f"Rendering {title} ({raga}, {instrument}, {tala}, {bpm} bpm)")
        write_mp3(mix_track(spec), spec, AUDIO_DIR / f"{track_id}.mp3")
        write_cover(spec, COVER_DIR / f"{track_id}.jpg")
        catalog.append({
            "id": track_id, "title": title, "artist": ARTIST, "album": ALBUM,
            "raga": raga, "instrument": instrument, "tala": tala.capitalize(), "bpm": bpm,
            "audio": f"assets/audio/{track_id}.mp3", "cover": f"assets/covers/{track_id}.jpg",
        })
    (ROOT / "assets" / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")
    (ROOT / "assets" / "icon").mkdir(exist_ok=True)
    write_icon(ROOT / "assets" / "icon" / "app_icon.png")


if __name__ == "__main__":
    main()
