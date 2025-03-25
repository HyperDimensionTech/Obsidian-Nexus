# URL Scheme Configuration Instructions

To enable QR code scanning and deep linking for locations, you need to add a URL scheme to your Xcode project. Follow these steps:

1. Open your Xcode project
2. Select the "Pocket Dimension" target in the project navigator
3. Go to the "Info" tab
4. Expand the "URL Types" section (add it if it doesn't exist)
5. Click the "+" button to add a new URL Type
6. Configure it as follows:
   - Identifier: com.yourcompany.pocketdimension
   - URL Schemes: pocketdimension
   - Role: Viewer
7. Save and rebuild the project

This will register the "pocketdimension://" URL scheme with iOS, allowing QR codes to open the app and navigate to specific locations.

## How It Works

The QR codes generated for locations contain URLs in this format:
```
pocketdimension://location/[LOCATION-UUID]
```

When a user scans these QR codes:
1. If scanned from outside the app, iOS will open Pocket Dimension and pass the URL
2. The app will parse the URL and navigate to the specified location
3. If scanned from within the app, the app will directly navigate to the location

This enables a seamless workflow for managing items across multiple physical locations. 

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.pocketdimension</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>pocketdimension</string>
        </array>
    </dict>
</array>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>To save QR codes of locations to your photo library for printing and tagging physical locations.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>To save QR codes of locations to your photo library for printing and tagging physical locations.</string> 