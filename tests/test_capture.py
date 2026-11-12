import binascii
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from capture_helpers import complete_png


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", binascii.crc32(kind + data))


PNG = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\xff")) + chunk(b"IEND", b""))


class CaptureTests(unittest.TestCase):
    def test_missing_empty_and_unrelated_files_are_not_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "capture.png"
            self.assertFalse(complete_png(image))
            for data in (b"", b"not a screenshot", b"wrong signature" + PNG[-12:]):
                image.write_bytes(data)
                self.assertFalse(complete_png(image))

    def test_progressive_screenshot_write_is_not_ready_until_finished(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "capture.png"
            with image.open("wb") as output:
                for byte in PNG[:-1]:
                    output.write(bytes([byte]))
                    output.flush()
                    self.assertFalse(complete_png(image))
                output.write(PNG[-1:])
                output.flush()
                self.assertTrue(complete_png(image))

    def test_completed_capture_is_ready(self):
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "capture.png"
            image.write_bytes(PNG)
            self.assertTrue(complete_png(image))


if __name__ == "__main__":
    unittest.main()
