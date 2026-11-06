# Examples — Icons & Images (R14)

Load when a screen/component renders icons or images. Priority order P1→P4 (R14.1).

## P1 — VectorDrawable from design (preferred, R14.2)

```kotlin
Icon(
    painter            = painterResource(id = R.drawable.ic_leave_calendar),
    contentDescription = stringResource(R.string.accessibility_leave_calendar),
    tint               = MaterialTheme.colorScheme.primary,      // never hardcode tint (R14.8)
    modifier           = Modifier.size(24.dp)                    // default size (R14.8)
)
```
Steps: export SVG → Vector Asset Studio → `app/src/main/res/drawable/ic_<feature>_<desc>.xml`.

## P2 — Material Icons Extended (utility only, R14.3)

```kotlin
// build.gradle.kts: implementation("androidx.compose.material:material-icons-extended")
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack

Icon(
    imageVector        = Icons.AutoMirrored.Filled.ArrowBack,
    contentDescription = stringResource(R.string.accessibility_back_button),
    tint               = MaterialTheme.colorScheme.onSurface
)
```
Allowed utility icons (no design asset): back, close, search, more-vert, share, settings, check,
visibility, add, delete. A design-provided version of any → use P1 instead.

## P3 — existing app drawable (R14.4)

```kotlin
Icon(
    painter            = painterResource(id = R.drawable.ic_common_avatar_placeholder),
    contentDescription = stringResource(R.string.accessibility_avatar),
    modifier           = Modifier.size(40.dp)
)
```
Check `res/drawable/` before converting a new SVG.

## P4 — remote image via Coil (R14.5)

```kotlin
// build.gradle.kts: implementation("io.coil-kt.coil3:coil-compose:3.0.0")
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(avatarUrl).crossfade(true)
        .placeholder(R.drawable.ic_common_avatar_placeholder)
        .error(R.drawable.ic_common_avatar_placeholder)
        .build(),
    contentDescription = stringResource(R.string.accessibility_profile_avatar),
    contentScale       = ContentScale.Crop,
    modifier           = Modifier.size(48.dp).clip(CircleShape)
)
```

## Decorative + wrong patterns (R14.8)

```kotlin
Icon(painter = painterResource(R.drawable.ic_decorative_divider),
     contentDescription = null,                                   // ✅ explicit null, not ""
     tint = MaterialTheme.colorScheme.outlineVariant, modifier = Modifier.size(24.dp))

// ❌ hardcoded string + hardcoded tint
Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = Color(0xFF333333))
```

Naming (R14.6): `ic_<feature>_<description>.xml`; shared → `ic_common_<name>.xml`.
