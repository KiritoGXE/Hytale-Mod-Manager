#!/bin/bash

HOMEDIR="/root/hytale"
MODS_DIR="$HOMEDIR/Server/mods"
METADATA_FILE="$MODS_DIR/mod-metadata.json"
CURSEFORGE_API="https://api.curseforge.com/v1"
API_KEY=''

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$MODS_DIR"

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

main_menu() {
    while true; do
        choice=$(whiptail --title "Hytale Mod Manager" --menu "Choose an option:" 22 60 8 \
            "1" "Search and install mod" \
            "2" "Install mod by ID" \
            "3" "Update all mods" \
            "4" "List installed mods" \
            "5" "Remove mod" \
            "6" "Test API connection" \
            "7" "Exit" 3>&1 1>&2 2>&3)
        
        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            break
        fi
        
        case $choice in
            1) search_mods ;;
            2) install_mod ;;
            3) update_mods ;;
            4) list_mods ;;
            5) remove_mod ;;
            6) test_api_connection; read -p "Press enter to continue..." ;;
            7) break ;;
        esac
    done
}

check_whiptail
check_jq
main_menu

echo -e "${GREEN}Thank you for using Hytale Mod Manager!${NC}"
