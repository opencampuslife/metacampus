#!/usr/bin/env python

import os
import sys

# Ensure we can find godot-cpp
env = SConscript("godot-cpp/SConstruct")

# Add our source directories to include paths
env.Append(CPPPATH=["src/native/", "native/canary_simulator/src/"])

# Collect source files
sources = Glob("src/native/*.cpp") + Glob("native/canary_simulator/src/*.cpp")

# Build shared library
library_path = ""
if env["platform"] == "macos":
    # macOS uses a framework bundle for GDExtension
    libdir = "bin/libmetacampus_native.{}.{}.framework".format(env["platform"], env["target"])
    libname = "libmetacampus_native.{}.{}".format(env["platform"], env["target"])
    library = env.SharedLibrary(
        os.path.join(libdir, libname),
        source=sources,
    )
    library_path = libdir

    # Generate Info.plist for the framework bundle
    def generate_info_plist(target, source, env):
        plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleExecutable</key>
\t<string>libmetacampus_native.{plat}.{tgt}</string>
\t<key>CFBundleIdentifier</key>
\t<string>org.metacampus.libmetacampus_native</string>
\t<key>CFBundleInfoDictionaryVersion</key>
\t<string>6.0</string>
\t<key>CFBundleName</key>
\t<string>libmetacampus_native.{plat}.{tgt}</string>
\t<key>CFBundlePackageType</key>
\t<string>FMWK</string>
\t<key>CFBundleShortVersionString</key>
\t<string>1.0.0</string>
\t<key>CFBundleSupportedPlatforms</key>
\t<array>
\t\t<string>MacOSX</string>
\t</array>
\t<key>CFBundleVersion</key>
\t<string>1.0.0</string>
\t<key>LSMinimumSystemVersion</key>
\t<string>10.12</string>
</dict>
</plist>""".format(plat=env["platform"], tgt=env["target"])
        with open(str(target[0]), "w") as f:
            f.write(plist_content)

    resources_dir = os.path.join(libdir, "Resources")
    if not os.path.exists(resources_dir):
        os.makedirs(resources_dir)
    plist_path = os.path.join(resources_dir, "Info.plist")
    # Always regenerate to match current target
    env.Command(plist_path, [], generate_info_plist)
    env.Depends(library, plist_path)
else:
    library = env.SharedLibrary(
        "bin/libmetacampus_native{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )
    library_path = "bin/"

env.NoCache(library)
Default(library)

# Print build summary
print("Build complete. Library in: " + library_path)
