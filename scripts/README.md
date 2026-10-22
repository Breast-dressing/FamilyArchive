# Scripts

## Unsigned IPA

[`build-unsigned-ipa.sh`](build-unsigned-ipa.sh) archives `FamilyArchive` for
`generic/platform=iOS` with code signing disabled and packages the app as:

```
build/unsigned/FamilyArchive.ipa
```

### Local (macOS + Xcode 27)

```bash
bash scripts/build-unsigned-ipa.sh
```

The IPA is unsigned. Re-sign it or use an installation workflow that accepts an
unsigned payload; it is not intended for direct TestFlight/App Store upload.

### GitHub Actions

Run **Actions → Build Unsigned IPA → Run workflow**. The IPA is uploaded as the
`unsigned-ipa` artifact. The workflow uses the same `xcode-27` runner and does not
use any signing secrets.
