# Contributing to Obsidian Nexus

Thank you for your interest in contributing to Obsidian Nexus! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please be respectful and considerate of others when contributing to the project. We aim to foster an inclusive and welcoming community.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with the following information:

- A clear, descriptive title
- Steps to reproduce the bug
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Device and OS version
- Any additional context

### Suggesting Features

Feature suggestions are welcome! When suggesting a feature, please:

- Provide a clear description of the feature
- Explain the use case and benefits
- Include any implementation ideas you may have

### Pull Requests

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes
4. Ensure your code follows the project's style guidelines
5. Add tests for your changes if applicable
6. Ensure all tests pass
7. Submit a pull request

## Development Guidelines

### Code Style

- Follow the Swift API Design Guidelines
- Use clear, descriptive variable and function names
- Use comprehensive documentation comments for public API
- Follow the existing code structure and patterns

### Component Architecture

When adding new components:

1. Follow the existing MVVM architecture
2. Use environment objects for dependency injection
3. Make components reusable where possible
4. Separate business logic from UI code

### Navigation

Use the `NavigationCoordinator` for all navigation:

```swift
// Correct
Button("View Item") {
    navigationCoordinator.navigateToItemDetail(item: myItem)
}

// Avoid direct NavigationLinks when possible
// NavigationLink(destination: ItemDetailView(item: myItem)) { ... }
```

### Documentation

- Document all public types, properties, and methods
- Include code examples in documentation comments
- Update README.md when adding significant features

### Reusable Components

When creating new reusable UI components:

1. Add comprehensive documentation with usage examples
2. Include default parameter values for convenience
3. Consider both light and dark mode appearance
4. Make components accessible and localization-ready

### Testing

- Write unit tests for new functionality
- Test both success and failure cases
- Update existing tests when modifying functionality

## Pull Request Process

1. Update documentation to reflect any changes
2. Update the README.md with details of significant changes
3. Ensure all tests pass
4. Have your code reviewed by at least one maintainer
5. Address any feedback from reviewers

## Setting Up the Development Environment

1. Clone the repository
2. Open `Obsidian Nexus.xcodeproj` in Xcode
3. Install any required dependencies
4. Build and run the project

## Project Structure

```
Obsidian Nexus/
├── Models/           # Data models
├── Views/            # SwiftUI views
│   ├── Shared/       # Reusable components
│   ├── Collections/  # Collection-related views
│   ├── Locations/    # Location-related views
│   └── Settings/     # Settings-related views
├── Managers/         # Data and state managers
├── Services/         # Helper services
├── Navigation/       # Navigation components
├── Utilities/        # Utility functions and extensions
└── Resources/        # Assets and resources
```

## Creating Documentation

We use DocC for API documentation. To generate documentation:

1. In Xcode, select Product > Build Documentation
2. View the documentation in Xcode's Developer Documentation window

## Questions?

If you have any questions about contributing, please open an issue or contact the project maintainers. 