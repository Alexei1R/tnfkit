# CLAUDE.md - tnfkit Development Guidelines

## Project Structure
```
├── Motionlink/       # iOS/macOS app (AR editor)
│   └── Motionlink/   # App source
├── Sources/          # Swift package
│   └── tnfkit/       # Main library
└── build.sh          # Build script
```

## Build & Test Commands
- Build package: `swift build`
- Run the app: Open Motionlink.xcodeproj in Xcode and run
- Check syntax: `swiftlint` (if installed)

## Code Style Guidelines

### Formatting & Structure
- Indentation: 4 spaces
- Braces: opening brace on same line as declaration
- Line spacing: single blank line between functions
- Max line length: ~100 characters
- Keep it simple - don't create new files when not needed

### Naming Conventions
- Types: PascalCase (structs, classes, protocols)
- Variables/properties/methods: camelCase
- Use descriptive names that convey purpose

### Types & Architecture
- Use protocols for interfaces, protocol extensions for shared logic
- Prefer value types (structs) over reference types (classes)
- Mark classes as `final` unless inheritance is required
- Follow Entity-Component-System (ECS) pattern for engine code

### Imports & Organization
- Order imports by framework importance (Foundation first)
- Group related functionality with MARK comments
- Use "// NOTE:" for important comments
- Maintain clear separation of concerns between components

### Error Handling
- Use early returns with guard statements
- Prefer optionals with nil-coalescing over forced unwrapping
- Log errors through centralized Log system
- Verify code correctness before committing changes