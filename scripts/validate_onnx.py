"""
Step 2 - check that the ONNX models behave like the original PyTorch ones.

Usage:
    python validate_onnx.py --image test.jpg \
        --shelf-pt shelf.pt --shelf-onnx shelf_model.onnx \
        --product-pt product.pt --product-onnx product_model.onnx
"""
import argparse

from ultralytics import YOLO


def summarize(res):
    r = res[0]
    boxes = r.boxes
    out = sorted(
        [(int(c), float(s), [round(float(v), 1) for v in b])
         for c, s, b in zip(boxes.cls, boxes.conf, boxes.xyxy)],
        key=lambda t: -t[1],
    )
    return out


def compare(name, pt, onnx, image, conf=0.35):
    a = summarize(YOLO(pt).predict(image, imgsz=640, conf=conf, verbose=False))
    b = summarize(YOLO(onnx, task=YOLO(pt).task).predict(image, imgsz=640, conf=conf, verbose=False))
    print(f"\n[{name}] PyTorch: {len(a)} detections | ONNX: {len(b)} detections")
    for i in range(min(5, len(a), len(b))):
        print("  PT  :", a[i])
        print("  ONNX:", b[i])


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--shelf-pt", required=True)
    ap.add_argument("--shelf-onnx", required=True)
    ap.add_argument("--product-pt", required=True)
    ap.add_argument("--product-onnx", required=True)
    a = ap.parse_args()
    compare("shelf", a.shelf_pt, a.shelf_onnx, a.image)
    compare("product", a.product_pt, a.product_onnx, a.image)
