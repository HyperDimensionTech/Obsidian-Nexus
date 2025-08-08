# Getting Started with Pocket Dimension

Learn how to set up and start using Pocket Dimension for your collection management needs.

## Overview

Pocket Dimension is designed to help collectors organize and track their physical items with a focus on hierarchical location management, detailed item information, and QR code integration. This guide will help you get started with the app.

## Installation

### Requirements

- iOS 16.0 or later
- macOS 13.0 or later
- Xcode 14.0 or later (for developers)

### Download and Setup

1. Clone the repository or download the source code
2. Open the project in Xcode
3. Build and run the app on your device or simulator

## First Steps

### Creating Your First Location

Locations in Pocket Dimension are organized hierarchically, starting with rooms at the top level:

```swift
// Create a room (top-level location)
let office = StorageLocation(
    name: "Office",
    type: .room
)

// Create a bookshelf in the office
let bookshelf = StorageLocation(
    name: "Main Bookshelf",
    type: .bookshelf,
    parentId: office.id
)

// Add locations to the manager
try locationManager.addLocation(office)
try locationManager.addLocation(bookshelf)
```

### Adding Your First Item

Once you have locations set up, you can add items to your inventory:

```swift
// Create a new book
let book = InventoryItem(
    title: "Design Patterns",
    type: .book,
    condition: .good,
    locationId: bookshelf.id,
    price: Price(amount: 39.99, currency: .usd)
)

// Add the item to your inventory
try inventoryViewModel.addItem(book)
```

### Scanning QR Codes for Locations

Pocket Dimension allows you to generate and scan QR codes for locations:

```swift
// Generate a QR code for a location
if let qrImage = QRCodeService.shared.generateQRCode(for: bookshelf.id) {
    // Display or save the QR code
    imageView.image = qrImage
}

// Later, when scanning a QR code:
func handleScannedCode(_ code: String) {
    if let locationId = QRCodeService.shared.parseLocationQRCode(from: code),
       let location = locationManager.location(withId: locationId) {
        // Navigate to the location
        navigationCoordinator.navigate(to: .locationDetail(location))
    }
}
```

## Using the App

### Browsing Your Inventory

The app provides multiple ways to browse your inventory:

- **Inventory Tab**: View all items, sorted and grouped by your preferences
- **Locations Tab**: Browse items by their physical locations
- **Collections Tab**: View items organized by series, type, or author
- **Search**: Find items or locations by name, type, or other properties

### Managing Locations

The app lets you create a hierarchical organization of your physical storage:

1. **Rooms**: Top-level locations (e.g., Living Room, Office)
2. **Furniture**: Second-level locations (e.g., Bookshelf, Cabinet)
3. **Containers**: Storage within furniture (e.g., Box, Drawer)

You can:
- Add new locations
- Move locations in the hierarchy
- Generate QR codes for locations
- Scan QR codes to quickly navigate to a location

### Customizing Preferences

The app allows you to customize various aspects:

- **Theme**: Choose between light, dark, or system theme
- **View Style**: Grid, list, or compact
- **Display Options**: Choose what information to show for items
- **Default Currency**: Set your preferred currency for item prices

## Next Steps

Once you're familiar with the basics, you can explore more advanced features:

- Export and import your inventory data
- Create item collections and track completion
- Use the bulk edit features for efficient updates
- Set up custom search filters

## Troubleshooting

If you encounter issues:

- Check the app logs for error messages
- Verify that locations and items have valid IDs
- Ensure your database connection is working
- For persistent issues, try clearing the app cache or reinstalling 