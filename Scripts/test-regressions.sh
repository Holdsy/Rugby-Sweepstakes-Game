#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
result_dir="${TEST_RESULTS_DIR:-$project_dir/.test-results/$(date +%Y%m%d-%H%M%S)-$$}"
mkdir -p "$result_dir"
if [[ -n "${TEST_DESTINATION:-}" ]]; then
  destination="$TEST_DESTINATION"
else
  device_id="$(python3 - <<'PY'
import json, subprocess
inventory=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
for devices in inventory['devices'].values():
    for device in devices:
        if device['name']=='Ruck Regression Tests iOS 27':
            print(device['udid']);raise SystemExit
runtimes=json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','--json']))['runtimes']
available=[r for r in runtimes if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
runtime=next((r for r in available if r['identifier']=='com.apple.CoreSimulator.SimRuntime.iOS-27-0'), sorted(available,key=lambda r:tuple(map(int,r['version'].split('.'))))[-1])
types=json.loads(subprocess.check_output(['xcrun','simctl','list','devicetypes','--json']))['devicetypes']
device=next((d for d in types if d['name']=='iPhone 17'), next(d for d in types if d['name'].startswith('iPhone')))
print(subprocess.check_output(['xcrun','simctl','create','Ruck Regression Tests iOS 27',device['identifier'],runtime['identifier']],text=True).strip())
PY
)"
  destination="platform=iOS Simulator,id=$device_id"
fi
printf 'Running regression tests on %s\n' "$destination"
printf 'Results: %s\n' "$result_dir"
if ! xcodebuild -project 'Rugby Sweepstakes Game.xcodeproj' -scheme 'Ruck of the Draw Regression' -destination "$destination" -parallel-testing-enabled NO -derivedDataPath "${TEST_DERIVED_DATA_DIR:-$project_dir/.test-results/DerivedData}" -resultBundlePath "$result_dir/Regression.xcresult" CODE_SIGNING_ALLOWED=NO test > "$result_dir/xcodebuild.log" 2>&1; then
  tail -100 "$result_dir/xcodebuild.log"
  exit 1
fi
xcrun xcresulttool get test-results summary --path "$result_dir/Regression.xcresult" > "$result_dir/summary.json"
python3 - "$result_dir/summary.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
print('Result:',s.get('result','unknown'))
for key in ['totalTestCount','passedTests','failedTests','skippedTests']:
    if key in s: print(f'{key}: {s[key]}')
PY
