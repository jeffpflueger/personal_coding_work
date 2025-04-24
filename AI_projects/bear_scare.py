# Imports
import os
import cv2
import numpy as np
import time
from threading import Thread
import shutil
from datetime import datetime
from collections import deque
import importlib.util
import RPi.GPIO as GPIO
import psutil

# --- Configuration ---
VIDEO_DURATION = 5  # Seconds to record after detection
VIDEO_DIR = "bear_videos"
MAX_VIDEOS = 100
FRAME_BUFFER_SECONDS = 1
FRAME_RATE = 30
FRAME_BUFFER_SIZE = FRAME_RATE * FRAME_BUFFER_SECONDS
STREAMING_ENABLED = False  # Toggle for streaming window
use_TPU = False

MODEL_NAME = 'Sample_TFLite_model'
GRAPH_NAME = 'detect.tflite'
LABELMAP_NAME = 'labelmap.txt'
min_conf_threshold = 0.5

# GPIO Setup
led = 40
led2 = 11
led_count = 11
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(led2, GPIO.OUT)

# Create video directory
if not os.path.exists(VIDEO_DIR):
    os.makedirs(VIDEO_DIR)

# TensorFlow Lite Setup
CWD_PATH = os.getcwd()
PATH_TO_CKPT = os.path.join(CWD_PATH, MODEL_NAME, GRAPH_NAME)
PATH_TO_LABELS = os.path.join(CWD_PATH, MODEL_NAME, LABELMAP_NAME)

# Load labels
with open(PATH_TO_LABELS, 'r') as f:
    labels = [line.strip() for line in f.readlines()]
if labels[0] == '???':
    del labels[0]

pkg = importlib.util.find_spec('tflite_runtime')
if pkg:
    from tflite_runtime.interpreter import Interpreter
    if use_TPU:
        from tflite_runtime.interpreter import load_delegate
else:
    from tensorflow.lite.python.interpreter import Interpreter
    if use_TPU:
        from tensorflow.lite.python.interpreter import load_delegate

if use_TPU:
    if GRAPH_NAME == 'detect.tflite':
        GRAPH_NAME = 'edgetpu.tflite'

interpreter = Interpreter(model_path=PATH_TO_CKPT)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

height = input_details[0]['shape'][1]
width = input_details[0]['shape'][2]

floating_model = (input_details[0]['dtype'] == np.float32)

# VideoStream Class
class VideoStream:
    def __init__(self, resolution=(640, 480), framerate=30):
        self.stream = cv2.VideoCapture(0)
        self.stream.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.stream.set(3, resolution[0])
        self.stream.set(4, resolution[1])
        (self.grabbed, self.frame) = self.stream.read()
        self.stopped = False

    def start(self):
        Thread(target=self.update, args=()).start()
        return self

    def update(self):
        while not self.stopped:
            (self.grabbed, self.frame) = self.stream.read()

    def read(self):
        return self.frame

    def stop(self):
        self.stopped = True
        self.stream.release()

# Delete oldest videos
def cleanup_old_videos():
    while True:
        usage = psutil.disk_usage(VIDEO_DIR)
        if usage.percent < 85:
            break
        files = sorted([os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR)],
                       key=os.path.getctime)
        if files:
            os.remove(files[0])
            print(f"[INFO] Deleted old video: {files[0]}")
        else:
            break
            
# Record video with pre-buffer
def record_bear_video(videostream, buffered_frames, fps=15):
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = os.path.join(VIDEO_DIR, f'bear_{timestamp}.mp4')
    frame_width = int(videostream.stream.get(3))
    frame_height = int(videostream.stream.get(4))

    fps = 15
    out = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'mp4v'), fps, (frame_width, frame_height))

    # Write buffered frames first
    for bf in buffered_frames:
        annotate_text = f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  BEAR DETECTED! AirHorn Activated"
        cv2.putText(bf, annotate_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        out.write(bf)

    # Record new frames
    start_time = time.time()
    while time.time() - start_time < VIDEO_DURATION:
        frame = videostream.read()
        annotate_text = f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  BEAR DETECTED! AirHorn Activated"
        cv2.putText(frame, annotate_text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
        out.write(frame)

    out.release()
    print(f"[INFO] Video saved: {filename} ")
    print("Actual capture FPS:", videostream.stream.get(cv2.CAP_PROP_FPS))
    cleanup_old_videos()

# Start stream and buffer
videostream = VideoStream(resolution=(800, 480), framerate=FRAME_RATE).start()
frame_buffer = deque(maxlen=FRAME_BUFFER_SIZE)
time.sleep(1)

# Main loop
while True:
    frame = videostream.read()
    frame_buffer.append(frame.copy())

    # Prepare input tensor
    image = cv2.resize(frame, (width, height))
    input_data = np.expand_dims(image, axis=0)
    if floating_model:
        input_data = (np.float32(input_data) - 127.5) / 127.5

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    boxes = interpreter.get_tensor(output_details[0]['index'])[0]
    classes = interpreter.get_tensor(output_details[1]['index'])[0]
    scores = interpreter.get_tensor(output_details[2]['index'])[0]

    detected = False
    for i in range(len(scores)):
        if (scores[i] > min_conf_threshold) and (scores[i] <= 1.0):
            object_name = labels[int(classes[i])]
            if object_name == "bear":
                print("[ALERT] BEAR DETECTED!")
                GPIO.output(led, GPIO.HIGH)
                GPIO.output(led2, GPIO.HIGH)
                led_count = 0
                if not detected:
                    detected = True
                    record_bear_video(videostream, list(frame_buffer))
                    frame_buffer.clear()
                break

    # LED Blinking Logic
    led_count += 1
    if led_count > 10:
        GPIO.output(led, GPIO.LOW)
        GPIO.output(led2, GPIO.LOW)
    elif led_count % 2 == 0:
        GPIO.output(led, GPIO.LOW)
        GPIO.output(led2, GPIO.LOW)
    else:
        GPIO.output(led, GPIO.HIGH)
        GPIO.output(led2, GPIO.HIGH)

    if STREAMING_ENABLED:
        cv2.imshow('Object detector', frame)
        if cv2.waitKey(1) == ord('q'):
            break

# Cleanup
cv2.destroyAllWindows()
videostream.stop()
