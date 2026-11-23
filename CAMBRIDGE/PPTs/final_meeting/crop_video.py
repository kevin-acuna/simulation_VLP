"""Digital-twin screen recording -> 16:9, 1920 x 1080 intermediate (large, H.264 via Media Foundation).

Keeps the top 2560 x 1440 of the 2560 x 1600 recording: drops the browser-preview bar ("Send element"),
the app toolbar and the status chip. Compress the result with compress_video.ps1 (~3 MB).
Run: py -3.14 crop_video.py <out.mp4>   (OpenCV)
"""
import sys
import time
from pathlib import Path

import cv2

# ---- hyperparameters --------------------------------------------------------------------------
SRC = Path(__file__).resolve().parents[2] / "photos_videos/simulation_video.mp4"
OUT_W, OUT_H = 1920, 1080
CROP_H = 1440
# -------------------------------------------------------------------------------------------------


def main(dst):
    cap = cv2.VideoCapture(str(SRC))
    fps = cap.get(cv2.CAP_PROP_FPS)
    wr = cv2.VideoWriter(dst, cv2.CAP_MSMF, cv2.VideoWriter_fourcc(*"H264"), fps, (OUT_W, OUT_H))
    if not wr.isOpened():
        raise RuntimeError("Media Foundation H.264 writer not available")
    n, t0 = 0, time.time()
    while True:
        ok, f = cap.read()
        if not ok:
            break
        wr.write(cv2.resize(f[:CROP_H], (OUT_W, OUT_H), interpolation=cv2.INTER_AREA))
        n += 1
    wr.release()
    print(f"{n} frames at {fps} fps -> {dst} ({time.time() - t0:.0f} s)")


if __name__ == "__main__":
    main(sys.argv[1])
