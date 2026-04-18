#!/usr/bin/env bash
# Mountain View Cafe and Bakery, build checks
set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJ_DIR="$( dirname "$SCRIPT_DIR" )"
HOST="http://localhost:8765"
PAGES=(index.html menu.html about.html visit.html)

PASS=0
FAIL=0
WARN=0
FAILURES=()

green()  { printf "\033[0;32m%s\033[0m" "$1"; }
red()    { printf "\033[0;31m%s\033[0m" "$1"; }
yellow() { printf "\033[0;33m%s\033[0m" "$1"; }
blue()   { printf "\033[0;34m%s\033[0m" "$1"; }

ok()   { printf "[%s] %s\n" "$(green PASS)" "$1"; PASS=$((PASS+1)); }
bad()  { printf "[%s] %s\n" "$(red FAIL)" "$1"; FAIL=$((FAIL+1)); FAILURES+=("$1"); }
warn() { printf "[%s] %s\n" "$(yellow WARN)" "$1"; WARN=$((WARN+1)); }
note() { printf "       %s\n" "$1"; }
heading() { printf "\n%s\n" "$(blue "==> $1")"; }

cd "$PROJ_DIR" || exit 2

printf "Mountain View Cafe and Bakery, build checks\n"
printf "===========================================\n"
printf "project: %s\n" "$PROJ_DIR"
printf "host:    %s\n" "$HOST"

heading "Server"
code=$(curl -s -o /dev/null -w "%{http_code}" "$HOST/" || echo 000)
if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
  ok "server reachable ($code)"
else
  bad "server unreachable (got $code)"
  printf "\nAborting.\n"; exit 1
fi

for page in "${PAGES[@]}"; do
  heading "$page"
  if [ ! -f "$page" ]; then
    bad "$page  file does not exist"
    continue
  fi

  has_title=$(grep -c '<title>[^<]\+</title>' "$page" || true)
  has_desc=$(grep -c 'name="description"[^>]*content="[^"]\+"' "$page" || true)
  has_viewport=$(grep -c 'name="viewport"' "$page" || true)
  has_icon=$(grep -c 'rel="icon"' "$page" || true)
  if [ "$has_title" -gt 0 ] && [ "$has_desc" -gt 0 ] && [ "$has_viewport" -gt 0 ] && [ "$has_icon" -gt 0 ]; then
    ok "$page  required meta present"
  else
    bad "$page  missing meta (title=$has_title desc=$has_desc viewport=$has_viewport icon=$has_icon)"
  fi

  refs=$(grep -oE '(src|href)="[^"]+"' "$page" \
    | sed -E 's/^(src|href)="//;s/"$//' \
    | grep -vE '^(https?:|mailto:|tel:|#|data:)' \
    | sort -u)
  total=0; missing=0; missing_list=""
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    total=$((total+1))
    rel="${ref%%#*}"
    [ -z "$rel" ] && continue
    if [ -f "$rel" ]; then
      ahttp=$(curl -s -o /dev/null -w "%{http_code}" "$HOST/$rel")
      if [ "$ahttp" != "200" ]; then
        missing=$((missing+1))
        missing_list+=$'\n       - '"$rel returns HTTP $ahttp"
      fi
    else
      missing=$((missing+1))
      missing_list+=$'\n       - '"$rel does not exist on disk"
    fi
  done <<< "$refs"
  if [ "$missing" = "0" ]; then
    ok "$page  asset paths ($total/$total)"
  else
    bad "$page  asset paths ($((total-missing))/$total)"
    printf "%s\n" "$missing_list"
  fi

  anchors=$(grep -oE 'href="[^"]+"' "$page" \
    | sed -E 's/^href="//;s/"$//' \
    | grep -E '#' || true)
  abad=0
  for a in $anchors; do
    [ -z "$a" ] && continue
    target_page="${a%%#*}"
    target_id="${a##*#}"
    [ -z "$target_id" ] && continue
    if [ -z "$target_page" ]; then
      target_page="$page"
    fi
    if [ -f "$target_page" ]; then
      if ! grep -qE "id=\"$target_id\"" "$target_page"; then
        abad=$((abad+1))
        note "$page  anchor #$target_id not found in $target_page"
      fi
    fi
  done
  if [ "$abad" = "0" ]; then
    ok "$page  internal anchors resolve"
  else
    bad "$page  $abad anchor target(s) missing"
  fi

  imgs=$(grep -c '<img' "$page" || true)
  alts=$(grep -oE '<img[^>]+alt="[^"]+"' "$page" | wc -l)
  if [ "$imgs" = "$alts" ]; then
    ok "$page  alt text ($alts/$imgs)"
  else
    bad "$page  alt text ($alts/$imgs)"
  fi
done

heading "Nav consistency"
nav_sig() {
  grep -oE 'href="(index|menu|about|visit)\.html"' "$1" \
    | sort -u | tr '\n' ',' | sed 's/,$//'
}
sig0=$(nav_sig "${PAGES[0]}")
all_match=1
for page in "${PAGES[@]}"; do
  sig=$(nav_sig "$page")
  if [ "$sig" != "$sig0" ]; then
    bad "nav links differ in $page"
    note "expected: $sig0"
    note "got:      $sig"
    all_match=0
  fi
done
if [ "$all_match" = "1" ]; then
  ok "nav links identical across all pages"
fi

heading "No em-dashes or en-dashes (AI tells)"
emdash_files=$(grep -l $'\xe2\x80\x94' index.html menu.html about.html visit.html style.css main.js 2>/dev/null || true)
endash_files=$(grep -l $'\xe2\x80\x93\|&ndash;\|&mdash;' index.html menu.html about.html visit.html style.css main.js 2>/dev/null || true)
if [ -z "$emdash_files" ] && [ -z "$endash_files" ]; then
  ok "no em-dashes or en-dashes found in any source file"
else
  for f in $emdash_files; do
    bad "em-dash found in $f"
    grep -n $'\xe2\x80\x94' "$f" | head -3 | while read -r line; do note "$line"; done
  done
  for f in $endash_files; do
    bad "en-dash or HTML entity found in $f"
    grep -nE $'\xe2\x80\x93|&ndash;|&mdash;' "$f" | head -3 | while read -r line; do note "$line"; done
  done
fi

heading "JS syntax"
if command -v node >/dev/null 2>&1; then
  if node --check main.js 2>/dev/null; then
    ok "main.js  syntax OK"
  else
    bad "main.js  syntax error"
    node --check main.js 2>&1 | head -5 | while read -r line; do note "$line"; done
  fi
else
  warn "node not installed, skipping JS syntax check"
fi

heading "CSS brace balance"
opens=$(grep -o '{' style.css | wc -l)
closes=$(grep -o '}' style.css | wc -l)
if [ "$opens" = "$closes" ]; then
  ok "style.css  $opens open / $closes close braces (balanced)"
else
  bad "style.css  $opens open vs $closes close (unbalanced)"
fi

heading "Image files"
img_total=0; img_bad=0
for img in images/*; do
  [ -f "$img" ] || continue
  img_total=$((img_total+1))
  size=$(stat -c %s "$img")
  if [ "$size" -lt 1024 ]; then
    img_bad=$((img_bad+1))
    note "$img  only ${size}b (suspect)"
    continue
  fi
  hex=$(head -c 4 "$img" | od -An -tx1 | tr -d ' \n')
  case "$hex" in
    ffd8ff*) : ;;
    89504e47) : ;;
    47494638) : ;;
    52494646) : ;;
    *)
      img_bad=$((img_bad+1))
      note "$img  unrecognized header $hex"
      ;;
  esac
done
if [ "$img_bad" = "0" ]; then
  ok "images  $img_total/$img_total valid"
else
  bad "images  $((img_total-img_bad))/$img_total valid"
fi

heading "HTTP smoke"
for page in "${PAGES[@]}"; do
  pcode=$(curl -s -o /dev/null -w "%{http_code}" "$HOST/$page")
  if [ "$pcode" = "200" ]; then
    ok "$page  serves 200"
  else
    bad "$page  serves $pcode"
  fi
done

printf "\n========================================\n"
printf "%s passed, %s failed, %s warnings\n" \
  "$(green "$PASS")" "$(red "$FAIL")" "$(yellow "$WARN")"
if [ "$FAIL" -gt 0 ]; then
  printf "\nFailures:\n"
  for f in "${FAILURES[@]}"; do printf "  - %s\n" "$f"; done
  exit 1
fi
exit 0
