# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2026-09-30

### Migration: Transition from Firebase Extensions to Native Cloud Functions Email Service

#### Why This Was Done
Google announced the deprecation of the Firebase Extensions service, with full decommissioning scheduled for March 31, 2027. Following this cutoff, installed extensions can no longer be updated, reconfigured, or patched. To ensure long-term maintainability, eliminate external service lock-in, and modernize our serverless architecture, we migrated from the managed `firestore-send-email` extension to a self-managed Cloud Functions pipeline.

#### What Was Changed
1. **Native Serverless Email Delivery**: Replaced the managed extension with a native `nodemailer` implementation leveraging Resend SMTP.
2. **Direct Event Notification**: Upgraded bug reporting (`onBugReport`) and user feedback (`onFeedback`) triggers to deliver notifications directly, removing unnecessary intermediary database writes and reducing Firestore latency and costs.
3. **Smart Reply-To Handling**: Configured email headers to dynamically populate the user's email into the `Reply-To` field for one-click admin replies.
4. **Backward-Compatible Queue Processor**: Added a background Firestore trigger (`processMailQueue`) matching the legacy extension’s exact schema and delivery state flags (`SUCCESS` / `ERROR`) to prevent breaking changes across existing workflows.
5. **Cleaned Legacy Infrastructure**: Removed extension configurations from project manifests and pruned deprecated video upload functions in favor of our event-driven AWS EventBridge media pipeline.
