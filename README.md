# Louisa WiFi Switcher for Raycast

A Raycast Script Command to quickly search, connect, and generate a QR code for Louisa Coffee shop Wi-Fi passwords. This tool allows you to easily switch to the correct Wi-Fi password for any Louisa Coffee location and display a QR code for fast mobile connection.

partly help by gemini

## Features
- **Search** for Louisa Coffee stores by name or keyword
- **Auto-connect** to the LouisaCoffee Wi-Fi network with the correct password
- **Generate a QR code** for easy mobile device connection
- **Interactive UI**: Use Raycast argument or a native macOS dialog for store selection

## Installation
1. **Clone this repository** to your local machine:
   ```sh
   git clone https://github.com/Watermelon-1234/LouisaInternetSwitch.git
   ```
2. **Add the folder to Raycast Script Commands**:
   - Open Raycast → Preferences → Extensions → Script Commands
   - Click "Add Script Folder" and select the cloned `LouisaInternetSwitch` directory
3. **(First-time setup)**: Run the script while connected to the internet. It will automatically download required dependencies (`jq`, `qrencode`) via Homebrew if missing, and fetch the latest password list.

## Usage
- Open Raycast and search for "Louisa WiFi Switcher"
- Enter a store keyword (optional) or leave blank to see all stores
- Select the desired store from the list
- The script will connect to the Wi-Fi and display a QR code for your phone

## Troubleshooting
- If you encounter issues with store passwords, please [open an issue](https://github.com/Watermelon-1234/LouisaInternetSwitch/issues) or submit a pull request with corrections.

## Requirements
- macOS with [Homebrew](https://brew.sh/) installed
- Raycast (with Script Commands enabled)

## License
MIT
