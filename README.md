## Configuration Setup

To run this project locally, you need to set up your configuration file:

1. Copy the template configuration file:
   ```bash
   cp Obsidian\ Nexus/Config.template.plist Obsidian\ Nexus/Config.plist
   ```

2. Edit `Config.plist` and replace `YOUR_API_KEY_HERE` with your Google Books API key.

3. Never commit your `Config.plist` file to version control.

Note: The app will still run without a valid API key, but book search functionality will be disabled. 