# Graph Report - mac-ai-limit-widget  (2026-07-13)

## Corpus Check
- 7 files · ~17,073 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 90 nodes · 128 edges · 7 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]

## God Nodes (most connected - your core abstractions)
1. `AppDelegate` - 11 edges
2. `UsageStore` - 10 edges
3. `ProviderID` - 9 edges
4. `NotchPanel` - 9 edges
5. `AppSettings` - 8 edges
6. `UpdateController` - 8 edges
7. `ServerStatus` - 6 edges
8. `StatusStore` - 6 edges
9. `LimitMetric` - 5 edges
10. `NotchView` - 5 edges

## Surprising Connections (you probably didn't know these)
- `ProviderID` --inherits--> `String`  [EXTRACTED]
  Sources/AILimitNotch/AppModel.swift →   _Bridges community 1 → community 4_
- `AppSettings` --inherits--> `ObservableObject`  [EXTRACTED]
  Sources/AILimitNotch/AppModel.swift →   _Bridges community 5 → community 3_
- `UsageStore` --inherits--> `ObservableObject`  [EXTRACTED]
  Sources/AILimitNotch/AppModel.swift →   _Bridges community 3 → community 4_
- `StatusStore` --inherits--> `ObservableObject`  [EXTRACTED]
  Sources/AILimitNotch/AppModel.swift →   _Bridges community 3 → community 6_
- `AppDelegate` --inherits--> `NSObject`  [EXTRACTED]
  Sources/AILimitNotch/AILimitNotchApp.swift →   _Bridges community 3 → community 0_

## Communities (9 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.16
Nodes (6): AILimitNotchApp, AppDelegate, NotchPanel, App, NSApplicationDelegate, NSPanel

### Community 1 - "Community 1"
Cohesion: 0.12
Nodes (16): Font, LimitMetric, Notification.Name, ProviderID, antigravity, claudeCode, codex, cursor (+8 more)

### Community 2 - "Community 2"
Cohesion: 0.18
Nodes (8): LimitRow, NotchShape, NotchView, ProviderLimitSection, ProviderLogoImage, SettingsView, Shape, View

### Community 3 - "Community 3"
Cohesion: 0.17
Nodes (6): NotchState, LaunchAtLoginController, UpdateController, NSObject, ObservableObject, SPUUpdaterDelegate

## Knowledge Gaps
- **8 isolated node(s):** `claudeCode`, `codex`, `antigravity`, `cursor`, `operational` (+3 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppDelegate` connect `Community 0` to `Community 2`, `Community 3`?**
  _High betweenness centrality (0.508) - this node is a cross-community bridge._
- **Why does `UsageStore` connect `Community 4` to `Community 1`, `Community 3`?**
  _High betweenness centrality (0.207) - this node is a cross-community bridge._
- **What connects `claudeCode`, `codex`, `antigravity` to the rest of the system?**
  _8 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.12 - nodes in this community are weakly interconnected._