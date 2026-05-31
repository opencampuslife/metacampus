#!/usr/bin/env python3
"""Generate game audio assets via MiniMax TTS + Music API."""

import binascii
import json
import os
import sys
import time
import urllib.request
import urllib.error

TTS_API_URL = "https://api.minimaxi.com/v1/t2a_v2"
MUSIC_API_URL = "https://api.minimaxi.com/v1/music_generation"
API_KEY = os.environ.get("MINIMAX_API_KEY", "")
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

if not API_KEY:
    print("ERROR: MINIMAX_API_KEY environment variable not set")
    sys.exit(1)


def _api_request(url: str, body: dict, retries: int = 3) -> dict:
    """Send a POST request to MiniMax API and return parsed JSON."""
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": "Bearer " + API_KEY,
            "Content-Type": "application/json",
        },
        method="POST",
    )

    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                base = result.get("base_resp", {})
                if base.get("status_code", -1) != 0:
                    print(f"  API error: {base.get('status_msg', 'unknown')}")
                    return {}
                return result
        except Exception as e:
            print(f"  Attempt {attempt + 1} failed: {e}")
            if attempt < retries - 1:
                time.sleep(5)
    return {}


def generate_speech(text: str, voice_id: str, output_path: str,
                    emotion: str = "calm") -> bool:
    """Generate speech via MiniMax TTS API and save to output_path."""
    print(f"  TTS: {text[:40]}...")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    body = {
        "model": "speech-2.8-hd",
        "text": text,
        "stream": False,
        "voice_setting": {
            "voice_id": voice_id,
            "speed": 1.0,
            "vol": 1.0,
            "pitch": 0,
            "emotion": emotion,
        },
        "audio_setting": {
            "sample_rate": 24000,
            "format": "mp3",
            "channel": 1,
        },
    }

    result = _api_request(TTS_API_URL, body)
    if not result:
        return False

    audio_hex = result.get("data", {}).get("audio", "")
    if not audio_hex:
        print("  No audio data in response")
        return False

    audio_bytes = binascii.unhexlify(audio_hex)
    with open(output_path, "wb") as f:
        f.write(audio_bytes)
    print(f"  Saved: {output_path} ({len(audio_bytes)} bytes)")
    return True


def generate_music(prompt: str, output_path: str,
                   instrumental: bool = True, lyrics: str = "") -> bool:
    """Generate music via MiniMax Music API and save to output_path."""
    print(f"  Music: {prompt[:40]}...")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    body = {
        "model": "music-2.6",
        "prompt": prompt,
        "stream": False,
        "output_format": "hex",
        "audio_setting": {
            "sample_rate": 44100,
            "format": "mp3",
        },
        "is_instrumental": instrumental,
    }
    if not instrumental and lyrics:
        body["lyrics"] = lyrics

    result = _api_request(MUSIC_API_URL, body)
    if not result:
        return False

    audio_hex = result.get("data", {}).get("audio", "")
    if not audio_hex:
        print("  No audio data in response")
        return False

    audio_bytes = binascii.unhexlify(audio_hex)
    with open(output_path, "wb") as f:
        f.write(audio_bytes)
    print(f"  Saved: {output_path} ({len(audio_bytes)} bytes)")
    return True


def generate_bgm():
    """Generate background music tracks."""
    print("\n=== Generating BGM ===")
    music_dir = os.path.join(PROJECT_DIR, "assets", "audio", "music")
    os.makedirs(music_dir, exist_ok=True)

    tracks = [
        ("campus_theme.mp3",
         "校园背景音乐,轻松愉快,钢琴,弦乐,中速,适合校园场景,温馨,希望感,阳光明媚的校园早晨,积极向上"),
    ]

    for filename, prompt in tracks:
        output = os.path.join(music_dir, filename)
        if os.path.exists(output):
            print(f"  [SKIP] {filename} already exists")
            continue
        print(f"\n  [{filename}]")
        ok = generate_music(prompt, output, instrumental=True)
        if ok:
            print(f"  OK")
        else:
            print(f"  FAILED")
        time.sleep(2)


def generate_npc_voices():
    """Generate NPC voice clips."""
    print("\n=== Generating NPC Voice Clips ===")

    npcs = [
        ("admissions_director", "male-qn-qingse",
         "你好，我是招生办主任，欢迎来到校园，有什么我可以帮助你的吗？"),
        ("compliance_officer", "male-qn-jingpin",
         "我是合规部的负责人，所有的招生流程都必须符合教育部门的规定。"),
        ("homeroom_teacher", "female-wenrou",
         "同学们好，我是班主任王老师，有学习上的问题随时可以来找我。"),
        ("it_operator", "male-qn-qingse",
         "系统运维就交给我吧，学校的信息化建设每时每刻都在进步。"),
        ("logistics_manager", "male-qn-jingpin",
         "后勤保障是我的职责，食堂、宿舍、教室，方方面面都要管理好。"),
        ("parent_representative", "female-wenrou",
         "作为家长代表，我希望学校能给孩子提供最好的教育环境。"),
        ("principal", "male-qn-qingse",
         "我是校长，欢迎来到我们的校园。教育是百年大计，我们一起努力。"),
        ("student_representative", "female-tianmei",
         "大家好，我是学生会代表，学校的每一项活动都离不开同学们的参与。"),
    ]

    base_dir = os.path.join(PROJECT_DIR, "assets", "audio", "voices")
    errors = []

    for npc_id, voice_id, text in npcs:
        npc_dir = os.path.join(base_dir, npc_id)
        os.makedirs(npc_dir, exist_ok=True)

        for key, line in [("greeting", text)]:
            filename = f"{key}.mp3"
            output = os.path.join(npc_dir, filename)
            if os.path.exists(output):
                print(f"  [SKIP] {npc_id}/{filename} already exists")
                continue
            print(f"\n  [{npc_id}/{filename}]")
            ok = generate_speech(line, voice_id, output, "calm")
            if ok:
                print(f"  OK")
            else:
                print(f"  FAILED")
                errors.append(f"{npc_id}/{filename}")
            time.sleep(1)

    return errors


def main():
    print(f"Project: {PROJECT_DIR}")
    print(f"TTS API: {TTS_API_URL}")
    print(f"Music API: {MUSIC_API_URL}")

    generate_bgm()
    errors = generate_npc_voices()

    print("\n=== Summary ===")
    print(f"  BGM: generated")
    if errors:
        print(f"  NPC voice errors: {len(errors)}")
        for e in errors:
            print(f"    FAILED: {e}")
    else:
        print(f"  NPC voices: all OK")


if __name__ == "__main__":
    main()
