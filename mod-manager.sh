#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEDIR="/root/hytale"
MODS_DIR="$HOMEDIR/Server/mods"
METADATA_FILE="$MODS_DIR/mod-metadata.json"
CURSEFORGE_API="https://api.curseforge.com/v1"
API_KEY=''

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WEB_DIR="$SCRIPT_DIR/web"
WEB_PID_FILE="$WEB_DIR/server.pid"

mkdir -p "$MODS_DIR"
mkdir -p "$WEB_DIR/templates"

if [[ ! -f "$METADATA_FILE" ]]; then
    echo "{}" > "$METADATA_FILE"
fi

check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        echo -e "${RED}Error: whiptail is not installed${NC}"
        echo "Please install it with: sudo apt-get install whiptail"
        exit 1
    fi
}

check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        echo "Please install it with: sudo apt-get install jq"
        exit 1
    fi
}

check_python() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: python3 is not installed${NC}"
        echo "Please install it with: sudo apt-get install python3 python3-pip"
        return 1
    fi
    return 0
}

check_api_key() {
    if [[ -z "$API_KEY" ]]; then
        whiptail --title "API Key Missing" --msgbox "CurseForge API key is not configured.\n\nPlease edit this script and add your API key.\nGet one from: https://console.curseforge.com/" 12 60
        return 1
    fi
    return 0
}

test_api_connection() {
    if [[ -z "$API_KEY" ]]; then
        echo -e "${RED}✗ API Key is empty${NC}"
        return 1
    fi
    
    echo "Testing CurseForge API connection..."
    echo ""
    
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -H "x-api-key: $API_KEY" \
        -H "Accept: application/json" \
        -H "User-Agent: HytaleModManager/1.0" \
        "$CURSEFORGE_API/games")
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ API connection successful!${NC}"
        echo -e "${GREEN}✓ API key is valid and active${NC}"
        echo ""
        echo "You can now use all mod management features."
        return 0
    else
        echo -e "${RED}✗ API connection failed (HTTP $http_code)${NC}"
        echo ""
        echo "Possible solutions:"
        echo "  1. Wait 5-10 minutes if you just created the API key"
        echo "  2. Check if you accepted Terms of Service on console.curseforge.com"
        echo "  3. Verify your email on CurseForge"
        echo "  4. Regenerate your API key on console.curseforge.com"
        echo ""
        echo "API Key info:"
        echo "  Length: ${#API_KEY} characters"
        echo "  First 15 chars: ${API_KEY:0:15}..."
        return 1
    fi
}

setup_web_ui() {
    echo -e "${BLUE}Setting up Web UI...${NC}"
    echo ""
    
    if ! check_python; then
        echo ""
        echo -e "${RED}Python 3 is required for Web UI${NC}"
        read -p "Press enter to continue..."
        return 1
    fi
    
    echo "Checking Python packages..."
    if ! python3 -c "import flask" 2>/dev/null; then
        echo -e "${YELLOW}Flask not found. Installing required packages...${NC}"
        echo ""
        echo "Installing: flask flask-cors requests"
        echo ""
        
        if pip3 install flask flask-cors requests --quiet; then
            echo -e "${GREEN}✓ Packages installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install packages${NC}"
            echo "Try manually: pip3 install flask flask-cors requests"
            read -p "Press enter to continue..."
            return 1
        fi
    else
        echo -e "${GREEN}✓ Required packages already installed${NC}"
    fi
    
    echo ""
    echo "Creating Web UI files..."
    
    cat > "$WEB_DIR/app.py" << 'WEBUI_APP'
from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import requests
import json
import os

app = Flask(__name__)
CORS(app, 
     resources={r"/api/*": {"origins": "*"}},
     supports_credentials=True,
     allow_headers=["Content-Type", "Authorization"],
     methods=["GET", "POST", "DELETE", "OPTIONS"])

HOMEDIR = os.environ.get("HOMEDIR")
API_KEY = os.environ.get("CURSEFORGE_API_KEY")

if not HOMEDIR:
    raise RuntimeError("HOMEDIR non impostata nell'ambiente")

if not API_KEY:
    print("⚠ ATTENZIONE: CURSEFORGE_API_KEY non impostata")

MODS_DIR = os.path.join(HOMEDIR, "Server", "mods")
METADATA_FILE = os.path.join(MODS_DIR, "mod-metadata.json")
CURSEFORGE_API = "https://api.curseforge.com/v1"
API_KEY = "REPLACE_API_KEY"

os.makedirs(MODS_DIR, exist_ok=True)
if not os.path.exists(METADATA_FILE):
    with open(METADATA_FILE, 'w') as f:
        json.dump({}, f)

def get_metadata():
    with open(METADATA_FILE, 'r') as f:
        return json.load(f)

def save_metadata(data):
    with open(METADATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/test-connection', methods=['GET'])
def test_connection():
    if not API_KEY or not API_KEY.strip():
        return jsonify({"success": False, "error": "API key not configured"}), 400
    
    try:
        headers = {
            "x-api-key": API_KEY,
            "Accept": "application/json",
            "User-Agent": "HytaleModManager/1.0"
        }
        response = requests.get(f"{CURSEFORGE_API}/games", headers=headers, timeout=10)
        
        if response.status_code == 200:
            return jsonify({"success": True, "message": "API connection successful!"})
        else:
            return jsonify({"success": False, "error": f"API returned status {response.status_code}"}), 400
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/api/search', methods=['GET'])
def search_mods():
    query = request.args.get('q', '')
    if not query:
        return jsonify({"error": "Query parameter required"}), 400
    
    if not API_KEY or not API_KEY.strip():
        return jsonify({"error": "API key not configured"}), 400
    
    try:
        headers = {
            "x-api-key": API_KEY,
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0"
        }
        
        slug = query.lower().replace(' ', '-')
        response = requests.get(
            f"{CURSEFORGE_API}/mods/search?gameId=70216&slug={slug}",
            headers=headers,
            timeout=10
        )
        
        data = response.json()
        if not data.get('data'):
            response = requests.get(
                f"{CURSEFORGE_API}/mods/search?gameId=70216&searchFilter={query}&pageSize=50",
                headers=headers,
                timeout=10
            )
            data = response.json()
        
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/mods', methods=['GET'])
def list_mods():
    metadata = get_metadata()
    mods_list = []
    
    for filename, info in metadata.items():
        mods_list.append({
            "filename": filename,
            "name": info.get("name"),
            "version": info.get("version"),
            "project_id": info.get("project_id"),
            "file_id": info.get("file_id"),
            "last_updated": info.get("last_updated")
        })
    
    return jsonify(mods_list)

@app.route('/api/mods/<project_id>', methods=['POST'])
def install_mod(project_id):
    if not API_KEY or not API_KEY.strip():
        return jsonify({"error": "API key not configured"}), 400
    
    try:
        headers = {
            "x-api-key": API_KEY,
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0"
        }
        
        mod_info = requests.get(f"{CURSEFORGE_API}/mods/{project_id}", headers=headers, timeout=10)
        if mod_info.status_code != 200:
            return jsonify({"error": "Failed to fetch mod info"}), 400
        
        mod_data = mod_info.json()['data']
        
        files_info = requests.get(
            f"{CURSEFORGE_API}/mods/{project_id}/files?pageSize=1",
            headers=headers,
            timeout=10
        )
        if files_info.status_code != 200:
            return jsonify({"error": "Failed to fetch mod files"}), 400
        
        file_data = files_info.json()['data'][0]
        filename = file_data['fileName']
        download_url = file_data['downloadUrl']
        
        file_response = requests.get(download_url, stream=True, timeout=30)
        file_path = os.path.join(MODS_DIR, filename)
        
        with open(file_path, 'wb') as f:
            for chunk in file_response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        metadata = get_metadata()
        metadata[filename] = {
            "project_id": project_id,
            "file_id": str(file_data['id']),
            "name": mod_data['name'],
            "version": file_data['displayName'],
            "last_updated": file_data['fileDate']
        }
        save_metadata(metadata)
        
        return jsonify({
            "success": True,
            "message": f"Mod {mod_data['name']} installed successfully!",
            "mod": metadata[filename]
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/mods/<filename>', methods=['DELETE'])
def remove_mod(filename):
    try:
        metadata = get_metadata()
        
        if filename not in metadata:
            return jsonify({"error": "Mod not found"}), 404
        
        file_path = os.path.join(MODS_DIR, filename)
        if os.path.exists(file_path):
            os.remove(file_path)
        
        del metadata[filename]
        save_metadata(metadata)
        
        return jsonify({"success": True, "message": "Mod removed successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/mods/update-all', methods=['POST'])
def update_all_mods():
    if not API_KEY or not API_KEY.strip():
        return jsonify({"error": "API key not configured"}), 400
    
    try:
        metadata = get_metadata()
        updated_mods = []
        
        headers = {
            "x-api-key": API_KEY,
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0"
        }
        
        for filename, info in list(metadata.items()):
            project_id = info['project_id']
            current_file_id = info['file_id']
            
            files_info = requests.get(
                f"{CURSEFORGE_API}/mods/{project_id}/files?pageSize=1",
                headers=headers,
                timeout=10
            )
            
            if files_info.status_code != 200:
                continue
            
            file_data = files_info.json()['data'][0]
            latest_file_id = str(file_data['id'])
            
            if latest_file_id != current_file_id:
                new_filename = file_data['fileName']
                download_url = file_data['downloadUrl']
                
                file_response = requests.get(download_url, stream=True, timeout=30)
                new_file_path = os.path.join(MODS_DIR, new_filename)
                
                with open(new_file_path, 'wb') as f:
                    for chunk in file_response.iter_content(chunk_size=8192):
                        f.write(chunk)
                
                old_file_path = os.path.join(MODS_DIR, filename)
                if os.path.exists(old_file_path):
                    os.remove(old_file_path)
                
                del metadata[filename]
                metadata[new_filename] = {
                    "project_id": project_id,
                    "file_id": latest_file_id,
                    "name": info['name'],
                    "version": file_data['displayName'],
                    "last_updated": file_data['fileDate']
                }
                
                updated_mods.append(info['name'])
        
        save_metadata(metadata)
        
        return jsonify({
            "success": True,
            "updated_count": len(updated_mods),
            "updated_mods": updated_mods
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("Starting Hytale Mod Manager Web UI...")
    print("Access the interface at: http://localhost:5000")
    print("Press CTRL+C to stop the server")
    app.run(host='0.0.0.0', port=5000, debug=False)
WEBUI_APP

    sed -i "s/REPLACE_API_KEY/$API_KEY/" "$WEB_DIR/app.py"

    if [[ ! -f "$WEB_DIR/templates/index.html" ]]; then
        echo -e "${YELLOW}⚠ index.html not found in templates/${NC}"
        echo "Please create the file: $WEB_DIR/templates/index.html"
        echo "You can download it from the repository or create it manually."
        echo ""
        read -p "Press enter to continue..."
        return 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ Web UI setup complete!${NC}"
    echo ""
    read -p "Press enter to continue..."
}

start_web_ui() {
    if [[ -f "$WEB_PID_FILE" ]] && kill -0 $(cat "$WEB_PID_FILE") 2>/dev/null; then
        whiptail --title "Web UI Status" --msgbox "Web UI is already running!\n\nAccess it at: http://localhost:5000\n\nPID: $(cat $WEB_PID_FILE)" 12 60
        return
    fi
    
    if [[ ! -f "$WEB_DIR/app.py" ]]; then
        if whiptail --title "Setup Required" --yesno "Web UI is not set up yet.\n\nDo you want to set it up now?" 10 60; then
            setup_web_ui
            if [[ ! -f "$WEB_DIR/app.py" ]]; then
                return
            fi
        else
            return
        fi
    fi
    
    echo -e "${BLUE}Starting Web UI...${NC}"
    echo ""
    
    cd "$WEB_DIR"
    HOMEDIR="$HOMEDIR" CURSEFORGE_API_KEY="$API_KEY" nohup python3 app.py > server.log 2>&1 &
    echo $! > "$WEB_PID_FILE"
    
    sleep 2
    
    if kill -0 $(cat "$WEB_PID_FILE") 2>/dev/null; then
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        echo -e "${GREEN}✓ Web UI started successfully!${NC}"
        echo ""
        echo -e "${GREEN}Access the Web UI at:${NC}"
        echo -e "  Local:   ${BLUE}http://localhost:5000${NC}"
        echo -e "  Network: ${BLUE}http://$IP_ADDRESS:5000${NC}"
        echo ""
        echo -e "${YELLOW}The server is running in background${NC}"
        echo -e "Use 'Stop Web UI' option to stop it"
        echo ""
        echo "Server log: $WEB_DIR/server.log"
        echo ""
    else
        echo -e "${RED}✗ Failed to start Web UI${NC}"
        echo "Check the log: $WEB_DIR/server.log"
        echo ""
        rm -f "$WEB_PID_FILE"
    fi
    
    read -p "Press enter to continue..."
}

stop_web_ui() {
    if [[ ! -f "$WEB_PID_FILE" ]]; then
        whiptail --title "Web UI Status" --msgbox "Web UI is not running." 8 50
        return
    fi
    
    PID=$(cat "$WEB_PID_FILE")
    
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        rm -f "$WEB_PID_FILE"
        whiptail --title "Web UI Stopped" --msgbox "Web UI has been stopped successfully." 8 50
    else
        rm -f "$WEB_PID_FILE"
        whiptail --title "Web UI Status" --msgbox "Web UI was not running." 8 50
    fi
}

web_ui_status() {
    if [[ -f "$WEB_PID_FILE" ]] && kill -0 $(cat "$WEB_PID_FILE") 2>/dev/null; then
        PID=$(cat "$WEB_PID_FILE")
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        
        echo -e "${GREEN}✓ Web UI is running${NC}"
        echo ""
        echo "PID: $PID"
        echo ""
        echo -e "${GREEN}Access URLs:${NC}"
        echo -e "  Local:   ${BLUE}http://localhost:5000${NC}"
        echo -e "  Network: ${BLUE}http://$IP_ADDRESS:5000${NC}"
        echo ""
        echo "Log file: $WEB_DIR/server.log"
        echo ""
        echo "Last 10 log lines:"
        echo "---"
        tail -n 10 "$WEB_DIR/server.log" 2>/dev/null || echo "No logs available"
    else
        echo -e "${RED}✗ Web UI is not running${NC}"
    fi
    echo ""
    read -p "Press enter to continue..."
}

get_mod_info() {
    local project_id=$1
    
    response=$(curl -s -H "x-api-key: $API_KEY" \
        -H "Accept: application/json" \
        -H "User-Agent: Mozilla/5.0" \
        "$CURSEFORGE_API/mods/$project_id")
    
    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        echo "$response"
        return 0
    else
        return 1
    fi
}

get_latest_file() {
    local project_id=$1
    
    response=$(curl -s -H "x-api-key: $API_KEY" \
        -H "Accept: application/json" \
        -H "User-Agent: Mozilla/5.0" \
        "$CURSEFORGE_API/mods/$project_id/files?pageSize=1")
    
    if echo "$response" | jq -e '.data[0]' > /dev/null 2>&1; then
        echo "$response"
        return 0
    else
        return 1
    fi
}

download_mod() {
    local download_url=$1
    local filename=$2
    
    curl -L -o "$MODS_DIR/$filename" "$download_url"
    return $?
}

search_mods() {
    if ! check_api_key; then
        return 1
    fi
    
    search_query=$(whiptail --inputbox "Enter mod name to search:" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$search_query" ]; then
        return 1
    fi
    
    whiptail --title "Searching" --infobox "Searching for mods..." 8 50
    
    search_query_encoded=$(printf '%s' "$search_query" | jq -sRr @uri)
    
    slug_query=$(echo "$search_query" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    response=$(curl -s -H "x-api-key: $API_KEY" \
        -H "Accept: application/json" \
        -H "User-Agent: Mozilla/5.0" \
        "$CURSEFORGE_API/mods/search?gameId=70216&slug=$slug_query")
    
    if ! echo "$response" | jq -e '.data[0]' > /dev/null 2>&1; then
        response=$(curl -s -H "x-api-key: $API_KEY" \
            -H "Accept: application/json" \
            -H "User-Agent: Mozilla/5.0" \
            "$CURSEFORGE_API/mods/search?gameId=70216&searchFilter=$search_query_encoded&pageSize=50&index=0")
    fi
    
    if ! echo "$response" | jq -e '.data[0]' > /dev/null 2>&1; then
        simple_encoded=$(echo "$search_query" | sed 's/ /%20/g')
        response=$(curl -s -H "x-api-key: $API_KEY" \
            -H "Accept: application/json" \
            -H "User-Agent: Mozilla/5.0" \
            "$CURSEFORGE_API/mods/search?gameId=70216&searchFilter=$simple_encoded&pageSize=50")
    fi
    
    if ! echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        whiptail --title "Error" --msgbox "Search failed. API response:\n\n$(echo "$response" | jq -r '.message // "Unknown error"')" 12 60
        return 1
    fi
    
    result_count=$(echo "$response" | jq '.data | length')
    
    if [ "$result_count" -eq 0 ]; then
        whiptail --title "No Results" --msgbox "No mods found for: '$search_query'\n\nTips:\n- Try using fewer words\n- Check spelling\n- Use 'Install mod by ID' option instead\n- The mod might not be on CurseForge" 14 65
        return 1
    fi
    
    menu_options=()
    i=0
    while [ $i -lt $result_count ]; do
        mod_id=$(echo "$response" | jq -r ".data[$i].id")
        mod_name=$(echo "$response" | jq -r ".data[$i].name")
        mod_summary=$(echo "$response" | jq -r ".data[$i].summary // \"No description\"" | cut -c1-50)
        downloads=$(echo "$response" | jq -r ".data[$i].downloadCount // 0")
        menu_options+=("$mod_id" "$mod_name (${downloads} DL) - ${mod_summary}...")
        i=$((i + 1))
    done
    
    selected=$(whiptail --title "Search Results: $search_query ($result_count found)" --menu "Select a mod to install:" 20 78 12 "${menu_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$selected" ]; then
        return 1
    fi
    
    install_mod_by_id "$selected"
}

install_mod_by_id() {
    local project_id=$1

    whiptail --title "Downloading" --infobox "Fetching mod information..." 8 50

    mod_info=$(get_mod_info "$project_id")
    if [ $? -ne 0 ]; then
        whiptail --title "Error" --msgbox "Failed to fetch mod information.\nCheck the Project ID and your API key." 10 60
        return 1
    fi
    
    mod_name=$(echo "$mod_info" | jq -r '.data.name')
    mod_summary=$(echo "$mod_info" | jq -r '.data.summary')

    if ! whiptail --title "Confirm Installation" --yesno "Mod: $mod_name\n\n$mod_summary\n\nDo you want to install this mod?" 15 70; then
        return 1
    fi

    whiptail --title "Downloading" --infobox "Fetching latest version..." 8 50
    
    file_info=$(get_latest_file "$project_id")
    if [ $? -ne 0 ]; then
        whiptail --title "Error" --msgbox "Failed to fetch mod files." 10 60
        return 1
    fi
    
    file_id=$(echo "$file_info" | jq -r '.data[0].id')
    filename=$(echo "$file_info" | jq -r '.data[0].fileName')
    download_url=$(echo "$file_info" | jq -r '.data[0].downloadUrl')
    display_name=$(echo "$file_info" | jq -r '.data[0].displayName')
    file_date=$(echo "$file_info" | jq -r '.data[0].fileDate')

    whiptail --title "Downloading" --infobox "Downloading $filename..." 8 50
    
    if download_mod "$download_url" "$filename"; then
        temp_file=$(mktemp)
        jq --arg filename "$filename" \
           --arg project_id "$project_id" \
           --arg file_id "$file_id" \
           --arg name "$mod_name" \
           --arg version "$display_name" \
           --arg date "$file_date" \
           '. + {($filename): {project_id: $project_id, file_id: $file_id, name: $name, version: $version, last_updated: $date}}' \
           "$METADATA_FILE" > "$temp_file"
        
        mv "$temp_file" "$METADATA_FILE"
        
        whiptail --title "Success" --msgbox "Mod installed successfully!\n\nName: $mod_name\nFile: $filename" 12 60
    else
        whiptail --title "Error" --msgbox "Failed to download mod file." 10 60
        return 1
    fi
}

install_mod() {
    if ! check_api_key; then
        return 1
    fi

    project_id=$(whiptail --inputbox "Enter CurseForge Project ID:" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$project_id" ]; then
        return 1
    fi
    
    install_mod_by_id "$project_id"
}

list_mods() {
    if [[ ! -s "$METADATA_FILE" ]] || [[ $(jq 'length' "$METADATA_FILE") -eq 0 ]]; then
        whiptail --title "Installed Mods" --msgbox "No mods installed yet." 10 60
        return
    fi
    
    mod_list=""
    while IFS= read -r filename; do
        name=$(jq -r --arg f "$filename" '.[$f].name' "$METADATA_FILE")
        version=$(jq -r --arg f "$filename" '.[$f].version' "$METADATA_FILE")
        mod_list+="$name\n  File: $filename\n  Version: $version\n\n"
    done < <(jq -r 'keys[]' "$METADATA_FILE")
    
    whiptail --title "Installed Mods" --msgbox "$mod_list" 20 70 --scrolltext
}

update_mods() {
    if ! check_api_key; then
        return 1
    fi
    
    if [[ ! -s "$METADATA_FILE" ]] || [[ $(jq 'length' "$METADATA_FILE") -eq 0 ]]; then
        whiptail --title "Update Mods" --msgbox "No mods installed yet." 10 60
        return
    fi
    
    updated_count=0
    total_count=$(jq 'length' "$METADATA_FILE")
    current=0
    
    while IFS= read -r filename; do
        current=$((current + 1))
        project_id=$(jq -r --arg f "$filename" '.[$f].project_id' "$METADATA_FILE")
        current_file_id=$(jq -r --arg f "$filename" '.[$f].file_id' "$METADATA_FILE")
        mod_name=$(jq -r --arg f "$filename" '.[$f].name' "$METADATA_FILE")
        
        whiptail --title "Updating" --gauge "Checking $mod_name ($current/$total_count)..." 8 60 $((current * 100 / total_count))

        file_info=$(get_latest_file "$project_id")
        if [ $? -ne 0 ]; then
            continue
        fi
        
        latest_file_id=$(echo "$file_info" | jq -r '.data[0].id')

        if [[ "$latest_file_id" != "$current_file_id" ]]; then
            new_filename=$(echo "$file_info" | jq -r '.data[0].fileName')
            download_url=$(echo "$file_info" | jq -r '.data[0].downloadUrl')
            display_name=$(echo "$file_info" | jq -r '.data[0].displayName')
            file_date=$(echo "$file_info" | jq -r '.data[0].fileDate')

            if download_mod "$download_url" "$new_filename"; then
                rm -f "$MODS_DIR/$filename"

                temp_file=$(mktemp)
                jq --arg old "$filename" \
                   --arg new "$new_filename" \
                   --arg file_id "$latest_file_id" \
                   --arg version "$display_name" \
                   --arg date "$file_date" \
                   '. as $root | .[$old] as $old_data | del(.[$old]) | . + {($new): ($old_data | .file_id = $file_id | .version = $version | .last_updated = $date)}' \
                   "$METADATA_FILE" > "$temp_file"
                
                mv "$temp_file" "$METADATA_FILE"
                updated_count=$((updated_count + 1))
            fi
        fi
    done < <(jq -r 'keys[]' "$METADATA_FILE")
    
    if [ $updated_count -eq 0 ]; then
        whiptail --title "Update Complete" --msgbox "All mods are up to date!" 10 60
    else
        whiptail --title "Update Complete" --msgbox "Updated $updated_count mod(s) successfully!" 10 60
    fi
}

remove_mod() {
    if [[ ! -s "$METADATA_FILE" ]] || [[ $(jq 'length' "$METADATA_FILE") -eq 0 ]]; then
        whiptail --title "Remove Mod" --msgbox "No mods installed yet." 10 60
        return
    fi
    
    menu_options=()
    while IFS= read -r filename; do
        name=$(jq -r --arg f "$filename" '.[$f].name' "$METADATA_FILE")
        menu_options+=("$filename" "$name")
    done < <(jq -r 'keys[]' "$METADATA_FILE")
    
    selected=$(whiptail --title "Remove Mod" --menu "Select mod to remove:" 20 70 10 "${menu_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    
    if [ $exitstatus != 0 ] || [ -z "$selected" ]; then
        return 1
    fi
    
    mod_name=$(jq -r --arg f "$selected" '.[$f].name' "$METADATA_FILE")
    
    if whiptail --title "Confirm Removal" --yesno "Remove $mod_name?\n\nFile: $selected" 10 60; then
        rm -f "$MODS_DIR/$selected"
        
        temp_file=$(mktemp)
        jq --arg f "$selected" 'del(.[$f])' "$METADATA_FILE" > "$temp_file"
        mv "$temp_file" "$METADATA_FILE"
        
        whiptail --title "Success" --msgbox "Mod removed successfully!" 10 60
    fi
}

web_ui_menu() {
    while true; do
        if [[ -f "$WEB_PID_FILE" ]] && kill -0 $(cat "$WEB_PID_FILE") 2>/dev/null; then
            web_status="Running ✓"
        else
            web_status="Stopped ✗"
        fi
        
        choice=$(whiptail --title "Web UI Manager" --menu "Web UI Status: $web_status" 18 60 6 \
            "1" "Start Web UI" \
            "2" "Stop Web UI" \
            "3" "Web UI Status & Logs" \
            "4" "Setup/Reinstall Web UI" \
            "5" "Back to main menu" 3>&1 1>&2 2>&3)
        
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            break
        fi
        
        case $choice in
            1)
                start_web_ui
                ;;
            2)
                stop_web_ui
                ;;
            3)
                web_ui_status
                ;;
            4)
                setup_web_ui
                ;;
            5)
                break
                ;;
        esac
    done
}

main_menu() {
    while true; do
        choice=$(whiptail --title "Hytale Mod Manager" --menu "Choose an option:" 24 60 10 \
            "1" "Search and install mod" \
            "2" "Install mod by ID" \
            "3" "Update all mods" \
            "4" "List installed mods" \
            "5" "Remove mod" \
            "6" "Test API connection" \
            "7" "Web UI Manager" \
            "8" "Exit" 3>&1 1>&2 2>&3)
        
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            break
        fi
        
        case $choice in
            1)
                search_mods
                ;;
            2)
                install_mod
                ;;
            3)
                update_mods
                ;;
            4)
                list_mods
                ;;
            5)
                remove_mod
                ;;
            6)
                test_api_connection
                read -p "Press enter to continue..."
                ;;
            7)
                web_ui_menu
                ;;
            8)
                if [[ -f "$WEB_PID_FILE" ]] && kill -0 $(cat "$WEB_PID_FILE") 2>/dev/null; then
                    if whiptail --title "Exit" --yesno "Web UI is still running.\n\nDo you want to stop it before exiting?" 10 60; then
                        stop_web_ui
                    fi
                fi
                break
                ;;
        esac
    done
}

check_whiptail
check_jq

main_menu

echo -e "${GREEN}Thank you for using Hytale Mod Manager!${NC}"
