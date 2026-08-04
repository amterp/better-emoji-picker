#!/usr/bin/env python3
"""
Build emoji data for BetterEmojiPicker.

Merges four upstream sources into the app's search-optimized format:

  - iamcal/emoji-data     metadata, Apple-render filter, categories, sort order
  - muan/emojilib         rich colloquial keywords ("happy", "highfive")
  - unicode-org/cldr      human display names and annotation keywords
  - ummoji/emoji-rankings real-world usage frequency

Usage:
    python3 build_emoji_data.py

Output:
    ../BetterEmojiPicker/Resources/emojis.json
"""

import json
import math
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

# URL for emoji-data (the industry standard used by Slack, Discord, etc.)
# Note: The repo is "emoji-data" not "emoji-datasource"
EMOJI_DATA_URL = "https://raw.githubusercontent.com/iamcal/emoji-data/master/emoji.json"

# URL for emojilib (provides rich keywords for better search)
# We merge these with emoji-data to get the best of both worlds:
# - emoji-data: reliable metadata, has_img_apple filter, categories
# - emojilib: rich keywords like "happy", "joy", "highfive" for great search UX
EMOJILIB_URL = "https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json"

# CLDR annotations supply the names humans actually use. emoji-data ships the
# legacy Unicode character names, which are archaic for exactly the emojis
# people search for most: "heavy black heart" (❤️), "thumbs up sign" (👍),
# "white medium star" (⭐), "squared ok" (🆗). Ranking on those names actively
# buries the popular emoji, so CLDR wins and the legacy name becomes a keyword.
#
# annotations/ has names for base emoji; annotationsDerived/ covers sequences
# built from them. We need both for full coverage.
CLDR_ANNOTATIONS_URL = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml"
CLDR_DERIVED_URL = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/en.xml"

# Observed usage frequency, sourced from EmojiTracker's Twitter corpus.
# This is the only public machine-readable emoji frequency data we could find.
# It covers 845 emoji and is a 2015-era snapshot, so anything encoded from
# Unicode 9.0 (2016) on is absent - see MODERN_POPULAR below.
EMOJI_RANKINGS_URL = "https://raw.githubusercontent.com/ummoji/emoji-rankings/HEAD/rankings.json"

# Output path (relative to this script)
SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR.parent / "BetterEmojiPicker" / "Resources" / "emojis.json"


# Hand-assigned popularity for emoji the frequency snapshot predates.
#
# Without these, 🤣 and 🤔 score as low as an obscure flag, and search returns
# 💭 for "think" and demotes 🤣 below 😂 for "laugh". We tried deriving a
# stand-in from Unicode sort order instead; measured against real queries it
# moved almost nothing, so the values are set by hand.
#
# Scale matches the derived scores: 1.0 is "as common as 😂", 0.30 is the
# no-data default. Emoji popularity shifts slowly, so this rarely needs edits.
MODERN_POPULAR = {
    # Ubiquitous
    "🤣": 0.95, "🤔": 0.92,
    # Very common
    "🥺": 0.88, "🥰": 0.88, "🙄": 0.86, "🤗": 0.84, "🤦": 0.84, "🤷": 0.84,
    "🤝": 0.82, "🥳": 0.80, "🤯": 0.80, "🤩": 0.78, "🖤": 0.78,
    # Common
    "🫡": 0.74, "🤡": 0.74, "🧡": 0.72, "🤍": 0.72, "🥵": 0.72, "🫶": 0.70,
    "🤪": 0.70, "🥲": 0.70, "🤞": 0.70, "🧠": 0.68, "🥶": 0.68, "🫠": 0.68,
    "🤙": 0.66, "🫂": 0.66, "🤎": 0.64, "🩷": 0.64, "🥹": 0.64, "🤢": 0.62,
    "🤮": 0.62, "😵‍💫": 0.62, "😮‍💨": 0.60, "🤫": 0.60, "🤭": 0.60, "🤨": 0.60,
    # Moderate
    "🥴": 0.58, "🫰": 0.56, "🤟": 0.56, "🤘": 0.56, "🫣": 0.54, "🫢": 0.54,
    "🥸": 0.52, "🤌": 0.52, "🫵": 0.52, "🦄": 0.52, "🤠": 0.50, "🧊": 0.50,
    "🥑": 0.50, "🤖": 0.50, "🤤": 0.50, "🤥": 0.48, "🤒": 0.48, "🤕": 0.48,
    "🤧": 0.48, "🫥": 0.44, "🫱": 0.42, "🧑": 0.42,
}

# Codepoints that mark an emoji as a variant of a more canonical base form.
# ♂/♀ gender signs, ➡ direction, and the hair-component sequences all produce
# near-duplicate entries (🧎 🧎‍♂️ 🧎‍♀️ 🧎‍➡️ 🧎‍♀️‍➡️ 🧎‍♂️‍➡️) that otherwise flood a
# single-word search and bury the emoji the user meant.
VARIANT_CODEPOINTS = ["♂", "♀", "➡", "\U0001f9b0", "\U0001f9b1", "\U0001f9b2", "\U0001f9b3"]

GENDERED_NAME_PREFIXES = {"man", "woman", "men", "women"}

# Popularity assigned to emoji absent from every frequency source.
DEFAULT_POPULARITY = 0.30


def download_json(url: str) -> list:
    """Download and parse JSON from a URL."""
    print(f"Downloading: {url}")
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))


def download_text(url: str) -> str:
    """Download raw text from a URL."""
    print(f"Downloading: {url}")
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8")


def normalize(emoji_char: str) -> str:
    """
    Strip variation selectors so lookups match across sources.

    CLDR removes U+FE0F from its `cp` attributes while emoji-data keeps it, so
    "❤️" and "❤" must resolve to the same key.
    """
    return emoji_char.replace("️", "")


def hex_to_emoji(unified: str) -> str:
    """
    Convert a Unicode hex code string to the actual emoji character.

    Examples:
        "1F600" -> "😀"
        "1F1FA-1F1F8" -> "🇺🇸" (flag, multi-codepoint)
    """
    # Split on dash for multi-codepoint emojis (like flags, skin tones, ZWJ sequences)
    codepoints = unified.split("-")
    # Convert each hex string to an integer, then to a character
    chars = [chr(int(cp, 16)) for cp in codepoints]
    return "".join(chars)


def load_cldr(urls: list[str]) -> tuple[dict, dict]:
    """
    Parse CLDR annotation XML into display names and keyword lists.

    Each emoji gets two annotation elements: one with type="tts" holding the
    display name, one untyped holding pipe-separated keywords.

    Returns:
        (names, keywords) both keyed by normalized emoji character.
    """
    names: dict[str, str] = {}
    keywords: dict[str, list[str]] = {}

    for url in urls:
        root = ET.fromstring(download_text(url))
        for annotation in root.iter("annotation"):
            key = normalize(annotation.get("cp", ""))
            text = (annotation.text or "").strip()
            if not key or not text:
                continue
            if annotation.get("type") == "tts":
                names[key] = text
            else:
                keywords[key] = [k.strip() for k in text.split("|") if k.strip()]

    return names, keywords


def build_frequency_table(rankings: list) -> dict[str, float]:
    """
    Convert raw usage counts into a 0.45-1.0 popularity scale.

    Counts span four orders of magnitude, so we normalize on a log scale -
    otherwise 😂 alone would swamp everything below it. The floor of 0.45 keeps
    every measured emoji above the no-data default: appearing in the corpus at
    all is itself evidence of real use.
    """
    counts = {normalize(r["char"]): r["score"] for r in rankings if r.get("score", 0) > 0}
    if not counts:
        return {}

    log_min = math.log(min(counts.values()))
    log_max = math.log(max(counts.values()))
    span = log_max - log_min or 1.0

    return {
        char: 0.45 + 0.55 * (math.log(count) - log_min) / span
        for char, count in counts.items()
    }


def variant_penalty(emoji_char: str, name: str, category: str) -> float:
    """
    How far to demote an emoji for being a non-canonical form.

    Gendered, directional, and hair variants are what the user almost never
    means when they type a single word, and flags crowd out real matches for
    country and color words. Subtracted from popularity rather than filtered,
    so everything stays findable - just not first.
    """
    penalty = 0.0
    lowered = name.lower()

    if any(cp in emoji_char for cp in VARIANT_CODEPOINTS):
        penalty += 0.45

    words = lowered.split()
    if words and words[0] in GENDERED_NAME_PREFIXES:
        penalty += 0.25

    if "facing right" in lowered:
        penalty += 0.25

    if category == "Flags":
        penalty += 0.35

    # Cap so no emoji is pushed so far down that it is unreachable.
    return min(penalty, 0.85)


def compute_popularity(emoji_char: str, name: str, category: str, frequencies: dict) -> float:
    """
    Blend measured usage with a preference for canonical forms.

    The result is a ranking prior, not a measurement. Search treats it as a
    tiebreaker within a match-quality tier, never as a reason to surface a
    worse match.
    """
    key = normalize(emoji_char)
    base = MODERN_POPULAR.get(key) or frequencies.get(key) or DEFAULT_POPULARITY
    popularity = base - variant_penalty(emoji_char, name, category)
    return round(max(0.0, min(1.0, popularity)), 4)


def build_keywords(entry: dict, emoji_char: str, legacy_name: str, emojilib_data: dict, cldr_keywords: dict) -> list[str]:
    """
    Merge every keyword source, most relevant first.

    The legacy Unicode name is included so queries that worked before the
    switch to CLDR names still resolve - searching "heavy black heart" must
    still find ❤️.
    """
    keywords: list[str] = []
    seen: set[str] = set()

    def add(raw: str):
        cleaned = raw.lower().replace("_", " ").strip()
        # Skip text emoticons like ":D" and ";)"
        if not cleaned or cleaned in seen or raw.startswith((":", ";")):
            return
        seen.add(cleaned)
        keywords.append(cleaned)

    # short_names from emoji-data ("thumbsup", "thumbs_up") are the most direct
    for short_name in entry.get("short_names", []):
        add(short_name)

    # CLDR annotations: curated, translated, and consistently scoped
    for keyword in cldr_keywords.get(normalize(emoji_char), []):
        add(keyword)

    # emojilib: colloquial terms nobody else carries ("highfive", "yum")
    # Index 0 repeats the name, so skip it.
    for keyword in emojilib_data.get(emoji_char, [])[1:]:
        add(keyword)

    add(legacy_name)

    return keywords


def build_emoji_list(raw_data: list, emojilib_data: dict, cldr_names: dict,
                     cldr_keywords: dict, frequencies: dict) -> list[dict]:
    """
    Transform emoji-data format into our app's format, enriched from every source.

    Output format:
    {
        "emoji": "👍",
        "name": "thumbs up",
        "keywords": ["thumbsup", "+1", "hand", "thumbs up sign", ...],
        "category": "People & Body",
        "sortOrder": 197,
        "popularity": 0.7413
    }
    """
    emojis = []
    seen_emojis = set()  # Track duplicates
    missing_cldr = []

    for entry in raw_data:
        # Skip emojis that don't have an Apple rendering
        # (they won't display correctly on macOS)
        if not entry.get("has_img_apple", False):
            continue

        # Skip skin tone variations for MVP
        # These have a "skin_variations" parent or contain skin tone modifiers
        unified = entry.get("unified", "")

        # Skin tone modifiers are in range 1F3FB-1F3FF
        # Skip entries that ARE skin tone variations (but keep base emojis that support them)
        if any(mod in unified for mod in ["1F3FB", "1F3FC", "1F3FD", "1F3FE", "1F3FF"]):
            continue

        # Convert hex code to actual emoji character
        try:
            emoji_char = hex_to_emoji(unified)
        except (ValueError, OverflowError):
            # Skip invalid entries
            continue

        # Skip duplicates (shouldn't happen, but be safe)
        if emoji_char in seen_emojis:
            continue
        seen_emojis.add(emoji_char)

        legacy_name = entry.get("name", "").lower()
        cldr_name = cldr_names.get(normalize(emoji_char))
        if not cldr_name:
            missing_cldr.append(emoji_char)
        name = (cldr_name or legacy_name).lower()
        category = entry.get("category", "Other")

        emojis.append({
            "emoji": emoji_char,
            "name": name,
            "keywords": build_keywords(entry, emoji_char, legacy_name, emojilib_data, cldr_keywords),
            "category": category,
            "sortOrder": entry.get("sort_order", 9999),  # Unicode order for ranking tiebreaker
            "popularity": compute_popularity(emoji_char, name, category, frequencies),
        })

    if missing_cldr:
        print(f"\n⚠️  {len(missing_cldr)} emoji have no CLDR name and fell back to the legacy "
              f"Unicode name. Those will rank poorly for their obvious search terms. "
              f"Check whether CLDR moved them between annotations/ and annotationsDerived/: "
              f"{' '.join(missing_cldr[:10])}")

    return emojis


def report(emojis: list[dict], frequencies: dict):
    """Print a summary and the checks worth eyeballing after a rebuild."""
    categories = {}
    for e in emojis:
        categories[e["category"]] = categories.get(e["category"], 0) + 1

    print()
    print("By category:")
    for cat, count in sorted(categories.items()):
        print(f"  {cat}: {count}")

    measured = sum(1 for e in emojis if normalize(e["emoji"]) in frequencies)
    curated = sum(1 for e in emojis if normalize(e["emoji"]) in MODERN_POPULAR)
    defaulted = len(emojis) - measured - curated

    print()
    print("Popularity coverage:")
    print(f"  measured (frequency data): {measured}")
    print(f"  curated (MODERN_POPULAR):  {curated}")
    print(f"  default ({DEFAULT_POPULARITY}):            {defaulted}")

    unused = [c for c in MODERN_POPULAR if c not in {normalize(e["emoji"]) for e in emojis}]
    if unused:
        print(f"\n⚠️  MODERN_POPULAR entries that match no emoji (typo, or dropped upstream): {' '.join(unused)}")

    overridden = [c for c in MODERN_POPULAR if c in frequencies]
    if overridden:
        print(f"\n⚠️  MODERN_POPULAR overrides real measured data for: {' '.join(overridden)}. "
              f"Measured data is better evidence - drop these entries unless the override is deliberate.")

    print()
    print("Most popular:")
    for e in sorted(emojis, key=lambda x: -x["popularity"])[:12]:
        print(f"  {e['emoji']} {e['name']} ({e['popularity']})")


def main():
    print("=" * 60)
    print("BetterEmojiPicker - Emoji Data Builder")
    print("=" * 60)
    print()

    raw_data = download_json(EMOJI_DATA_URL)
    print(f"Downloaded {len(raw_data)} entries from emoji-data")

    emojilib_data = download_json(EMOJILIB_URL)
    print(f"Downloaded {len(emojilib_data)} entries from emojilib")

    cldr_names, cldr_keywords = load_cldr([CLDR_ANNOTATIONS_URL, CLDR_DERIVED_URL])
    print(f"Parsed {len(cldr_names)} CLDR names and {len(cldr_keywords)} CLDR keyword sets")

    rankings = download_json(EMOJI_RANKINGS_URL)
    frequencies = build_frequency_table(rankings)
    print(f"Derived popularity for {len(frequencies)} emoji from usage rankings")
    print()

    emojis = build_emoji_list(raw_data, emojilib_data, cldr_names, cldr_keywords, frequencies)
    print(f"Processed {len(emojis)} emojis (after filtering)")

    report(emojis, frequencies)

    # Ensure output directory exists
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Write output (minified for smaller file size)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        # Use separators to minify, ensure_ascii=False to keep emoji readable
        json.dump(emojis, f, ensure_ascii=False, separators=(",", ":"))

    file_size = OUTPUT_PATH.stat().st_size
    print()
    print(f"Output: {OUTPUT_PATH}")
    print(f"Size: {file_size:,} bytes ({file_size / 1024:.1f} KB)")
    print()
    print("✅ Done!")


if __name__ == "__main__":
    main()
