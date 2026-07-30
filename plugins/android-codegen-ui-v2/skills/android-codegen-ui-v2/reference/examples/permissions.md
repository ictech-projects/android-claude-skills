# Examples — Runtime Permissions: Camera & Gallery (R15)

⚠️ **Load this file ONLY when a screen has an image/photo/file picker** (R15.1 trigger). Screens
without a picker (splash, list, detail, dashboard) never need it — do not load.

## Manifest (R15.3)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.provider"
    android:exported="false" android:grantUriPermissions="true">
    <meta-data android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_provider_paths" />
</provider>
```

```xml
<!-- res/xml/file_provider_paths.xml -->
<paths>
    <external-cache-path name="camera_photos" path="." />
    <cache-path name="cache_photos" path="." />
</paths>
```

Dependency (R15.4): `implementation("com.google.accompanist:accompanist-permissions:0.36.0")`

## Full pattern in the Screen composable (R15.5)

```kotlin
@Composable
fun ProfileScreen(viewModel: ProfileViewModel = hiltViewModel(), onNavigateBack: () -> Unit) {
    val state      by viewModel.uiState.collectAsStateWithLifecycle()
    val fieldState by viewModel.fieldState.collectAsStateWithLifecycle()
    val context    = LocalContext.current

    var cameraImageUri by remember { mutableStateOf<Uri?>(null) }

    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok && cameraImageUri != null) viewModel.setSelectedFile(cameraImageUri!!)   // R15.7
    }
    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { viewModel.setSelectedFile(it) }
    }

    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA) { granted ->
        if (granted) { val uri = createCameraImageUri(context); cameraImageUri = uri; cameraLauncher.launch(uri) }
        else viewModel.setDialog(ProfileDialog.Error(
            title = context.getString(R.string.permission_camera_title),
            message = context.getString(R.string.permission_camera_denied_message)))
    }
    val storagePermission = rememberPermissionState(
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE
    ) { granted ->
        if (granted) galleryLauncher.launch("image/*")
        else viewModel.setDialog(ProfileDialog.Error(
            title = context.getString(R.string.permission_storage_title),
            message = context.getString(R.string.permission_storage_denied_message)))
    }

    fun requestCamera() = when {                                    // R15.8 rationale + permanent denial
        cameraPermission.status.isGranted          -> { val uri = createCameraImageUri(context); cameraImageUri = uri; cameraLauncher.launch(uri) }
        cameraPermission.status.shouldShowRationale -> viewModel.setDialog(ProfileDialog.Error(
            title = context.getString(R.string.permission_camera_title),
            message = context.getString(R.string.permission_camera_rationale_message)))
        else                                        -> cameraPermission.launchPermissionRequest()
    }
    fun requestGallery() = when {
        storagePermission.status.isGranted          -> galleryLauncher.launch("image/*")
        storagePermission.status.shouldShowRationale -> viewModel.setDialog(ProfileDialog.Error(
            title = context.getString(R.string.permission_storage_title),
            message = context.getString(R.string.permission_storage_rationale_message)))
        else                                        -> storagePermission.launchPermissionRequest()
    }

    ProfileScreenContent(
        state = state, fieldState = fieldState, onEvent = viewModel::onEvent,
        onCameraClick = ::requestCamera, onGalleryClick = ::requestGallery,
    )
}

private fun createCameraImageUri(context: Context): Uri {
    val file = File(context.externalCacheDir, "camera_photo_${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
}
```

## Picker component + ViewModel callback (R15.6, R15.7)

```kotlin
AppImagePickerField(                                                // from component package (R13)
    label = stringResource(R.string.profile_label_photo),
    imageUri = fieldState.selectedImageUri,
    onCameraClick = onCameraClick, onGalleryClick = onGalleryClick,
    onClearClick = { onEvent(ProfileEvent.ClearSelectedImage) },
    modifier = Modifier.fillMaxWidth()
)

// ViewModel — dedicated setter, NOT via onEvent
fun setSelectedFile(fileUri: Uri) {
    _fieldState.update { it.copy(
        selectedImageUri  = fileUri,
        selectedImageName = fileUri.getFileName(context),
        selectedImageSize = fileUri.getFileSize(context).toReadableFileSize()) }
}
```

## Permanent denial → settings (R15.8)

```kotlin
fun openAppSettings(context: Context) {
    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", context.packageName, null)
    })
}
```

## Required strings (R15.9)

```xml
<string name="permission_camera_title">Camera Permission Required</string>
<string name="permission_camera_rationale_message">Camera access is needed to take a photo.</string>
<string name="permission_camera_denied_message">Camera permission was denied. Enable it in app settings.</string>
<string name="permission_storage_title">Storage Permission Required</string>
<string name="permission_storage_rationale_message">Storage access is needed to select a photo.</string>
<string name="permission_storage_denied_message">Storage permission was denied. Enable it in app settings.</string>
<string name="permission_open_settings">Open Settings</string>
<string name="permission_cancel">Cancel</string>
```
