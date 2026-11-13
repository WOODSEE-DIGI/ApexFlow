# Apex Flow Updates

This directory is served by GitHub Pages and provides the Sparkle update feed for Apex Flow.

- `appcast.xml` — Sparkle feed that tells installed apps when an update is available
- `ApexFlow-<version>.zip` — Signed update archives

## Enable GitHub Pages

1. Go to **Settings → Pages** in the GitHub repo.
2. Under **Build and deployment**, select **Deploy from a branch**.
3. Choose the `main` branch and the `/docs` folder.
4. Click **Save**.

The feed will be available at:

```
https://WOODSEE-DIGI.github.io/ApexFlow/updates/appcast.xml
```

## Publish an update

1. Set up your local signing config once (never committed):
   ```bash
   cp signing.config.template signing.config
   # Edit signing.config with your real Developer ID and Team ID
   ```

2. Build and publish:
   ```bash
   ./build-dmg.sh
   ./publish-update.sh
   git add docs/updates/
   git commit -m "release: ApexFlow 1.x"
   git push origin main
   ```

GitHub Pages will redeploy automatically and installed apps will be prompted to update.
