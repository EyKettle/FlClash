# ─── Local pre-CI validation ───
# Usage: just              — show this help
#        just test          — quick checks (always available)
#        just test-full     — full checks (includes env-dependent)

# Default: show available recipes
default:
    @just --list

# Quick checks — always available, no special environment needed
test: check-versions check-changelog check-submodules check-setup-dart check-awk check-template check-workflows

# Full checks — includes Kotlin/Go/Flutter checks
test-full: test flutter-analyze flutter-test go-vet kotlin-compile check-distributor

# ─── Version consistency (warning only) ───
# Checks pubspec.yaml version matches CHANGELOG.md latest tag
check-versions:
    #!/usr/bin/env bash
    pub_ver=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
    chg_ver=$(grep -m1 '^## ' CHANGELOG.md 2>/dev/null | sed 's/^## v//')
    if [ -z "$chg_ver" ]; then
        echo "⚠️  CHANGELOG.md: no version heading found"
    elif [ "$pub_ver" != "$chg_ver" ]; then
        echo "⚠️  version: pubspec=$pub_ver ≠ CHANGELOG=$chg_ver (update before release)"
    else
        echo "✅ version consistent: $pub_ver"
    fi

# ─── CHANGELOG heading hierarchy ───
# Validates: ## version (H2) → ### type (H3), no ## type directly
check-changelog:
    #!/usr/bin/env bash
    set -euo pipefail
    errors=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[^#] ]]; then
            if [[ ! "$line" =~ ^##\ v ]]; then
                echo "❌ H2 without version: $line"
                ((errors++))
            fi
        fi
    done < CHANGELOG.md
    if [ "$errors" -gt 0 ]; then
        exit 1
    fi
    echo "✅ CHANGELOG heading hierarchy OK"

# ─── Submodule integrity ───
check-submodules:
    #!/usr/bin/env bash
    set -euo pipefail
    if git submodule status | grep -q '^-'; then
        echo "⚠️  Uninitialized submodules found. Run: git submodule update --init --recursive"
        exit 1
    fi
    if git submodule status | grep -q '^+'; then
        echo "⚠️  Submodules not at expected commit:"
        git submodule status | grep '^+'
        exit 1
    fi
    echo "✅ Submodules OK"

# ─── setup.dart syntax check ───
check-setup-dart:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking setup.dart..."
    out=$(dart analyze setup.dart 2>&1) || {
        echo "$out"
        exit 1
    }
    echo "✅ setup.dart OK"

# ─── group-commits.awk syntax check ───
check-awk:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v gawk &>/dev/null; then
        gawk --lint -f /dev/null 2>&1 || true
        out=$(gawk --lint -f scripts/group-commits.awk /dev/null 2>&1) || true
        if echo "$out" | grep -q 'error:'; then
            echo "$out"
            exit 1
        fi
        echo "✅ awk script OK"
    else
        echo "⏭️  gawk not installed, skipping awk lint"
    fi

# ─── Release template placeholder check ───
check-template:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -q 'VERSION' .github/release_template.md; then
        echo "✅ release_template.md has VERSION placeholder"
    else
        exit 1
    fi

# ─── Workflow YAML syntax check ───
check-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    find .github/workflows -maxdepth 1 -name '*.yaml' | while IFS= read -r f; do
        python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>&1 || {
            echo "❌ $f: YAML syntax error"
            exit 1
        }
        echo "✅ $(basename $f) YAML OK"
    done

# ─── Flutter analyze (already in CI Test) ───
flutter-analyze:
    flutter analyze --no-fatal-infos

# ─── Flutter test (already in CI Test) ───
flutter-test:
    flutter test --reporter expanded

# ─── Go vet (core subproject, vettable packages only) ───
go-vet:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v go &>/dev/null; then
        cd core
        vettable=""
        for pkg in $(go list ./... 2>/dev/null); do
            out=$(go vet "$pkg" 2>&1) || true
            if echo "$out" | grep -q 'build constraints exclude'; then
                echo "⏭️  skip $pkg (platform constraints)"
                continue
            fi
            vettable="$vettable $pkg"
        done
        if [ -z "$vettable" ]; then
            echo "❌ No vettable Go packages (all excluded by build constraints)"
            exit 1
        fi
        echo "Running go vet on vettable packages..."
        # shellcheck disable=SC2086
        go vet $vettable
        echo "✅ Go vet OK"
        echo "   Vetted: $vettable"
    else
        echo "⏭️  go not installed, skipping"
    fi

# ─── Kotlin compile check (service module, requires Android SDK) ───
kotlin-compile:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${ANDROID_HOME:-}" ] && [ -f android/gradlew ]; then
        echo "Running Kotlin compile check..."
        # Kotlin 2.2.x cannot parse Java versions >= 25
        java_ver=$(java -version 2>&1 | head -1 | sed 's/[^"]*"//; s/".*//')
        major=$(echo "$java_ver" | cut -d. -f1)
        if [ "$major" -ge 25 ] 2>/dev/null; then
            echo "❌ Kotlin 2.2.10 incompatible with Java $java_ver"
            echo "   Install JDK 17 or JDK 21, then set: export JAVA_HOME=/usr/lib/jvm/java-17-openjdk"
            exit 1
        fi
        cd android
        out=$(./gradlew :service:compileReleaseKotlin 2>&1) || {
            echo "$out" | grep -E "^e:|error:|FAILED" | head -10
            exit 1
        }
        echo "$out" | tail -3
        echo "✅ Kotlin compile OK"
    else
        echo "⏭️  Android SDK not configured, skipping Kotlin compile check"
    fi

# ─── flutter_distributor activation check ───
check-distributor:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d plugins/flutter_distributor/packages/flutter_distributor ]; then
        echo "Checking flutter_distributor activation..."
        out=$(dart pub global activate -s path plugins/flutter_distributor/packages/flutter_distributor 2>&1) || {
            echo "❌ flutter_distributor activation failed"
            echo "$out"
            exit 1
        }
        echo "✅ flutter_distributor OK"
    else
        echo "⚠️  plugins/flutter_distributor not found — run git submodule update --init --recursive"
        exit 1
    fi
