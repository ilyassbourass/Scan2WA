import json
import os
import plistlib
from datetime import datetime, timezone

def update_apps_json(ipa_path="Scan2WA.ipa", apps_json_path="apps.json", info_plist_path="Scan2WA/App/Info.plist"):
    if not os.path.exists(info_plist_path):
        print(f"Info.plist not found at {info_plist_path}")
        return

    with open(info_plist_path, "rb") as f:
        plist = plistlib.load(f)

    version = plist.get("CFBundleShortVersionString", "1.11.2")
    bundle_id = plist.get("CFBundleIdentifier", "com.ilyassbourass.Scan2WA")
    app_name = plist.get("CFBundleDisplayName", "Scan2WA")

    size = 0
    if os.path.exists(ipa_path):
        size = os.path.getsize(ipa_path)

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    download_url = f"https://github.com/ilyassbourass/Scan2WA/releases/download/v{version}/Scan2WA.ipa"

    source_data = {}
    if os.path.exists(apps_json_path):
        try:
            with open(apps_json_path, "r", encoding="utf-8") as f:
                source_data = json.load(f)
        except Exception as e:
            print(f"Warning: could not parse existing {apps_json_path}: {e}")

    source_data["name"] = "Scan2WA Source"
    source_data["identifier"] = "com.ilyassbourass.scan2wa.source"
    source_data["sourceURL"] = "https://raw.githubusercontent.com/ilyassbourass/Scan2WA/main/apps.json"
    source_data["iconURL"] = "https://raw.githubusercontent.com/ilyassbourass/Scan2WA/main/Scan2WA/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

    version_description = f"Scan2WA v{version} update with direct SideStore support and instant packaging."

    app_entry = {
        "name": app_name,
        "bundleIdentifier": bundle_id,
        "developerName": "Ilyass Bourass",
        "version": version,
        "versionDate": now_iso,
        "versionDescription": version_description,
        "downloadURL": download_url,
        "localizedDescription": "Scan delivery package labels, auto-detect Moroccan phone numbers via Apple Vision OCR, track delivery statuses, and open WhatsApp directly.",
        "iconURL": "https://raw.githubusercontent.com/ilyassbourass/Scan2WA/main/Scan2WA/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        "tintColor": "25D366",
        "size": size,
        "subtitle": "Delivery package scanner & WhatsApp organizer",
        "appID": bundle_id,
        "versions": []
    }

    # If existing apps array has Scan2WA, preserve older versions
    existing_apps = source_data.get("apps", [])
    existing_scan2wa = next((a for a in existing_apps if a.get("bundleIdentifier") == bundle_id), None)
    past_versions = []
    if existing_scan2wa and "versions" in existing_scan2wa:
        past_versions = [v for v in existing_scan2wa["versions"] if v.get("version") != version]

    new_version_obj = {
        "version": version,
        "date": now_iso,
        "downloadURL": download_url,
        "localizedDescription": version_description,
        "size": size
    }

    app_entry["versions"] = [new_version_obj] + past_versions
    source_data["apps"] = [app_entry]

    with open(apps_json_path, "w", encoding="utf-8") as f:
        json.dump(source_data, f, indent=2)

    print(f"Successfully generated {apps_json_path} for version {version} (size: {size} bytes)")

if __name__ == "__main__":
    import sys
    ipa = sys.argv[1] if len(sys.argv) > 1 else "Scan2WA.ipa"
    update_apps_json(ipa_path=ipa)
