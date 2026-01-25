# 🎮 Hytale Mod Manager

A simple and intuitive **terminal-based mod manager** for **Hytale servers**, featuring a clean TUI built with **whiptail** and automatic updates via the **CurseForge API**.

---

## ✨ Features

* 🔍 **Search mods** directly on CurseForge by name
* 📥 **One-step installation** (just press Enter)
* 🔄 **Automatic updates** for all installed mods
* 📋 **List installed mods** with version and file info
* 🗑️ **Easy mod removal**
* 💾 **Metadata tracking** for reliable mod management
* 🎨 **User-friendly TUI** powered by whiptail
* ✅ **API connection testing** for CurseForge configuration

---

## 📸 Interface Preview

```
┌─────────────── Hytale Mod Manager ───────────────┐
│                                                  │
│  1. Search and install mod                       │
│  2. Install mod by ID                            │
│  3. Update all mods                              │
│  4. List installed mods                          │
│  5. Remove mod                                   │
│  6. Test API connection                          │
│  7. Exit                                         │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

The script requires the following packages:

* `whiptail` – Terminal-based GUI
* `jq` – JSON parsing
* `curl` – HTTP requests

Install on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install whiptail jq curl
```

---

## 🔑 CurseForge API Setup

1. Go to **[https://console.curseforge.com/](https://console.curseforge.com/)**
2. Log in or create an account
3. Open the **API Keys** section
4. Click **Generate API Key**
5. Accept the **Terms of Service**
6. Copy the generated key

---

## 📦 Installation

1. Clone the repository:

```bash
git clone https://github.com/KiritoGXE/Hytale-Mod-Manager.git
cd Hytale-Mod-Manager
```

2. Make the script executable:

```bash
chmod +x mod-manager.sh
```

3. Add your **API Key** to the script:

```bash
nano mod-manager.sh
```

Locate this line:

```bash
API_KEY=''
```

Replace it with your key (**use single quotes only**):

```bash
API_KEY='$2a$10$YourActualAPIKeyHere...'
```

> ⚠️ **Important**: The API key contains `$` characters. Using double quotes will cause Bash variable expansion.

---

### (Optional) Path customization

```bash
HOMEDIR="/root/hytale"          # Main Hytale directory
MODS_DIR="$HOMEDIR/Server/mods" # Mods directory
```

---

## 💻 Usage

Run the manager with:

```bash
./mod-manager.sh
```

---

## 🧭 Available Actions

### 🔍 Search and install mods

* Enter a mod name
* Browse search results with descriptions
* Select and confirm installation

### 🆔 Install by Project ID

* Enter the CurseForge Project ID directly
* Fastest method if you know the mod

### 🔄 Update all mods

* Checks every installed mod
* Downloads newer versions automatically
* Removes outdated files

### 📋 List installed mods

* Displays mod name
* Installed file
* Version information

### 🗑️ Remove mods

* Select from a menu
* Confirmation prompt
* Removes both file and metadata

### ✅ Test API connection

* Verifies API key validity
* Helps diagnose common issues

---

## 📁 File Structure

```
/root/hytale/
├── Server/
│   └── mods/
│       ├── example-mod-1.2.3.jar
│       ├── another-mod-2.0.0.jar
│       └── mod-metadata.json
└── Scripts/
    └── mod-manager.sh
```

The `mod-metadata.json` file is automatically managed and contains:

```json
{
  "example-mod-1.2.3.jar": {
    "project_id": "123456",
    "file_id": "7891011",
    "name": "Example Mod",
    "version": "1.2.3",
    "last_updated": "2026-01-20T12:00:00Z"
  }
}
```

---

## 🛠️ Troubleshooting

### ❌ Error 403 – API connection failed

Possible solutions:

1. Wait 5–10 minutes after generating the API key
2. Accept the **Terms of Service** on CurseForge
3. Verify your CurseForge account email
4. Make sure you used **single quotes** for the API key
5. Regenerate the API key

### ❌ Empty API Key

You forgot to set the `API_KEY` variable in the script.

### ❌ whiptail not found

```bash
sudo apt install whiptail
```

---

## 🤝 Contributing

Contributions are welcome:

* Bug reports
* Feature suggestions
* Pull requests
* Documentation improvements

---

## ⚠️ Important Notes

* Designed for **Linux servers**
* Tested on Debian/Ubuntu
* Requires Bash ≥ 4.0
* **Back up your mods folder** before first update
* Old mod versions are deleted automatically

---

## 📜 License

This project is open source. You are free to use, modify, and share it, as long as you always credit the original project. 🎉

---

## 🙏 Credits

* **CurseForge API**
* Hytale community
* TUI powered by whiptail

---

### ⚠️ Disclaimer

This is an unofficial tool and is not affiliated with Hypixel Studios, Hytale, or CurseForge.
Use at your own risk.

---

❤️ Made for the Hytale community
