# Memory Management Test Instructions

## Verify Retain Cycle Fixes

The following retain cycle fixes have been implemented. To verify they're working:

### 1. Monitor Console Output

When running the app in Debug mode, you should see initialization and deallocation messages:

**Initialization Messages:**
- 🟢 InventoryViewModel: Initializing and loading items from storage
- 🟢 LocationManager: Initializing
- 🟢 ServiceContainer: Initialized shared services
- 🟢 BarcodeScannerViewModel: Initializing
- 🟢 CollectionManager: Initializing
- 🟢 ImportExportViewModel: Initializing

**Deallocation Messages (when objects are properly released):**
- 🔴 InventoryViewModel: Deallocating
- 🔴 LocationManager: Deallocating
- 🔴 ServiceContainer: Deallocating
- 🔴 BarcodeScannerViewModel: Deallocating
- 🔴 CollectionManager: Deallocating
- 🔴 ImportExportViewModel: Deallocating

### 2. Test Navigation and Memory Release

1. **Launch the app** - Check console for initialization messages
2. **Navigate between tabs** - Objects should remain in memory (expected)
3. **Use barcode scanner** - Should see BarcodeScannerViewModel init/deinit
4. **Use import/export** - Should see ImportExportViewModel init/deinit
5. **Background/foreground the app** - Check for proper cleanup

### 3. Fixed Issues

#### ✅ NotificationCenter Observer Cleanup
- MainTabView, CombinedSearchTabView, and CollectionsTabView now properly remove observers
- Added weak references in notification closures

#### ✅ Async Task Retain Cycles
- ImportExportViewModel init Tasks now use `[weak self]`
- Prevents retain cycles in async operations

#### ✅ Memory Tracking
- Added deinit methods to all major ViewModels and services
- Console logging helps identify memory leaks

#### ✅ Weak Reference Pattern
- LocationManager correctly uses weak reference to InventoryViewModel
- NotificationCenter closures use weak references to avoid cycles

### 4. Expected Behavior

**Normal Operation:**
- ViewModels should initialize once and remain in memory while the app is active
- Temporary ViewModels (scanner, import/export) should deallocate when dismissed
- No memory warnings or crashes due to retain cycles

**Memory Efficient:**
- NotificationCenter observers are properly cleaned up
- No strong reference cycles between ViewModels
- Async operations don't prevent deallocation

### 5. If You See Issues

If objects are not deallocating as expected:
1. Check console for missing 🔴 deallocation messages
2. Use Xcode's Memory Graph Debugger to identify cycles
3. Ensure weak references are used in closures and delegates
4. Verify NotificationCenter observers are removed in onDisappear

## Testing Tools

- **Xcode Memory Graph Debugger**: Debug → Memory Graph Hierarchy
- **Console Logs**: Filter for 🟢 and 🔴 symbols
- **Instruments**: Use Leaks and Allocations instruments for detailed analysis 