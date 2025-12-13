#!/usr/bin/env bash
# Save as ~/.config/hypr/scripts/focus-priority-or-fallback.sh
#
# Usage:
#   focus-priority-or-fallback.sh title=Picture-in-Picture class=mpv class=jellyfin -- jellyfin
#   - Any number of matchers in precedence order. Supported fields: class, title
#   - Operators:
#       =     exact match (e.g., title=Picture-in-Picture)
#       ~=    substring match (e.g., title~=Picture)
#       ~i=   case-insensitive substring (e.g., title~i=picture)
#       ~re=  regex match via jq test() (e.g., title~re=^Picture)
#   - OR-groups at a single precedence level using parentheses and '|':
#       (class=mpv|class=vlc|title~i=picture)
#   - Use "--" to separate matchers from the fallback command. If only one
#     argument remains after "--", it is executed via "sh -c"; otherwise
#     arguments are executed directly.

# Cache Hyprland clients JSON once for efficiency
clients_json="$(hyprctl clients -j 2>/dev/null)"

# Focus a window by address and exit
focus_address() {
	addr="$1"
	[ -n "$addr" ] || return 1
	hyprctl dispatch focuswindow "address:$addr"
	exit 0
}

# Execute fallback command if provided
run_fallback() {
	if [ "$#" -eq 0 ]; then
		exit 0
	fi
	if [ "$#" -eq 1 ]; then
		sh -c "$1" &
		exit 0
	fi
	"$@" &
	exit 0
}

# Parse arguments: collect matchers until '--', then fallback command
in_fallback=0
last_bare=""
matchers_buf=""

while [ "$#" -gt 0 ]; do
	if [ "$in_fallback" -eq 1 ]; then
		break
	fi
	case "$1" in
	--)
		in_fallback=1
		shift
		;;
	*=*)
		# Append matcher token as its own line (key=value)
		matchers_buf=$(printf '%s\n%s\n' "$matchers_buf" "$1")
		shift
		;;
	*)
		# Keep last bare token to allow single-word fallback without '--'
		last_bare="$1"
		shift
		;;
	esac
done

# Resolve first matching address in one jq pass, respecting matcher order
addr=$(printf '%s' "$matchers_buf" | jq -r -R -s --argjson clients "$clients_json" '
  def split_once(s): . as $t | ($t|index(s)) as $i | if $i == null then [$t] else [ $t[0:$i], $t[($i + (s|length)):]] end;
  def parse_one(t):
    if (t | index("~re=")) then (t | split_once("~re=")) as $p | {key: ($p[0] // ""), op: "re", val: ($p[1] // "")}
    elif (t | index("~i=")) then (t | split_once("~i=")) as $p | {key: ($p[0] // ""), op: "icontains", val: ($p[1] // "")}
    elif (t | index("~=")) then (t | split_once("~=")) as $p | {key: ($p[0] // ""), op: "contains", val: ($p[1] // "")}
    elif (t | index("=")) then (t | split_once("=")) as $p | {key: ($p[0] // ""), op: "eq", val: ($p[1] // "")}
    else {key: t, op: "", val: ""} end;
  def parse_token(t):
    if (t | startswith("(") and endswith(")")) then
      (t[1:-1] | split("|") | map(parse_one(.))) as $alts | {type:"any", ms:$alts}
    else {type:"one", m:(parse_one(t))} end;
  def getval(k; c): if k == "class" then c.class elif k == "title" then c.title else null end;
  def is_match(m; c):
    (getval(m.key; c)) as $v
    | if $v == null then false
      elif m.op == "eq" then $v == m.val
      elif m.op == "contains" then ($v | tostring | index(m.val)) != null
      elif m.op == "icontains" then ((($v|tostring)|ascii_downcase) | index((m.val|ascii_downcase))) != null
      elif m.op == "re" then ($v | test(m.val))
      else false end;
  def matches(T; c):
    if T.type == "one" then is_match(T.m; c)
    elif T.type == "any" then any(T.ms[]; is_match(. ; c))
    else false end;
  ( split("\n") | map(select(length>0)) | map(parse_token(.)) ) as $ms
  | first( $ms[] as $T | $clients[] | select(matches($T; .)) | .address )
  // empty
')

[ -n "$addr" ] && focus_address "$addr"

# No matcher matched; run fallback
if [ "$in_fallback" -eq 1 ]; then
	run_fallback "$@"
else
	[ -n "$last_bare" ] && run_fallback "$last_bare"
fi

exit 0
