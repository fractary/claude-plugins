---
model: claude-haiku-4-5
---

Generate a new database migration from schema changes.

This command creates a new migration file by comparing your current schema definition with the database state, capturing the differences as SQL statements.

## Usage

```bash
/faber-db:generate-migration "<description>" [options]
```

## Arguments

- `<description>` (required): Brief description of schema changes (e.g., "add user profiles", "remove deprecated columns")

## Options

- `--environment <env>`: Environment to generate against (default: dev)
- `--force`: Force migration generation even if no changes detected
- `--name <name>`: Custom migration name (auto-generated from description if not provided)
- `--preview`: Show what would be generated without creating files

## What It Does

1. **Validates environment**
   - Checks working directory has Prisma schema
   - Verifies configuration is valid
   - Confirms environment is set up

2. **Detects schema changes**
   - Compares `prisma/schema.prisma` with database state
   - Identifies new tables, columns, indexes
   - Detects modified or removed schema elements
   - Reports if no changes detected

3. **Generates migration files**
   - Creates timestamped migration directory
   - Generates SQL migration file with changes
   - Updates migration history
   - Validates migration syntax

4. **Preview mode** (if --preview)
   - Shows SQL that would be generated
   - Displays migration directory name
   - No files created on filesystem

5. **Reports results**
   - Migration file path
   - SQL preview
   - Next steps (review, apply)

## Examples

### Generate Migration for New Table

```bash
/faber-db:generate-migration "add user profiles table"
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Migration Generation
═══════════════════════════════════════

Environment: dev
Database: myapp_dev
Provider: PostgreSQL

Step 1: Loading Configuration
✓ Configuration loaded
✓ Environment validated: dev
✓ Prisma schema found: prisma/schema.prisma

Step 2: Detecting Schema Changes
Comparing schema with database state...

Changes detected:
  + New table: UserProfile
    - id: String (Primary Key)
    - userId: String (Foreign Key → User.id)
    - bio: Text (nullable)
    - avatar: Text (nullable)
    - createdAt: DateTime
    - updatedAt: DateTime

  + New index: UserProfile_userId_key (unique)

Step 3: Generating Migration
✓ Migration created: 20250124140000_add_user_profiles_table

Migration file: prisma/migrations/20250124140000_add_user_profiles_table/migration.sql

SQL Preview:
────────────────────────────────────────
-- CreateTable
CREATE TABLE "UserProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bio" TEXT,
    "avatar" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserProfile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "UserProfile_userId_key" ON "UserProfile"("userId");

-- AddForeignKey
ALTER TABLE "UserProfile" ADD CONSTRAINT "UserProfile_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
────────────────────────────────────────

✅ COMPLETED: Migration Generation
Migration: 20250124140000_add_user_profiles_table
File: prisma/migrations/20250124140000_add_user_profiles_table/migration.sql
Status: ✓ Ready to apply

Next steps:
  1. Review migration SQL in generated file
  2. Test migration: /faber-db:migrate dev
  3. Commit migration to version control: git add prisma/migrations
  4. Deploy to staging: /faber-db:migrate staging
```

### Preview Migration Without Creating Files

```bash
/faber-db:generate-migration "add email notifications" --preview
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Migration Preview
═══════════════════════════════════════

Environment: dev
Preview Mode: No files will be created

Changes detected:
  + New column: User.emailVerified (Boolean, default: false)
  + New column: User.emailVerifiedAt (DateTime, nullable)

Migration would be named: 20250124150000_add_email_notifications

SQL Preview:
────────────────────────────────────────
-- AlterTable
ALTER TABLE "User" ADD COLUMN "emailVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "emailVerifiedAt" TIMESTAMP(3);
────────────────────────────────────────

⚠️  This is a preview only. No migration files created.

To create this migration:
  /faber-db:generate-migration "add email notifications"
```

### Generate Migration with Custom Name

```bash
/faber-db:generate-migration "refactor user schema" --name restructure_users
```

Output:
```
✓ Migration created: 20250124160000_restructure_users

Migration name: restructure_users (custom)
Description: refactor user schema
```

### No Schema Changes Detected

```bash
/faber-db:generate-migration "update schema"
```

Output:
```
═══════════════════════════════════════
  FABER-DB: Migration Generation
═══════════════════════════════════════

Environment: dev
Database: myapp_dev

Step 1: Loading Configuration
✓ Configuration loaded
✓ Prisma schema found

Step 2: Detecting Schema Changes
Comparing schema with database state...

✓ No schema changes detected

Your Prisma schema matches the database state exactly.

Options:
  1. Modify prisma/schema.prisma and try again
  2. Force empty migration: /faber-db:generate-migration "description" --force
  3. Check schema diff: npx prisma migrate diff

Current schema: Up to date
Last migration: 20250124140000_add_user_profiles_table
Database: ✓ In sync
```

### Force Migration Generation (No Changes)

```bash
/faber-db:generate-migration "manual schema update" --force
```

Output:
```
⚠️  Warning: Forcing migration generation with no detected changes

This creates an empty migration file you can manually populate.

✓ Migration created: 20250124170000_manual_schema_update

Migration file: prisma/migrations/20250124170000_manual_schema_update/migration.sql

The migration file is empty. Add your SQL manually:
  1. Edit: prisma/migrations/20250124170000_manual_schema_update/migration.sql
  2. Add custom SQL statements
  3. Apply: /faber-db:migrate dev
```

## Migration Naming Convention

Migrations are automatically named with:
- **Timestamp**: `YYYYMMDDHHMMSS` (ensures ordering)
- **Description**: Slugified from your description

Examples:
- "add user profiles" → `20250124140000_add_user_profiles`
- "remove deprecated fields" → `20250124150000_remove_deprecated_fields`
- "fix index on email" → `20250124160000_fix_index_on_email`

Override with `--name` option:
```bash
/faber-db:generate-migration "description" --name custom_name
```

## Workflow Integration

### Development Workflow

1. **Modify schema**:
   ```prisma
   // prisma/schema.prisma
   model UserProfile {
     id        String   @id @default(cuid())
     userId    String   @unique
     bio       String?
     avatar    String?
     user      User     @relation(fields: [userId], references: [id])
   }
   ```

2. **Generate migration**:
   ```bash
   /faber-db:generate-migration "add user profiles table"
   ```

3. **Review SQL**:
   ```bash
   cat prisma/migrations/20250124140000_add_user_profiles_table/migration.sql
   ```

4. **Apply to dev**:
   ```bash
   /faber-db:migrate dev
   ```

5. **Test application**:
   ```bash
   npm test
   ```

6. **Commit migration**:
   ```bash
   git add prisma/migrations/
   git commit -m "feat: add user profiles table"
   ```

### Staging Deployment

After committing migration:
```bash
# Pull latest with migration files
git pull origin main

# Apply to staging
/faber-db:migrate staging
```

### Production Deployment

```bash
# Preview first
/faber-db:migrate production --dry-run

# Apply with approval
/faber-db:migrate production
```

## Schema Change Types

### Adding Elements

**New table**:
```prisma
model Post {
  id        String   @id @default(cuid())
  title     String
  content   String?
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
}
```

**New column**:
```prisma
model User {
  // ... existing fields ...
  emailVerified Boolean @default(false)
}
```

**New index**:
```prisma
model User {
  // ... existing fields ...
  @@index([email])
}
```

### Modifying Elements

**Change column type**:
```prisma
model User {
  age Int // was String before
}
```

**Add constraint**:
```prisma
model User {
  email String @unique // was not unique before
}
```

**Rename field** (requires `@map`):
```prisma
model User {
  emailAddress String @map("email") // rename from "email"
}
```

### Removing Elements

**Drop column**:
```prisma
model User {
  // Remove: phone String?
  // (just delete the line)
}
```

**Drop table**:
```prisma
// Remove entire model definition
// (delete the model block)
```

**Drop index**:
```prisma
model User {
  // Remove: @@index([name])
  // (delete the index line)
}
```

## Migration Tool Behavior

### Prisma (Primary)

Uses `prisma migrate dev`:
- Compares `prisma/schema.prisma` with database state
- Auto-generates SQL migration
- Creates migration directory with timestamp
- Applies migration to database immediately (in dev)
- Updates `_prisma_migrations` table
- Regenerates Prisma Client

**Migration directory structure**:
```
prisma/migrations/
├── 20250124140000_add_user_profiles/
│   └── migration.sql
├── 20250124150000_add_posts/
│   └── migration.sql
└── migration_lock.toml
```

### TypeORM (Future)

Would use TypeORM CLI:
```bash
typeorm migration:generate -n AddUserProfiles
```

### Sequelize (Future)

Would use Sequelize CLI:
```bash
sequelize migration:generate --name add-user-profiles
```

### Knex (Future)

Would use Knex CLI:
```bash
knex migrate:make add_user_profiles
```

## Error Handling

### Schema File Not Found

```
✗ Prisma schema not found

Expected location: prisma/schema.prisma

This command requires a Prisma schema file.

Solutions:
1. Initialize Prisma: npx prisma init
2. Create schema: /faber-db:init dev
3. Check working directory: pwd
```

### Invalid Schema Syntax

```
✗ Invalid Prisma schema

Error: Unexpected token at line 15
  model User {
    id String @id @default(cuid()
    ^^ Missing closing parenthesis

Fix the schema and try again:
  1. Open: prisma/schema.prisma
  2. Fix syntax error
  3. Validate: npx prisma validate
  4. Retry: /faber-db:generate-migration "description"
```

### Database Connection Failed

```
✗ Cannot connect to database

Error: Connection refused at localhost:5432

Migration generation requires database access to compare current state.

Troubleshooting:
1. Verify database is running: psql $DEV_DATABASE_URL
2. Check connection string: echo $DEV_DATABASE_URL
3. Start database: docker-compose up -d
4. Retry when database is available
```

### Schema Drift Detected

```
⚠️  Schema drift detected

Your database has changes that aren't in the Prisma schema.

Detected differences:
  + Table "audit_log" exists in database but not in schema
  + Column "users.last_login" exists in database but not in schema

This usually means:
1. Manual database changes were made
2. Schema file is out of sync

Solutions:
1. Pull schema from database: npx prisma db pull
2. Remove manual changes: (requires careful review)
3. Create migration to sync: /faber-db:generate-migration "sync schema"
```

### Migration Generation Failed

```
✗ Migration generation failed

Error: P1014 - The migration engine failed

This can happen if:
1. Database is in an inconsistent state
2. Previous migration failed mid-application
3. Migration lock file is corrupted

Recovery:
1. Check migration status: /faber-db:status dev
2. Fix failed migration: npx prisma migrate resolve
3. Reset database (WARNING: data loss): npx prisma migrate reset
4. Contact database administrator if needed
```

## Best Practices

### 1. Descriptive Names

**Good**:
- "add user profiles table"
- "add email verification columns"
- "create index on user email"
- "remove deprecated phone field"

**Bad**:
- "update schema" (too vague)
- "changes" (not descriptive)
- "fix" (what was fixed?)

### 2. Atomic Changes

Each migration should represent one logical change:

**Good** (separate migrations):
```bash
/faber-db:generate-migration "add user profiles table"
/faber-db:generate-migration "add email verification"
/faber-db:generate-migration "create posts table"
```

**Bad** (too many unrelated changes):
```bash
/faber-db:generate-migration "add profiles and posts and comments and notifications"
```

### 3. Review Before Applying

Always review generated SQL:
```bash
# Generate
/faber-db:generate-migration "description"

# Review
cat prisma/migrations/*/migration.sql

# Apply if looks good
/faber-db:migrate dev
```

### 4. Test Thoroughly

After applying migration:
```bash
# Run tests
npm test

# Test application
npm run dev

# Verify data integrity
psql $DEV_DATABASE_URL -c "SELECT COUNT(*) FROM users;"
```

### 5. Commit Migrations

Always commit migration files to version control:
```bash
git add prisma/migrations/
git add prisma/schema.prisma
git commit -m "feat: add user profiles table"
```

**Never**:
- Modify migration files after applying
- Delete migration files
- Edit migration history

### 6. Handle Data Migrations

For migrations with data transformations, use `--force` to create empty migration and add custom SQL:

```bash
# Generate empty migration
/faber-db:generate-migration "migrate user names" --force

# Add custom SQL
cat >> prisma/migrations/20250124170000_migrate_user_names/migration.sql << 'EOF'
-- Migrate data
UPDATE "User"
SET "fullName" = "firstName" || ' ' || "lastName"
WHERE "fullName" IS NULL;

-- Drop old columns
ALTER TABLE "User" DROP COLUMN "firstName";
ALTER TABLE "User" DROP COLUMN "lastName";
EOF

# Apply
/faber-db:migrate dev
```

## Integration with FABER Workflow

Migration generation typically happens in **Architect** or **Build** phases:

### Architect Phase
```toml
[workflow.architect]
post_architect = [
  "faber-db:generate-migration '<description from spec>'"
]
```

### Build Phase
```toml
[workflow.build]
pre_build = [
  "faber-db:generate-migration '<schema changes>'"
]
post_build = [
  "faber-db:migrate dev"
]
```

## Troubleshooting

### Migration Already Exists

```
⚠️  Migration with similar name already exists

Existing: 20250124140000_add_user_profiles
New: add_user_profiles (would conflict)

Options:
1. Use more specific description
2. Review existing migration
3. Combine changes into existing migration (before applying)
```

### Prisma Client Out of Sync

```
⚠️  Prisma Client is out of sync

After generating migrations, regenerate the client:
  npx prisma generate

Or apply migration (auto-regenerates):
  /faber-db:migrate dev
```

### Migration Lock Conflict

```
✗ Migration lock conflict

Another migration is in progress or the lock file is stale.

Solutions:
1. Wait for other migration to complete
2. Check for running processes: ps aux | grep prisma
3. Remove stale lock (if confirmed no other process): rm prisma/migrations/migration_lock.toml
```

## Exit Codes

- **0**: Migration generated successfully
- **1**: Configuration or validation errors
- **2**: No schema changes detected (without --force)
- **3**: Schema syntax errors
- **4**: Database connection failed
- **5**: Migration generation failed

## See Also

Related commands:
- `/faber-db:migrate` - Apply migrations to environment
- `/faber-db:status` - Check migration status
- `/faber-db:rollback` - Rollback applied migrations
- `/faber-db:init` - Initialize database environment

Documentation:
- `docs/README.md` - Plugin overview
- `docs/MIGRATION-GUIDE.md` - Migration workflows
- `docs/TROUBLESHOOTING.md` - Troubleshooting guide

External documentation:
- [Prisma Migrate](https://www.prisma.io/docs/concepts/components/prisma-migrate)
- [Migration flows](https://www.prisma.io/docs/guides/migrate/developing-with-prisma-migrate)
