# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Sod is a Phoenix-based privacy analysis system that analyzes Terms of Service and Privacy Policy documents using AI (LangChain integration). It provides personalized risk assessments based on user preferences and caches analysis results to optimize token usage.

## Development Commands

### Setup and Installation
```bash
mix setup                    # Install dependencies, setup database, and build assets
mix deps.get                 # Install Elixir dependencies only
mix ecto.setup              # Create database, run migrations, and seeds
mix ecto.reset              # Drop and recreate database
```

### Running the Application
```bash
mix phx.server              # Start Phoenix server (localhost:4000)
iex -S mix phx.server       # Start server with interactive Elixir shell
```

### Database Operations
```bash
mix ecto.create             # Create database
mix ecto.migrate            # Run pending migrations
mix ecto.rollback           # Rollback last migration
mix ecto.gen.migration <name> # Generate new migration
```

### Testing
```bash
mix test                    # Run all tests (includes test database setup)
mix test test/path/to/test.exs # Run specific test file
mix test --cover            # Run tests with coverage report
```

### Assets and Styling
```bash
mix assets.setup            # Install Tailwind CSS and esbuild if missing
mix assets.build            # Build assets for development
mix assets.deploy           # Build and minify assets for production
```

### Code Quality
```bash
mix format                  # Format Elixir code
mix credo                   # Run static code analysis (if configured)
```

## Core Architecture

### Domain Contexts

**Sod.AiCache** - Handles caching of AI analysis results to prevent duplicate API calls for identical content:
- `TosAnalysisCache` - Stores complete AI analysis results with content hashes
- `ClauseLibrary` - Library of detected risky clauses for pattern matching
- `UserAnalysisHistory` - Per-user analysis history and personalized results

**Sod.Ai.LangchainAnalyzer** - Core AI integration module:
- Generates content hashes to check for cached analysis
- Builds structured prompts for AI analysis of TOS/Privacy Policy documents
- Processes AI responses into structured risk assessments
- Personalizes analysis based on user privacy preferences

**Sod.Sites** - Manages website/domain information and metadata

**Sod.Analytics** - Tracks user behavior, site visits, and risk statistics

**Sod.Alerts** - Risk alert system for notifying users of privacy concerns

**Sod.Preferences** - User privacy preference management (data sharing, tracking, retention policies)

### API Controllers

**SodWeb.API.ExtensionController** - Primary API for browser extension integration:
- `get_or_create_site/2` - Register new sites when visited
- `analyze_site_content/2` - Analyze TOS content with optional personalization
- `get_user_preferences/2` - Retrieve user privacy settings
- `update_preferences/2` - Update user privacy preferences
- Authentication via `x-session-token` header

**SodWeb.API.RiskController** - Risk analysis and alert management:
- `analyze_for_user/2` - Personalized TOS analysis based on user preferences
- `list_alerts/2` - Paginated user alerts
- `user_risk_summary/2` - Comprehensive user risk statistics

### Background Processing

**Sod.BackgroundJobs.AiAnalyzer** - GenServer for periodic site analysis:
- Analyzes sites every 12 hours
- Batch processes sites with rate limiting
- Identifies sites needing fresh analysis

### Key Design Patterns

**Content Hashing** - SHA-256 hashes prevent duplicate AI analysis of identical content across sites

**Intelligent Caching** - Three-tier caching strategy:
1. Check content hash for existing analysis
2. Personalize cached analysis based on user preferences  
3. Store user-specific analysis history

**Preference Violation Detection** - Maps detected TOS clauses to specific user privacy preferences to generate personalized risk scores and warnings

**Session Management** - Browser extension authentication through session tokens with activity tracking

## Development Notes

### AI Integration
- LangChain integration is stubbed with mock responses in `call_ai_service/2`
- Real implementation would use OpenAI/Claude APIs
- Token usage tracking built-in for cost management

### Database Schema
- Uses binary UUIDs as primary keys
- Comprehensive migration history in `priv/repo/migrations/`
- Focus on user privacy preferences, site analysis caching, and risk tracking

### Extension Integration  
- Designed for browser extension that analyzes TOS/Privacy Policies in real-time
- Session-based authentication without requiring traditional login flow
- Real-time risk alerts and personalized recommendations

### Performance Considerations
- Content hashing prevents duplicate AI analysis
- Background job system for batch processing
- Access count tracking for cache effectiveness
