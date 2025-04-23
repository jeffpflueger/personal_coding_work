# Bear Scare Tensorflow-trained Classifier with Local Video Saving and Email Alerts #

import os
import argparse
import cv2
import numpy as np
import sys
import time
from threading import Thread
import importlib.util
import RPi.GPIO as GPIO
from collections import deque
from datetime import datetime, timedelta
from pathlib import Path
import smtplib
from email.message import EmailMessage

# Email Configuration
EMAIL_ADDRESS = 'your_email@gmail.com'        # <-- Your email here
EMAIL_PASSWORD = 'your_email_password'        # <-- App Password recommended
EMAIL_RECIPIENT = 'jeff@jeffpflueger.com'
SMTP_SERVER = 'smtp.gmail.com'
SMTP_PORT = 587

# Directory to store bear videos
CLIP_DIR = Path('./bear_clips')
CLIP_DIR.mkdir(exist_ok=True)
CLIP_DURATION_SEC = 30
FPS = 30
MAX_FRAMES = CLIP_DURATION_SEC * FPS
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
video_buffer = deque(maxlen=MAX_FRAMES)

# Email function
def send_email_with_attachment(filepath):
    msg = EmailMessage()
    msg['Subject'] = 'Bear Detected!'
    msg['From'] = EMAIL_ADDRESS
    msg['To'] = EMAIL_RECIPIENT
    msg.set_content('A bear was detected. See attached video.')

    with open(filepath, 'rb') as f:
        file_data = f.read()
        msg.add_attachment(file_data, maintype='video', subtype='mp4', filename=Path(filepath).name)

    with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as smtp:
        smtp.starttls()
        smtp.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
        smtp.send_message(msg)

# Cleanup function
def cleanup_old_clips(directory, days_old=7):
    cutoff = datetime.now() - timedelta(days=days_old)
    for file in directory.glob("*.mp4"):
        if datetime.fromtimestamp(file.stat().st_mtime) < cutoff:
            file.unlink()

# GPIO setup
led = 40
led2 = 11
led_count = 11
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(led2, GPIO.OUT)

# Video stream class
class VideoStream:
    def __init__(self, resolution=(640,480), framerate=30):
        self.stream = cv2.VideoCapture(0)
        self.stream.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
        self.stream.set(3, resolution[0])
        self.stream.set(4, resolution[1])
        (self.grabbed, self.frame) = self.stream.read()
        self.stopped = False

    def start(self):
        Thread(target=self.update,args=()).start()
        return self

    def update(self):
        while True:
            if self.stopped:
                self.stream.release()
                return
            (self.grabbed, self.frame) = self.stream.read()

    def read(self):
        return self.frame

    def stop(self):
        self.stopped = True

# Parse arguments
parser = argparse.ArgumentParser()
parser.add_argument('--modeldir', required=True)
parser.add_argument('--graph', default='detect.tflite')
parser.add_argument('--labels', default='labelmap.txt')
parser.add_argument('--threshold', default=0.65)
parser.add_argument('--resolution', default='800x480')
parser.add_argument('--edgetpu', action='store_true')
args = parser.parse_args()

MODEL_NAME = args.modeldir
GRAPH_NAME = args.graph
LABELMAP_NAME = args.labels
min_conf_threshold = float(args.threshold)
resW, resH = args.resolution.split('x')
imW, imH = int(resW), int(resH)
use_TPU = args.edgetpu

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

CWD_PATH = os.getcwd()
PATH_TO_CKPT = os.path.join(CWD_PATH, MODEL_NAME, GRAPH_NAME)
PATH_TO_LABELS = os.path.join(CWD_PATH, MODEL_NAME, LABELMAP_NAME)

with open(PATH_TO_LABELS, 'r') as f:
    labels = [line.strip() for line in f.readlines()]
if labels[0] == '???':
    del(labels[0])

interpreter = Interpreter(model_path=PATH_TO_CKPT,
                          experimental_delegates=[load_delegate('libedgetpu.so.1.0')] if use_TPU else None)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
height = input_details[0]['shape'][1]
width = input_details[0]['shape'][2]
floating_model = (input_details[0]['dtype'] == np.float32)
input_mean = 127.5
input_std = 127.5

frame_rate_calc = 1
freq = cv2.getTickFrequency()
videostream = VideoStream(resolution=(imW,imH),framerate=FPS).start()
time.sleep(1)

while True:
    t1 = cv2.getTickCount()
    frame1 = videostream.read()
    frame = frame1.copy()
    video_buffer.append(frame.copy())

    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    frame_resized = cv2.resize(frame_rgb, (width, height))
    input_data = np.expand_dims(frame_resized, axis=0)
    if floating_model:
        input_data = (np.float32(input_data) - input_mean) / input_std
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    boxes = interpreter.get_tensor(output_details[0]['index'])[0]
    classes = interpreter.get_tensor(output_details[1]['index'])[0]
    scores = interpreter.get_tensor(output_details[2]['index'])[0]

    for i in range(len(scores)):
        if ((scores[i] > min_conf_threshold) and (scores[i] <= 1.0)):
            ymin = int(max(1,(boxes[i][0] * imH)))
            xmin = int(max(1,(boxes[i][1] * imW)))
            ymax = int(min(imH,(boxes[i][2] * imH)))
            xmax = int(min(imW,(boxes[i][3] * imW)))

            object_name = labels[int(classes[i])]
            if object_name == "bear" and int(scores[i]*100) > 55:
                print("BEAR!!!! - Score:", int(scores[i]*100))
                GPIO.output(led, GPIO.HIGH)
                GPIO.output(led2, GPIO.HIGH)
                led_count = 0

                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"bear_clip_{timestamp}.mp4"
                filepath = CLIP_DIR / filename

                out = cv2.VideoWriter(str(filepath), fourcc, FPS, (imW, imH))
                for f in video_buffer:
                    out.write(f)
                out.release()

                cleanup_old_clips(CLIP_DIR)
                try:
                    send_email_with_attachment(filepath)
                    print(f"Emailed bear clip: {filepath}")
                except Exception as e:
                    print(f"Email failed: {e}")

    led_count += 1
    if (led_count > 10):
        GPIO.output(led, GPIO.LOW)
        GPIO.output(led2, GPIO.LOW)
    elif (led_count % 2) == 0:
        GPIO.output(led, GPIO.LOW)
        GPIO.output(led2, GPIO.LOW)
    else:
        GPIO.output(led, GPIO.HIGH)
        GPIO.output(led2, GPIO.HIGH)

    t2 = cv2.getTickCount()
    time1 = (t2-t1)/freq
    frame_rate_calc = 1/time1

    cv2.imshow('Object detector', frame)
    if cv2.waitKey(1) == ord('q'):
        break

cv2.destroyAllWindows()
videostream.stop()
