#!/usr/bin/env python3
"""
ImgProxy URL Generator
Generates secure signed URLs for imgproxy with the configured key and salt.
"""

import hashlib
import hmac
import base64
import urllib.parse

# ImgProxy configuration (from your .env file)
IMGPROXY_KEY = "7365637265746b6579"  # hex encoded
IMGPROXY_SALT = "73656372657473616c74"  # hex encoded
IMGPROXY_BASE_URL = "http://localhost:1055"

def hex_to_bytes(hex_string):
    """Convert hex string to bytes."""
    return bytes.fromhex(hex_string)

def generate_signed_url(processing_options, source_url):
    """
    Generate a signed imgproxy URL.
    
    Args:
        processing_options (str): Processing options like 'rs:fill:300:300'
        source_url (str): Source URL like 's3://defaultbucket/image.jpg'
    
    Returns:
        str: Signed imgproxy URL
    """
    # Convert hex strings to bytes
    key = hex_to_bytes(IMGPROXY_KEY)
    salt = hex_to_bytes(IMGPROXY_SALT)
    
    # Create the path to sign
    path = f"/{processing_options}/{source_url}"
    
    # Create signature
    signature = hmac.new(key, salt + path.encode(), hashlib.sha256).digest()
    signature_base64 = base64.urlsafe_b64encode(signature).decode()
    
    # Return the signed URL
    return f"{IMGPROXY_BASE_URL}/{signature_base64}{path}"

def main():
    """Main function to demonstrate URL generation."""
    # Your image file
    image_file = "artworks-6q1AORcYNairySXl-bq2mjw-t500x500.jpg"
    bucket = "defaultbucket"
    source_url = f"s3://{bucket}/{image_file}"
    
    print("=== ImgProxy Secure URL Generator ===\n")
    print(f"Base URL: {IMGPROXY_BASE_URL}")
    print(f"Source: {source_url}\n")
    
    # Generate different URLs
    urls = [
        ("Original", "", source_url),
        ("300x300", "rs:fill:300:300", source_url),
        ("500x500", "rs:fill:500:500", source_url),
        ("800x800", "rs:fill:800:800", source_url),
        ("WebP 300x300", "f:webp/rs:fill:300:300", source_url),
        ("WebP 500x500", "f:webp/rs:fill:500:500", source_url),
        ("Thumbnail 150x150", "rs:fill:150:150", source_url),
        ("Thumbnail 250x250", "rs:fill:250:250", source_url),
    ]
    
    for name, processing, source in urls:
        if processing:
            signed_url = generate_signed_url(processing, source)
        else:
            signed_url = generate_signed_url("plain", source)
        
        print(f"{name}:")
        print(f"  {signed_url}")
        print()

if __name__ == "__main__":
    main() 