#!/usr/bin/env bash

set -e -o pipefail

if  [[ -n "$(type -t flutter)" ]]; then
  : ${FLUTTER:=flutter}
fi
echo "== FLUTTER: $FLUTTER"

FLUTTER_VERS=`$FLUTTER --version | head -1`
echo "== FLUTTER_VERS: $FLUTTER_VERS"

# plugin_codelab is a special case since it's a plugin.  Analysis doesn't seem to be working.
pushd $PWD
echo "== TESTING plugin_codelab"
cd ./plugin_codelab
$FLUTTER format --dry-run --set-exit-if-changed .;
popd

declare -a CODELABS=(
  "add_flutter_to_android_app"
  "cookbook"
  "cupertino_store"
  "firebase-get-to-know-flutter"
  "friendly_chat"
  "github-graphql-client"
  "google-maps-in-flutter"
  "in_app_purchases"
  "star_counter"
  "startup_namer"
  "startup_namer_null_safety"
  "testing_codelab"
  )

# Plugin codelab is failing on ubuntu-latest in CI.
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  CODELABS+=("plugin_codelab")
fi

declare -a PROJECT_PATHS=($(
  for CODELAB in "${CODELABS[@]}"
  do 
    find $CODELAB -not -path './flutter/*' -not -path './plugin_codelab/pubspec.yaml' -name pubspec.yaml -exec dirname {} \; 
  done
  ))

for PROJECT in "${PROJECT_PATHS[@]}"; do
  echo "== TESTING $PROJECT"
  (
    cd "$PROJECT";
    set -x;
    # Only warn about analysis and format issues for dev and beta
    $FLUTTER analyze --no-fatal-infos;
    $FLUTTER format --dry-run .;
    $FLUTTER test
  )
done

declare -a WORKSHOP_STEP_PATHS=($(
    find dartpad_codelabs -name snippet.dart -exec dirname {} \; 
  ))

for WORKSHOP_STEP_PATH in "${WORKSHOP_STEP_PATHS[@]}"; do
  echo "== TESTING $WORKSHOP_STEP_PATH"
  (
    cd "$WORKSHOP_STEP_PATH";
    set -x;
    if [[ -r solution.dart ]]; then
      $FLUTTER format --dry-run solution.dart;
    else
      $FLUTTER format --dry-run snippet.dart;
    fi
  )
done

echo "== END OF TESTS"
