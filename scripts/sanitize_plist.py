import sys
import plistlib

def sanitize_plist(plist_path):
    with open(plist_path, "rb") as f:
        data = plistlib.load(f)

    # Replace any unresolved Xcode variable placeholders with actual values
    defaults = {
        "CFBundleName": "Scan2WA",
        "CFBundleDisplayName": "Scan2WA",
        "CFBundleExecutable": "Scan2WA",
        "CFBundleIdentifier": "com.ilyassbourass.Scan2WA",
        "CFBundleDevelopmentRegion": "en",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.10.0",
        "CFBundleVersion": "1100",
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": "17.0"
    }

    for key, val in defaults.items():
        existing = data.get(key)
        if existing is None or (isinstance(existing, str) and "$(" in existing):
            data[key] = val

    # Extra safety check: scan all string values for any remaining "$("
    for k, v in list(data.items()):
        if isinstance(v, str) and "$(" in v:
            print(f"Warning: replacing unresolved variable in {k}: {v}")
            if "NAME" in k or "Name" in k:
                data[k] = "Scan2WA"
            elif "IDENTIFIER" in k or "Identifier" in k:
                data[k] = "com.ilyassbourass.Scan2WA"
            elif "EXECUTABLE" in k or "Executable" in k:
                data[k] = "Scan2WA"
            elif "LANGUAGE" in k or "Region" in k:
                data[k] = "en"

    with open(plist_path, "wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

    print(f"Successfully sanitized {plist_path}")
    for k in ["CFBundleName", "CFBundleDisplayName", "CFBundleExecutable", "CFBundleIdentifier"]:
        print(f"  {k} = {data.get(k)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        sanitize_plist(sys.argv[1])
    else:
        print("Usage: python sanitize_plist.py <path_to_Info.plist>")
