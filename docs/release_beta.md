# Beta Release Checklist

Use this checklist when publishing a beta build to GitHub.

## 1) Choose version and tag

- Version format in `pubspec.yaml`: `x.y.z-beta.n+build`
- Git tag format: `vx.y.z-beta.n`
- Example: `version: 1.0.0-beta.1+2` and tag `v1.0.0-beta.1`

## 2) Update app version

Edit `pubspec.yaml`:

```yaml
version: 1.0.0-beta.1+2
```

## 3) Validate locally

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## 4) Update changelog

- Move relevant items from `[Unreleased]` to a new version section in `CHANGELOG.md`.
- Ensure release date matches publish date.

## 5) Commit and tag

```powershell
git add pubspec.yaml CHANGELOG.md
git add .github/workflows/beta-release.yml docs/release_beta.md
git commit -m "chore(release): beta v1.0.0-beta.1"
git tag -a v1.0.0-beta.1 -m "Beta release v1.0.0-beta.1"
```

## 6) Push branch and tag

```powershell
git push origin main
git push origin v1.0.0-beta.1
```

Pushing a matching beta tag triggers the GitHub Actions workflow.
The workflow also verifies that the pushed tag (without `v`) matches
`pubspec.yaml` build-name (value before `+`).

## 7) Verify GitHub prerelease

- Open GitHub -> Releases.
- Confirm a prerelease is created for tag `v1.0.0-beta.1`.
- Confirm artifacts are attached:
    - `app-release.apk`
    - `app-release.aab`

## 8) Roll-forward strategy

Do not delete/reuse a published tag. If an issue is found:

1. Fix on branch.
2. Bump beta number and build number.
3. Tag a new beta release (`v1.0.0-beta.2`).

