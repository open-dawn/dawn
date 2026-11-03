# Contributing to DAWN

Thank you for contributing. Participation in this project is covered by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Issues

Use the issue forms for bug reports and feature requests.

Security vulnerabilities do not belong in a public issue. Report them as described in [SECURITY.md](SECURITY.md).

## Pull requests

Open pull requests against `main`.

`stable` and `release/*` are used to prepare a release. Do not start feature work on those branches. The release flow is documented in [RELEASING.md](RELEASING.md).

The pull request template asks for:

* a task PIN
* a type: `feature`, `fix`, `chore`, or `misc`
* a description of the change
* how it was tested
* the checklist, including a `swiftlint` run

## Commits

Commit messages follow [.github/.gitmessage](.github/.gitmessage):

```
<tag>(scope): <short description>

<Long description: explain the what and the why of the change>
Part of PIN-0
```

Tags:

| Tag | Use |
| --- | --- |
| `feat` | A new feature for the user |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `style` | Formatting that does not change behavior |
| `refactor` | A code change that is neither a fix nor a feature |
| `perf` | A performance improvement |
| `test` | Adding or correcting tests |
| `chore` | Build process or auxiliary tools |
| `revert` | Revert a previous commit |

To use that file as the local commit template:

```sh
bash .github/config.sh
```

## Development

You need:

* an Apple Silicon Mac
* macOS 26
* Xcode 26.5
* XcodeGen 2.46.0
* SwiftLint 0.65.1

```sh
brew install xcodegen swiftlint
git clone https://github.com/open-dawn/dawn.git
cd dawn
xcodegen generate
swiftlint lint --strict
xcodebuild \
  -project dawn.xcodeproj \
  -scheme dawn \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  test
```

Continuous integration pins XcodeGen 2.46.0 and SwiftLint 0.65.1. A newer Homebrew formula can differ from those pins.

`xcodegen generate` writes `dawn.xcodeproj` from `project.yml`. Open that project and run:

* `dawnApp` to launch `DAWN.app`
* `dawnAgent` to launch the menu bar agent

The `dawn` scheme is what continuous integration tests.
