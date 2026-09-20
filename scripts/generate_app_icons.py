import os
import json
from PIL import Image

def generate_icons():
    appicon_dir = os.path.join("Scan2WA", "Assets.xcassets", "AppIcon.appiconset")
    source_path = os.path.join(appicon_dir, "AppIcon-1024.png")
    
    if not os.path.exists(source_path):
        print(f"Error: {source_path} does not exist")
        return

    base_img = Image.open(source_path).convert("RGB")

    sizes = [
        {"size": "20x20", "idiom": "iphone", "scale": "2x", "pixels": 40, "filename": "AppIcon-20@2x.png"},
        {"size": "20x20", "idiom": "iphone", "scale": "3x", "pixels": 60, "filename": "AppIcon-20@3x.png"},
        {"size": "29x29", "idiom": "iphone", "scale": "2x", "pixels": 58, "filename": "AppIcon-29@2x.png"},
        {"size": "29x29", "idiom": "iphone", "scale": "3x", "pixels": 87, "filename": "AppIcon-29@3x.png"},
        {"size": "40x40", "idiom": "iphone", "scale": "2x", "pixels": 80, "filename": "AppIcon-40@2x.png"},
        {"size": "40x40", "idiom": "iphone", "scale": "3x", "pixels": 120, "filename": "AppIcon-40@3x.png"},
        {"size": "60x60", "idiom": "iphone", "scale": "2x", "pixels": 120, "filename": "AppIcon-60@2x.png"},
        {"size": "60x60", "idiom": "iphone", "scale": "3x", "pixels": 180, "filename": "AppIcon-60@3x.png"},
        {"size": "76x76", "idiom": "ipad", "scale": "2x", "pixels": 152, "filename": "AppIcon-76@2x.png"},
        {"size": "83.5x83.5", "idiom": "ipad", "scale": "2x", "pixels": 167, "filename": "AppIcon-83.5@2x.png"},
        {"size": "1024x1024", "idiom": "universal", "platform": "ios", "scale": "1x", "pixels": 1024, "filename": "AppIcon-1024.png"}
    ]

    images_json = []

    for item in sizes:
        dest_file = os.path.join(appicon_dir, item["filename"])
        resized = base_img.resize((item["pixels"], item["pixels"]), Image.Resampling.LANCZOS)
        resized.save(dest_file, format="PNG", optimize=True)
        print(f"Generated {item['filename']} ({item['pixels']}x{item['pixels']})")
        
        entry = {
            "size": item["size"],
            "idiom": item["idiom"],
            "scale": item["scale"],
            "filename": item["filename"]
        }
        if "platform" in item:
            entry["platform"] = item["platform"]
        images_json.append(entry)

    contents = {
        "images": images_json,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    contents_path = os.path.join(appicon_dir, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)

    print(f"Updated {contents_path} successfully!")

if __name__ == "__main__":
    generate_icons()
