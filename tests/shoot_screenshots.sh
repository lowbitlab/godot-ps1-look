#!/bin/bash
# Re-creates the six 1280x720 screenshots in screenshots/ (same camera time for all of them).
#   bash tests/shoot_screenshots.sh [godot-binary]
set -u
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
RUN=(xvfb-run -a -s "-screen 0 1280x720x24")
command -v xvfb-run >/dev/null || RUN=()
"$GODOT" --headless --path . --import --quit >/dev/null 2>&1   # first run in a fresh checkout: import the project once
i=1
for p in off on palette dither fog panel; do
  out=$(printf 'screenshots/%02d_%s.png' $i $p)
  "${RUN[@]}" "$GODOT" --path . --rendering-driver opengl3 --resolution 1280x720 -- --still --time=0 --preset=$p --shot=res://$out 2>&1 | grep saved
  i=$((i+1))
done
