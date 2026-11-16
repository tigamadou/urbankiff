#!/usr/bin/env python
"""
Post Image Migration Seeder

This script migrates post images from the post.image field to the file table.
It extracts image names from URLs, creates corresponding File records with
the post's author as the owner, and updates the post's image field with the file URL.

Usage:
    python seed/migrate_post_images.py

Requirements:
    - Posts with image URLs in format: http://api.urbankiff.local/files/user_X/image_name.webp
    - Valid post authors (users must exist)
"""

import os
import sys
import django
import re
from typing import Optional

# Setup Django environment
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'project.settings')
django.setup()

from django.conf import settings
from apps.post.models import Post
from apps.file.models import File


class PostImageMigrator:
    """Handles migration of post images to file table"""
    
    # MIME type mapping for common image formats
    MIME_TYPES = {
        'webp': 'image/webp',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'bmp': 'image/bmp',
        'svg': 'image/svg+xml',
        'tiff': 'image/tiff',
        'ico': 'image/x-icon'
    }
    
    def __init__(self):
        self.migrated_count = 0
        self.skipped_count = 0
        self.error_count = 0
        self.errors = []
    
    def extract_image_name(self, image_url: str) -> Optional[str]:
        """
        Extract image filename from URL
        
        Args:
            image_url: Full URL to the image
            
        Returns:
            Image filename or None if extraction fails
        """
        try:
            if not image_url or not isinstance(image_url, str):
                return None
            
            # Get the last part of the URL (filename)
            filename = image_url.split('/')[-1]
            
            # Basic validation - should have an extension
            if '.' in filename and len(filename) > 1:
                return filename
            
            return None
            
        except (IndexError, AttributeError):
            return None
    
    def get_mime_type(self, filename: str) -> str:
        """
        Determine MIME type based on file extension
        
        Args:
            filename: Image filename
            
        Returns:
            MIME type string, defaults to 'image/jpeg'
        """
        if not filename:
            return 'image/jpeg'
        
        try:
            extension = filename.lower().split('.')[-1]
            return self.MIME_TYPES.get(extension, 'image/jpeg')
        except (IndexError, AttributeError):
            return 'image/jpeg'
    
    def generate_file_url(self, filename: str) -> str:
        """
        Generate file URL using the same format as FileUploadView
        
        Args:
            filename: Image filename
            
        Returns:
            Complete file URL
        """
        minio_endpoint = getattr(settings, 'FILES_CDN_ENDPOINT', '')
        if not minio_endpoint:
            # Fallback to original URL if FILES_CDN_ENDPOINT is not set
            return f"http://api.urbankiff.local/files/{filename}"
        
        return f"{minio_endpoint}/{filename}"
    
    def is_valid_image_url(self, image_url: str) -> bool:
        """
        Check if the image URL is valid for migration
        
        Args:
            image_url: URL to validate
            
        Returns:
            True if URL is valid for migration
        """
        if not image_url or not isinstance(image_url, str):
            return False
        
        # Must contain /files/ and have a valid structure
        return (
            '/files/' in image_url and
            len(image_url.split('/')) >= 2 and
            image_url.endswith(('.webp', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.tiff', '.ico'))
        )
    
    def migrate_single_post(self, post: Post) -> bool:
        """
        Migrate a single post's image to file table
        
        Args:
            post: Post instance to migrate
            
        Returns:
            True if migration successful, False otherwise
        """
        try:
            # Validate image URL
            if not self.is_valid_image_url(post.image):
                self.skipped_count += 1
                return False
            
            # Check if file already exists
            if File.objects.filter(url=post.image).exists():
                self.skipped_count += 1
                return False
            
            # Extract image name
            image_name = self.extract_image_name(post.image)
            if not image_name:
                self.skipped_count += 1
                return False
            
            # Generate proper file URL using the same format as FileUploadView
            file_url = self.generate_file_url(image_name)
            
            # Create file record
            file_record = File.objects.create(
                owner=post.author,
                name=image_name,
                path='uploads',
                url=file_url,
                mime_type=self.get_mime_type(image_name),
                created_at=post.created_at,
                updated_at=post.updated_at
            )
            
            # Update post image field with the new file URL
            post.image = file_url
            post.save(update_fields=['image', 'updated_at'])
            
            self.migrated_count += 1
            return True
            
        except Exception as e:
            error_msg = f"Post {post.id}: {str(e)}"
            self.errors.append(error_msg)
            self.error_count += 1
            return False
    
    def run_migration(self) -> None:
        """Run the complete migration process"""
        print("🚀 Starting Post Image Migration")
        print("=" * 50)
        
        # Get posts with image URLs
        posts_with_images = Post.objects.filter(
            image__isnull=False,
            image__gt=''
        ).select_related('author')
        
        total_posts = posts_with_images.count()
        print(f"📊 Found {total_posts} posts with image data")
        
        if total_posts == 0:
            print("✅ No posts to migrate")
            return
        
        # Process each post
        for i, post in enumerate(posts_with_images, 1):
            if i % 10 == 0:  # Progress indicator every 10 posts
                print(f"⏳ Processing post {i}/{total_posts}...")
            
            self.migrate_single_post(post)
        
        # Print summary
        self.print_summary(total_posts)
    
    def print_summary(self, total_posts: int) -> None:
        """Print migration summary"""
        print("\n" + "=" * 50)
        print("📋 MIGRATION SUMMARY")
        print("=" * 50)
        print(f"Total posts processed: {total_posts}")
        print(f"✅ Successfully migrated: {self.migrated_count}")
        print(f"⏭️  Skipped: {self.skipped_count}")
        print(f"❌ Errors: {self.error_count}")
        
        if self.errors:
            print(f"\n🔍 Error Details:")
            for error in self.errors[:10]:  # Show first 10 errors
                print(f"   • {error}")
            if len(self.errors) > 10:
                print(f"   ... and {len(self.errors) - 10} more errors")
        
        print("=" * 50)
        
        if self.migrated_count > 0:
            print("🎉 Migration completed successfully!")
            print("📝 Post image fields have been updated with file URLs")
        else:
            print("⚠️  No files were migrated. Check the logs above for details.")


def main():
    """Main entry point"""
    try:
        migrator = PostImageMigrator()
        migrator.run_migration()
    except Exception as e:
        print(f"💥 Fatal error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()