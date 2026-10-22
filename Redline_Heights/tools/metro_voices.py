"""Generates the metro announcements with Piper (neural text to speech) and ffmpeg.
Station loudspeaker: voice 'alba' (en_GB, CC BY 4.0), band-limited with a little echo and a two-note chime in front.
Inside the train: voice 'cori' (en_GB, public domain), close and soft, no chime.
Usage: python3 tools/metro_voices.py <piper venv python> <alba.onnx> <cori.onnx> <out dir>"""
import subprocess, sys, os, tempfile

PY, ALBA, CORI, OUT = sys.argv[1:5]
ST = [("atlanta_court", "Atlanta Court"), ("island_plaza", "Island Plaza")]

def say(model, text, wav, scale=1.08, silence=0.45):
    subprocess.run([PY, "-m", "piper", "-m", model, "-f", wav, "--length-scale", str(scale), "--sentence-silence", str(silence)],
                   input=text.encode(), check=True, capture_output=True)

def ff(args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)

def station(name, text, out):
    with tempfile.TemporaryDirectory() as td:
        v = os.path.join(td, "v.wav")
        say(ALBA, text, v)
        # two-note chime, then the announcement through a loudspeaker-like filter
        ff(["-f", "lavfi", "-i", "aevalsrc=0.45*sin(2*PI*784*t)*exp(-3.2*t)+0.2*sin(2*PI*1568*t)*exp(-5*t):d=0.7:s=22050",
            "-f", "lavfi", "-i", "aevalsrc=0.45*sin(2*PI*587*t)*exp(-3.2*t)+0.2*sin(2*PI*1174*t)*exp(-5*t):d=0.9:s=22050",
            "-i", v, "-filter_complex",
            "[2:a]highpass=f=280,lowpass=f=3800,acompressor=threshold=0.05:ratio=4,aecho=0.8:0.75:55|120:0.22|0.12,volume=1.3[vv];"
            "[0:a][1:a][vv]concat=n=3:v=0:a=1,aresample=22050,pan=mono|c0=c0[o]", "-map", "[o]", "-ac", "1", "-c:a", "pcm_s16le", out])

def train(name, text, out):
    with tempfile.TemporaryDirectory() as td:
        v = os.path.join(td, "v.wav")
        say(CORI, text, v, scale=1.12, silence=0.5)
        ff(["-i", v, "-af", "highpass=f=140,lowpass=f=5200,volume=0.75,aecho=0.7:0.6:25:0.12", "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", out])

for i, (slug, nm) in enumerate(ST):
    other = ST[1 - i][1]
    station(slug, f"Attention please. The train from {other} is now arriving at {nm}. Please stand behind the yellow line, and mind the gap.", f"{OUT}/plat_arriving_{slug}.wav")
    station(slug, f"The train to {other} is ready to depart. Please stand clear of the doors.", f"{OUT}/plat_departing_{slug}.wav")
    train(slug, f"We are now arriving at {nm}. This is the last stop. Please take all your belongings with you, and mind the gap when leaving the train.", f"{OUT}/train_arrive_{slug}.wav")
    train(slug, f"Welcome aboard the Redline Metro, line R1. This train is for {other}. The next station is {other}.", f"{OUT}/train_to_{slug}.wav")
train("x", "The doors are closing. Please stand clear.", f"{OUT}/train_doors_closing.wav")
print("done")
