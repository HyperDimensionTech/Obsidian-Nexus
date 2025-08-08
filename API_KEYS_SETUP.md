# 🔐 API Keys Setup Guide

This guide explains how to configure API keys for the Pocket Dimension app.

## 🚀 Quick Setup

1. **Copy the example configuration**:
   ```bash
   cp "Pocket Dimension/Config.example.plist" "Pocket Dimension/Config.plist"
   ```

2. **Edit `Config.plist`** with your actual API keys (see [Getting API Keys](#getting-api-keys) below)

3. **Build and run** the app

## 📁 Configuration Files

### `Config.plist` (Your actual keys - **NEVER commit this**)
- Contains your real API keys
- Automatically excluded from git via `.gitignore`
- Required for the app to function

### `Config.example.plist` (Template - safe to commit)
- Contains placeholder values
- Serves as a template for new developers
- Shows the required structure

## 🔑 Getting API Keys

### Google Books API (Required for book scanning)

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Create a new project** or select existing one
3. **Enable the Books API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Books API"
   - Click "Enable"
4. **Create credentials**:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy the generated key
5. **Add to Config.plist**:
   ```xml
   <key>GoogleBooksAPIKey</key>
   <string>YOUR_ACTUAL_API_KEY_HERE</string>
   ```

### Firebase (Optional - for cloud sync)

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Create a new project**
3. **Get your configuration**:
   - Project ID: Found in project settings
   - API Key: Found in project settings > Web API Key
4. **Add to Config.plist**:
   ```xml
   <key>FirebaseProjectID</key>
   <string>your-actual-project-id</string>
   <key>FirebaseAPIKey</key>
   <string>your-actual-api-key</string>
   ```

### Supabase (Optional - alternative cloud sync)

1. **Go to Supabase**: https://supabase.com/
2. **Create a new project**
3. **Get your configuration**:
   - URL: Found in Settings > API
   - Anon Key: Found in Settings > API
4. **Add to Config.plist**:
   ```xml
   <key>SupabaseURL</key>
   <string>https://your-project.supabase.co</string>
   <key>SupabaseKey</key>
   <string>your-actual-anon-key</string>
   ```

## 🔧 Configuration Structure

Your `Config.plist` should look like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for book scanning -->
    <key>GoogleBooksAPIKey</key>
    <string>YOUR_GOOGLE_BOOKS_API_KEY</string>
    
    <!-- Optional: Firebase cloud sync -->
    <key>FirebaseProjectID</key>
    <string>your-firebase-project-id</string>
    <key>FirebaseAPIKey</key>
    <string>your-firebase-api-key</string>
    
    <!-- Optional: Supabase cloud sync -->
    <key>SupabaseURL</key>
    <string>https://your-project.supabase.co</string>
    <key>SupabaseKey</key>
    <string>your-supabase-anon-key</string>
    
    <!-- Other configuration -->
    <key>AuthServiceBaseURL</key>
    <string>https://your-backend.com</string>
    
    <key>iCloudContainerIdentifier</key>
    <string>iCloud.com.hyperdimension.Pocket-Dimension</string>
    
    <!-- API Settings -->
    <key>APIConfiguration</key>
    <dict>
        <key>GoogleBooksMaxResults</key>
        <integer>40</integer>
        <key>RequestTimeout</key>
        <integer>30</integer>
        <key>EnableDebugLogging</key>
        <true/>
    </dict>
</dict>
</plist>
```

## 🚨 Security Notes

### What's Protected
- ✅ `Config.plist` is excluded from git
- ✅ API keys never appear in source code
- ✅ Placeholder values in committed files

### What You Must Do
- 🔒 **Never commit `Config.plist`** to version control
- 🔒 **Keep API keys private** - don't share them
- 🔒 **Rotate keys regularly** if they're compromised
- 🔒 **Use different keys** for development and production

## 🛠️ Troubleshooting

### "Google Books API key not configured"
- **Problem**: The app can't find or load your API key
- **Solution**: 
  1. Ensure `Config.plist` exists in the `Pocket Dimension/` folder
  2. Check that `GoogleBooksAPIKey` is not empty or placeholder text
  3. Verify the plist file is valid XML

### "Configuration file not found"
- **Problem**: `Config.plist` doesn't exist
- **Solution**: Copy `Config.example.plist` to `Config.plist`

### Build errors about missing Config.plist
- **Problem**: Xcode can't find the configuration file
- **Solution**: 
  1. Add `Config.plist` to your Xcode project
  2. Ensure it's in the correct target
  3. Check file permissions

### API requests failing
- **Problem**: Invalid or expired API keys
- **Solution**:
  1. Verify keys are correct in Google Cloud Console
  2. Check API quotas and limits
  3. Ensure Books API is enabled

## 📱 App Behavior

### With Google Books API configured:
- ✅ Barcode scanning works
- ✅ Book search by title/author works
- ✅ ISBN lookup works
- ✅ Full book metadata available

### Without Google Books API:
- ❌ Barcode scanning disabled
- ❌ Book search limited
- ⚠️ Manual entry still works
- ⚠️ App continues to function for inventory management

### Debug Information
The app logs configuration status on startup:
```
✅ GoogleBooksService: API key configured successfully
🔧 APIConfiguration: Configuration loaded successfully
📊 API Configuration Status:
  • Google Books API: ✅ Configured
  • Firebase: ❌ Not configured
  • Supabase: ❌ Not configured
```

## 🔄 Updating Configuration

To update API keys without rebuilding:
1. Edit `Config.plist`
2. Restart the app (configuration loads on startup)

For dynamic updates (advanced):
```swift
APIConfiguration.shared.reloadConfiguration()
```

## 📞 Support

If you encounter issues:
1. Check the console logs for error messages
2. Verify your API keys in the respective consoles
3. Ensure configuration file format is correct
4. File an issue with configuration status output

---

**Remember**: Keep your API keys secure and never commit them to version control! 🔒 