# 🎮 Hytale Mod Manager

A simple and intuitive **mod manager** for **Hytale servers**, with a **terminal TUI** (whiptail) and a **browser-based Web UI** — both powered by the **CurseForge API**.

---

## ✨ Features

* 🔍 **Search mods** directly on CurseForge by name
* 📥 **One-step installation** (just press Enter)
* 🔄 **Automatic updates** for all installed mods
* 📋 **List installed mods** with version and file info
* 🗑️ **Easy mod removal**
* 💾 **Metadata tracking** for reliable mod management
* 🎨 **Terminal TUI** powered by whiptail
* 🌐 **Web UI** accessible from any browser on your network
* ✅ **API connection testing** for CurseForge configuration
* 🔁 **Automatic CDN fallback** for mods with restricted direct downloads

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
│  7. Web UI Manager                               │
│  8. Exit                                         │
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

For the **Web UI**, you also need:

* `python3` and `pip3`
* The Flask packages (installed automatically by the script)

```bash
sudo apt install python3 python3-pip
```

---

## 🔑 CurseForge API Setup

1. Go to **<https://console.curseforge.com/>**
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

> ⚠️ **Important**: The API key contains `$` characters. Using double quotes will cause Bash variable expansion and break the key.

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

## 🌐 Web UI Setup & Usage

The Web UI provides a browser-based interface to manage mods from any device on your network.

### Step 1 — First-time setup

From the main menu, choose **7 → Web UI Manager → Setup/Reinstall Web UI**.

The script will:
- Check that Python 3 is installed
- Install the required Python packages (`flask`, `flask-cors`, `requests`) via pip if missing
- Generate `web/app.py` with your API key embedded
- Verify that `web/templates/index.html` is present

> ℹ️ The `web/templates/index.html` file is included in the repository. If it is missing, re-clone or download it from the repository manually.

### Step 2 — Start the Web UI

From the main menu, choose **7 → Web UI Manager → Start Web UI**.

The Flask server starts in the background. You will see two access URLs:

```
Local:   http://localhost:5000
Network: http://<your-server-ip>:5000
```

Use the **Network** URL to access the interface from another device (e.g. your laptop or phone) as long as you are on the same network.

### Step 3 — Use the Web UI

Open the URL in any browser. The interface lets you:

- **Search** for mods by name
- **Install** mods with one click
- **View** all installed mods
- **Remove** mods
- **Update** all mods at once
- **Test** the CurseForge API connection

### Step 4 — Stop the Web UI

From the main menu, choose **7 → Web UI Manager → Stop Web UI**.

The background process is terminated and the PID file is cleaned up.

### Web UI status & logs

Choose **7 → Web UI Manager → Web UI Status & Logs** to check whether the server is running, see its PID, and view the last 10 lines of `web/server.log`.

---

## 🧭 Terminal TUI — Available Actions

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

* Displays mod name, installed file, and version information

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
Hytale-Mod-Manager/
├── mod-manager.sh
└── web/
    ├── app.py          ← generated on first Web UI setup
    ├── server.log      ← Web UI runtime log
    ├── server.pid      ← PID of running Web UI process
    └── templates/
        └── index.html

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

### ❌ Web UI fails to start

Check the log file:

```bash
cat web/server.log
```

Common causes:
- Port 5000 already in use → stop the conflicting service or change the port in `web/app.py`
- Python packages not installed → run **Setup/Reinstall Web UI** again from the menu
- `index.html` missing from `web/templates/` → re-download from the repository

### ❌ Some mods fail to download

Some mod authors disable direct API distribution on CurseForge. When the API returns `downloadUrl: null`, the script automatically falls back to the Forge CDN (`edge.forgecdn.net`) to complete the download. If a mod still fails after this, the author may have disabled all automated distribution — in that case, download the file manually from the CurseForge website.

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
* Old mod versions are deleted automatically during updates

---

## 📜 License

This project is open source under the MIT License. You are free to use, modify, and share it, as long as you always credit the original project. 🎉

---

## 🙏 Credits

* **CurseForge API** and **Forge CDN**
* Hytale community
* TUI powered by whiptail
* Web UI powered by Flask

---

### ⚠️ Disclaimer

This is an unofficial tool and is not affiliated with Hypixel Studios, Hytale, or CurseForge.
Use at your own risk.

---

❤️ Made for the Hytale community
