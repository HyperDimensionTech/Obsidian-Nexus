# Obsidian Nexus

A powerful inventory management app for collectors, designed to help organize, track, and search your physical collections.

## Overview

Obsidian Nexus is a SwiftUI app for iOS and macOS that allows collectors to:

- Organize items in a hierarchical location structure
- Track detailed information about collectibles
- Generate QR codes for physical locations
- Scan QR codes to quickly access inventory information
- Search and filter collections
- Export and import data

## Architecture

The app follows a clean architecture approach with the following key components:

### Models

- `InventoryItem`: Represents a collectible item with properties like title, type, condition, price
- `StorageLocation`: Represents a physical location with support for hierarchical structure
- `UserPreferences`: Manages user settings and preferences

### View Models

- `InventoryViewModel`: Manages the inventory item collection and operations
- `NavigationCoordinator`: Coordinates navigation between views

### Managers

- `LocationManager`: Manages the location hierarchy and relationships
- `StorageManager`: Handles data persistence

### Services

- `QRCodeService`: Generates and processes QR codes for locations
- `ExportImportManager`: Handles data import/export functionality

### Views

The UI is built using SwiftUI with reusable components:

- `ItemDisplayComponent`: Reusable component for displaying items
- `ItemListComponent`: Reusable component for displaying lists of items
- Various screens for browsing, editing, and managing collections

## Key Features

### Hierarchical Location Management

Locations can be organized in a hierarchical structure:

- Rooms can contain bookshelves, cabinets, or boxes
- Bookshelves and cabinets can contain boxes
- Items can be assigned to any location

### QR Code Integration

- Generate QR codes for locations
- Scan QR codes to quickly navigate to locations
- Custom URL scheme for deep linking

### Search and Browse

- Full-text search across items and locations
- Filter by type, location, and other properties
- View collections by series, author, or location

### Data Management

- Export inventory to JSON files
- Import inventory from JSON files
- Export QR codes as image files

## Getting Started

### Prerequisites

- Xcode 14 or later
- iOS 16 or later / macOS 13 or later

### Building the Project

1. Clone the repository
2. Open `Obsidian Nexus.xcodeproj` in Xcode
3. Build and run for your target device

## Development Guidelines

### Adding New Components

When adding new components:

1. Follow existing code style and architecture patterns
2. Ensure components are reusable where appropriate
3. Add comprehensive documentation
4. Update tests

### Navigation

The app uses a centralized `NavigationCoordinator` for consistent navigation:

- Each screen should use the coordinator for navigation
- Sheet presentations are managed by the coordinator
- Avoid using hardcoded NavigationLinks

### Data Persistence

Data is persisted using SQLite through custom repositories:

- `InventoryRepository`: Manages inventory items
- `LocationRepository`: Manages location data

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Icons by [SF Symbols](https://developer.apple.com/sf-symbols/)
- QR Code generation using Core Image 