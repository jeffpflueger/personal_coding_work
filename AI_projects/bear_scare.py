# Bear Scare Tensorflow-trained Classifier and OpenCV with Video Recording #

import os
import argparse
import cv2
import numpy as np
import sys
import time
from threading import Thread, Lock
import importlib.util
import RPi.GPIO as GPIO
from datetime import datetime
from queue import Queue
import shutil

# Video settings
VIDEO_DURATION = 15  # seconds
VIDEO_DIR = os.path.join(os.getcwd(), "bear_videos")
DISK_USAGE_THRESHOLD = 85  # percent
os.makedirs(VIDEO_DIR, exist_ok=True)

# GPIO setup
led = 40
led2 = 11
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(led2, GPIO.OUT)

# Frame queue for recording
frame_queue = Queue()
recording_lock = Lock()
recording = False

# VideoStream class
class VideoStream:
    def __init__(self, resolution=(640, 480), framerate=30):
        self.stream = cv2.VideoCapture(0)
        self.stream.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.stream.set(3, resolution[0])
        self.stream.set(4, resolution[1])
        (self.grabbed, self.frame) = self.stream.read()
        self.stopped = False

    def start(self):
        Thread(target=self.update, args=(), daemon=True).start()
        return self

    def update(self):
        while not self.stopped:
            (self.grabbed, self.frame) = self.stream.read()

    def read(self):
        return self.frame

    def stop(self):
        self.stopped = True
        self.stream.release()

# Cleanup old videos based on disk space

def cleanup_old_videos():
    total, used, free = shutil.disk_usage(VIDEO_DIR)
    percent_used = used / total * 100

    video_files = sorted(
        [os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR) if f.endswith('.mp4')],
        key=os.path.getctime
    )

    while percent_used > DISK_USAGE_THRESHOLD and video_files:
        os.remove(video_files[0])
        video_files.pop(0)
        total, used, free = shutil.disk_usage(VIDEO_DIR)
        percent_used = used / total * 100

# Record video from queue in background

def record_bear_video_async():
    def _record():
        global recording
        with recording_lock:
            if recording:
                return
            recording = True

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = os.path.join(VIDEO_DIR, f'bear_{timestamp}.mp4')
        frame_width = 640
        frame_height = 480
        out = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'X264'), 15, (frame_width, frame_height))

        start_time = time.time()
        while time.time() - start_time < VIDEO_DURATION:
            if not frame_queue.empty():
                frame = frame_queue.get()
                if frame is not None:
                    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                    cv2.putText(frame, "Bear Scare Horn Activated", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2, cv2.LINE_AA)
                    cv2.putText(frame, now, (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2, cv2.LINE_AA)
                    out.write(frame)
            else:
                time.sleep(0.01)

        out.release()
        cleanup_old_videos()
        with recording_lock:
            recording = False

    Thread(target=_record, daemon=True).start()

# Start video stream
videostream = VideoStream().start()
time.sleep(1)

while True:
    frame = videostream.read()
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    frame_resized = cv2.resize(frame_rgb, (300, 300))
    input_data = np.expand_dims(frame_resized, axis=0)

    # Simulate detection logic (replace this with actual TensorFlow Lite detection)
    detected = np.random.rand() > 0.98  # Simulated detection

    if detected and not recording:
        GPIO.output(led, GPIO.HIGH)
        GPIO.output(led2, GPIO.HIGH)
        record_bear_video_async()
        print("Bear detected! Starting video recording...")
        time.sleep(2)  # Keep horn on briefly
        GPIO.output(led, GPIO.LOW)
        GPIO.output(led2, GPIO.LOW)

    # Add current frame to the recording queue
    if recording:
        frame_queue.put(frame.copy())

    # Draw streaming text
    cv2.putText(frame, "Bear Scare Monitoring", (10, 460), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    cv2.imshow('Object detector', frame)

    if cv2.waitKey(1) == ord('q'):
        break

videostream.stop()
cv2.destroyAllWindows()
GPIO.cleanup()
