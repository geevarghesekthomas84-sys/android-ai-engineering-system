# Material 3 Design Tokens

## Color Roles

Material 3 defines 29 color roles organized into five groups. Every color in your UI must map to one of these roles.

### Primary Group
- `primary` -- Brand color, used for key components (FAB, prominent buttons, active states)
- `onPrimary` -- Content color on primary surfaces
- `primaryContainer` -- Standout container fill (cards, chips with emphasis)
- `onPrimaryContainer` -- Content on primaryContainer

### Secondary Group
- `secondary` -- Supporting color for less prominent components
- `onSecondary` -- Content on secondary
- `secondaryContainer` -- Fill for toggles, filters, secondary chips
- `onSecondaryContainer` -- Content on secondaryContainer

### Tertiary Group
- `tertiary` -- Accent for contrast and visual interest
- `onTertiary` -- Content on tertiary
- `tertiaryContainer` -- Complementary container
- `onTertiaryContainer` -- Content on tertiaryContainer

### Surface Group
- `surface` -- Default background
- `onSurface` -- Primary text/icon color on surface
- `surfaceVariant` -- Alternate surface for differentiation
- `onSurfaceVariant` -- Secondary text/icon color
- `surfaceTint` -- Tint overlay color
- `surfaceBright` -- Brighter surface variant
- `surfaceDim` -- Dimmer surface variant
- `surfaceContainer` -- Default container on surface
- `surfaceContainerHigh` -- Higher emphasis container
- `surfaceContainerHighest` -- Highest emphasis container
- `surfaceContainerLow` -- Lower emphasis container
- `surfaceContainerLowest` -- Lowest emphasis container
- `inverseSurface` -- Inverse surface for snackbars, tooltips
- `inverseOnSurface` -- Content on inverseSurface
- `inversePrimary` -- Primary color on inverseSurface

### Error Group
- `error` -- Error indicators and destructive actions
- `onError` -- Content on error
- `errorContainer` -- Error container fill
- `onErrorContainer` -- Content on errorContainer

### Other
- `outline` -- Borders, dividers (medium emphasis)
- `outlineVariant` -- Subtle borders (low emphasis)
- `scrim` -- Scrim overlay behind dialogs/sheets

## Typography Scale

Material 3 type scale with default sizes. Customize via `Typography()`.

| Role | Default Size | Line Height | Letter Spacing | Weight |
|---|---|---|---|---|
| displayLarge | 57sp | 64sp | -0.25sp | 400 |
| displayMedium | 45sp | 52sp | 0sp | 400 |
| displaySmall | 36sp | 44sp | 0sp | 400 |
| headlineLarge | 32sp | 40sp | 0sp | 400 |
| headlineMedium | 28sp | 36sp | 0sp | 400 |
| headlineSmall | 24sp | 32sp | 0sp | 400 |
| titleLarge | 22sp | 28sp | 0sp | 400 |
| titleMedium | 16sp | 24sp | 0.15sp | 500 |
| titleSmall | 14sp | 20sp | 0.1sp | 500 |
| bodyLarge | 16sp | 24sp | 0.5sp | 400 |
| bodyMedium | 14sp | 20sp | 0.25sp | 400 |
| bodySmall | 12sp | 16sp | 0.4sp | 400 |
| labelLarge | 14sp | 20sp | 0.1sp | 500 |
| labelMedium | 12sp | 16sp | 0.5sp | 500 |
| labelSmall | 11sp | 16sp | 0.5sp | 500 |

## Spacing System

Use a 4dp baseline grid. Standard spacing tokens:

| Token | Value | Usage |
|---|---|---|
| xxs | 4.dp | Tight gaps between related elements |
| xs | 8.dp | Inner padding for compact components |
| sm | 12.dp | Standard component inner padding |
| md | 16.dp | Screen edge padding, card padding |
| lg | 24.dp | Section separation |
| xl | 32.dp | Major section breaks |
| xxl | 48.dp | Top-level structural spacing |

## Elevation Levels

Material 3 uses tonal elevation (surface tint) rather than shadow-only.

| Level | Elevation | Usage |
|---|---|---|
| Level 0 | 0.dp | Flat surfaces (background) |
| Level 1 | 1.dp | Cards, navigation bar |
| Level 2 | 3.dp | Elevated cards, FAB (resting) |
| Level 3 | 6.dp | FAB (pressed), top app bar (scrolled) |
| Level 4 | 8.dp | Bottom sheets, side sheets |
| Level 5 | 12.dp | Dialogs, menus |

## Shape System

Corner radii following Material 3 shape scale:

| Shape | Corner Radius | Usage |
|---|---|---|
| extraSmall | 4.dp | Small components (checkboxes, toggles) |
| small | 8.dp | Chips, small cards |
| medium | 12.dp | Cards, dialogs |
| large | 16.dp | Large cards, FAB |
| extraLarge | 28.dp | Sheets, large containers |
| full | 50% | Pills, circular buttons |

## Custom Theme Implementation

```kotlin
import androidx.compose.material3.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable

// Brand colors
val BrandPrimary = Color(0xFF1B6EF3)
val BrandOnPrimary = Color(0xFFFFFFFF)
val BrandPrimaryContainer = Color(0xFFD8E2FF)
val BrandOnPrimaryContainer = Color(0xFF001A41)

val LightColorScheme = lightColorScheme(
    primary = BrandPrimary,
    onPrimary = BrandOnPrimary,
    primaryContainer = BrandPrimaryContainer,
    onPrimaryContainer = BrandOnPrimaryContainer,
    secondary = Color(0xFF565E71),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFDAE2F9),
    onSecondaryContainer = Color(0xFF131C2B),
    tertiary = Color(0xFF6E5676),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFF8D8FF),
    onTertiaryContainer = Color(0xFF27132F),
    surface = Color(0xFFFAF9FD),
    onSurface = Color(0xFF1A1B20),
    surfaceVariant = Color(0xFFE0E2EC),
    onSurfaceVariant = Color(0xFF44464F),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    outline = Color(0xFF74777F),
    outlineVariant = Color(0xFFC4C6D0),
)

val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFADC6FF),
    onPrimary = Color(0xFF002E69),
    primaryContainer = Color(0xFF004494),
    onPrimaryContainer = Color(0xFFD8E2FF),
    secondary = Color(0xFFBEC6DC),
    onSecondary = Color(0xFF283141),
    secondaryContainer = Color(0xFF3E4759),
    onSecondaryContainer = Color(0xFFDAE2F9),
    tertiary = Color(0xFFDBBDE2),
    onTertiary = Color(0xFF3E2846),
    tertiaryContainer = Color(0xFF553F5D),
    onTertiaryContainer = Color(0xFFF8D8FF),
    surface = Color(0xFF121318),
    onSurface = Color(0xFFE3E2E6),
    surfaceVariant = Color(0xFF44464F),
    onSurfaceVariant = Color(0xFFC4C6D0),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    outline = Color(0xFF8E9099),
    outlineVariant = Color(0xFF44464F),
)

val AppTypography = Typography(
    displayLarge = TextStyle(
        fontSize = 57.sp,
        lineHeight = 64.sp,
        letterSpacing = (-0.25).sp,
        fontWeight = FontWeight.Normal,
    ),
    headlineLarge = TextStyle(
        fontSize = 32.sp,
        lineHeight = 40.sp,
        letterSpacing = 0.sp,
        fontWeight = FontWeight.Normal,
    ),
    titleLarge = TextStyle(
        fontSize = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = 0.sp,
        fontWeight = FontWeight.Normal,
    ),
    bodyLarge = TextStyle(
        fontSize = 16.sp,
        lineHeight = 24.sp,
        letterSpacing = 0.5.sp,
        fontWeight = FontWeight.Normal,
    ),
    bodyMedium = TextStyle(
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.25.sp,
        fontWeight = FontWeight.Normal,
    ),
    labelLarge = TextStyle(
        fontSize = 14.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp,
        fontWeight = FontWeight.Medium,
    ),
)

val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp),
    small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(28.dp),
)

@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content,
    )
}
```
