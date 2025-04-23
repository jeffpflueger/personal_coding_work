# Imports
import os
import cv2
import numpy as np
import time
import importlib.util
from threading import Thread
import shutil
from datetime import datetime
import RPi.GPIO as GPIO

# Settings
VIDEO_DURATION = 15  # seconds
VIDEO_DIR = "bear_videos"
MAX_VIDEOS = 100
stream_display = False  # Toggle streaming display

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

# TFLite Setup
use_TPU = False
MODEL_NAME = 'Sample_TFLite_model'
GRAPH_NAME = 'detect.tflite'
LABELMAP_NAME = 'labelmap.txt'
min_conf_threshold = 0.5

CWD_PATH = os.getcwd()
PATH_TO_CKPT = os.path.join(CWD_PATH, MODEL_NAME, GRAPH_NAME)
PATH_TO_LABELS = os.path.join(CWD_PATH, MODEL_NAME, LABELMAP_NAME)

pkg = importlib.util.find_spec('tflite_runtime')
if pkg:
    from tflite_runtime.interpreter import Interpreter
    if use_TPU:
        from tflite_runtime.interpreter import load_delegate
else:
    from tensorflow.lite.python.interpreter import Interpreter
    if use_TPU:
        from tensorflow.lite.python.interpreter import load_delegate

if use_TPU and GRAPH_NAME == 'detect.tflite':
    GRAPH_NAME = 'edgetpu.tflite'

# Load label map
with open(PATH_TO_LABELS, 'r') as f:
    labels = [line.strip() for line in f.readlines()]
if labels[0] == '???':
    del labels[0]

# Load model
if use_TPU:
    interpreter = Interpreter(model_path=PATH_TO_CKPT,
                              experimental_delegates=[load_delegate('libedgetpu.so.1.0')])
else:
    interpreter = Interpreter(model_path=PATH_TO_CKPT)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
height = input_details[0]['shape'][1]
width = input_details[0]['shape'][2]
floating_model = input_details[0]['dtype'] == np.float32

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

# Video Cleanup
def cleanup_old_videos():
    files = sorted([os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR)],
                   key=os.path.getctime)
    while len(files) > MAX_VIDEOS:
        os.remove(files[0])
        files.pop(0)

# Video Recording
def record_bear_video(videostream, fps=30):
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = os.path.join(VIDEO_DIR, f'bear_{timestamp}.avi')
    frame_width = int(videostream.stream.get(3))
    frame_height = int(videostream.stream.get(4))

    out = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'XVID'), fps, (frame_width, frame_height))
    start_time = time.time()
    while time.time() - start_time < VIDEO_DURATION:
        frame = videostream.read()
        out.write(frame)
        time.sleep(1 / fps)
    out.release()
    print(f"[INFO] Video saved: {filename}")
    cleanup_old_videos()

# Start camera stream
videostream = VideoStream(resolution=(800, 480), framerate=30).start()
time.sleep(1)

# Detection Loop
while True:
    frame = videostream.read()
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    imH, imW, _ = frame.shape
    image_resized = cv2.resize(frame_rgb, (width, height))
    input_data = np.expand_dims(image_resized, axis=0)

    if floating_model:
        input_data = (np.float32(input_data) - 127.5) / 127.5

    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()

    boxes = interpreter.get_tensor(output_details[0]['index'])[0]
    classes = interpreter.get_tensor(output_details[1]['index'])[0]
    scores = interpreter.get_tensor(output_details[2]['index'])[0]

    for i in range(len(scores)):
        if scores[i] > min_conf_threshold:
            object_name = labels[int(classes[i])]
            if object_name == "bear" and int(scores[i] * 100) > 55:
                print("[ALERT] BEAR DETECTED!")
                GPIO.output(led, GPIO.HIGH)
                GPIO.output(led2, GPIO.HIGH)
                led_count = 0
                record_bear_video(videostream)

    # LED blinking logic
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

    # Toggleable display
    if stream_display:
        cv2.imshow('Object detector', frame)
        if cv2.waitKey(1) == ord('q'):
            break

# Cleanup
cv2.destroyAllWindows()
videostream.stop()
