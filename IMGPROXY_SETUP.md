# ImgProxy Setup Guide

## Overview
ImgProxy is a fast and secure standalone server for resizing and converting remote images. It's now configured to work with your MinIO S3 storage.

## Configuration

### Environment Variables
The imgproxy service is configured with the following key settings:

- **S3 Integration**: Configured to work with MinIO
- **Port**: 1055 (accessible at http://localhost:1055)
- **Security**: Uses key/salt authentication
- **Performance**: Optimized for production use

### Key Configuration Files
- `docker-compose.yml`: Main service configuration
- `configs/imgproxy.env`: Environment variables for imgproxy

## Usage

### Starting the Service
```bash
docker-compose up imgproxy
```

### Image Processing Examples

#### Basic Resize
```
http://localhost:1055/unsafe/rs:fill:300:200/s3://your-bucket/image.jpg
```

#### Resize with Quality
```
http://localhost:1055/unsafe/rs:fill:300:200/q:80/s3://your-bucket/image.jpg
```

#### Format Conversion
```
http://localhost:1055/unsafe/f:webp/rs:fill:300:200/s3://your-bucket/image.jpg
```

#### Watermark
```
http://localhost:1055/unsafe/rs:fill:300:200/wm:0.5:soea:0:0:0.1:0.1/s3://your-bucket/image.jpg
```

### URL Structure
```
http://localhost:1055/unsafe/[processing_options]/s3://[bucket]/[path_to_image]
```

### Common Processing Options
- `rs:fill:width:height` - Resize to fill dimensions
- `rs:fit:width:height` - Resize to fit dimensions
- `q:quality` - Set JPEG quality (1-100)
- `f:format` - Convert format (webp, jpeg, png, etc.)
- `blur:sigma` - Apply blur effect
- `sharpen:sigma` - Apply sharpening

## Integration with Your Application

### Frontend Integration
```javascript
// Example function to generate imgproxy URLs
function getImgProxyUrl(imagePath, width = 300, height = 200) {
  const baseUrl = 'http://localhost:1055/unsafe';
  const processing = `rs:fill:${width}:${height}`;
  const s3Path = `s3://urbankiff-media/${imagePath}`;
  
  return `${baseUrl}/${processing}/${s3Path}`;
}

// Usage
const optimizedImageUrl = getImgProxyUrl('uploads/profile.jpg', 150, 150);
```

### Backend Integration (Python/Django)
```python
import hashlib
import hmac
import base64

def generate_imgproxy_url(image_path, width=300, height=200):
    # Your imgproxy key and salt (from environment variables)
    key = b'secretkey'  # Replace with your actual key
    salt = b'secretsalt'  # Replace with your actual salt
    
    # Processing options
    processing = f'rs:fill:{width}:{height}'
    
    # S3 path
    s3_path = f's3://urbankiff-media/{image_path}'
    
    # Create the path to sign
    path_to_sign = f'/{processing}/{s3_path}'
    
    # Create signature
    signature = hmac.new(key, salt + path_to_sign.encode(), hashlib.sha256).digest()
    signature_base64 = base64.urlsafe_b64encode(signature).decode()
    
    # Return the signed URL
    return f'http://localhost:1055/{signature_base64}{path_to_sign}'
```

## Security Considerations

1. **Key and Salt**: Keep your IMGPROXY_KEY and IMGPROXY_SALT secure
2. **Allowed Sources**: Only S3 sources are allowed by default
3. **Rate Limiting**: Consider implementing rate limiting in production
4. **HTTPS**: Use HTTPS in production environments

## Troubleshooting

### Common Issues

1. **Connection to MinIO fails**
   - Check if MinIO is running: `docker-compose ps minio`
   - Verify MinIO credentials in environment variables

2. **Images not loading**
   - Check imgproxy logs: `docker-compose logs imgproxy`
   - Verify S3 bucket and file paths

3. **Performance issues**
   - Adjust IMGPROXY_MAX_SRC_RESOLUTION and IMGPROXY_MAX_SRC_FILE_SIZE
   - Consider implementing caching

### Logs
```bash
# View imgproxy logs
docker-compose logs imgproxy

# Follow logs in real-time
docker-compose logs -f imgproxy
```

## Production Deployment

For production deployment, consider:

1. **HTTPS**: Use a reverse proxy with SSL termination
2. **Caching**: Implement Redis or CDN caching
3. **Monitoring**: Add health checks and monitoring
4. **Scaling**: Use multiple imgproxy instances behind a load balancer
5. **Security**: Use signed URLs instead of unsafe URLs

## MinIO Bucket Setup

Make sure your MinIO buckets are properly configured:

```bash
# Access MinIO console at http://localhost:9003
# Login with: minioadmin / minioadmin123

# Create buckets if they don't exist:
# - urbankiff-media
# - urbankiff-documents  
# - urbankiff-avatars
``` 