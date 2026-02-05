# App Icon & Splash Screen Setup

## Required Assets

Create the following image files:

### App Icon
- `assets/icon/app_icon.png` - 1024x1024 px square PNG (main app icon)
- `assets/icon/app_icon_foreground.png` - 1024x1024 px PNG with transparent background (for Android adaptive icon)

**Design Guidelines:**
- Use a notification bell icon as the primary symbol
- Primary color: #FF6B9D (Candy pink)
- Keep the icon simple and recognizable
- Leave padding around the icon for adaptive icon cropping

### Splash Screen
- `assets/splash/splash_logo.png` - 512x512 px PNG with transparent background

## Generating Icons

After adding the image files, run:

```bash
# Generate app icons
flutter pub run flutter_launcher_icons

# Generate splash screen
flutter pub run flutter_native_splash:create
```

## Quick Icon Creation (using Figma or Canva)

1. Create a 1024x1024 canvas
2. Background: #FF6B9D (Candy pink)
3. Icon: White notification bell (Material Icons: notifications_active)
4. Export as PNG

## Color Reference
- Primary (Candy): #FF6B9D
- Secondary (Candy): #FFB4D2
- White: #FFFFFF
