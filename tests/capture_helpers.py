from pathlib import Path


def complete_png(path):
    try:
        with Path(path).open("rb") as image:
            signature = image.read(8)
            image.seek(-12, 2)
            ending = image.read(12)
        return signature == b"\x89PNG\r\n\x1a\n" and ending == b"\x00\x00\x00\x00IEND\xaeB`\x82"
    except OSError:
        return False
