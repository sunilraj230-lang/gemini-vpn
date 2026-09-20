import zlib
import struct
import math
import os

def create_png(width, height, get_pixel_func):
    """
    Generates an uncompressed/zlib-compressed RGBA PNG in pure Python without external dependencies.
    """
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)  # filter type 0 (None)
        for x in range(width):
            r, g, b, a = get_pixel_func(x, y, width, height)
            raw_data.extend([r, g, b, a])

    def chunk(tag, data):
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xffffffff)

    png_header = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0) # 8-bit RGBA
    ihdr = chunk(b"IHDR", ihdr_data)
    idat = chunk(b"IDAT", zlib.compress(bytes(raw_data), 6))
    iend = chunk(b"IEND", b"")

    return png_header + ihdr + idat + iend

def app_icon_pixel(x, y, w, h):
    # Normalized coordinates from -1.0 to 1.0
    nx = (x / w) * 2.0 - 1.0
    ny = (y / h) * 2.0 - 1.0
    dist = math.sqrt(nx * nx + ny * ny)

    # Background gradient: deep midnight blue (#0b0f19 to #030509)
    bg_factor = 1.0 - (dist * 0.4)
    r = int(11 * bg_factor)
    g = int(15 * bg_factor)
    b = int(25 * bg_factor)

    # Shield shape formula:
    # x in [-0.55, 0.55], y in [-0.6, 0.6]
    # top: y = -0.6
    # bottom tip: (0, 0.65)
    in_shield = False
    if -0.65 <= ny <= 0.65:
        # width tapering from 0.55 at top to 0.0 at bottom tip
        max_w = 0.55
        if ny > 0.0:
            allowed_w = max_w * (1.0 - (ny / 0.65) ** 1.3)
        else:
            allowed_w = max_w
        
        if abs(nx) <= allowed_w:
            in_shield = True

    if in_shield:
        # Edge of shield glowing neon cyan/blue (#00f2ff)
        edge_dist = allowed_w - abs(nx)
        is_border = (edge_dist < 0.04) or (abs(ny - (-0.65)) < 0.04) or (abs(ny - 0.65) < 0.04)
        
        if is_border:
            r, g, b = 0, 240, 255 # Bright Cyan
        else:
            # Inner shield gradient (Dark rich navy with cyan radial glow)
            inner_glow = max(0.0, 1.0 - dist * 1.5)
            r = int(10 + inner_glow * 30)
            g = int(30 + inner_glow * 150)
            b = int(60 + inner_glow * 200)

            # Central "G" or bolt silhouette
            # Lightning bolt coordinates
            # Top segment: (0.1, -0.4) to (-0.1, -0.05)
            # Middle step
            # Bottom segment: (0.05, 0.0) to (-0.15, 0.4)
            is_bolt = False
            if -0.4 <= ny <= -0.05 and abs(nx - (-ny * 0.4)) < 0.08:
                is_bolt = True
            elif -0.08 <= ny <= 0.05 and -0.18 <= nx <= 0.15:
                is_bolt = True
            elif 0.0 <= ny <= 0.4 and abs(nx - (-(ny-0.4) * 0.4 - 0.15)) < 0.08:
                is_bolt = True

            if is_bolt:
                r, g, b = 255, 255, 255 # Crisp White / Electric

    return (min(255, max(0, r)), min(255, max(0, g)), min(255, max(0, b)), 255)

if __name__ == "__main__":
    out_dir = "h:/GEMINI-VPN/GeminiVPN/Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "AppIcon-512@2x.png")
    print(f"Generating 1024x1024 AppIcon at {out_path}...")
    png_bytes = create_png(1024, 1024, app_icon_pixel)
    with open(out_path, "wb") as f:
        f.write(png_bytes)
    print(f"Successfully generated {len(png_bytes)} bytes AppIcon!")
