# A Short Guide to Building with Crave

## Introduction

This repository contains automated build scripts optimized for building custom Android ROMs (primarily LineageOS) using the Crave.io build environment.

The scripts automate the entire build lifecycle, including environment preparation, source synchronization, build execution, Telegram notifications, and artifact distribution.

---

## Features

* **Automated Tooling** – Installs required dependencies such as `jq` automatically when missing.
* **Smart Sync** – Uses Crave's native resync mechanism for faster and more reliable source synchronization.
* **Real-Time Notifications** – Sends build status updates, sync progress, timings, and error logs directly to Telegram.
* **Artifact Hosting** – Automatically uploads successful build packages (`.zip`) to PixelDrain.

---

## Prerequisites

Before getting started, make sure you have:

* A Crave.io account
* The `crave` CLI installed and configured
* Access to a Crave DevSpace

---

# 🛠️ Setup & Usage

## Step 1 – Create a Workspace

Create a dedicated folder for your device inside your DevSpace:

```bash
cd /crave-devspaces
```
```bash
mkdir -p <device>
```
```bash
cd <device>
```

Replace `<device>` with your device codename.

Keeping each device in its own directory makes it easier to manage multiple builds in the future.

---

## Step 2 – List Available Projects

Run the following command to view the preconfigured projects available on Crave:

```bash
crave clone list
```

Example output:

```text
admin@foss:/crave-devspaces/los/<device>$ crave clone list

Projects:

  Id  Name           Source Url                                                                Setup State
----  -------------  ------------------------------------------------------------------------  -------------
  73  Arrow OS       https://github.com/ArrowOS/android_manifest.git                           Complete
  79  CipherOS       https://github.com/CipherOS/android_manifest.git                          Complete
  64  DerpFest-aosp  https://github.com/DerpFest-AOSP/manifest.git                             Complete
  81  LOS 16         https://github.com/accupara/los16.git                                     Complete
  85  LOS 18.1       https://github.com/accupara/los18.1.git                                   Complete
  36  LOS 20         https://github.com/accupara/los20.git                                     Complete
  72  LOS 21         https://github.com/LineageOS/android.git                                  Complete
  93  LOS 22.1       https://github.com/accupara/los22.git                                     Complete
  80  LOS CM 12.1    https://github.com/accupara/los-cm12.1.git                                Complete
  83  LOS CM 14.1    https://github.com/accupara/los-cm14.1.git                                Complete
  82  PixelOS        https://github.com/PixelOS-AOSP/android_manifest                          Complete
  77  ROM Dumper     https://github.com/DumprX/DumprX                                          Complete
  86  Rising OS      https://github.com/RisingOS-Revived/android.git                           Complete
  78  TWRP           https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git  Complete
  35  aosp           https://android.googlesource.com/platform/manifest                        Complete

Clones:
```

If your project list looks different and the Android ROM projects are missing, you are likely assigned to the wrong team.

Simply contact the Crave administrators through Discord or Telegram and request access to the correct team.

For most modern ROM development, **LOS 22.1** is recommended if the rom you want to build is not in the preconfigured project list.

---

## Step 3 – Create a Clone

Create a local clone of the selected project inside your device directory:

```bash
crave clone create --projectID 93 .
```

Example output:

```text
Cloning projectid LOS 22.1(pid = 93) into los/<device>.
Successfully cloned projectid LOS 22.1(pid = 93) into los/<device>.
```

At this point, the basic Crave setup is complete.

The remaining steps describe the workflow used in this repository. Feel free to adapt them to your own requirements.

---

## Step 4 – Create a `.env` File

Create a `.env` file in the project root directory:

```bash
cd /crave-devspaces/<device>
```
```bash
nano .env
```

Example template:

```bash
# Adjust to your local timezone (optional)
TZ=""

# Telegram Notifications (optional)
TG_TOKEN=""
TG_GROUP=""
TG_CHAT=""

# PixelDrain Uploads (optional)
PIXELDRAIN=""

# Build Configuration
ROM_NAME=""
DEVICE=""
BUILD_TYPE=""
ANDROID_VERSION=""
ROM_VERSION=""

# Build Metadata
BUILD_USERNAME=""
BUILD_HOSTNAME=""

# OTA Configuration (optional)
OTA_URL=""
```

After creating the file, push it to the build container:

```bash
cd /crave-devspaces/<device>
```
```bash
crave push .env -d /tmp/src/android
```

This allows the build environment to access the same configuration and secrets.

---

## Step 5 – Create the Build Launcher Script

Create a simple launcher script in the crave-devspace root dir:

```bash
cd /crave-devspaces
```
```bash
nano build.sh
```

Paste the following: (described based on this repo)

```bash
#!/bin/bash

cd <device>

curl -sf https://raw.githubusercontent.com/nuruszama/build_scripts/android-16/lineageos/crave_queue.sh | bash
```

### Note

The scripts hosted in this repository are intended as a reference.

It is recommended that you fork or clone them into your own GitHub repository and update the URLs accordingly before using them in production.

---

## Step 6 – Make the Script Executable

Grant execution permissions:

```bash
chmod +x build.sh
```

---

## Step 7 – Configure Local Manifests

Create a separate repository containing the `local_manifest.xml` required for your device.

Update the corresponding manifest URL inside `crave_run.sh` so the build system can fetch the correct device-specific sources.

---

## Step 8 – Start Building

Once everything is configured, start a build with:

```bash
./build.sh
```

The script will automatically handle:

* Environment preparation
* Source synchronization
* Build execution
* Telegram notifications
* Artifact uploads

---

## Step 9 – Only if neccessary

After completing and when you want to close your project in crave, you can destroy your project directory using

```
crave clone destry ./<project_folder/dir>
```

Avoid using rm -rf command to destroy the project folder since it will use more resource and affect other users.


---

# 🤝 Credits

A huge thanks to the people and projects that made this workflow possible:

* **[EternalMikaelson](https://github.com/EternalMikaelson)** – Original script architecture, automation workflow, and Telegram integration.
* **[SoundDrill31](https://github.com/sounddrill31)** – Guidance on pushing `.env` files into the Crave workspace.
* **[Saroj-Tajpuriya ](https://github.com/saroj-nokia)** – Script optimization and workflow improvements.
* **[{⚡}crave.io](https://crave.io/)** – Providing free cloud build infrastructure for Android developers who do not have access to powerful local hardware.
