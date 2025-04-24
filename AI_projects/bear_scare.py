# Imports
import os
import cv2
import numpy as np
import time
from threading import Thread
from collections import deque
import importlib.util
import shutil
from datetime import datetime
import RPi.GPIO as GPIO

# ========== USER SETTINGS ==========
MODEL_NAME = 'Sample_TFLite_model'
GRAPH_NAME = 'detect.tflite'
LABELMAP_NAME = 'labelmap.txt'
use_TPU = False
min_conf_threshold = 0.5
VIDEO_DURATION = 7  # seconds total
PRE_RECORD_SECONDS = 2
STREAMING_ENABLED = False
VIDEO_DIR = "bear_videos"
MAX_DISK_USAGE_PERCENT = 85
FRAME_WIDTH = 640
FRAME_HEIGHT = 480
FPS = 30

# GPIO setup
led = 40
led2 = 11
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(led2, GPIO.OUT)

# Create video folder if needed
if not os.path.exists(VIDEO_DIR):
    os.makedirs(VIDEO_DIR)

# Get current path and build model/label paths
CWD_PATH = os.getcwd()
PATH_TO_CKPT = os.path.join(CWD_PATH, MODEL_NAME, GRAPH_NAME)
PATH_TO_LABELS = os.path.join(CWD_PATH, MODEL_NAME, LABELMAP_NAME)

# Load label map
with open(PATH_TO_LABELS, 'r') as f:
    labels = [line.strip() for line in f.readlines()]

# Import TFLite Interpreter
pkg = importlib.util.find_spec('tflite_runtime')
if pkg:
    from tflite_runtime.interpreter import Interpreter
    if use_TPU:
        from tflite_runtime.interpreter import load_delegate
else:
    from tensorflow.lite.python.interpreter import Interpreter
    if use_TPU:
        from tensorflow.lite.python.interpreter import load_delegate

# Load interpreter
if use_TPU:
    interpreter = Interpreter(model_path=PATH_TO_CKPT,
                              experimental_delegates=[load_delegate('libedgetpu.so.1.0')])
else:
    interpreter = Interpreter(model_path=PATH_TO_CKPT)
interpreter.allocate_tensors()

# Get model details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
height = input_details[0]['shape'][1]
width = input_details[0]['shape'][2]
floating_model = (input_details[0]['dtype'] == np.float32)

# VideoStream class
class VideoStream:
    def __init__(self, resolution=(FRAME_WIDTH, FRAME_HEIGHT), framerate=FPS):
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
        return self.frame.copy()

    def stop(self):
        self.stopped = True
        self.stream.release()

# Delete videos if disk usage too high
def cleanup_old_videos():
    usage = shutil.disk_usage(VIDEO_DIR)
    percent = usage.used / usage.total * 100
    if percent < MAX_DISK_USAGE_PERCENT:
        return
    files = sorted([os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR)],
                   key=os.path.getctime)
    while percent > (MAX_DISK_USAGE_PERCENT - 5) and files:
        os.remove(files[0])
        files.pop(0)
        usage = shutil.disk_usage(VIDEO_DIR)
        percent = usage.used / usage.total * 100

# Record video function
def record_bear_video(buffered_frames, videostream):
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = os.path.join(VIDEO_DIR, f'bear_{timestamp}.avi')
    frame_width = int(videostream.stream.get(3))
    frame_height = int(videostream.stream.get(4))
    out = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'XVID'), FPS, (frame_width, frame_height))

    # Write buffered frames (pre-detection)
    for frame in buffered_frames:
        out.write(frame)

    # Record live frames post-detection
    start_time = time.time()
    while time.time() - start_time < (VIDEO_DURATION - PRE_RECORD_SECONDS):
        frame = videostream.read()
        out.write(frame)
        time.sleep(1 / FPS)

    out.release()
    print(f"[INFO] Video saved: {filename}")
    cleanup_old_videos()

# Start video stream
videostream = VideoStream().start()
time.sleep(1)

# Frame buffer and detection loop
frame_buffer = deque(maxlen=int(PRE_RECORD_SECONDS * FPS))
recording = False

try:
    while True:
        frame = videostream.read()
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        imH, imW, _ = frame.shape
        frame_resized = cv2.resize(frame_rgb, (width, height))
        input_data = np.expand_dims(frame_resized, axis=0)

        # Normalize if needed
        if floating_model:
            input_data = (np.float32(input_data) - 127.5) / 127.5

        # Set tensor and run inference
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()

        # Extract detection results
        boxes = interpreter.get_tensor(output_details[0]['index'])[0]
        classes = interpreter.get_tensor(output_details[1]['index'])[0]
        scores = interpreter.get_tensor(output_details[2]['index'])[0]

        # Add frame to buffer
        frame_buffer.append(frame.copy())

        # Detection check
        bear_detected = False
        for i in range(len(scores)):
            if (scores[i] > min_conf_threshold) and (labels[int(classes[i])] == 'bear'):
                bear_detected = True
                break

        if bear_detected and not recording:
            print("[ALERT] Bear Detected!")
            GPIO.output(led, GPIO.HIGH)
            GPIO.output(led2, GPIO.HIGH)
            recording = True
            Thread(target=lambda: (record_bear_video(list(frame_buffer), videostream), setattr(globals(), 'recording', False))).start()

        # Toggle LED off after short delay
        if not bear_detected:
            GPIO.output(led, GPIO.LOW)
            GPIO.output(led2, GPIO.LOW)

        # Optionally show stream
        if STREAMING_ENABLED:
            cv2.imshow('Object detector', frame)
            if cv2.waitKey(1) == ord('q'):
                break

except KeyboardInterrupt:
    pass

# Cleanup
videostream.stop()
cv2.destroyAllWindows()
GPIO.cleanup()
