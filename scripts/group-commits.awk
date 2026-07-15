#!/usr/bin/awk -f
# Group Conventional Commits by type for changelog/release generation
# Input: git log --pretty=format:"%s" lines
# Output: type-grouped sections with "<prefix> type" headers
# Usage: awk -f group-commits.awk [-v heading_prefix="###"]

BEGIN {
  if (heading_prefix == "") heading_prefix = "###"
}

!/^Update changelog/ && NF {
  line = $0; type = ""; scope = ""; desc = ""
  if (match(line, /^[a-z]+\(/)) {
    c = substr(line, RSTART, RLENGTH - 1)
    r = substr(line, RSTART + RLENGTH)
    if (c == "feat" || c == "fix" || c == "docs" || c == "chore" || c == "build" || c == "ci" || c == "refactor" || c == "perf" || c == "test" || c == "style" || c == "revert") {
      type = c
      if (match(r, /^[^)]+\): /)) {
        scope = substr(r, 1, RLENGTH - 3)
        desc = substr(r, RLENGTH + 1)
      }
    }
  }
  if (type == "") {
    if (match(line, /^[a-z]+: /)) {
      c = substr(line, RSTART, RLENGTH - 2)
      if (c == "feat" || c == "fix" || c == "docs" || c == "chore" || c == "build" || c == "ci" || c == "refactor" || c == "perf" || c == "test" || c == "style" || c == "revert") {
        type = c; desc = substr(line, RLENGTH + 1)
      }
    }
  }
  if (type == "") { other = other "- " line "\n"; next }
  if (scope != "") entry = "- (" scope ") " desc "\n"; else entry = "- " desc "\n"
  if (type == "feat") feats = feats entry
  else if (type == "fix") fixes = fixes entry
  else if (type == "docs") docss = docss entry
  else if (type == "chore") chores = chores entry
  else if (type == "build") builds = builds entry
  else if (type == "ci") cis = cis entry
  else if (type == "refactor") refs = refs entry
  else other = other entry
}
END {
  f = 1
  if (feats)  { if (!f) print ""; print heading_prefix " feat"; printf "%s", feats; f = 0 }
  if (fixes)  { if (!f) print ""; print heading_prefix " fix"; printf "%s", fixes; f = 0 }
  if (docss)  { if (!f) print ""; print heading_prefix " docs"; printf "%s", docss; f = 0 }
  if (chores) { if (!f) print ""; print heading_prefix " chore"; printf "%s", chores; f = 0 }
  if (builds) { if (!f) print ""; print heading_prefix " build"; printf "%s", builds; f = 0 }
  if (cis)    { if (!f) print ""; print heading_prefix " ci"; printf "%s", cis; f = 0 }
  if (refs)   { if (!f) print ""; print heading_prefix " refactor"; printf "%s", refs; f = 0 }
  if (other)  { if (!f) print ""; print heading_prefix " other"; printf "%s", other }
}
