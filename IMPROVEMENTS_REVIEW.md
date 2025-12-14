# SnowbirdCalc - Comprehensive Code Review & Improvement Recommendations

## Executive Summary

This is a well-structured SwiftUI app for financial scenario modeling. The codebase demonstrates good architectural patterns with MVVM-style separation, file-based persistence, and a clean feature-based organization. However, there are several areas for improvement, particularly around error handling, testing, and code quality.

---

## 🔴 Critical Issues

### 1. Unsafe Force Unwrapping (`try!`)
**Location:** Multiple files
- `AppViewModel.swift:21` - FileManager URL creation
- `CapitalViewModel.swift:38` - FileManager URL creation
- `MustacheLite.swift:24, 86, 121` - NSRegularExpression initialization

**Issue:** Force unwrapping can crash the app if file system operations fail.

**Recommendation:**
```swift
// Instead of:
let docs = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

// Use:
guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
    // Handle error gracefully - show alert or use fallback
    return
}
```

### 2. Silent Error Handling (`try?`)
**Location:** Throughout persistence code
- `AppViewModel.swift:24-25, 89-90` - File I/O operations
- `CapitalViewModel.swift:41-42, 124-125` - File I/O operations
- `SignerStore.swift:76-77, 83-84` - File I/O operations

**Issue:** Errors are silently swallowed, making debugging difficult and potentially losing user data.

**Recommendation:**
- Add proper error logging
- Show user-friendly error messages for critical operations
- Implement retry logic for transient failures
- Consider using Result types for error propagation

---

## 🟡 High Priority Improvements

### 3. Missing Error Handling in Persistence

**Current State:**
```swift
private func save() {
    let state = SavedState(scenarios: scenarios, selectedID: selectedID)
    if let data = try? JSONEncoder().encode(state) {
        try? data.write(to: saveURL)
    }
    recalcAll()
}
```

**Issues:**
- No error logging
- No user notification if save fails
- `recalcAll()` called even if save fails
- No retry mechanism

**Recommendation:**
```swift
private func save() {
    let state = SavedState(scenarios: scenarios, selectedID: selectedID)
    do {
        let data = try JSONEncoder().encode(state)
        try data.write(to: saveURL, options: [.atomic])
    } catch {
        // Log error
        print("Failed to save scenarios: \(error.localizedDescription)")
        // Optionally: show user alert or use error reporting service
        // Consider: implement background retry queue
    }
    recalcAll()
}
```

### 4. Inefficient Recalculation Strategy

**Location:** `AppViewModel.swift:87-93`

**Issue:** `recalcAll()` is called on every save, even when only one scenario changes.

**Recommendation:**
- Only recalculate changed scenarios
- Use debouncing for rapid successive changes
- Consider background queue for heavy calculations

```swift
private func save() {
    // ... save logic ...
    // Only recalc if scenarios actually changed
    if scenariosChanged {
        recalcAll()
    }
}
```

### 5. Missing Input Validation

**Location:** Multiple input fields throughout the app

**Issues:**
- No validation for currency inputs (negative values, extreme values)
- No validation for percentage sliders (bounds checking)
- No validation for scenario names (empty, duplicates)

**Recommendation:**
- Add validation helpers
- Show inline error messages
- Disable invalid operations

### 6. Testing Coverage

**Current State:** Only placeholder test exists

**Recommendation:**
- Unit tests for `Calculator` logic
- Unit tests for `AppViewModel` persistence
- Unit tests for `CapitalViewModel` calculations
- UI tests for critical user flows
- Edge case testing (empty scenarios, invalid inputs, etc.)

---

## 🟢 Medium Priority Improvements

### 7. Code Duplication

**Issues:**
- `SectionCard` defined in `ScenarioEditorView.swift` but used in multiple files
- Currency formatting duplicated across views
- Percent formatting logic duplicated
- Similar UI helpers in multiple views (`row`, `currencyField`, `percentSlider`)

**Recommendation:**
- Extract `SectionCard` to shared UI components
- Create shared formatters
- Create reusable view modifiers or helper views

### 8. Architecture: Separation of Concerns

**Issues:**
- `AppViewModel` handles both business logic and persistence
- `CapitalViewModel` duplicates persistence pattern from `AppViewModel`
- No clear abstraction for storage layer

**Recommendation:**
- Create a `StorageService` protocol for persistence
- Extract calculation logic to dedicated service
- Use dependency injection for testability

### 9. Memory Management

**Location:** `CapitalViewModel.swift:55-60`

**Issue:** Combine publishers may retain references longer than needed.

**Recommendation:**
- Ensure proper cleanup in `deinit`
- Use `[weak self]` in closures where appropriate

### 10. Accessibility Improvements

**Current State:** Some accessibility features exist but inconsistent

**Recommendations:**
- Add `.accessibilityLabel` to all interactive elements
- Add `.accessibilityHint` for complex interactions
- Test with VoiceOver
- Ensure proper semantic roles for buttons, links, etc.
- Add accessibility identifiers for UI testing

### 11. Performance Optimizations

**Issues:**
- `recalcAll()` recalculates all scenarios even when only one changes
- No debouncing on rapid input changes
- Charts may re-render unnecessarily

**Recommendations:**
- Implement incremental recalculation
- Add debouncing to input fields (already done in `CapitalViewModel`)
- Use `@ViewBuilder` more consistently
- Consider lazy loading for large scenario lists

### 12. State Management

**Issues:**
- `PortfolioStore` and `AppRouter` in `AppState.swift` appear unused
- `AppViewModel` has both `store` and `router` but they may not be needed

**Recommendation:**
- Remove unused code or clarify its purpose
- Consolidate state management approach

---

## 🔵 Low Priority / Nice to Have

### 13. Code Organization

**Recommendations:**
- Group related extensions together
- Add MARK comments for better navigation
- Consider splitting large view files (e.g., `OverviewView.swift`)

### 14. Documentation

**Recommendations:**
- Add doc comments to public APIs
- Document complex calculation logic
- Add inline comments for non-obvious code paths

### 15. Localization

**Current State:** Hard-coded English strings

**Recommendation:**
- Extract strings to `Localizable.strings`
- Use `NSLocalizedString` or SwiftUI's localization support

### 16. Dark Mode Support

**Current State:** Appears to support dark mode but should be verified

**Recommendation:**
- Test all views in dark mode
- Ensure sufficient contrast ratios
- Verify chart colors work in both modes

### 17. iPad Support

**Recommendations:**
- Test layout on iPad
- Consider split-view navigation
- Optimize for larger screens

### 18. Data Migration

**Issue:** No versioning or migration strategy for saved data

**Recommendation:**
- Add version field to saved state
- Implement migration logic for schema changes
- Handle backward compatibility

---

## 📋 Specific Code Improvements

### AppViewModel.swift

1. **Add error handling:**
```swift
init() {
    let fm = FileManager.default
    guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
        // Handle error - could use a fallback or show alert
        self.saveURL = URL(fileURLWithPath: NSTemporaryDirectory())
        return
    }
    self.saveURL = docs.appendingPathComponent("scenarios.json")
    // ... rest of init
}
```

2. **Improve save method:**
```swift
private func save() {
    let state = SavedState(scenarios: scenarios, selectedID: selectedID)
    do {
        let data = try JSONEncoder().encode(state)
        try data.write(to: saveURL, options: [.atomic])
    } catch {
        // Log error
        os_log("Failed to save scenarios: %{public}@", log: .default, type: .error, error.localizedDescription)
        // Consider: show user notification
    }
    // Only recalc if scenarios changed
    recalcAll()
}
```

3. **Add input validation:**
```swift
func addScenario(_ base: Scenario? = nil) {
    let new = base.map(withFreshIDs) ?? Scenario()
    // Validate scenario name
    guard !new.name.trimmingCharacters(in: .whitespaces).isEmpty else {
        // Show error or use default name
        return
    }
    scenarios.append(new)
    selectedID = new.id
}
```

### CapitalViewModel.swift

1. **Improve error handling:**
```swift
init() {
    let fm = FileManager.default
    guard let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
        // Handle error
        return
    }
    self.saveURL = docs.appendingPathComponent("capital.json")
    // ... rest of init
}
```

2. **Add validation:**
```swift
var contributions: Double {
    didSet {
        // Validate: ensure non-negative
        if contributions < 0 {
            contributions = 0
        }
    }
}
```

### Shared Components

**Create `UI/Components/Formatters.swift`:**
```swift
import Foundation

enum Formatters {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    static func percent(_ value: Double) -> String {
        let v = (value <= 1.0) ? value : (value / 100.0)
        return v.formatted(.percent.precision(.fractionLength(1)))
    }
    
    static func dollar(_ value: Double) -> String {
        return currency.string(from: NSNumber(value: value)) ?? "$0"
    }
}
```

**Create `UI/Components/SectionCard.swift`:**
```swift
import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 6)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1)
        }
    }
}
```

---

## 🧪 Testing Recommendations

### Unit Tests Needed:

1. **Calculator Tests:**
   - Test each subsidiary type calculation
   - Test edge cases (zero values, negative values)
   - Test tax calculations
   - Test retirement contribution calculations

2. **AppViewModel Tests:**
   - Test scenario CRUD operations
   - Test persistence (save/load)
   - Test selection logic
   - Test duplicate scenario naming

3. **CapitalViewModel Tests:**
   - Test allocation calculations
   - Test blended yield calculation
   - Test over-allocation detection
   - Test persistence

### UI Tests Needed:

1. Create scenario flow
2. Edit scenario flow
3. Delete scenario flow
4. Capital allocation flow
5. Navigation between tabs

---

## 🔒 Security Considerations

1. **PIN Storage:** `SignerStore` uses Keychain (good), but ensure proper error handling
2. **File Permissions:** Ensure saved files have appropriate permissions
3. **Input Sanitization:** Validate all user inputs to prevent injection issues
4. **Sensitive Data:** Consider encrypting financial data at rest

---

## 📊 Metrics & Monitoring

**Recommendations:**
- Add analytics for user flows
- Track error rates
- Monitor performance metrics
- Add crash reporting (e.g., Crashlytics)

---

## 🎯 Priority Action Items

1. **Immediate (This Week):**
   - Fix all `try!` force unwraps
   - Add error logging to persistence operations
   - Extract `SectionCard` to shared component

2. **Short Term (This Month):**
   - Add input validation
   - Improve error handling with user feedback
   - Write unit tests for Calculator
   - Create shared formatters

3. **Medium Term (Next Quarter):**
   - Refactor persistence layer
   - Add comprehensive test coverage
   - Improve accessibility
   - Add data migration support

---

## ✅ Positive Aspects

The codebase has many strengths:

1. **Clean Architecture:** Good separation of concerns with MVVM pattern
2. **Modern SwiftUI:** Uses latest SwiftUI features appropriately
3. **Feature Organization:** Well-organized file structure
4. **Type Safety:** Good use of Swift's type system
5. **User Experience:** Thoughtful UI with good keyboard handling
6. **Persistence:** Simple, effective file-based storage
7. **Code Style:** Generally consistent and readable

---

## 📝 Summary

This is a solid codebase with good architectural decisions. The main areas for improvement are:

1. **Error Handling:** Replace silent failures with proper error handling
2. **Testing:** Add comprehensive test coverage
3. **Code Reuse:** Extract shared components and utilities
4. **Validation:** Add input validation throughout
5. **Performance:** Optimize recalculation and rendering

Addressing these issues will make the app more robust, maintainable, and user-friendly.

