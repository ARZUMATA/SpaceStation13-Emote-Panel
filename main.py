import webview
import json
import os
import threading
import time
import pygetwindow as gw
import pyautogui
import keyboard
from pynput import mouse
import win32gui
import win32process
import ctypes
from ctypes import wintypes
import sys

# Global variables
biggest_dialog_hwnd = 0
biggest_dialog_pid = 0
button_hotkey = "t"
button_hotkey_emote = "m"
send_keys_to_game = True
is_hidden = False
CONFIG_LOAD_DELAY = 500  # milliseconds

# Window configuration
window_config = {
    "x": 100,
    "y": 100,
    "width": 800,
    "height": 600,
    "maximized": False,
    "hiddenX": 100,
    "hiddenY": 100,
    "hiddenWidth": 150,
    "hiddenHeight": 50
}

# Find the biggest dialog window
def find_game_window():
    global biggest_dialog_hwnd, biggest_dialog_pid
    
    biggest_hwnd = 0
    biggest_area = 0
    biggest_pid = 0
    
    def enum_windows_callback(hwnd, lParam):
        nonlocal biggest_hwnd, biggest_area, biggest_pid
        
        # Check if window class is #32770 (dialog)
        class_name = win32gui.GetClassName(hwnd)
        if class_name == "#32770":
            # Get window position and size
            try:
                rect = win32gui.GetWindowRect(hwnd)
                x, y, w, h = rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]
                area = w * h
                
                # Get process ID
                _, pid = win32process.GetWindowThreadProcessId(hwnd)
                
                # Check if this window is bigger
                if area > biggest_area:
                    biggest_area = area
                    biggest_hwnd = hwnd
                    biggest_pid = pid
            except:
                pass
        return True
    
    # Enumerate all windows
    win32gui.EnumWindows(enum_windows_callback, 0)
    
    # Store results
    biggest_dialog_hwnd = biggest_hwnd
    biggest_dialog_pid = biggest_pid
    
    if biggest_hwnd != 0:
        title = win32gui.GetWindowText(biggest_hwnd)
        rect = win32gui.GetWindowRect(biggest_hwnd)
        x, y, w, h = rect[0], rect[1], rect[2] - rect[0], rect[3] - rect[1]
        print(f"Biggest Dialog Window: HWND={biggest_hwnd}, PID={biggest_pid}, Title='{title}', Pos={x},{y} Size={w}x{h} Area={biggest_area}")
    else:
        print("No dialog windows found.")

# Validate window position
def validate_window_position():
    global window_config
    
    # Get screen dimensions
    screen_width = ctypes.windll.user32.GetSystemMetrics(0)
    screen_height = ctypes.windll.user32.GetSystemMetrics(1)
    
    # Ensure window is within bounds
    window_config["x"] = max(0, min(window_config["x"], screen_width - 100))
    window_config["y"] = max(0, min(window_config["y"], screen_height - 100))
    window_config["width"] = max(100, min(window_config["width"], screen_width))
    window_config["height"] = max(100, min(window_config["height"], screen_height))

# Save window configuration
def save_window_config():
    global window_config, is_hidden, button_hotkey, button_hotkey_emote
    
    # Default values
    config = {
        "buttonWidth": 190,
        "buttonHeight": 35,
        "buttonSpacing": 5,
        "hiddenWidth": window_config["hiddenWidth"],
        "hiddenHeight": window_config["hiddenHeight"],
        "hiddenX": window_config["hiddenX"],
        "hiddenY": window_config["hiddenY"],
        "x": window_config["x"],
        "y": window_config["y"],
        "width": window_config["width"],
        "height": window_config["height"],
        "maximized": window_config["maximized"],
        "isHidden": is_hidden,
        "buttonHotkey": button_hotkey,
        "buttonHotkeyEmote": button_hotkey_emote
    }
    
    # Read existing config to preserve button properties
    config_path = "configs/config.json"
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                existing_config = json.load(f)
                
            # Preserve specific properties
            for key in ["buttonWidth", "buttonHeight", "buttonSpacing", "buttonHotkey", "buttonHotkeyEmote"]:
                if key in existing_config:
                    config[key] = existing_config[key]
        except:
            pass
    
    # Create configs directory if it doesn't exist
    os.makedirs("configs", exist_ok=True)
    
    # Write config to file
    try:
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2)
    except Exception as e:
        print(f"Error saving config: {e}")

# Load and send configurations
def load_and_send_configs():
    global window_config, is_hidden, button_hotkey
    
    config_path = "configs/config.json"
    if not os.path.exists(config_path):
        return
    
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config_content = json.load(f)
        
        # Extract window position values
        for key in ["x", "y", "width", "height", "hiddenWidth", "hiddenHeight", "hiddenX", "hiddenY"]:
            if key in config_content:
                window_config[key] = config_content[key]
        
        # Extract boolean values
        if "maximized" in config_content:
            window_config["maximized"] = config_content["maximized"]
        if "isHidden" in config_content:
            is_hidden = config_content["isHidden"]
        
        # Extract button hotkey
        if "buttonHotkey" in config_content:
            button_hotkey = config_content["buttonHotkey"]
            
        # Validate window position
        validate_window_position()
        
        # Send configs to web with delay
        threading.Timer(CONFIG_LOAD_DELAY / 1000, send_config_data).start()
        
    except Exception as e:
        print(f"Error loading config: {e}")

# Send configuration data to web
def send_config_data():
    global window
    
    config_path = "configs/config.json"
    if not os.path.exists(config_path):
        return
    
    try:
        # Load main config
        with open(config_path, 'r', encoding='utf-8') as f:
            config_content = json.load(f)
        
        # Send main config
        window.evaluate_js(f"window.handleConfigMessage({json.dumps(config_content)})")
        
        # Load and send character configs
        char_configs = []
        if os.path.exists("configs"):
            for filename in os.listdir("configs"):
                if filename != "config.json" and filename.endswith(".json"):
                    try:
                        with open(os.path.join("configs", filename), 'r', encoding='utf-8') as f:
                            char_configs.append(json.load(f))
                    except:
                        pass
        
        # Send character configs
        window.evaluate_js(f"window.handleCharConfigsMessage({json.dumps(char_configs)})")
        
    except Exception as e:
        print(f"Error sending config data: {e}")

# Send raw key
def send_raw_key(key):
    try:
        # Handle special keys
        special_keys = {
            "Enter": "enter",
            "Space": "space",
            "Tab": "tab",
            "Esc": "esc",
            "Backspace": "backspace"
        }
        
        if key in special_keys:
            pyautogui.press(special_keys[key])
            return
        
        # Handle single character keys
        if len(key) == 1:
            pyautogui.press(key.lower())
            return
        
        # Handle key combinations
        pyautogui.hotkey(*key.split('+'))
    except Exception as e:
        print(f"Error sending key: {e}")

# Web callback functions
def web_button_click_event(button_data):
    global biggest_dialog_hwnd, button_hotkey, button_hotkey_emote, send_keys_to_game, window
    
    try:
        # Parse button data
        if isinstance(button_data, str):
            button_data = json.loads(button_data)
        
        command = button_data.get("command", "")
        is_emote = button_data.get("emote", False)
        
        # Check if we have a valid HWND
        if biggest_dialog_hwnd == 0:
            print("No target window found to send hotkey to.")
            return
        
        # Focus the window using its HWND
        try:
            win32gui.SetForegroundWindow(biggest_dialog_hwnd)
        except:
            pass
        
        # Check if we should send keys to the game
        if not send_keys_to_game:
            print("SendInput skipped - sendKeysToGame is false")
            return
        
        # Copy command to clipboard and paste it
        if not command:
            return
        
        # Save current clipboard
        old_clipboard = pyautogui.hotkey('ctrl', 'c')
        time.sleep(0.1)
        
        # Set new clipboard content
        import pyperclip
        pyperclip.copy(command)
        time.sleep(0.1)
        
        # Determine which hotkey to send based on emote flag
        hotkey_to_send = button_hotkey_emote if is_emote else button_hotkey
        
        # Send the configured hotkey
        send_raw_key(hotkey_to_send)
        time.sleep(0.1)
        
        # Paste the command using Ctrl+V
        pyautogui.hotkey('ctrl', 'v')
        print(f"Sent command: {command}")
        print(f"Hotkey used: {hotkey_to_send} (Emote: {is_emote})")
        
        time.sleep(0.05)
        pyautogui.press('enter')
        
        # Restore clipboard
        if old_clipboard:
            pyperclip.copy(old_clipboard)
        
        # Ensure our WebView window stays on top
        try:
            hwnd = win32gui.FindWindow(None, "WebViewGui Example")
            if hwnd:
                win32gui.SetWindowPos(hwnd, win32con.HWND_TOPMOST, 0, 0, 0, 0, 
                                    win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
        except:
            pass
            
    except Exception as e:
        print(f"Error in button click event: {e}")

def web_panel_toggle_event(action):
    global is_hidden, window_config, window
    
    print(f"PanelToggleEvent received: {action}")
    
    if action == "hide":
        is_hidden = True
        # Update window to hidden state
        window.resize(window_config["hiddenWidth"], window_config["hiddenHeight"])
        window.move(window_config["hiddenX"], window_config["hiddenY"])
        print(f"Window hidden: {window_config['hiddenX']},{window_config['hiddenY']} {window_config['hiddenWidth']}x{window_config['hiddenHeight']}")
    elif action == "show":
        is_hidden = False
        # Restore normal window
        if "width" in window_config and "height" in window_config:
            window.resize(window_config["width"], window_config["height"])
            window.move(window_config["x"], window_config["y"])
            print(f"Window shown: {window_config['width']}x{window_config['height']}")
        else:
            # Fallback to default size
            window.resize(800, 600)
            print("Window shown: 800x600 (fallback)")

def web_window_move_event(x, y):
    global is_hidden, window_config, window
    
    # Move the window to the new position
    window.move(int(x), int(y))
    print(f"Window moved to: {x},{y}")
    
    # Save position based on current state
    try:
        current_x, current_y = window.x, window.y
        if is_hidden:
            window_config["hiddenX"] = current_x
            window_config["hiddenY"] = current_y
        else:
            window_config["x"] = current_x
            window_config["y"] = current_y
        save_window_config()  # Save immediately
    except:
        pass

# Window event handlers
def window_close():
    save_window_config()
    # Exit application
    os._exit(0)

# Check window position periodically
def check_window_position():
    global window, window_config, is_hidden
    
    while True:
        try:
            time.sleep(1)
            # Get current window position
            current_x, current_y = window.x, window.y
            current_width, current_height = window.width, window.height
            
            if is_hidden:
                # Update hidden position/size
                if (current_x != window_config["hiddenX"] or current_y != window_config["hiddenY"] or 
                    current_width != window_config["hiddenWidth"] or current_height != window_config["hiddenHeight"]):
                    window_config["hiddenX"] = current_x
                    window_config["hiddenY"] = current_y
                    window_config["hiddenWidth"] = current_width
                    window_config["hiddenHeight"] = current_height
                    save_window_config()
            else:
                # Update normal position/size
                if (current_x != window_config["x"] or current_y != window_config["y"] or 
                    current_width != window_config["width"] or current_height != window_config["height"]):
                    window_config["x"] = current_x
                    window_config["y"] = current_y
                    window_config["width"] = current_width
                    window_config["height"] = current_height
                    save_window_config()
        except:
            pass

# Ensure WebView stays on top
def ensure_webview_on_top():
    while True:
        try:
            time.sleep(1)
            hwnd = win32gui.FindWindow(None, "WebViewGui Example")
            if hwnd:
                import win32con
                win32gui.SetWindowPos(hwnd, win32con.HWND_TOPMOST, 0, 0, 0, 0, 
                                    win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
        except:
            pass

# Create API for JavaScript communication
class Api:
    def button_click_event(self, button_data):
        web_button_click_event(button_data)
        return "OK"
    
    def panel_toggle_event(self, action):
        web_panel_toggle_event(action)
        return "OK"
    
    def window_move_event(self, x, y):
        web_window_move_event(x, y)
        return "OK"

# Main function
def main():
    global window
    
    # Find game window
    find_game_window()
    
    # Create API instance
    api = Api()
    
    # Create webview window
    window = webview.create_window(
        "WebViewGui Example",
        "Pages/index.html",
        width=window_config["width"],
        height=window_config["height"],
        x=window_config["x"],
        y=window_config["y"],
        resizable=True,
        frameless=True
    )
    
    # Load and send configs
    load_and_send_configs()
    
    # Start background threads
    threading.Thread(target=check_window_position, daemon=True).start()
    threading.Thread(target=ensure_webview_on_top, daemon=True).start()
    
    # Start webview
    webview.start(debug=True)

if __name__ == "__main__":
    main()