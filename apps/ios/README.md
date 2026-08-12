# Overture — SwiftUI

Native Overture client. It loads the current published edition from the publication
API, falls back to its bundled prototype edition when offline, and exchanges native
Sign in with Apple identity tokens for Better Auth bearer sessions stored in Keychain.

## Run

1. Open `Overture.xcodeproj` in Xcode.
2. Select the `Overture` scheme and an iPhone simulator running iOS 18 or newer.
3. Press Run.

For Debug, the API base URL is `http://localhost:3001`. Release uses
`https://api.overture.news`; change `OvertureAPIBaseURL` in the target build settings
if the production API is hosted elsewhere. The project has no third-party package
install step.

Sign in with Apple requires the `com.overture.news.swiftui` App ID to have the Sign in
with Apple capability and the backend Apple provider variables described in the root
README. A Simulator build verifies the integration code, but a real Apple sign-in must
be tested with configured Apple credentials.
