#!/bin/bash
# Runs every check of the add-on under a virtual display with the Compatibility renderer.
#   bash tests/run_tests.sh [godot-binary]
# Needs: Godot 4.3+ (binary path as argument or GODOT env var), xvfb-run (Linux) and a software or hardware OpenGL driver.
# Renderer: Compatibility by default. For Forward+ (needs Vulkan, e.g. mesa-vulkan-drivers):
#   DRIVER=vulkan METHOD=forward_plus bash tests/run_tests.sh /path/to/godot
# On a desktop with a screen you can run one test by hand:
#   godot --path . res://tests/test_runner.tscn -- --test=still_frames
set -u
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
DRIVER="${DRIVER:-opengl3}"
METHOD="${METHOD:-gl_compatibility}"
RUN=(xvfb-run -a -s "-screen 0 1280x720x24")
command -v xvfb-run >/dev/null || RUN=()
fail=0
"$GODOT" --headless --path . --import --quit >/dev/null 2>&1
for t in static_scan identity moving_identity still_frames edge_follows_projection motion_noise integer_scale toggle late_camera start_disabled two_nodes colour_reduction; do
  out=$(timeout 300 "${RUN[@]}" "$GODOT" --path . --rendering-driver $DRIVER --rendering-method $METHOD --resolution 1280x720 res://tests/test_runner.tscn -- --test=$t 2>&1)
  line=$(echo "$out" | grep -E '^(PASS|FAIL) ' | tail -1)
  [ -z "$line" ] && line="FAIL $t: no result (crash or timeout)" && echo "$out" | grep -E 'SCRIPT ERROR|Parse Error' | head -5
  echo "$line"
  case "$line" in PASS*) ;; *) fail=1 ;; esac
done
exit $fail
