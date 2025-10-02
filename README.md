# SnowbirdCalc

A lightweight SwiftUI app for modeling investment scenarios and tracking capital allocations. Built with a pragmatic MVVM-style architecture and file-based persistence so you can iterate quickly without backend dependencies.

> **Status:** Working baseline with Overview, Scenarios, and Capital tabs. Actively evolving.

---

## ✨ Features

- **Overview tab** — at-a-glance summary of the currently selected Scenario plus quick actions.
- **Scenarios tab** — create, duplicate, select, and delete financial scenarios.
- **Capital tab** — (existing screen) manage contributions, allocations, and portfolio summaries.
- **Persistence** — scenarios saved to `Documents/scenarios.json` (no database required).
- **SwiftUI-first** — single source of truth via `AppViewModel` as an `@EnvironmentObject`.

---

## 🧱 Architecture

- **AppViewModel** (`ObservableObject`, `@MainActor`) is the top-level source of truth.
  - Publishes `scenarios`, a `selectedID`, and computed `outputs` (from `Calculator`).
  - Persists state to disk on change and recomputes outputs.
- **Views**
  - `MainTabView` hosts tabs: **Overview**, **Scenarios**, **Capital**.
  - `OverviewView` reads from `AppViewModel` and provides quick actions.
  - `CapitalView` (and its `CapitalViewModel`) contains capital-specific UI and logic.
- **Calculator** encapsulates the financial math and produces `CalculatorOutput` per `Scenario`.

**Data Flow**

```
Scenario edits → AppViewModel.scenarios → save() → recompute via Calculator → outputs
```

---

## 📦 Requirements

- **Xcode** 15 or newer (Swift 5.9+)
- **iOS** 17.0+ (SwiftUI / Charts usage may require these SDKs)
- No backend services required

> If you use an older Xcode, you may need to relax the iOS deployment target or remove newer API usages.

---

## 🚀 Getting Started

1. **Clone** the repo
   ```bash
   git clone https://github.com/therealtplum/SnowbirdCalc.git
   cd SnowbirdCalc
   ```

2. **Open** `SnowbirdCalc.xcodeproj` (or `.xcworkspace` if present) in Xcode.

3. **Build & Run** on iOS Simulator (iPhone 15/16) or a device.

The app will create and load `Documents/scenarios.json` on first run and seed a default scenario.

---

## 🗂 Project Structure (key files)

```
SnowbirdCalc/
 ├─ AppViewModel.swift        # Source of truth: scenarios, selection, persistence, outputs
 ├─ MainTabView.swift         # Tabs: Overview, Scenarios, Capital
 ├─ OverviewView.swift        # Overview dashboard (uses AppViewModel)
 ├─ CapitalView.swift         # Capital tab UI
 ├─ CapitalViewModel.swift    # Capital tab logic
 ├─ Calculator.swift          # Financial computation → CalculatorOutput
 ├─ AboutView.swift           # (Optional) About screen
 ├─ BunnyEggView.swift        # (Optional) Fun/testing view
 └─ ChartsSection.swift       # (Optional) Shared charts/sections helpers
```

> If you maintain your own `SectionCard` component, keep a **single** definition to avoid duplicate type errors.

---

## 🔧 Development Tips

### Environment Objects
- Root injection (in your `@main` app):
  ```swift
  @main
  struct SnowbirdApp: App {
      @StateObject private var appVM = AppViewModel()
      var body: some Scene {
          WindowGroup {
              MainTabView()
                  .environmentObject(appVM)
          }
      }
  }
  ```
- In child views, use:
  ```swift
  @EnvironmentObject var vm: AppViewModel
  ```

### Persistence
- `AppViewModel` saves on each mutation to `Documents/scenarios.json`.
- Safe to edit scenarios via `updateCurrent { … }`; outputs recompute automatically.

### Git Workflow
- Keep `main` green. Do feature work on branches:
  ```bash
  git switch -c feature/overview-polish
  # work, commit
  git push -u origin feature/overview-polish
  ```
- Commit messages: *imperative mood*, scope first (e.g., `overview: add snapshot card & quick actions`).

---

## 🧭 Roadmap Ideas

- Performance chart (value vs. return %) on Overview.
- Donut allocation breakdown shared with Capital tab.
- Capital calls & upcoming items surfaced on Overview.
- Export/import scenarios (JSON).
- Unit tests for `Calculator` and edge cases.

---

## 🛠 Troubleshooting

**Crash: “No ObservableObject of type AppViewModel found.”**  
You forgot to inject `.environmentObject(appVM)` at the app root or in Previews.

**“Missing argument for parameter 'isPresented' in call.”**  
When using `.sheet`, `.popover`, or `.alert`, provide a `Binding<Bool>`:
```swift
@State private var show = false
.sheet(isPresented: $show) { MyView() }
```

**Blank Overview / recursion**  
Avoid nesting `MainTabView` inside itself:
```swift
// ❌ Wrong
NavigationStack { MainTabView() }

// ✅ Right
NavigationStack { OverviewView() }
```

**Duplicate type 'SectionCard'**  
Ensure only one `SectionCard` exists in the target, or mark a file-local helper as `private` and remove the other.

---

## 📄 License

MIT © Thomas Plummer
