# Google Drive OAuth2 Setup Guide

Complete guide for setting up Google Drive with the fractary-file plugin using OAuth2 authentication.

## Overview

Google Drive requires OAuth2 authentication, which is handled via rclone. This guide walks you through the complete setup process.

## Prerequisites

1. **Google Cloud Project** with Drive API enabled
2. **rclone** installed on your machine
3. **Google account** with Drive access

## Step 1: Install rclone

### macOS
```bash
brew install rclone
```

### Linux
```bash
curl https://rclone.org/install.sh | sudo bash
```

### Windows
Download from: https://rclone.org/downloads/

### Verify Installation
```bash
rclone version
# Should show version 1.50 or higher
```

## Step 2: Create OAuth 2.0 Credentials

### 2.1: Go to Google Cloud Console

Visit: https://console.cloud.google.com/

### 2.2: Create or Select Project

1. Click project dropdown at top
2. Click "New Project" or select existing project
3. Note the project ID

### 2.3: Enable Google Drive API

1. Go to "APIs & Services" → "Library"
2. Search for "Google Drive API"
3. Click "Enable"

### 2.4: Create OAuth 2.0 Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. If prompted, configure OAuth consent screen:
   - User Type: External (for personal use) or Internal (for organization)
   - App name: "Fractary File Plugin" (or your choice)
   - User support email: Your email
   - Developer contact: Your email
   - Scopes: Add `../auth/drive.file` or `../auth/drive`
   - Test users: Add your Google account
   - Click "Save and Continue"

4. Back to "Create OAuth client ID":
   - Application type: **Desktop app**
   - Name: "Fractary File Plugin Client"
   - Click "Create"

5. **Important**: Save the credentials:
   - Client ID: `1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com`
   - Client Secret: `GOCSPX-aBcDeFgHiJkLmNoPqRsTuVwXyZ`

### 2.5: OAuth Consent Screen

If your app is in "Testing" mode:
- **Limitation**: Only test users can authenticate
- **Solution**: Add users to "Test users" list or publish the app

## Step 3: Configure rclone

### 3.1: Start Interactive Config

```bash
rclone config
```

### 3.2: Create New Remote

```
n) New remote
s) Set configuration password
q) Quit config
n/s/q> n
```

### 3.3: Name the Remote

```
name> gdrive
```
*(Use "gdrive" or your preferred name)*

### 3.4: Select Storage Type

```
Type of storage to configure.
Choose a number from below:
...
XX / Google Drive
   \ "drive"
...
Storage> drive
```

### 3.5: Enter Client ID

```
Google Application Client ID
Setting your own is recommended.
See https://rclone.org/drive/#making-your-own-client-id for how to create your own.
If you leave this blank, it will use an internal key which is low performance.
Enter a string value. Press Enter for the default ("").
client_id> 1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
```

### 3.6: Enter Client Secret

```
OAuth Client Secret
Leave blank normally.
Enter a string value. Press Enter for the default ("").
client_secret> GOCSPX-aBcDeFgHiJkLmNoPqRsTuVwXyZ
```

### 3.7: Configure Scope

```
Scope that rclone should use when requesting access from drive.
Choose a number from below, or type in your own value
 1 / Full access all files, excluding Application Data Folder.
   \ "drive"
 2 / Read-only access to file metadata and file contents.
   \ "drive.readonly"
 3 / Access to files created by rclone only.
   \ "drive.file"
...
scope> 3
```

**Recommended**: Use scope `3` (drive.file) for better security. Only files created by fractary-file will be accessible.

**Alternative**: Use scope `1` (drive) for full access to all Drive files.

### 3.8: Root Folder ID

```
ID of the root folder
Leave blank normally.
Enter a string value. Press Enter for the default ("").
root_folder_id>
```

Press Enter to use root, or enter a specific folder ID to restrict access to that folder.

**To get folder ID**:
1. Open folder in Google Drive web interface
2. URL will be: `https://drive.google.com/drive/folders/1a2b3c4d5e6f7g8h9i0`
3. Folder ID is: `1a2b3c4d5e6f7g8h9i0`

### 3.9: Service Account

```
Service Account Credentials JSON file path
Leave blank normally.
Enter a string value. Press Enter for the default ("").
service_account_file>
```

Press Enter (we're using OAuth2, not service account).

### 3.10: Advanced Config

```
Edit advanced config? (y/n)
y) Yes
n) No (default)
y/n> n
```

Press `n` unless you need advanced features.

### 3.11: Auto Config

```
Use auto config?
 * Say Y if not sure
 * Say N if you are working on a remote or headless machine

y) Yes (default)
n) No
y/n> y
```

**Press `y`** - This will open a browser window for OAuth authentication.

### 3.12: Complete OAuth Flow

1. Browser window opens automatically
2. Select your Google account
3. Review permissions requested
4. Click "Allow" or "Continue"
5. See "Success! You can close this page" message
6. Return to terminal

### 3.13: Configure Team Drive

```
Configure this as a team drive?
y) Yes
n) No (default)
y/n> n
```

Press `n` unless using a shared drive.

### 3.14: Confirm Configuration

```
--------------------
[gdrive]
type = drive
client_id = 1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com
client_secret = GOCSPX-aBcDeFgHiJkLmNoPqRsTuVwXyZ
scope = drive.file
token = {"access_token":"ya29.a0AfH6...","token_type":"Bearer","refresh_token":"1//0gK...","expiry":"2025-01-15T12:00:00Z"}
--------------------
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> y
```

Press `y` to save the configuration.

### 3.15: Quit Config

```
e) Edit existing remote
n) New remote
d) Delete remote
r) Rename remote
c) Copy remote
s) Set configuration password
q) Quit config
e/n/d/r/c/s/q> q
```

Press `q` to quit.

## Step 4: Verify rclone Setup

Test the rclone configuration:

```bash
# List top-level folders
rclone lsd gdrive:

# List all files
rclone ls gdrive:

# Test file upload
echo "test" > test.txt
rclone copy test.txt gdrive:test/
rclone ls gdrive:test/
rclone delete gdrive:test/test.txt
```

## Step 5: Configure fractary-file

### 5.1: Set Environment Variables

```bash
# Add to ~/.bashrc, ~/.zshrc, or equivalent
export GDRIVE_CLIENT_ID="1234567890-abcdefghijklmnopqrstuvwxyz.apps.googleusercontent.com"
export GDRIVE_CLIENT_SECRET="GOCSPX-aBcDeFgHiJkLmNoPqRsTuVwXyZ"

# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc
```

### 5.2: Create Plugin Configuration

Create `.fractary/plugins/file/config.json`:

```json
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
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true
  }
}
```

### 5.3: Set Secure Permissions

```bash
chmod 0600 .fractary/plugins/file/config.json
```

## Step 6: Test fractary-file Integration

Use the file-manager agent to test:

```
Use the @agent-fractary-file:file-manager agent to upload test file:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "fractary/test.txt"
  }
}
```

## Token Management

### Token Expiration

OAuth tokens expire after 1 hour, but rclone automatically refreshes them using the refresh token.

### Manual Token Refresh

If needed, manually refresh the token:

```bash
rclone config reconnect gdrive:
```

This will:
1. Open browser for re-authentication
2. Generate new access token
3. Update rclone configuration

### Token Storage

Tokens are stored in rclone configuration:
- **Location**: `~/.config/rclone/rclone.conf`
- **Format**: Encrypted (if password set) or plain text
- **Contents**: Access token, refresh token, expiry time

### Token Security

**Best Practices**:
- ✅ Use environment variables for client ID/secret (never hardcode in config)
- ✅ Set restrictive permissions (0600) on config files containing secrets
- ✅ Use `drive.file` scope (minimal access)
- ✅ Regularly review authorized apps in Google Account settings
- ✅ Commit `.fractary/` configs to version control (they should only reference env vars)
- ❌ Never commit OAuth credentials directly in config files
- ❌ Never share refresh tokens
- ❌ Never add `.fractary/` to `.gitignore` (configs need to be shared with team)

## OAuth Scopes

### drive.file (Recommended)

**Access**: Only files created by fractary-file
**Pros**:
- Better security
- Limited access scope
- Easier permission auditing

**Cons**:
- Cannot access existing files not created by the app

**Use Case**: New files, isolated storage

### drive (Full Access)

**Access**: All files in Google Drive
**Pros**:
- Can access any file
- Works with existing files

**Cons**:
- Broader permission scope
- Security risk if credentials compromised

**Use Case**: Managing existing Drive files

## Troubleshooting

### Issue: "Invalid client"

**Error**: `oauth2: cannot fetch token: 401 Unauthorized`

**Cause**: Invalid Client ID or Client Secret

**Solution**:
1. Verify credentials in Google Cloud Console
2. Check for extra spaces in rclone config
3. Regenerate OAuth credentials if needed

### Issue: "Access not configured"

**Error**: `Drive API has not been used in project before`

**Cause**: Drive API not enabled

**Solution**:
1. Go to Google Cloud Console
2. Navigate to "APIs & Services" → "Library"
3. Search for "Google Drive API"
4. Click "Enable"

### Issue: "Rate limit exceeded"

**Error**: `Rate Limit Exceeded`

**Cause**: Too many API requests

**Solution**:
- Wait a few minutes and retry
- Check for loops in your code
- Consider requesting higher quota in Google Cloud Console

### Issue: "Authorization Error"

**Error**: `Access denied: Access blocked: This app's request is invalid`

**Cause**: OAuth consent screen not configured properly

**Solution**:
1. Go to OAuth consent screen in Google Cloud Console
2. Add test users if app is in "Testing" mode
3. Or publish the app for production

### Issue: "Token expired" (no auto-refresh)

**Error**: `Token expired and refresh not working`

**Cause**: Refresh token invalid or revoked

**Solution**:
```bash
# Reconnect rclone
rclone config reconnect gdrive:

# Or delete and recreate remote
rclone config delete gdrive
rclone config  # Follow setup steps again
```

### Issue: "rclone remote not found"

**Error**: `rclone remote 'gdrive' not configured`

**Cause**: Misconfigured rclone remote name

**Solution**:
1. Check rclone remotes: `rclone listremotes`
2. Update `rclone_remote_name` in config.json to match
3. Or recreate remote with correct name

## Security Best Practices

1. **Use Minimal Scopes**: Prefer `drive.file` over `drive`
2. **Environment Variables**: Store credentials in env vars, not config files
3. **File Permissions**: Always use 0600 for config files
4. **Regular Audits**: Review authorized apps in Google Account settings
5. **Rotate Credentials**: Regenerate OAuth credentials every 90 days
6. **Monitor Access**: Check Drive activity logs for suspicious access
7. **Revoke Access**: Revoke app access when no longer needed

## Revoking Access

To revoke fractary-file's access to Google Drive:

### Option 1: Via Google Account

1. Go to https://myaccount.google.com/permissions
2. Find "Fractary File Plugin" (or your app name)
3. Click "Remove Access"

### Option 2: Via rclone

```bash
# Remove rclone remote
rclone config delete gdrive

# This does not revoke cloud-side access - use Option 1 for that
```

## Advanced Configuration

### Using Custom Root Folder

Restrict fractary-file to a specific folder:

1. Create folder in Google Drive
2. Get folder ID from URL
3. Configure in rclone:
   ```bash
   rclone config update gdrive root_folder_id 1a2b3c4d5e6f7g8h9i0
   ```
4. Or update config.json:
   ```json
   {
     "handlers": {
       "gdrive": {
         "folder_id": "1a2b3c4d5e6f7g8h9i0"
       }
     }
   }
   ```

### Using Shared Drive (Team Drive)

For organization shared drives:

1. During rclone config, answer `y` to "Configure this as a team drive?"
2. Select the shared drive from the list
3. Ensure you have appropriate permissions on the shared drive

### Encrypting rclone Configuration

Protect rclone config with password:

```bash
rclone config
s) Set configuration password
# Follow prompts to set password
```

**Note**: You'll need to enter password when rclone starts.

## Support

For issues with:
- **rclone**: https://rclone.org/drive/
- **Google Drive API**: https://developers.google.com/drive
- **fractary-file**: GitHub issues or documentation

## References

- rclone Google Drive docs: https://rclone.org/drive/
- Google OAuth2: https://developers.google.com/identity/protocols/oauth2
- Google Drive API: https://developers.google.com/drive/api/v3/about-sdk
