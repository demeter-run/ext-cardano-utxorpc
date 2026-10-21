#!/bin/sh
# Fails when the lockfile carries a TLS trust crate below its floor.
set -eu

lock="${1:-Cargo.lock}"

awk '
function lt(a, b,   i, n, m, x, y) {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= 3; i++) {
        if ((x[i] + 0) < (y[i] + 0)) return 1
        if ((x[i] + 0) > (y[i] + 0)) return 0
    }
    return 0
}
/^name = / { name = $3; gsub(/"/, "", name); next }
/^version = / {
    v = $3; gsub(/"/, "", v); sub(/[-+].*/, "", v)
    floor = ""
    if (name == "webpki-roots" || name == "webpki-root-certs") floor = "1.0.10"
    if (name == "rustls-webpki") floor = "0.103.16"
    if (floor != "" && lt(v, floor)) {
        printf "trust floor: %s %s is below %s\n", name, v, floor
        bad = 1
    }
}
END { exit bad }
' "$lock"
