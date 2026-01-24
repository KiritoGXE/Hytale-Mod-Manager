# 🎮 Hytale Mod Manager

A beautiful terminal-based GUI mod manager for Hytale servers with automatic updates from CurseForge!

## ✨ Features

- 🔍 **Search mods** directly from CurseForge by name
- 📥 **Install mods** with a single click (well, enter key)
- 🔄 **Auto-update** all installed mods to their latest versions
- 📋 **List** all installed mods with version info
- 🗑️ **Remove** mods easily
- 💾 **Metadata tracking** - keeps track of all mod information
- 🎨 **User-friendly terminal GUI** using whiptail
- ✅ **API connection testing** to verify your CurseForge setup

## 📸 Screenshots

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

## 🚀 Quick Start

### Prerequisites

The script requires the following packages:
- `whiptail` - For the terminal GUI
- `jq` - For JSON parsing
- `curl` - For API requests

Install them on Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install whiptail jq curl
```

### CurseForge API Key Setup

1. Go to [CurseForge Console](https://console.curseforge.com/)
2. Create an account or log in
3. Navigate to **API Keys**
4. Click **"Generate API Key"**
5. **Accept the Terms of Service** (very important!)
6. Copy your API key

### Installation

1. Clone this repository:
```bash
git clone https://github.com/KiritoGXE/Hytale-Mod-Manager.git
cd hytale-mod-manager
```

2. Make the script executable:
```bash
chmod +x mod-manager.sh
```

3. Edit the script and add your API key:
```bash
nano mod-manager.sh
```

Find this line:
```bash
API_KEY=""
```

And replace it with your key (use single quotes!):
```bash
API_KEY='$2a$10$YourActualAPIKeyHere...'
```

**Important:** Always use single quotes `'...'` for the API key because it contains `$` characters that would be interpreted as variables if you use double quotes.

4. (Optional) Customize the paths in the script:
```bash
HOMEDIR="/root/hytale"           # Main Hytale directory
MODS_DIR="$HOMEDIR/mods"         # Mods folder
```

## 💻 Usage

Simply run the script:
```bash
./mod-manager.sh
```

### Main Features

#### 1. Search and Install Mod
- Enter the mod name you want to search for
- Browse through results with descriptions
- Select a mod to install
- Confirm and download automatically

#### 2. Install Mod by ID
- If you know the CurseForge Project ID, enter it directly
- Faster than searching if you know what you want

#### 3. Update All Mods
- Checks all installed mods for updates
- Downloads and installs new versions automatically
- Shows progress with a nice progress bar
- Removes old versions automatically

#### 4. List Installed Mods
- Shows all your installed mods
- Displays mod names, file names, and versions

#### 5. Remove Mod
- Select a mod from a menu
- Confirm deletion
- Removes both the file and metadata

#### 6. Test API Connection
- Verifies your API key is working
- Shows helpful error messages if something is wrong
- Great for troubleshooting

## 📁 File Structure

```
/root/hytale/
├── mods/
│   ├── cool-mod-1.2.3.jar
│   ├── another-mod-2.1.0.jar
│   └── mod-metadata.json       # Automatically managed
└── Scripts/
    └── mod-manager.sh
```

The `mod-metadata.json` file stores information about each installed mod:
```json
{
  "cool-mod-1.2.3.jar": {
    "project_id": "123456",
    "file_id": "7891011",
    "name": "Cool Mod",
    "version": "1.2.3",
    "last_updated": "2026-01-20T12:00:00Z"
  }
}
```

## 🔧 Troubleshooting

### API Key Issues

**Error: API connection failed (HTTP 403)**

Solutions:
1. Wait 5-10 minutes after creating the key - they take time to activate
2. Make sure you accepted the Terms of Service on console.curseforge.com
3. Verify your email address on your CurseForge account
4. Check that you used **single quotes** `'...'` around the API key in the script
5. Try regenerating your API key

**Error: API Key is empty**

You forgot to add your API key to the script. Edit `mod-manager.sh` and add it to the `API_KEY` variable.

### Common Issues

**"No mods found" when searching**

The search uses gameId 432 (Minecraft) as a placeholder. When Hytale releases, you may need to update the gameId in the `search_mods()` function.

**Mods not updating**

- Check that the `mod-metadata.json` file exists and is valid JSON
- Try removing and reinstalling the mod
- Verify your internet connection

**whiptail not found**

Install it with: `sudo apt-get install whiptail`

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Improve documentation

## 📝 Notes

- This script is designed for **Linux servers**
- Tested on Debian/Ubuntu
- Should work on most distributions with bash 4.0+
- The script automatically manages mod metadata - don't edit `mod-metadata.json` manually unless you know what you're doing

## ⚠️ Important

- **Back up your mods folder** before using the auto-update feature for the first time
- The script will **automatically delete old mod versions** when updating
- Make sure the mods you install are compatible with your server version
- Always test mods on a development server first

## 📜 License

This project is free and open source. Do whatever you want with it! 🎉

## 🙏 Credits

- Uses the [CurseForge API](https://docs.curseforge.com/)
- Built with love for the Hytale community
- Terminal GUI powered by whiptail

---

**Disclaimer**: This is an unofficial tool and is not affiliated with Hypixel Studios, Hytale, or CurseForge. Use at your own risk!

## 🔗 Useful Links

- [CurseForge API Documentation](https://docs.curseforge.com/)
- [CurseForge Console](https://console.curseforge.com/)
- [Hytale Official Website](https://hytale.com/)

---

Made with ❤️ for the Hytale community
