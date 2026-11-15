"""
Step 1 - export the two trained Ultralytics .pt models to ONNX.

Usage:
    pip install ultralytics onnx onnxslim onnxruntime
    python export_models.py --shelf path/to/shelf.pt --product path/to/product.pt

Outputs (next to this script):
    shelf_model.onnx     (YOLO11n-Seg, class: row)
    product_model.onnx   (YOLO11n,     classes: empty, product)
Copy both into  assets/models/  of the Flutter project.
"""
import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO


def export(pt_path: str, out_name: str, imgsz: int):
    model = YOLO(pt_path)
    print(f"\n=== {pt_path} ===")
    print("task :", model.task)
    print("names:", model.names, "  <-- class ORDER must match AppConstants in Flutter")
    onnx_path = model.export(
        format="onnx",
        imgsz=imgsz,
        opset=12,        # conservative opset = best ONNX Runtime Mobile compatibility
        simplify=True,
        dynamic=False,   # fixed 1x3xSxS input
        half=False,
    )
    dst = Path(__file__).parent / out_name
    shutil.copy(onnx_path, dst)
    print("saved:", dst)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--shelf", required=True)
    ap.add_argument("--product", required=True)
    ap.add_argument("--imgsz", type=int, default=640,
                    help="640 matches training. 480/416 is faster on phones but must also be set as AppConstants.inputSize")
    a = ap.parse_args()
    export(a.shelf, "shelf_model.onnx", a.imgsz)
    export(a.product, "product_model.onnx", a.imgsz)
