"""Generates the placeholder sound effects in audio/ from nothing but maths.

Run from the project folder:  python3 tools/make_sounds.py
Needs numpy. Every sound is synthesised, so there are no recordings to
license. They are stand-ins: replace any of them with a real recording of
the same file name and the game will use it.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(1768)


def save(name, samples, peak=0.8):
    samples = np.asarray(samples, dtype=np.float64)
    top = np.max(np.abs(samples))
    if top > 0:
        samples = samples / top * peak
    data = (samples * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def lowpass(x, cutoff):
    """One-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = a * acc + (1 - a) * v
        out[i] = acc
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return highpass(lowpass(x, high), low)


def fade(x, seconds_in=0.01, seconds_out=0.05):
    n_in = max(1, int(seconds_in * RATE))
    n_out = max(1, int(seconds_out * RATE))
    x = x.copy()
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def make_loop(x, overlap_seconds=1.0):
    """Cross-fades the tail into the head so the sound repeats without a click."""
    n = int(overlap_seconds * RATE)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    ramp = np.linspace(0, 1, n)
    return np.concatenate([head * ramp + tail * (1 - ramp), body])


def pipe(notes, breath=0.06):
    """A boatswain's call: a small shrill whistle. `notes` is a list of
    (seconds, start_hz, end_hz, warble) pieces played one after another."""
    parts = []
    phase = 0.0
    for seconds, f0, f1, warble in notes:
        n = int(seconds * RATE)
        if f0 <= 0:
            parts.append(np.zeros(n))
            continue
        tt = np.arange(n) / RATE
        freq = np.linspace(f0, f1, n)
        if warble:
            freq = freq * (1 + 0.035 * np.sign(np.sin(2 * np.pi * 14 * tt)))
        ph = phase + 2 * np.pi * np.cumsum(freq) / RATE
        phase = ph[-1]
        tone = np.sin(ph) + 0.18 * np.sin(2 * ph)
        tone += breath * highpass(rng.standard_normal(n), 2500) * 4
        parts.append(fade(tone, 0.015, 0.03))
    return np.concatenate(parts)


LOW, HIGH = 2250.0, 3350.0


def sea_loop():
    seconds = 12.0
    tt = t(seconds)
    wash = lowpass(noise(seconds), 900)
    hiss = bandpass(noise(seconds), 1500, 5000)
    # Swells that rise and fall, at periods that divide the loop length.
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * tt / 4.0 - 1.0) ** 2
    surge = 0.5 + 0.5 * np.sin(2 * np.pi * tt / 6.0 + 0.7)
    rumble = lowpass(noise(seconds), 120) * 3.0
    return make_loop(wash * swell + 0.35 * hiss * surge * swell + rumble * 0.6)


def wind_loop():
    seconds = 12.0
    tt = t(seconds)
    body = bandpass(noise(seconds), 200, 1400)
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * tt / 6.0) * np.sin(2 * np.pi * tt / 4.0 + 1.3)
    # A thin whistle in the rigging that drifts in pitch.
    whistle_f = 620 + 90 * np.sin(2 * np.pi * tt / 6.0) + 40 * np.sin(2 * np.pi * tt / 2.4)
    whistle = np.sin(2 * np.pi * np.cumsum(whistle_f) / RATE)
    whistle *= bandpass(noise(seconds), 2, 12) * 6
    return make_loop(body * gust + 0.12 * whistle * gust)


def creak(base, seconds, wobble):
    """Timber working: a rough, slow, groaning tone."""
    tt = t(seconds)
    freq = base * (1 + 0.25 * np.sin(2 * np.pi * wobble * tt) + 0.5 * tt / seconds)
    ph = 2 * np.pi * np.cumsum(freq) / RATE
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    stick = (np.sin(2 * np.pi * 23 * tt) > 0.2).astype(float)
    x = lowpass(saw * (0.5 + 0.5 * stick), 1400) + 0.1 * lowpass(noise(seconds), 600)
    env = np.sin(np.pi * tt / seconds) ** 1.5
    return fade(x * env, 0.03, 0.1)


def bell(strikes):
    """A ship's bell struck `strikes` times, in pairs as at sea."""
    def one():
        tt = t(1.6)
        partials = [(1.0, 1.0, 1.2), (2.0, 0.6, 1.8), (2.76, 0.45, 2.4),
                    (5.4, 0.25, 3.5), (8.9, 0.12, 5.0)]
        x = sum(a * np.sin(2 * np.pi * 760 * m * tt) * np.exp(-d * tt)
                for m, a, d in partials)
        return fade(x, 0.002, 0.2)
    gaps = []
    for i in range(strikes):
        gaps.append(0.35 if i % 2 == 0 else 0.9)
    total = int((sum(gaps) + 1.7) * RATE)
    out = np.zeros(total)
    pos = 0
    for i in range(strikes):
        s = one()
        out[pos:pos + len(s)] += s
        pos += int(gaps[i] * RATE)
    return out


def splash():
    seconds = 0.9
    tt = t(seconds)
    plunge = lowpass(noise(seconds), 500) * np.exp(-9 * tt) * 2.5
    spray = bandpass(noise(seconds), 1200, 6000) * np.exp(-4 * tt) * (1 - np.exp(-60 * tt))
    return fade(plunge + 0.6 * spray, 0.002, 0.2)


def sail_thump():
    """Canvas filling: a soft boom and a flutter."""
    seconds = 1.1
    tt = t(seconds)
    boom = np.sin(2 * np.pi * (70 - 25 * tt) * tt) * np.exp(-6 * tt)
    flutter = lowpass(noise(seconds), 700) * np.exp(-3 * tt) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * tt))
    return fade(boom + 0.7 * flutter, 0.004, 0.2)


def sail_flap():
    """Sails shivering: a few slack slaps."""
    seconds = 1.4
    tt = t(seconds)
    slaps = np.zeros_like(tt)
    for at in (0.0, 0.33, 0.52, 0.9):
        d = np.clip(tt - at, 0, None)
        slaps += (tt >= at) * np.exp(-14 * d)
    return fade(lowpass(noise(seconds), 1100) * slaps, 0.004, 0.2)


def grounding():
    seconds = 2.2
    tt = t(seconds)
    thud = np.sin(2 * np.pi * 45 * tt) * np.exp(-3 * tt) * 2.0
    grind = bandpass(noise(seconds), 150, 1800) * np.exp(-1.6 * tt)
    grind *= 0.5 + 0.5 * (np.sin(2 * np.pi * 17 * tt) > 0)
    return fade(thud + grind, 0.003, 0.4)


def paper():
    seconds = 0.45
    tt = t(seconds)
    return fade(bandpass(noise(seconds), 1800, 7000) * np.sin(np.pi * tt / seconds) ** 2, 0.02, 0.08)


def tick():
    tt = t(0.09)
    return fade(np.sin(2 * np.pi * 900 * tt) * np.exp(-60 * tt)
                + 0.5 * lowpass(noise(0.09), 2500) * np.exp(-90 * tt), 0.001, 0.02)


def footstep():
    """A shoe on a wooden deck: a dull knock."""
    tt = t(0.16)
    knock = np.sin(2 * np.pi * (150 - 300 * tt) * tt) * np.exp(-38 * tt)
    scuff = lowpass(noise(0.16), 1800) * np.exp(-55 * tt)
    return fade(knock + 0.5 * scuff, 0.001, 0.04)


def chain():
    """The anchor cable running out."""
    seconds = 2.4
    tt = t(seconds)
    rattle = bandpass(noise(seconds), 600, 4000) * (np.sin(2 * np.pi * 26 * tt) > 0.3)
    env = np.clip(tt / 0.2, 0, 1) * np.exp(-0.6 * tt)
    end_splash = np.concatenate([np.zeros(int(1.5 * RATE)), splash()])[:len(tt)]
    end_splash = np.pad(end_splash, (0, len(tt) - len(end_splash)))
    return fade(rattle * env + 1.2 * end_splash, 0.01, 0.3)


def main():
    os.makedirs(OUT, exist_ok=True)
    save("sea_loop", sea_loop(), 0.7)
    save("wind_loop", wind_loop(), 0.7)
    save("creak_1", creak(95, 1.3, 1.1), 0.5)
    save("creak_2", creak(130, 0.9, 1.7), 0.5)
    save("creak_3", creak(70, 1.8, 0.7), 0.5)
    save("bell_2", bell(2))
    save("bell_8", bell(8))
    save("splash", splash())
    save("sail_thump", sail_thump())
    save("sail_flap", sail_flap(), 0.6)
    save("grounding", grounding(), 0.9)
    save("paper", paper(), 0.4)
    save("tick", tick(), 0.4)
    save("anchor", chain())
    save("footstep", footstep(), 0.5)
    # Boatswain's calls. Real calls were a language of their own; these are
    # simple stand-ins with the right kind of sound, not the true signals.
    save("pipe_make_sail", pipe([(0.25, LOW, LOW, False), (0.5, LOW, HIGH, False),
                                 (0.5, HIGH, HIGH, True)]), 0.5)
    save("pipe_shorten_sail", pipe([(0.3, HIGH, HIGH, False), (0.6, HIGH, LOW, False),
                                    (0.3, LOW, LOW, False)]), 0.5)
    save("pipe_helm", pipe([(0.12, HIGH, HIGH, False), (0.07, 0, 0, False),
                            (0.12, HIGH, HIGH, False)]), 0.45)
    save("pipe_attention", pipe([(0.2, LOW, LOW, False), (0.9, HIGH, HIGH, True),
                                 (0.25, HIGH, LOW, False)]), 0.5)
    save("pipe_still", pipe([(1.0, HIGH, HIGH, False)]), 0.45)
    for name in sorted(os.listdir(OUT)):
        if name.endswith(".wav"):
            with wave.open(os.path.join(OUT, name)) as f:
                print("%-22s %5.2fs" % (name, f.getnframes() / f.getframerate()))


if __name__ == "__main__":
    main()
