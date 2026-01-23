# CLAUDE.md

This file provides guidance to AI Agents when working with code in this repository.

## Project Overview

Campfire is a Rails 8 web-based chat application (fork of Once Campfire). Single-tenant deployment with rooms, direct messages, file attachments, search, Web Push notifications, @mentions, and bot API integrations.

## Development Commands

```bash
# Setup
bin/setup                    # Install deps, configure DB, start Redis

# Run application
bin/rails server             # Start Rails on :3000
bin/dev                      # Start all Procfile processes (web + redis + workers)

# Testing
bin/rails test               # Run unit/functional tests
bin/rails test test/models/user_test.rb              # Run single test file
bin/rails test test/models/user_test.rb:42           # Run specific test line
bin/rails test:system        # Run browser tests (Capybara/Selenium)

# Full CI suite (runs locally)
bin/ci

# Code quality
bin/rubocop                  # Ruby linting (Rails Omakase style)
bin/brakeman                 # Security analysis
bin/bundler-audit            # Gem vulnerability scan
bin/importmap audit          # JS dependency check

# Database
bin/rails db:prepare         # Idempotent DB setup
bin/rails db:seed:replant    # Reset + reseed with test data
```

## CI Pipeline Steps

Defined in `config/ci.rb`:
1. Setup
2. Style: Ruby (rubocop)
3. Security: Gem audit, Importmap audit, Brakeman
4. Tests: Rails tests, System tests, Seeds validation
5. Signoff (via `gh signoff`)

## Architecture

**Stack:** Rails 8.2, Ruby 3.4.5, SQLite3, Redis, Puma, Resque

**Real-time:** ActionCable WebSocket channels + Turbo broadcasts + Stimulus controllers

**Key Models:**
- `Account` - Singleton per instance (settings, branding)
- `User` - Application users
- `Room` - Chat rooms (public/private with access controls)
- `Message` - Messages within rooms
- `Membership` - User participation in rooms
- `Webhook` - Bot integration endpoints

**Background Jobs:** Resque with resque-pool (`app/jobs/`)

**Key Directories:**
- `app/channels/` - ActionCable WebSocket channels for live updates
- `app/jobs/` - Resque background jobs (Web Push, link unfurling, media processing)
- `lib/restricted_http/` - SSRF protection utilities
- `lib/web_push/` - Push notification connection pooling
- `script/admin/` - Admin utilities (e.g., `create-vapid-key`)

## Deployment

Blue-green deployment via GitHub Actions. Docker multi-arch images (amd64 + arm64) published to GHCR.

**Production env vars:** `SECRET_KEY_BASE`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `SSL_DOMAIN` (or `DISABLE_SSL`), `SENTRY_DSN`

**Data persistence:** Mount volume to `/rails/storage` (SQLite DB + file attachments)

## Pull Request Guidelines

- Do not include a "Test plan" section in PR descriptions
- Keep PR descriptions concise with a summary of changes
