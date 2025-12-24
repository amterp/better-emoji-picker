#!/usr/bin/env python3
"""
Build emoji data for BetterEmojiPicker.

Downloads emoji data from iamcal/emoji-datasource (the industry standard used by
Slack, Discord, etc.) and transforms it into our app's optimized format.

Source: https://github.com/iamcal/emoji-datasource
License: MIT

Usage:
    python3 build_emoji_data.py

Output:
    ../BetterEmojiPicker/Resources/emojis.json
"""

import json
import urllib.request
from pathlib import Path

# URL for emoji-data (the industry standard used by Slack, Discord, etc.)
# Note: The repo is "emoji-data" not "emoji-datasource"
EMOJI_DATA_URL = "https://raw.githubusercontent.com/iamcal/emoji-data/master/emoji.json"

# URL for emojilib (provides rich keywords for better search)
# We merge these with emoji-data to get the best of both worlds:
# - emoji-data: reliable metadata, has_img_apple filter, categories
# - emojilib: rich keywords like "happy", "joy", "highfive" for great search UX
EMOJILIB_URL = "https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json"

# Output path (relative to this script)
SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR.parent / "BetterEmojiPicker" / "Resources" / "emojis.json"


def download_json(url: str) -> list:
    """Download and parse JSON from a URL."""
    print(f"Downloading: {url}")
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))


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


def build_emoji_list(raw_data: list, emojilib_data: dict) -> list[dict]:
    """
    Transform emoji-data format into our app's format, enriched with emojilib keywords.

    Input format (emoji-data):
    {
        "name": "GRINNING FACE",
        "unified": "1F600",
        "short_name": "grinning",
        "short_names": ["grinning"],
        "category": "Smileys & Emotion",
        "subcategory": "face-smiling",
        "sort_order": 1,
        "has_img_apple": true,
        ...
    }

    Input format (emojilib):
    {
        "😀": ["grinning_face", "face", "smile", "happy", "joy", ":D", "grin"]
    }

    Output format (our app):
    {
        "emoji": "😀",
        "name": "grinning face",
        "keywords": ["grinning", "face", "smile", "happy", "joy", "grin"],
        "category": "Smileys & Emotion"
    }
    """
    emojis = []
    seen_emojis = set()  # Track duplicates

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

        # Build keywords list from multiple sources:
        # 1. short_names from emoji-data (like "grinning", "thumbsup")
        # 2. Rich keywords from emojilib (like "happy", "joy", "highfive")
        short_names = entry.get("short_names", [])
        emojilib_keywords = emojilib_data.get(emoji_char, [])

        # Combine and deduplicate, filtering out text emoticons like ":D"
        all_keywords = []
        seen_keywords = set()

        # Add short_names first (they're usually the most relevant)
        for kw in short_names:
            kw_clean = kw.lower().replace("_", " ")  # "thumbs_up" -> "thumbs up"
            if kw_clean not in seen_keywords:
                all_keywords.append(kw_clean)
                seen_keywords.add(kw_clean)

        # Add emojilib keywords (skip first one as it's usually the name)
        for kw in emojilib_keywords[1:] if len(emojilib_keywords) > 1 else []:
            kw_clean = kw.lower().replace("_", " ")
            # Skip emoticons (start with : or ;) and duplicates
            if kw_clean not in seen_keywords and not kw.startswith(":") and not kw.startswith(";"):
                all_keywords.append(kw_clean)
                seen_keywords.add(kw_clean)

        # Build the emoji entry
        emoji_entry = {
            "emoji": emoji_char,
            "name": entry.get("name", "").lower(),  # Normalize to lowercase
            "keywords": all_keywords,
            "category": entry.get("category", "Other"),
            "sortOrder": entry.get("sort_order", 9999)  # Unicode order for ranking tiebreaker
        }
        emojis.append(emoji_entry)

    # The original data is already sorted by sort_order, and we process in order,
    # so our output maintains the standard emoji ordering.

    return emojis


def main():
    print("=" * 60)
    print("BetterEmojiPicker - Emoji Data Builder")
    print("=" * 60)
    print()

    # Download source data from both sources
    raw_data = download_json(EMOJI_DATA_URL)
    print(f"Downloaded {len(raw_data)} entries from emoji-data")

    emojilib_data = download_json(EMOJILIB_URL)
    print(f"Downloaded {len(emojilib_data)} entries from emojilib")
    print()

    # Transform to our format, merging keywords from both sources
    emojis = build_emoji_list(raw_data, emojilib_data)
    print(f"Processed {len(emojis)} emojis (after filtering)")

    # Count by category
    categories = {}
    for e in emojis:
        cat = e["category"]
        categories[cat] = categories.get(cat, 0) + 1

    print()
    print("By category:")
    for cat, count in sorted(categories.items()):
        print(f"  {cat}: {count}")

    # Ensure output directory exists
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Write output (minified for smaller file size)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        # Use separators to minify, ensure_ascii=False to keep emoji readable
        json.dump(emojis, f, ensure_ascii=False, separators=(",", ":"))

    # Calculate file size
    file_size = OUTPUT_PATH.stat().st_size
    print()
    print(f"Output: {OUTPUT_PATH}")
    print(f"Size: {file_size:,} bytes ({file_size / 1024:.1f} KB)")

    # Show sample entries
    print()
    print("Sample entries:")
    for emoji in emojis[:3]:
        keywords_preview = emoji["keywords"][:5]
        print(f"  {emoji['emoji']} {emoji['name']} (order: {emoji['sortOrder']})")
        print(f"     keywords: {keywords_preview}")

    print()
    print("✅ Done!")


if __name__ == "__main__":
    main()
