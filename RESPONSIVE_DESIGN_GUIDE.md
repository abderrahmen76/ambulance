# Phase 1 Responsive Design Implementation Guide

## Quick Start

All screens now have `responsive` utility available via:

```dart
context.responsive  // Access all responsive helpers
```

## Key Responsive Properties to Use

### Padding (automatically scales by device)

```dart
// Instead of: const EdgeInsets.all(16)
context.responsive.paddingLarge  // 16px on phone, 24px on tablet

// Predefined:
.paddingSmall      // 8px base
.paddingMedium     // 12px base
.paddingLarge      // 16px base
.paddingXLarge     // 20px base
```

### Spacing/Heights

```dart
// Instead of: SizedBox(height: 16)
SizedBox(height: context.responsive.spacingLarge)

// Or use predefined values:
context.responsive.spacingSmall      // 8px
context.responsive.spacingMedium     // 12px
context.responsive.spacingLarge      // 16px
```

### Grid Columns (adapts to device)

```dart
// Instead of: GridView.count(crossAxisCount: 2)
GridView.count(
  crossAxisCount: context.responsive.gridColumns2,  // 1 on phone, 2 on tablet
)

// Or for 4-column layouts:
crossAxisCount: context.responsive.gridColumns4,  // 2→3→4 columns
```

### Font Sizes

```dart
// Let Flutter's TextTheme handle most sizes
// For custom sizes:
fontSize: context.responsive.fontSizeLarge  // Scales automatically
```

### Box Dimensions

```dart
// Responsive width (percentage):
width: context.responsive.width(80),   // 80% of screen width

// Responsive height (percentage):
height: context.responsive.height(50), // 50% of screen height
```

### Check Device Type

```dart
if (context.responsive.isPhone) {
  // Show phone layout
} else if (context.responsive.isTablet) {
  // Show tablet layout
} else {
  // Show desktop layout
}

// Available properties:
context.responsive.isPhone     // < 600px
context.responsive.isTablet    // 600px - 1000px
context.responsive.isDesktop   // > 1000px
context.responsive.isSmallPhone // < 380px
```

## Migration Path for Each Screen

### Pattern 1: Replace Fixed Paddings

**Before:**

```dart
padding: const EdgeInsets.all(16),
```

**After:**

```dart
padding: context.responsive.paddingLarge,
```

### Pattern 2: Replace Fixed Spacings

**Before:**

```dart
children: [
  Widget1(),
  const SizedBox(height: 16),
  Widget2(),
]
```

**After:**

```dart
children: [
  Widget1(),
  SizedBox(height: context.responsive.spacingLarge),
  Widget2(),
]
```

### Pattern 3: Make Columns Responsive

**Before:**

```dart
GridView.count(
  crossAxisCount: 2,
  children: [...],
)
```

**After:**

```dart
GridView.count(
  crossAxisCount: context.responsive.gridColumns2,
  children: [...],
)
```

### Pattern 4: Handle Text Overflow

**Before:**

```dart
Text('Long Title')
```

**After:**

```dart
Expanded(
  child: Text(
    'Long Title',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
)
```

---

## Implementation Checklist

### For Each Screen:

- [ ] **Add responsive padding to Scaffold/containers**
  - Replace `const EdgeInsets.all(16)` with `context.responsive.paddingLarge`
  - Replace symmetric paddings similarly

- [ ] **Updates spacing between widgets**
  - Replace `SizedBox(height: 16)` with `SizedBox(height: context.responsive.spacingLarge)`
  - Keep proportions using responsive helpers

- [ ] **Make grid layouts adaptive**
  - Replace `gridColumns: 2` with `gridColumns: context.responsive.gridColumns2`
  - Replace `gridColumns: 4` with `gridColumns: context.responsive.gridColumns4`

- [ ] **Fix text overflow issues**
  - Wrap long titles with `Expanded` widget
  - Add `maxLines` and `overflow: TextOverflow.ellipsis`

- [ ] **Adaptive card layouts**
  - Use `context.responsive.cardAspectRatio` for card dimensions
  - Adjust card widths based on device

---

## Device-Specific Behaviors

### Small Phone (< 380px)

- Smallest spacing and padding (75% of base)
- Single column layouts
- Compact font sizes
- Minimal decorations

### Phone (< 600px) - Most Common

- Standard padding (90% of base)
- 1-2 column grids
- Normal font sizes
- Standard spacing

### Tablet (600px - 1000px)

- Larger padding (120% of base)
- 2-3 column grids
- Slightly larger fonts
- More breathing room

### Desktop (> 1000px)

- Extra padding (150% of base)
- 3-4 column grids
- Larger fonts
- Maximum width constraints

---

## Testing

Test on:

- **Small Phone**: Galaxy A10 (720x1520) or iPhone SE
- **Regular Phone**: iPhone 12 (390x844) or Pixel 5
- **Tablet**: iPad Mini (768x1024) or Tab S6 Lite
- **Tablet Large**: iPad Pro (1024x1366)

---

## Screens in Phase 1

1. **manager_dashboard_screen.dart** - Main dashboard with stats cards and tabs
2. **manager_ambulances_screen.dart** - Ambulance fleet with cards and details
3. **manager_historique_screen.dart** - Mission history with filters and list
4. **manager_missions_screen.dart** - Missions view with list/grid

---

## Common Issues & Solutions

### Issue: Text Overflowing

**Solution:** Wrap title with `Expanded` and add `maxLines: 1, overflow: TextOverflow.ellipsis`

### Issue: Cards too wide on tablet

**Solution:** Use `maxWidth: context.responsive.maxContentWidth` on container

### Issue: Grid too cramped on phone

**Solution:** Use `context.responsive.gridColumns` instead of fixed numbers

### Issue: Padding too large on small phones

**Solution:** Use `context.responsive.paddingLarge` (auto-scales)

---

## Apply Changes Using This Pattern

Find-and-replace examples for common patterns:

```
OLD: const EdgeInsets.all(16),
NEW: context.responsive.paddingLarge,

OLD: const SizedBox(height: 16)
NEW: SizedBox(height: context.responsive.spacingLarge)

OLD: crossAxisCount: 2
NEW: crossAxisCount: context.responsive.gridColumns2

OLD: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
NEW: context.responsive.paddingHorizontalLarge + EdgeInsets.symmetric(vertical: context.responsive.spacingMedium)
```

---

## Summary

The responsive system is now in place! Each screen just needs its layout constants updated to use the responsive helpers. The app will automatically adapt to any device size from small phones to large tablets.
