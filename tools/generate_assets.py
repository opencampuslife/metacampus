#!/usr/bin/env python3
"""Generate game art assets via MiniMax API."""

import json
import os
import sys
import time
import urllib.request
import urllib.error

API_URL = "https://api.minimax.chat/v1/image_generation"
API_KEY = "MINIMAX_API_KEY_REMOVED"
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def generate_image(prompt: str, output_path: str, retries: int = 3) -> bool:
    """Generate an image via MiniMax API and save to output_path."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    body = json.dumps({
        "model": "image-01",
        "prompt": prompt,
        "n": 1,
    }).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={
            "Authorization": "Bearer " + API_KEY,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("base_resp", {}).get("status_code", -1) != 0:
                    msg = data.get("base_resp", {}).get("status_msg", "unknown")
                    print(f"  API error: {msg}")
                    return False
                urls = data.get("data", {}).get("image_urls", [])
                if not urls:
                    print(f"  No image URLs in response")
                    return False
                image_url = urls[0]
                print(f"  Downloading from: {image_url[:60]}...")
                urllib.request.urlretrieve(image_url, output_path)
                size = os.path.getsize(output_path)
                print(f"  Saved: {output_path} ({size} bytes)")
                return True
        except Exception as e:
            print(f"  Attempt {attempt + 1} failed: {e}")
            if attempt < retries - 1:
                time.sleep(3)
    return False


def generate_player_sprite():
    """Generate player character sprite sheet."""
    print("\n=== Generating Player Sprite ===")
    dir_path = os.path.join(PROJECT_DIR, "assets", "sprites", "player")
    output = os.path.join(dir_path, "player_spritesheet.png")
    prompt = (
        "2D pixel art game character sprite sheet, top-down view, "
        "male student with blue school uniform and short black hair, "
        "4 rows for 4 directions (down, up, left, right), "
        "4 columns for walk animation frames per row, "
        "each cell 64x64 pixels, total 256x256 pixels, "
        "transparent background, 16-bit color palette, "
        "retro RPG pixel art style, clean pixel edges"
    )
    return generate_image(prompt, output)


def generate_tile_textures():
    """Generate tilemap textures."""
    print("\n=== Generating Tilemap Textures ===")

    tiles = [
        ("grass.png", "grass",
         "2D top-down pixel art grass tile, 32x32 pixels, vibrant green grass texture with subtle variation, seamless tileable, RPG game style, 16-bit color palette"),
        ("path.png", "path",
         "2D top-down pixel art stone path tile, 32x32 pixels, gray cobblestone with brown edges, seamless tileable, RPG game style"),
        ("wall.png", "wall",
         "2D top-down pixel art brick wall tile, 32x32 pixels, red-brown bricks with mortar lines, seamless tileable, RPG game style"),
        ("water.png", "water",
         "2D top-down pixel art water tile, 32x32 pixels, blue water surface, seamless tileable, RPG game style, 16-bit color palette"),
        ("building_roof.png", "building_roof",
         "2D top-down pixel art roof tile, 64x64 pixels, gray-brown school building roof, RPG game style"),
        ("tree.png", "tree",
         "2D top-down pixel art tree tile, 64x64 pixels, round green tree canopy with brown trunk, RPG game style"),
        ("flower.png", "flower",
         "2D top-down pixel art flower tile, 32x32 pixels, small colorful flowers on grass, RPG game style"),
        ("fence.png", "fence",
         "2D top-down pixel art fence tile, 32x32 pixels, white wooden fence, RPG game style"),
    ]

    tiles_dir = os.path.join(PROJECT_DIR, "assets", "tiles")
    results = []
    for filename, name, prompt in tiles:
        output = os.path.join(tiles_dir, filename)
        print(f"\n  [{name}] {prompt[:60]}...")
        ok = generate_image(prompt, output)
        results.append((name, ok))
        time.sleep(1)

    return results


def main():
    print(f"Project: {PROJECT_DIR}")
    print(f"API: {API_URL}")

    ok = generate_player_sprite()
    if not ok:
        print("  Failed to generate player sprite")

    results = generate_tile_textures()

    print("\n=== Summary ===")
    print(f"  Player sprite: {'OK' if ok else 'FAIL'}")
    for name, ok in results:
        print(f"  {name}: {'OK' if ok else 'FAIL'}")


if __name__ == "__main__":
    main()
