# run every example through both phases and compare.
# The two phases must agree on the SVG (byte for byte), on every message,
# and on success/failure. Files named *error* are expected to fail.
set -u
cd "$(dirname "$0")"
ROOT=$PWD
WORK=$ROOT/build/test
LLC=${LLC:-llc}
CLANG=${CLANG:-clang}
pass=0
fail=0

for src in examples/*.draw; do
    name=$(basename "$src" .draw)
    d=$WORK/$name
    rm -rf "$d"; mkdir -p "$d/interp" "$d/comp"

    (cd "$d/interp" && "$ROOT/drawi" "$ROOT/$src" >out.txt 2>err.txt; echo $? >code.txt)

    (
        cd "$d/comp"
        if "$ROOT/drawc" "$ROOT/$src" -o program.ll >/dev/null 2>err.txt; then
            "$LLC" -filetype=obj -relocation-model=pic program.ll -o program.o &&
            "$CLANG" program.o "$ROOT/build/runtime.o" -lm -o program || { echo "build failed" >err.txt; echo 99 >code.txt; exit; }
            ./program >out.txt 2>err.txt; echo $? >code.txt
        else
            echo $? >code.txt; : >out.txt
        fi
    )

    ok=1
    cmp -s "$d/interp/code.txt" "$d/comp/code.txt" || ok=0
    cmp -s "$d/interp/err.txt" "$d/comp/err.txt" || ok=0
    cmp -s "$d/interp/out.txt" "$d/comp/out.txt" || ok=0
    if [ -f "$d/interp/picture.svg" ] || [ -f "$d/comp/picture.svg" ]; then
        cmp -s "$d/interp/picture.svg" "$d/comp/picture.svg" 2>/dev/null || ok=0
    fi
    code=$(cat "$d/interp/code.txt")
    case "$name" in
        *error*) [ "$code" != 0 ] || ok=0 ;;     # must be rejected
        *)       [ "$code" = 0 ] || ok=0 ;;      # must succeed
    esac

    if [ $ok = 1 ]; then
        pass=$((pass + 1))
        if [ "$code" = 0 ]; then echo "PASS  $src  (identical SVG, $(grep -c '<' "$d/interp/picture.svg") lines)"
        else echo "PASS  $src  (both phases rejected it with the same errors)"; fi
    else
        fail=$((fail + 1))
        echo "FAIL  $src  (see $d)"
    fi
done

echo "$pass passed, $fail failed"
[ $fail = 0 ]
