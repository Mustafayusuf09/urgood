#!/usr/bin/env python3
"""
Generate app icons for iOS and macOS using Pillow.
Requires: pip install pillow
"""

from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("❌ Missing dependencies!")
    print("Please install required packages:")
    print("  pip install pillow")
    exit(1)

def draw_urgood_icon(size):
    """Draw the UrGood app icon - minimal chat bubble with sparkle."""
    # Create image with RGBA for transparency
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Colors - from brand guidelines
    sky_blue = (77, 166, 255)           # #4DA6FF
    sky_blue_light = (102, 178, 255)    # Lighter variant
    peach = (255, 185, 151)             # #FFB997
    white = (255, 255, 255)
    
    # Scale factor
    scale = size / 1024
    
    # Calculate dimensions for the chat bubble
    # Bubble should be centered and take up ~70% of canvas
    bubble_size = int(700 * scale)
    bubble_x = (size - bubble_size) // 2
    bubble_y = int((size - bubble_size) // 2 - 40 * scale)  # Slightly up for tail room
    
    # Main chat bubble with subtle gradient (sky blue)
    # Draw shadow first for depth
    shadow_offset = int(8 * scale)
    draw.rounded_rectangle(
        [(bubble_x + shadow_offset, bubble_y + shadow_offset), 
         (bubble_x + bubble_size + shadow_offset, bubble_y + bubble_size + shadow_offset)],
        radius=int(bubble_size * 0.25),  # 25% radius for nice roundness
        fill=(0, 0, 0, 30)  # Subtle shadow
    )
    
    # Main bubble body
    draw.rounded_rectangle(
        [(bubble_x, bubble_y), (bubble_x + bubble_size, bubble_y + bubble_size)],
        radius=int(bubble_size * 0.25),
        fill=sky_blue
    )
    
    # Chat bubble tail (small triangle at bottom)
    tail_size = int(60 * scale)
    tail_x = bubble_x + int(bubble_size * 0.2)  # Position at 20% from left
    tail_y = bubble_y + bubble_size
    
    draw.polygon([
        (tail_x, tail_y),
        (tail_x + tail_size, tail_y),
        (tail_x + tail_size // 2, tail_y + tail_size)
    ], fill=sky_blue)
    
    # Draw sparkle in the center (represents positivity, magic, hope)
    sparkle_center_x = bubble_x + bubble_size // 2
    sparkle_center_y = bubble_y + bubble_size // 2
    sparkle_size = int(200 * scale)
    
    # 4-pointed star sparkle (using peach color for warmth)
    # Main points (top, right, bottom, left)
    point_length = sparkle_size // 2
    point_width = int(sparkle_size * 0.3)
    
    # Vertical diamond
    draw.polygon([
        (sparkle_center_x, sparkle_center_y - point_length),  # Top
        (sparkle_center_x + point_width // 2, sparkle_center_y),  # Right middle
        (sparkle_center_x, sparkle_center_y + point_length),  # Bottom
        (sparkle_center_x - point_width // 2, sparkle_center_y),  # Left middle
    ], fill=peach)
    
    # Horizontal diamond
    draw.polygon([
        (sparkle_center_x - point_length, sparkle_center_y),  # Left
        (sparkle_center_x, sparkle_center_y - point_width // 2),  # Top middle
        (sparkle_center_x + point_length, sparkle_center_y),  # Right
        (sparkle_center_x, sparkle_center_y + point_width // 2),  # Bottom middle
    ], fill=peach)
    
    # Add smaller white sparkle in center for extra pop
    small_sparkle = int(sparkle_size * 0.4)
    small_width = int(small_sparkle * 0.3)
    
    # Small vertical diamond
    draw.polygon([
        (sparkle_center_x, sparkle_center_y - small_sparkle // 2),
        (sparkle_center_x + small_width // 2, sparkle_center_y),
        (sparkle_center_x, sparkle_center_y + small_sparkle // 2),
        (sparkle_center_x - small_width // 2, sparkle_center_y),
    ], fill=white)
    
    # Small horizontal diamond
    draw.polygon([
        (sparkle_center_x - small_sparkle // 2, sparkle_center_y),
        (sparkle_center_x, sparkle_center_y - small_width // 2),
        (sparkle_center_x + small_sparkle // 2, sparkle_center_y),
        (sparkle_center_x, sparkle_center_y + small_width // 2),
    ], fill=white)
    
    # Add tiny accent dots around sparkle for extra magic
    dot_distance = int(sparkle_size * 0.8)
    dot_size = int(20 * scale)
    accent_positions = [
        (sparkle_center_x + dot_distance, sparkle_center_y - dot_distance),  # Top right
        (sparkle_center_x - dot_distance, sparkle_center_y - dot_distance),  # Top left
        (sparkle_center_x + dot_distance, sparkle_center_y + dot_distance),  # Bottom right
    ]
    
    for x, y in accent_positions:
        draw.ellipse([(x - dot_size, y - dot_size), (x + dot_size, y + dot_size)], 
                    fill=(255, 255, 255, 200))
    
    # Create final image with solid background
    # Use subtle gradient for background
    final_img = Image.new('RGB', (size, size))
    final_draw = ImageDraw.Draw(final_img)
    
    # Gradient background (lighter sky blue at top, slightly deeper at bottom)
    for y in range(size):
        ratio = y / size
        # Very subtle gradient from light to slightly darker
        r = int(sky_blue_light[0] * (1 - ratio) + sky_blue[0] * ratio)
        g = int(sky_blue_light[1] * (1 - ratio) + sky_blue[1] * ratio)
        b = int(sky_blue_light[2] * (1 - ratio) + sky_blue[2] * ratio)
        final_draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    # Paste the chat bubble with transparency
    final_img.paste(img, (0, 0), img)
    
    return final_img

def generate_icon(output_path, size):
    """Generate PNG icon at specified size."""
    print(f"  Generating {size}x{size}px -> {output_path}")
    img = draw_urgood_icon(size)
    img.save(output_path, 'PNG', quality=95)

def main():
    script_dir = Path(__file__).parent
    icon_dir = script_dir / "urgood/urgood/Assets.xcassets/AppIcon.appiconset"
    
    if not icon_dir.exists():
        print(f"❌ Icon directory not found: {icon_dir}")
        exit(1)
    
    print("🎨 Generating app icons...\n")
    
    # iOS icons
    ios_sizes = [
        ("app_icon_1024.png", 1024),  # Main iOS icon
    ]
    
    # macOS icons
    mac_sizes = [
        ("app_icon_16.png", 16),
        ("app_icon_16@2x.png", 32),
        ("app_icon_32.png", 32),
        ("app_icon_32@2x.png", 64),
        ("app_icon_128.png", 128),
        ("app_icon_128@2x.png", 256),
        ("app_icon_256.png", 256),
        ("app_icon_256@2x.png", 512),
        ("app_icon_512.png", 512),
        ("app_icon_512@2x.png", 1024),
    ]
    
    all_sizes = ios_sizes + mac_sizes
    
    for filename, size in all_sizes:
        output_path = icon_dir / filename
        try:
            generate_icon(str(output_path), size)
        except Exception as e:
            print(f"  ❌ Failed to generate {filename}: {e}")
            import traceback
            traceback.print_exc()
    
    print("\n✅ Icon generation complete!")
    print("\n📝 Next steps:")
    print("1. Open Xcode and navigate to Assets.xcassets > AppIcon")
    print("2. Drag the generated PNG files into the appropriate slots")
    print("3. Build and run your app to see the new icon!")

if __name__ == "__main__":
    main()

