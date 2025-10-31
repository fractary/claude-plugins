# AWS S3 API Reference for File Manager (Future Implementation)

This document outlines the planned AWS S3 integration for the file-manager skill.

## Status

**Not yet implemented.** This is a placeholder for future development.

## Planned Authentication

S3 adapter will use AWS CLI with standard S3 endpoints.

### Planned Setup

```bash
# Install AWS CLI (same as R2)
aws configure

# Or environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

## Planned Configuration

```toml
[project]
file_system = "s3"

[systems.file_config]
s3_bucket = "faber-artifacts"
s3_region = "us-east-1"
s3_endpoint = ""  # Optional: for S3-compatible services like MinIO
```

## Planned Operations

Similar to R2 adapter but using standard S3 endpoints:

### upload.sh
```bash
aws s3 cp <local> s3://<bucket>/<path> --acl public-read
```

### download.sh
```bash
aws s3 cp s3://<bucket>/<path> <local>
```

### delete.sh
```bash
aws s3 rm s3://<bucket>/<path>
```

### list.sh
```bash
aws s3 ls s3://<bucket>/<prefix> --recursive
```

### get-url.sh
```bash
# Public URL
https://<bucket>.s3.<region>.amazonaws.com/<path>

# Presigned URL
aws s3 presign s3://<bucket>/<path> --expires-in <seconds>
```

## Differences from R2

- **Endpoint**: Standard AWS S3 endpoints (no custom account ID)
- **Pricing**: Different pricing model (storage + egress)
- **Regions**: Must specify AWS region
- **Features**: Full S3 feature set (versioning, lifecycle, etc.)

## Implementation Checklist

- [ ] Create scripts/s3/ directory
- [ ] Implement upload.sh with standard S3
- [ ] Implement download.sh
- [ ] Implement delete.sh
- [ ] Implement list.sh
- [ ] Implement get-url.sh with public and presigned URL support
- [ ] Test with AWS S3
- [ ] Test with S3-compatible services (MinIO, DigitalOcean Spaces)
- [ ] Document S3-specific features

## References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
