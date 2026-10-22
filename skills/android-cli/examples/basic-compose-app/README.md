# Basic Compose App — Project Scaffold

This is a reference scaffold for a minimal Jetpack Compose + Material 3 app.
Use this as a starting point or reference when creating new projects.

## To create a real project, use:

```powershell
android create empty-activity --name="My App" --namespace=com.example.myapp --output=./my-app
```

Or replicate this structure manually.

## Project Structure

```
my-app/
├── build.gradle.kts              # Project-level
├── settings.gradle.kts
├── gradle.properties
├── gradle/
│   ├── wrapper/
│   │   └── gradle-wrapper.properties
│   └── libs.versions.toml
├── local.properties              # Auto-generated, not committed
└── app/
    ├── build.gradle.kts          # App module
    ├── proguard-rules.pro
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── java/com/example/myapp/
        │   │   ├── MyApplication.kt
        │   │   ├── MainActivity.kt
        │   │   ├── ui/
        │   │   │   ├── theme/
        │   │   │   │   ├── Color.kt
        │   │   │   │   ├── Theme.kt
        │   │   │   │   └── Type.kt
        │   │   │   └── screens/
        │   │   │       └── HomeScreen.kt
        │   │   └── navigation/
        │   │       └── AppNavigation.kt
        │   └── res/
        │       ├── values/
        │       │   ├── strings.xml
        │       │   └── themes.xml
        │       └── mipmap-*/ (launcher icons)
        └── test/
            └── java/com/example/myapp/
                └── ExampleUnitTest.kt
```

## Key Files

### AndroidManifest.xml
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name=".MyApplication"
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.MyApp"
        android:usesCleartextTraffic="false">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/Theme.MyApp">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### MainActivity.kt
```kotlin
package com.example.myapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.myapp.ui.theme.MyAppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyAppTheme {
                HomeScreen()
            }
        }
    }
}
```

### HomeScreen.kt
```kotlin
package com.example.myapp.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen() {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("My App") })
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Hello, Android!",
                style = MaterialTheme.typography.headlineMedium
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = { /* TODO */ }) {
                Text("Get Started")
            }
        }
    }
}
```

## Build & Run

```powershell
cd my-app
.\gradlew assembleDebug
android run --apks=app/build/outputs/apk/debug/app-debug.apk
```
