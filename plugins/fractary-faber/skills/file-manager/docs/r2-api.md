# Cloudflare R2 API Reference for File Manager

This document describes the Cloudflare R2 integration for the file-manager skill.

## Overview

Cloudflare R2 is an S3-compatible object storage service. The file-manager uses the AWS CLI with R2-specific endpoints.

## Authentication

R2 adapter uses AWS CLI configured for R2 endpoints.

### Setup

1. Install AWS CLI:
   ```bash
   # macOS
   brew install awscli

   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Windows
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

2. Get R2 credentials from Cloudflare dashboard:
   - Go to R2 → Overview → Manage R2 API Tokens
   - Create API token with read/write permissions
   - Note: Access Key ID, Secret Access Key, Account ID

3. Configure AWS CLI for R2:
   ```bash
   aws configure
   AWS Access Key ID: <R2_ACCESS_KEY_ID>
   AWS Secret Access Key: <R2_SECRET_ACCESS_KEY>
   Default region name: auto
   Default output format: json
   ```

4. Or set environment variables:
   ```bash
   export AWS_ACCESS_KEY_ID="<R2_ACCESS_KEY_ID>"
   export AWS_SECRET_ACCESS_KEY="<R2_SECRET_ACCESS_KEY>"
   export R2_ACCOUNT_ID="<ACCOUNT_ID>"
   ```

## Configuration

In `.faber.config.toml`:

```toml
[project]
file_system = "r2"

[systems.file_config]
account_id = "your-account-id"
bucket_name = "faber-artifacts"
public_url = "https://faber-artifacts.your-account.r2.dev"
```

### Creating an R2 Bucket

```bash
# Using wrangler (Cloudflare CLI)
npm install -g wrangler
wrangler r2 bucket create faber-artifacts

# Or via Cloudflare dashboard
# R2 → Create bucket → faber-artifacts
```

## Operations

### upload.sh

Uploads files to R2 using S3-compatible API.

**AWS CLI Command:**
```bash
aws s3 cp <local> s3://<bucket>/<path> \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com \
  --acl public-read  # if public
```

**Public vs Private:**
- Public files: accessible via public URL without authentication
- Private files: require presigned URLs

**Example:**
```bash
./scripts/r2/upload.sh ./spec.md faber/specs/abc12345.md true
# Returns: https://faber-artifacts.account.r2.dev/faber/specs/abc12345.md
```

### download.sh

Downloads files from R2.

**AWS CLI Command:**
```bash
aws s3 cp s3://<bucket>/<path> <local> \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com
```

**Example:**
```bash
./scripts/r2/download.sh faber/specs/abc12345.md ./local-spec.md
```

### delete.sh

Deletes files from R2.

**AWS CLI Command:**
```bash
aws s3 rm s3://<bucket>/<path> \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com
```

**Example:**
```bash
./scripts/r2/delete.sh faber/specs/abc12345.md
```

### list.sh

Lists files in R2 bucket.

**AWS CLI Command:**
```bash
aws s3 ls s3://<bucket>/<prefix> \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com \
  --recursive
```

**Output:** JSON array of file paths

**Example:**
```bash
./scripts/r2/list.sh faber/specs/ 50
# Returns: ["faber/specs/abc12345.md", "faber/specs/def67890.md", ...]
```

### get-url.sh

Gets a public or presigned URL for a file.

**For Public Files:**
Returns public URL immediately: `https://<bucket>.<account>.r2.dev/<path>`

**For Private Files:**
Generates presigned URL:
```bash
aws s3 presign s3://<bucket>/<path> \
  --endpoint-url https://<account-id>.r2.cloudflarestorage.com \
  --expires-in <seconds>
```

**Example:**
```bash
./scripts/r2/get-url.sh faber/specs/abc12345.md 7200
# Returns: https://faber-artifacts.account.r2.dev/faber/specs/abc12345.md?X-Amz-...
```

## R2 Endpoints

- **API Endpoint**: `https://<account-id>.r2.cloudflarestorage.com`
- **Public URL**: `https://<bucket>.<account>.r2.dev` (if enabled)
- **Custom Domain**: Can configure custom domain in R2 settings

## Error Codes

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Configuration error (AWS CLI not found, missing config)
- `10`: File not found
- `11`: Authentication error
- `12`: Network error
- `13`: Permission denied

## R2 Limits

- **Storage**: Unlimited
- **Egress**: First 10 GB/month free, then $0.36/GB
- **Operations**: Class A (write): $4.50/million, Class B (read): $0.36/million
- **File size**: Up to 5 TB per file

## Best Practices

1. **Use public URLs for public files** - No egress charges for Cloudflare network
2. **Set appropriate expiration** for presigned URLs
3. **Organize with prefixes** - Use folder-like structure
4. **Enable versioning** - For important files (via R2 settings)
5. **Monitor usage** - Check R2 dashboard for storage and egress

## Troubleshooting

### Issue: "aws: command not found"
**Solution**: Install AWS CLI

### Issue: "Unable to locate credentials"
**Solution**: Run `aws configure` or set environment variables

### Issue: "Could not connect to the endpoint URL"
**Solution**: Verify R2_ACCOUNT_ID is correct and account has R2 enabled

### Issue: "Access Denied"
**Solution**: Check R2 API token has read/write permissions

### Issue: "NoSuchBucket"
**Solution**: Create bucket or verify bucket name in config

## Examples

```bash
# Complete workflow
# 1. Upload specification
spec_url=$(./scripts/r2/upload.sh ./spec.md faber/specs/abc12345-spec.md true)
echo "Spec URL: $spec_url"

# 2. List all specs
./scripts/r2/list.sh faber/specs/

# 3. Get presigned URL (for private file)
private_url=$(./scripts/r2/get-url.sh faber/logs/abc12345/build.log 3600)
echo "Log URL (expires in 1h): $private_url"

# 4. Download artifact
./scripts/r2/download.sh faber/artifacts/abc12345/build.tar.gz ./build.tar.gz

# 5. Delete old file
./scripts/r2/delete.sh faber/specs/old-spec.md
```

## References

- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [R2 S3 API Compatibility](https://developers.cloudflare.com/r2/api/s3/api/)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
