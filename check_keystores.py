import subprocess
import os
import re

keystores = [
    "/Users/anjitaitsolutions/SHE/android/app/she-keystore.jks",
    "/Users/anjitaitsolutions/Desktop/humrahi-keystore.jks",
    "/Users/anjitaitsolutions/health_parliament/android/app/HP.jks",
    "/Users/anjitaitsolutions/health_parliament/android/app/keystore.jks",
    "/Users/anjitaitsolutions/.android/debug.keystore",
    "/Users/anjitaitsolutions/spiro_app-dev/android/app/anjitait-release-key.jks",
    "/Users/anjitaitsolutions/ipu-keystore.jks",
    "/Users/anjitaitsolutions/Documents/SW.jks",
    "/Users/anjitaitsolutions/Documents/android/app/upload-keystore.jks",
    "/Users/anjitaitsolutions/Documents/android/app/HP.jks",
    "/Users/anjitaitsolutions/Downloads/anjitait-release-key.jks",
    "/Users/anjitaitsolutions/Downloads/tyremarket-keystore.jks",
    "/Users/anjitaitsolutions/Downloads/upload-keystore.jks",
    "/Users/anjitaitsolutions/Downloads/HP.jks",
    "/Users/anjitaitsolutions/Downloads/she-keystore.jks",
    "/Users/anjitaitsolutions/Downloads/gratefykey.jks",
    "/Volumes/Untitled/aitest/target99/mobile/android/app/dailyearn99.jks"
]

properties_files = [
    "/Users/anjitaitsolutions/SHE/android/key.properties",
    "/Users/anjitaitsolutions/Desktop/key.properties",
    "/Users/anjitaitsolutions/Desktop/eventpreneur/android/key.properties",
    "/Users/anjitaitsolutions/health_parliament/android/key.properties",
    "/Users/anjitaitsolutions/spiro_app-dev/android/key.properties",
    "/Users/anjitaitsolutions/Documents/android/key.properties",
    "/Users/anjitaitsolutions/Documents/key.properties",
    "/Users/anjitaitsolutions/Documents/eventpreneur/android/key.properties",
    "/Users/anjitaitsolutions/Downloads/health_parliament_/android/key.properties",
    "/Users/anjitaitsolutions/Downloads/healthism-plus-app-customer-main/android/key.properties",
    "/Users/anjitaitsolutions/Downloads/key.properties",
    "/Users/anjitaitsolutions/Downloads/health_parliament_ 2/android/key.properties",
    "/Volumes/Untitled/aitest/target99/mobile/android/key.properties"
]

passwords = {"Target@99", "android", "target99", "dailyearn99", "admin", "123456", "password"}

# Extract passwords from property files
for pf in properties_files:
    if os.path.exists(pf):
        try:
            with open(pf, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                for line in content.splitlines():
                    if "Password" in line or "password" in line:
                        parts = line.split("=")
                        if len(parts) >= 2:
                            val = parts[1].strip()
                            if val:
                                passwords.add(val)
        except Exception as e:
            print(f"Error reading {pf}: {e}")

print("Checking keystores with passwords:", passwords)

target_sha1 = "EC:24:33:14:46:29:71:D1:4C:B0:2B:86:D0:4D:D4:FF:EC:6F:86:B5".lower().replace(":", "")

match_found = False

for ks in keystores:
    if not os.path.exists(ks):
        continue
    for pw in passwords:
        try:
            cmd = ["keytool", "-list", "-v", "-keystore", ks, "-storepass", pw]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
            if res.returncode == 0:
                output = res.stdout
                for line in output.splitlines():
                    if "SHA1:" in line:
                        sha1_val = line.split("SHA1:")[1].strip().lower().replace(":", "")
                        if sha1_val == target_sha1:
                            print(f"\n=========================================")
                            print(f"MATCH FOUND!")
                            print(f"Keystore: {ks}")
                            print(f"Password: {pw}")
                            # Extract Alias
                            alias_match = re.search(r"Alias name:\s*(.*)", output)
                            if alias_match:
                                print(f"Alias: {alias_match.group(1).strip()}")
                            print(f"=========================================\n")
                            match_found = True
                            break
                if match_found:
                    break
        except Exception as e:
            pass

if not match_found:
    print("\nNo matching keystore found. Let's list all keystores that we could decrypt and their SHA1s to see what we have:")
    for ks in keystores:
        if not os.path.exists(ks):
            continue
        for pw in passwords:
            try:
                cmd = ["keytool", "-list", "-v", "-keystore", ks, "-storepass", pw]
                res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=5)
                if res.returncode == 0:
                    for line in res.stdout.splitlines():
                        if "SHA1:" in line:
                            sha1_val = line.split("SHA1:")[1].strip()
                            print(f"Keystore: {ks} | SHA1: {sha1_val} | Pass: {pw}")
                            break
                    break
            except Exception as e:
                pass
