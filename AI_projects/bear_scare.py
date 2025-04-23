import os
import argparse
import cv2
import numpy as np
import sys
import time
import importlib.util
import RPi.GPIO as GPIO
from datetime import datetime
import shutil
import tensorflow as tf
from tflite_runtime.interpreter import Interpreter

# Constants
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

# Setup camera
camera = cv2.VideoCapture(0)
camera.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

# Toggle streaming control
STREAMING_ENABLED = False  # Set to True to enable streaming

# Load TFLite model
def load_model(model_path):
    interpreter = Interpreter(model_path=Sample_TFLite_model)
    interpreter.allocate_tensors()
    return interpreter

# Preprocess image for model input
def preprocess_image(image):
    # Resize image to match model input size
    image = cv2.resize(image, (300, 300))
    image = np.expand_dims(image, axis=0)
    image = image.astype(np.float32)
    return image

# Perform detection using the model
def detect_bear(interpreter, image):
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    image = preprocess_image(image)

    # Set input tensor
    interpreter.set_tensor(input_details[0]['index'], image)

    # Run inference
    interpreter.invoke()

    # Get output tensor
    boxes = interpreter.get_tensor(output_details[0]['index'])[0]  # bounding boxes
    classes = interpreter.get_tensor(output_details[1]['index'])[0]  # class IDs
    scores = interpreter.get_tensor(output_details[2]['index'])[0]  # scores

    return boxes, classes, scores

# Cleanup old videos if disk space is high
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

# Record the bear video
def record_bear_video():
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = os.path.join(VIDEO_DIR, f'bear_{timestamp}.mp4')
    frame_width = int(camera.get(3))
    frame_height = int(camera.get(4))
    out = cv2.VideoWriter(filename, cv2.VideoWriter_fourcc(*'X264'), 15, (frame_width, frame_height))

    start_time = time.time()
    while time.time() - start_time < VIDEO_DURATION:
        ret, frame = camera.read()
        if not ret:
            break
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        cv2.putText(frame, "Bear Scare Horn Activated", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        cv2.putText(frame, now, (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
        out.write(frame)
    out.release()
    cleanup_old_videos()

# Main loop for detection and streaming
def main(model_path):
    interpreter = load_model(model_path)

    try:
        while True:
            ret, frame = camera.read()
            if not ret:
                continue

            # Perform bear detection using TFLite model
            boxes, classes, scores = detect_bear(interpreter, frame)

            bear_detected = False
            for i in range(len(scores)):
                if scores[i] > 0.5:  # Adjust score threshold as necessary
                    bear_detected = True
                    y_min, x_min, y_max, x_max = boxes[i]
                    cv2.rectangle(frame, (int(x_min * 640), int(y_min * 480)), (int(x_max * 640), int(y_max * 480)), (0, 255, 0), 2)

            if bear_detected:
                GPIO.output(led, GPIO.HIGH)
                GPIO.output(led2, GPIO.HIGH)
                record_bear_video()
                GPIO.output(led, GPIO.LOW)
                GPIO.output(led2, GPIO.LOW)

            # If streaming is enabled, show the frame
            if STREAMING_ENABLED:
                cv2.imshow('Bear Detection Stream', frame)

            # Quit by pressing 'q'
            if cv2.waitKey(1) == ord('q'):
                break

    except KeyboardInterrupt:
        print("Exiting")

    camera.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    model_path = "your_model.tflite"  # Specify the correct path to your TFLite model
    main(model_path)
