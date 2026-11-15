extends RefCounted

# Freshness check for docs/ai/goap-index.md: the committed index must equal
# what the GOAP-GUIDE banners produce right now. Regenerate with
#   ./tools/gen_goap_index.sh

const GoapIndex = preload("res://tools/goap_index.gd")


func run(harness) -> void:
	var expected := GoapIndex.build()
	harness.check(
		FileAccess.file_exists(GoapIndex.INDEX_PATH),
		"docs/ai/goap-index.md exists (generate with ./tools/gen_goap_index.sh)."
	)
	var actual := FileAccess.get_file_as_string(GoapIndex.INDEX_PATH)
	harness.check(
		actual == expected,
		"docs/ai/goap-index.md is up to date with the GOAP-GUIDE banners (regenerate with ./tools/gen_goap_index.sh)."
	)
