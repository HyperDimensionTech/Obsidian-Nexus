# Architecture Overview

Learn about the architectural design of Obsidian Nexus and how its components work together.

## Overview

Obsidian Nexus follows a modern SwiftUI architecture with a focus on maintainability, testability, and code reuse. The app is built using MVVM (Model-View-ViewModel) principles with additions for navigation and state management.

![Architecture Diagram](architecture-diagram)

## Core Components

### Models

The data models represent the core entities in the app:

- **InventoryItem**: Represents a physical item in the user's collection
  - Properties include title, type, condition, location, price, etc.
  - Supports various item types (books, manga, games, etc.)

- **StorageLocation**: Represents a physical storage location
  - Supports hierarchical structure (rooms, bookshelves, boxes)
  - Contains child locations and references to stored items

- **UserPreferences**: Stores user configuration settings
  - Theme preferences
  - Display options
  - Default values (currency, collection type)

### View Models

View models manage business logic and state for the views:

- **InventoryViewModel**: Manages the collection of inventory items
  - CRUD operations for items
  - Sorting and filtering
  - Collection-specific operations (series, authors)

### Managers

Managers handle more complex data management operations:

- **LocationManager**: Manages the location hierarchy
  - Handles parent-child relationships
  - Validates location operations
  - Provides location queries and searches

- **StorageManager**: Handles data persistence
  - Saves and loads data from storage
  - Manages repositories for different entity types
  - Handles data migration

### Services

Services provide specific functionality across the app:

- **QRCodeService**: Manages QR code generation and parsing
  - Generates QR codes for locations
  - Parses scanned QR codes
  - Handles deep linking

- **ExportImportManager**: Handles data import and export
  - Creates export documents
  - Processes imported data
  - Manages file formatting

### Navigation

The app uses a centralized navigation system:

- **NavigationCoordinator**: Manages app navigation
  - Tab-specific navigation paths
  - Deep linking support
  - Sheet presentation management

## Data Flow

### Unidirectional Data Flow

The app follows a generally unidirectional data flow:

1. **User Action**: User interacts with a view
2. **View Calls ViewModel**: The view calls methods on the view model
3. **ViewModel Updates Data**: The view model updates the data model
4. **Data Changes Published**: Changes are published to observers
5. **Views Reflect Changes**: Views update to reflect the new data state

### State Management

State management is handled through SwiftUI's native mechanisms:

- `@Published` properties for observable state
- `@EnvironmentObject` for dependency injection
- `@State` and `@Binding` for view-specific state

## UI Architecture

### Reusable Components

The UI is built with reusable components for consistency:

- **ItemDisplayComponent**: Standard item display across the app
- **ItemListComponent**: Reusable list of items with sorting and grouping
- **LocationRow**: Standardized location display

### Navigation

Navigation follows a consistent pattern:

1. All navigation goes through the `NavigationCoordinator`
2. Navigation destinations are defined as enum cases
3. Tab-specific navigation paths are maintained separately
4. Deep links are processed through the coordinator

## Data Persistence

The app uses SQLite for data persistence:

- **DatabaseManager**: Manages the SQLite connection
- **Repositories**: Handle CRUD operations for specific entity types
  - `InventoryRepository`
  - `LocationRepository`
  - `PreferencesRepository`

## Best Practices

The codebase follows these best practices:

### Dependency Injection

- Dependencies are injected through initializers or environment objects
- This makes components testable and loosely coupled

### Separation of Concerns

- Each component has a single responsibility
- Business logic is separated from UI code
- Data access is abstracted through repositories

### Error Handling

- Errors are properly typed and propagated
- Operations that can fail use Swift's `throws` mechanism
- User-facing errors include appropriate messages

### Testing

- Core business logic is testable without UI
- View models are designed for test injection
- Critical paths have unit test coverage

## Design Patterns

The app uses several design patterns:

- **Repository Pattern**: For data access
- **Coordinator Pattern**: For navigation
- **Singleton Pattern**: For shared services
- **Observer Pattern**: For state changes (via Combine) 