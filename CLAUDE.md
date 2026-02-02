# Claude Code Instructions

## Releasing

When creating a new release, ALWAYS build separate binaries for each architecture:

### Build Steps

1. **Build for Apple Silicon (arm64)**
   ```bash
   xcodebuild -scheme SwissRailwayClock -configuration Release ARCHS="arm64" ONLY_ACTIVE_ARCH=NO clean build
   ```
   Copy the `.saver` bundle to a temp location.

2. **Build for Intel (x86_64)**
   ```bash
   xcodebuild -scheme SwissRailwayClock -configuration Release ARCHS="x86_64" ONLY_ACTIVE_ARCH=NO clean build
   ```
   Copy the `.saver` bundle to a temp location.

3. **Create DMGs**
   ```bash
   hdiutil create -volname "SwissRailwayClock" -srcfolder <apple-silicon-folder> -ov -format UDZO SwissRailwayClock-<version>-AppleSilicon.dmg
   hdiutil create -volname "SwissRailwayClock" -srcfolder <intel-folder> -ov -format UDZO SwissRailwayClock-<version>-Intel.dmg
   ```

4. **Create GitHub release with both DMGs**
   ```bash
   gh release create v<version> --title "v<version> - <title>" --notes "<notes>" <AppleSilicon.dmg> <Intel.dmg>
   ```

### Release Notes Format

Include:
- Summary of changes
- Download instructions specifying which DMG for which Mac type:
  - AppleSilicon.dmg for M1/M2/M3/M4 Macs
  - Intel.dmg for Intel Macs
