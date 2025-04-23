import os
import cv2
import numpy as np
import time
from threading import Thread
import shutil
from datetime import datetime
import RPi.GPIO as GPIO
import tensorflow as tf

# Constants
VIDEO_DURATION = 30  # seconds
VIDEO_DIR = "bear_videos"
MAX_VIDEOS = 100
STREAMING_ENABLED = False  # Toggle for streaming, default is off

# Set up GPIO
led = 40
led2 = 11
led_count = 11
GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings(False)
GPIO.setup(led, GPIO.OUT)
GPIO.setup(led2, GPIO.OUT)

# Create folder if it doesn't exist
if not os.path.exists(VIDEO_DIR):
    os.makedirs(VIDEO_DIR)

# VideoStream class (unchanged)
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

# Function to delete oldest videos if over limit
def cleanup_old_videos():
    files = sorted([os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR)],
                   key=os.path.getctime)
    while len(files) > MAX_VIDEOS:
        os.remove(files[0])
        files.pop(0)

# Function to record video
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

# TensorFlow Lite model inference (replacing the dummy function)
def detect_bear(frame, interpreter, input_details, output_details):
    # Preprocess frame
    resized_frame = cv2.resize(frame, (300, 300))
    input_data = np.expand_dims(resized_frame, axis=0)
    input_data = np.float32(input_data)

    # Set input tensor
    interpreter.set_tensor(input_details[0]['index'], input_data)
    
    # Run inference
    interpreter.invoke()

    # Get output tensors
    boxes = interpreter.get_tensor(output_details[0]['index'])[0]  # Bounding boxes
    classes = interpreter.get_tensor(output_details[1]['index'])[0]  # Class labels
    scores = interpreter.get_tensor(output_details[2]['index'])[0]  # Confidence scores

    return boxes, classes, scores

# Load TensorFlow Lite model
model_path = "Sample_TFLite_model/detect.tflite"  # Path to your TensorFlow Lite model
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

# Get input and output details
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Initialize videostream
videostream = VideoStream(resolution=(800, 480), framerate=30).start()
time.sleep(1)

# Main loop
while True:
    t1 = cv2.getTickCount()
    frame = videostream.read()
    
    # Run object detection using TensorFlow Lite model
    boxes, classes, scores = detect_bear(frame, interpreter, input_details, output_details)

    # Iterate through detections
    for i in range(len(scores)):
        if scores[i] > 0.5:  # Adjust score threshold as needed
            object_name = "bear"  # Replace with actual label
            if object_name == "bear" and int(scores[i] * 100) > 55:
                print("[ALERT] BEAR DETECTED!")
                GPIO.output(led, GPIO.HIGH)
                GPIO.output(led2, GPIO.HIGH)
                led_count = 0
                record_bear_video(videostream)

    # LED Blinking logic (same as before)
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

    # If streaming is enabled, show the frame
    if STREAMING_ENABLED:
        cv2.imshow('Object detector', frame)

    # Quit by pressing 'q'
    if cv2.waitKey(1) == ord('q'):
        break

# Cleanup
cv2.destroyAllWindows()
videostream.stop()
