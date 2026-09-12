#!/usr/bin/env python3
import subprocess
import json
import sys

def get_mako_history():
    try:
        # makoctl history の結果を取得
        result = subprocess.run(['makoctl', 'history'], capture_output=True, text=True)
        if result.returncode != 0:
            return 0
        
        history_data = json.loads(result.stdout)
        # data配列の長さが履歴件数
        return len(history_data.get('data', []))
    except Exception:
        return 0

def main():
    count = get_mako_history()
    
    # Waybar用 JSON 形式
    output = {
        "text": str(count) if count > 0 else "",
        "alt": "has-notifications" if count > 0 else "none",
        "class": "has-notifications" if count > 0 else "none",
        "tooltip": f"Notifications: {count}"
    }
    
    print(json.dumps(output))

if __name__ == "__main__":
    main()
