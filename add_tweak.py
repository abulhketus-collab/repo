import os, sys, shutil, gzip, bz2, lzma, hashlib, json, subprocess

# Universal deb scanner & repo updater for cocxace's Repo
def update_repo(new_deb_path=None):
    repo_dir = os.path.dirname(os.path.abspath(__file__))
    debs_dir = os.path.join(repo_dir, "debs")
    os.makedirs(debs_dir, exist_ok=True)

    if new_deb_path and os.path.exists(new_deb_path):
        dest = os.path.join(debs_dir, os.path.basename(new_deb_path))
        shutil.copy2(new_deb_path, dest)
        print(f"Added new deb: {os.path.basename(new_deb_path)}")

    # Scan all debs
    deb_files = [f for f in os.listdir(debs_dir) if f.endswith(".deb")]
    if not deb_files:
        print("No .deb files found in debs/")
        return

    packages_entries = []
    for deb_file in sorted(deb_files):
        p = os.path.join(debs_dir, deb_file)
        with open(p, "rb") as f:
            data = f.read()
        size = len(data)
        md5 = hashlib.md5(data).hexdigest()
        sha1 = hashlib.sha1(data).hexdigest()
        sha256 = hashlib.sha256(data).hexdigest()

        # Extract control
        control_text = ""
        try:
            res = subprocess.run(["dpkg-deb", "-f", p], capture_output=True, text=True)
            if res.returncode == 0:
                control_text = res.stdout.strip()
        except Exception:
            pass

        if not control_text:
            # Fallback simple control entry
            pkg_id = deb_file.split("_")[0] if "_" in deb_file else deb_file[:-4]
            control_text = f"Package: {pkg_id}\nName: {pkg_id}\nVersion: 1.0.0\nArchitecture: iphoneos-arm\nAuthor: @cocxace\nMaintainer: @cocxace\nSection: Tweaks"

        # Check SileoDepiction
        pkg_id = ""
        for line in control_text.splitlines():
            if line.startswith("Package:"):
                pkg_id = line.split(":", 1)[1].strip()

        depiction_line = ""
        dep_path = os.path.join(repo_dir, "depictions", pkg_id, "sileo.json")
        if os.path.exists(dep_path):
            depiction_line = f"SileoDepiction: depictions/{pkg_id}/sileo.json\n"

        entry = f"{control_text}\nFilename: debs/{deb_file}\nSize: {size}\nMD5sum: {md5}\nSHA1: {sha1}\nSHA256: {sha256}\n{depiction_line}"
        packages_entries.append(entry.strip() + "\n\n")

    full_packages = "".join(packages_entries)
    pkg_path = os.path.join(repo_dir, "Packages")
    with open(pkg_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(full_packages)

    with open(pkg_path, "rb") as f:
        pkg_data = f.read()

    with gzip.open(pkg_path + ".gz", "wb") as f: f.write(pkg_data)
    with bz2.open(pkg_path + ".bz2", "wb") as f: f.write(pkg_data)
    with lzma.open(pkg_path + ".xz", "wb") as f: f.write(pkg_data)

    def hash_for(fn):
        p = os.path.join(repo_dir, fn)
        d = open(p, "rb").read()
        return f" {hashlib.md5(d).hexdigest()} {len(d)} {fn}\n", \
               f" {hashlib.sha1(d).hexdigest()} {len(d)} {fn}\n", \
               f" {hashlib.sha256(d).hexdigest()} {len(d)} {fn}\n"

    md5_entries, sha1_entries, sha256_entries = "", "", ""
    for fn in ["Packages", "Packages.gz", "Packages.bz2", "Packages.xz"]:
        m, s1, s256 = hash_for(fn)
        md5_entries += m
        sha1_entries += s1
        sha256_entries += s256

    release_content = f"""Origin: cocxace's Repo
Label: cocxace's Repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm iphoneos-arm64
Components: main
Description: Official tweak repository by @cocxace for iOS 12+
MD5Sum:
{md5_entries}SHA1:
{sha1_entries}SHA256:
{sha256_entries}"""

    with open(os.path.join(repo_dir, "Release"), "w", encoding="utf-8", newline="\n") as f:
        f.write(release_content)

    print("Packages and Release successfully updated!")

    # Auto commit and push
    subprocess.run(["git", "add", "-A"], cwd=repo_dir)
    subprocess.run(["git", "commit", "-m", "Update repository tweaks and metadata"], cwd=repo_dir)
    subprocess.run(["git", "push", "origin", "main"], cwd=repo_dir)
    print("Changes pushed to GitHub!")

if __name__ == '__main__':
    deb = sys.argv[1] if len(sys.argv) > 1 else None
    update_repo(deb)
