# Changelog

All notable changes to the Mark app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.1] - 2024-04-09

### Added
- New Community feature implementation:
  - Created Community Feed view for displaying shared reading sessions
  - Added Post creation functionality allowing users to share reading experiences
  - Implemented Post detail view to display complete session information
  - Added real-time updates for community content using Supabase
- New models:
  - Created CommunityPost model for social sharing
- New services:
  - Added KeychainWrapper for secure credential storage
  - Extended SupabaseManager with community post methods
- Enhanced application lifecycle management:
  - Added realtime feature subscription handling
  - Improved network status change handling

### Changed
- Updated MainTabView to include new Community tab
- Refined UI/UX for reading session flow
- Modified Profile view by removing unnecessary navigation elements
- Updated MarkAppApp to use shared AuthManager instance
- Optimized database queries for better performance

### Fixed
- Issue with book cover images not loading properly
- Audio recording stability improvements
- Minor UI alignment issues in profile view

## [v0.1.0] - 2024-04-08

### Added
- Initial release of the Mark app
- Book management and library functionality
- Reading session recording and transcription
- Voice transcription capabilities
- User authentication and profile management
- Integration with Supabase backend

### Changed
- Updated app version from development to first release version

### Fixed
- Initial bug fixes and performance improvements 