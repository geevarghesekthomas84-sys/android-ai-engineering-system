---
name: android-ui-ux-design
description: Premium Android UI/UX design system with Material 3, Compose, dynamic color, responsive layouts, motion, and design-to-code workflows
metadata:
  author: Custom
  keywords:
  - material3
  - compose
  - ui-design
  - ux
  - design-system
  - responsive
  - accessibility
---

# Android UI/UX Design Skill

## Trigger Conditions

Activate this skill when the user request involves any of:
- Designing or building Android UI screens (login, dashboard, settings, onboarding, etc.)
- Material 3 / Material Design 3 theming, color schemes, typography, or component selection
- Jetpack Compose layout construction, component usage, or screen architecture
- Dark/light theme implementation or dynamic color (Material You)
- Responsive or adaptive layouts for phones, foldables, and tablets
- Motion design, animations, transitions, or micro-interactions in Compose
- Accessibility improvements (semantics, contrast, touch targets, TalkBack)
- Converting a Figma design, screenshot, or wireframe into Compose code
- UI state handling: loading skeletons, empty states, error states, success confirmations
- E-commerce, finance, cybersecurity, or dashboard screen design
- Form design, input validation UX, or multi-step flows

## Capabilities

### Theming & Color
- Material 3 Expressive color system with all 29 color roles
- Light and dark ColorScheme generation from seed colors
- Dynamic color with `dynamicDarkColorScheme` / `dynamicLightColorScheme`
- Custom brand color mapping to Material 3 tonal palettes

### Typography & Spacing
- Full Material 3 type scale (Display, Headline, Title, Body, Label at L/M/S)
- 4dp baseline grid spacing system
- Consistent padding and margin tokens

### Components
- All Material 3 Compose components: Scaffold, TopAppBar variants, NavigationBar, NavigationRail, NavigationDrawer, Cards, Buttons, FABs, TextFields, Dialogs, BottomSheets, Chips, Badges, SearchBar, DatePicker, TimePicker, and more

### Responsive & Adaptive
- WindowSizeClass-driven layout switching (Compact, Medium, Expanded)
- `ListDetailPaneScaffold` for list-detail patterns
- `NavigationSuiteScaffold` for automatic navigation component selection
- Foldable device support with `FoldingFeature` detection
- Tablet-optimized layouts with NavigationRail and two-pane designs

### Motion & Animation
- `AnimatedVisibility`, `AnimatedContent`, `Crossfade` for enter/exit
- `animate*AsState` for value-driven animation
- Spring, tween, snap animation specs
- Shared element transitions with Navigation3
- Micro-interactions: press feedback, expand/collapse, shimmer loading

### UI State Patterns
- Skeleton shimmer loaders during data fetch
- Empty state illustrations with call-to-action
- Error state with retry mechanism
- Success confirmation with animated feedback
- Pull-to-refresh, swipe-to-dismiss, infinite scroll

### Screen Recipes
- Authentication flows (login, register, forgot password)
- Dashboard screens (stats cards, charts, quick actions)
- E-commerce (product grid, product detail, cart)
- Finance overview (balance display, transaction list, spending charts)
- Cybersecurity dashboard (threat level, scan status, device health)
- Settings with categorized preference groups

### Accessibility
- Semantic annotations for screen readers
- 48dp minimum touch targets
- WCAG contrast ratios (4.5:1 normal, 3:1 large text)
- Content descriptions, roles, state descriptions
- Live regions for dynamic content updates

### Design-to-Code
- Figma design interpretation: extracting colors, spacing, typography, component mapping
- Screenshot analysis: identifying components, layout structure, visual hierarchy
- Wireframe to Compose: translating low-fidelity sketches into functional layouts

## Design Workflow

Follow this sequence for any UI/UX task:

1. **Research** -- Understand the screen purpose, user goals, data requirements, and interaction patterns. Identify which Material 3 components and patterns fit best.

2. **Visual Direction** -- Select color scheme (seed color, light/dark variants), typography emphasis, spacing density, and elevation strategy. Reference `references/design-tokens.md`.

3. **Component System** -- Choose specific Material 3 components for each UI element. Reference `references/material3-components.md` for correct API usage.

4. **Compose Implementation** -- Write the screen composables, applying responsive layout rules from `references/responsive-layouts.md`. Add animations from `references/motion-animation.md`. Implement UI state patterns from `references/ui-patterns.md`.

5. **Build** -- Compile the project with `gradlew assembleDebug` to verify no compilation errors.

6. **Emulator Screenshot** -- Deploy to emulator and capture screenshots to verify visual output.

7. **Compare** -- Compare the rendered output against the design intent or reference screenshot.

8. **Refine** -- Iterate on spacing, color, typography, and component choices based on comparison.

## Quick Reference: Common Design Patterns

| Pattern | Components | Reference |
|---|---|---|
| Auth screen | Scaffold, TextField, Button, Text | `references/premium-screens.md` |
| Dashboard | LazyVerticalGrid, Card, TopAppBar | `references/premium-screens.md` |
| List-detail | ListDetailPaneScaffold | `references/responsive-layouts.md` |
| Loading state | Shimmer skeleton | `references/ui-patterns.md` |
| Error + retry | Column, Text, Button, Icon | `references/ui-patterns.md` |
| Pull-to-refresh | PullToRefreshBox | `references/ui-patterns.md` |
| Bottom sheet | ModalBottomSheet | `references/material3-components.md` |
| Search bar | SearchBar, DockedSearchBar | `references/material3-components.md` |
| Navigation | NavigationSuiteScaffold | `references/responsive-layouts.md` |
| Animated transition | AnimatedContent, SharedElement | `references/motion-animation.md` |
| Accessible form | TextField + semantics | `references/accessibility.md` |
| Onboarding | HorizontalPager, PageIndicator | `references/ui-patterns.md` |

## Important Notes

- Never claim pixel-perfect fidelity without actual visual comparison between the rendered output and the design reference. Always build, screenshot, and compare.
- All code snippets in references target **Compose BOM 2026.03.01**, **Material 3**, **AGP 9.0.1**, **Kotlin 2.3.20**, **Navigation3 1.0.1**.
- Prefer `Modifier` parameter conventions: pass `modifier` as the first optional parameter of every composable.
- Use `MaterialTheme.colorScheme`, `MaterialTheme.typography`, and `MaterialTheme.shapes` instead of hardcoded values.
- Test on both light and dark themes before considering a screen complete.
