# Tutorial: Setting Up Cloud Storage

Step-by-step tutorial for configuring cloud storage with the fractary-file plugin.

## Choose Your Provider

This tutorial covers:
1. [Local Storage (Development)](#option-1-local-storage-development)
2. [Cloudflare R2 (Recommended for Production)](#option-2-cloudflare-r2-recommended)
3. [AWS S3](#option-3-aws-s3)
4. [Google Cloud Storage](#option-4-google-cloud-storage)
5. [Google Drive](#option-5-google-drive)

## Option 1: Local Storage (Development)

**Best for**: Development, testing, offline work

**Time**: < 1 minute

**Cost**: Free

### Steps

1. **Initialize plugin** (that's it!):
```bash
/fractary-file:init --handler local
```

2. **Test**:
```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

3. **Verify**:
```bash
ls ./storage/test/
```

You should see `test.txt`.

**Done!** Files stored in `./storage` directory.

---

## Option 2: Cloudflare R2 (Recommended)

**Best for**: Production, cost-conscious projects

**Time**: 10 minutes

**Cost**: $0.015/GB/month, $0 egress

### Step 1: Create R2 Bucket (5 min)

1. **Log into Cloudflare Dashboard**:
   - Go to https://dash.cloudflare.com
   - Navigate to R2

2. **Create bucket**:
   - Click "Create bucket"
   - Name: `my-project-archive` (or your choice)
   - Location: Automatic
   - Click "Create bucket"

3. **Enable public access** (optional):
   - Go to bucket settings
   - Click "Connect domain" or "Enable public URL"
   - Note the public URL: `https://pub-xxxxx.r2.dev`

### Step 2: Generate API Token (2 min)

1. **Go to R2 API Tokens**:
   - In R2 section, click "Manage R2 API Tokens"

2. **Create token**:
   - Click "Create API token"
   - Name: `fractary-file-access`
   - Permissions: Object Read & Write
   - Apply to bucket: `my-project-archive`
   - TTL: Never expire (or your preference)
   - Click "Create API Token"

3. **Save credentials**:
   - Account ID: `your-account-id`
   - Access Key ID: `your-access-key-id`
   - Secret Access Key: `your-secret-access-key`

   **⚠️ Save these now!** Secret is only shown once.

### Step 3: Configure Plugin (2 min)

1. **Create config file**:
```bash
mkdir -p .fractary/plugins/file
```

2. **Create configuration**:
```bash
cat > .fractary/plugins/file/config.json <<'EOF'
{
  "schema_version": "1.0",
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-project-archive",
      "public_url": "https://pub-xxxxx.r2.dev",
      "region": "auto"
    }
  }
}
EOF
```

3. **Secure config file**:
```bash
chmod 0600 .fractary/plugins/file/config.json
```

### Step 4: Set Environment Variables (1 min)

1. **Export variables**:
```bash
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key-id"
export R2_SECRET_ACCESS_KEY="your-secret-access-key"
```

2. **Make permanent** (add to shell profile):
```bash
echo 'export R2_ACCOUNT_ID="your-account-id"' >> ~/.bashrc
echo 'export R2_ACCESS_KEY_ID="your-access-key-id"' >> ~/.bashrc
echo 'export R2_SECRET_ACCESS_KEY="your-secret-access-key"' >> ~/.bashrc
source ~/.bashrc
```

### Step 5: Test (1 min)

1. **Create test file**:
```bash
echo "Hello R2!" > test.txt
```

2. **Upload**:
```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

3. **Verify in Cloudflare Dashboard**:
   - Go to your bucket
   - You should see `test/test.txt`

4. **Test read**:
```
Use @agent-fractary-file:file-manager to read:
{
  "operation": "read",
  "parameters": {
    "remote_path": "test/test.txt"
  }
}
```

**Done!** R2 storage configured and tested.

---

## Option 3: AWS S3

**Best for**: AWS ecosystem, enterprise

**Time**: 15 minutes

**Cost**: $0.023/GB/month + egress

### Step 1: Create S3 Bucket (5 min)

**Via AWS Console**:
1. Go to S3 service
2. Click "Create bucket"
3. Name: `my-project-archive`
4. Region: `us-east-1` (or your preference)
5. Block public access: Keep enabled (we'll use presigned URLs)
6. Click "Create bucket"

**Via AWS CLI**:
```bash
aws s3 mb s3://my-project-archive --region us-east-1
```

### Step 2: Create IAM Policy (3 min)

1. **Create policy JSON**:
```bash
cat > fractary-file-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-project-archive",
        "arn:aws:s3:::my-project-archive/*"
      ]
    }
  ]
}
EOF
```

2. **Create policy**:
```bash
aws iam create-policy \
  --policy-name FractaryFileAccess \
  --policy-document file://fractary-file-policy.json
```

### Step 3: Create IAM User (3 min)

1. **Create user**:
```bash
aws iam create-user --user-name fractary-file-user
```

2. **Attach policy**:
```bash
aws iam attach-user-policy \
  --user-name fractary-file-user \
  --policy-arn arn:aws:iam::ACCOUNT-ID:policy/FractaryFileAccess
```

3. **Create access keys**:
```bash
aws iam create-access-key --user-name fractary-file-user
```

Save the Access Key ID and Secret Access Key.

### Step 4: Configure Plugin (2 min)

```bash
cat > .fractary/plugins/file/config.json <<'EOF'
{
  "schema_version": "1.0",
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-project-archive",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
    }
  }
}
EOF

chmod 0600 .fractary/plugins/file/config.json
```

### Step 5: Set Environment Variables (1 min)

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Make permanent
echo 'export AWS_ACCESS_KEY_ID="your-access-key"' >> ~/.bashrc
echo 'export AWS_SECRET_ACCESS_KEY="your-secret-key"' >> ~/.bashrc
source ~/.bashrc
```

### Step 6: Test (1 min)

```bash
echo "Hello S3!" > test.txt
```

```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

Verify:
```bash
aws s3 ls s3://my-project-archive/test/
```

**Done!**

---

## Option 4: Google Cloud Storage

**Best for**: Google Cloud ecosystem

**Time**: 20 minutes

**Cost**: $0.020/GB/month + egress

### Step 1: Create GCS Bucket (5 min)

1. **Install gcloud** (if needed):
```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

2. **Authenticate**:
```bash
gcloud auth login
gcloud config set project YOUR-PROJECT-ID
```

3. **Create bucket**:
```bash
gsutil mb -l us-central1 gs://my-project-archive
```

### Step 2: Create Service Account (5 min)

1. **Create service account**:
```bash
gcloud iam service-accounts create fractary-file \
  --display-name="Fractary File Access"
```

2. **Grant permissions**:
```bash
gsutil iam ch \
  serviceAccount:fractary-file@YOUR-PROJECT-ID.iam.gserviceaccount.com:roles/storage.objectAdmin \
  gs://my-project-archive
```

3. **Generate key**:
```bash
gcloud iam service-accounts keys create ~/fractary-file-key.json \
  --iam-account=fractary-file@YOUR-PROJECT-ID.iam.gserviceaccount.com
```

4. **Secure key**:
```bash
chmod 0600 ~/fractary-file-key.json
```

### Step 3: Configure Plugin (2 min)

```bash
cat > .fractary/plugins/file/config.json <<'EOF'
{
  "schema_version": "1.0",
  "active_handler": "gcs",
  "handlers": {
    "gcs": {
      "project_id": "YOUR-PROJECT-ID",
      "bucket_name": "my-project-archive",
      "service_account_key": "${GOOGLE_APPLICATION_CREDENTIALS}",
      "region": "us-central1"
    }
  }
}
EOF

chmod 0600 .fractary/plugins/file/config.json
```

### Step 4: Set Environment Variable (1 min)

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/fractary-file-key.json"

# Make permanent
echo 'export GOOGLE_APPLICATION_CREDENTIALS="$HOME/fractary-file-key.json"' >> ~/.bashrc
source ~/.bashrc
```

### Step 5: Test (1 min)

```bash
echo "Hello GCS!" > test.txt
```

```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

Verify:
```bash
gsutil ls gs://my-project-archive/test/
```

**Done!**

---

## Option 5: Google Drive

**Best for**: Personal projects, small teams

**Time**: 30 minutes (OAuth setup complex)

**Cost**: Free (15GB)

### Step 1: Install rclone (2 min)

```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash

# Verify
rclone version
```

### Step 2: Create OAuth Credentials (10 min)

1. **Go to Google Cloud Console**:
   - https://console.cloud.google.com

2. **Create project** (or use existing):
   - Click "Select a project" → "New Project"
   - Name: `fractary-file-app`
   - Click "Create"

3. **Enable Google Drive API**:
   - Go to "APIs & Services" → "Library"
   - Search "Google Drive API"
   - Click "Enable"

4. **Create OAuth credentials**:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth client ID"
   - Application type: "Desktop app"
   - Name: `fractary-file-client`
   - Click "Create"
   - Save Client ID and Client Secret

### Step 3: Configure rclone (10 min)

1. **Run rclone config**:
```bash
rclone config
```

2. **Interactive setup**:
```
n) New remote
name> gdrive
Storage> drive  # or number for Google Drive
client_id> YOUR-CLIENT-ID
client_secret> YOUR-CLIENT-SECRET
scope> drive.file
root_folder_id> (leave empty)
service_account_file> (leave empty)
Edit advanced config? n
Use auto config? y
```

3. **Browser opens** for OAuth:
   - Log into Google account
   - Approve permissions
   - Return to terminal

4. **Finish config**:
```
Configure this as a team drive? n
y) Yes this is OK
q) Quit config
```

### Step 4: Configure Plugin (2 min)

```bash
cat > .fractary/plugins/file/config.json <<'EOF'
{
  "schema_version": "1.0",
  "active_handler": "gdrive",
  "handlers": {
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "folder_id": "root",
      "rclone_remote_name": "gdrive"
    }
  }
}
EOF

chmod 0600 .fractary/plugins/file/config.json
```

### Step 5: Set Environment Variables (1 min)

```bash
export GDRIVE_CLIENT_ID="your-client-id"
export GDRIVE_CLIENT_SECRET="your-client-secret"

# Make permanent
echo 'export GDRIVE_CLIENT_ID="your-client-id"' >> ~/.bashrc
echo 'export GDRIVE_CLIENT_SECRET="your-client-secret"' >> ~/.bashrc
source ~/.bashrc
```

### Step 6: Test (1 min)

```bash
echo "Hello Google Drive!" > test.txt
```

```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

Verify:
```bash
rclone ls gdrive:fractary-archives/test/
```

**Done!**

---

## Next Steps

1. **Initialize other plugins**:
```bash
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

2. **Configure FABER**:
```bash
cat > .faber.config.toml <<'EOF'
[plugins]
file = "fractary-file"
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"

[workflow.architect]
generate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
EOF
```

3. **Test workflow**:
```bash
/faber:run <test-issue> --autonomy guarded
```

4. **Verify archival**:
   - Complete workflow
   - Check cloud storage
   - Read archived content

## Troubleshooting

### Connection Timeout

**Problem**: Upload/download times out

**Solution**:
- Check network connectivity
- Increase timeout in config:
```json
{
  "global_settings": {
    "timeout_seconds": 600
  }
}
```

### Authentication Failed

**Problem**: "Access denied" or "Unauthorized"

**Solution**:
- Verify environment variables set
- Check credentials not expired
- Test with cloud provider CLI

### Bucket Not Found

**Problem**: "Bucket does not exist"

**Solution**:
- Verify bucket name in config matches actual bucket
- Check region correct
- Create bucket if missing

### Permission Denied

**Problem**: "Permission denied" errors

**Solution**:
- Check IAM permissions
- Verify service account has required roles
- Test with provider CLI

## Additional Resources

- [fractary-file Guide](../guides/fractary-file-guide.md) - Complete plugin guide
- [Troubleshooting Guide](../guides/troubleshooting.md) - Common issues
- Provider documentation:
  - [Cloudflare R2](https://developers.cloudflare.com/r2/)
  - [AWS S3](https://docs.aws.amazon.com/s3/)
  - [Google Cloud Storage](https://cloud.google.com/storage/docs)
  - [rclone](https://rclone.org/)

---

**Tutorial Version**: 1.0 (2025-01-15)
