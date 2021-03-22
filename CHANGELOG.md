# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Added: `HACache<T>` which can send requests and subscribe to events to keep its value up-to-date.
- Added `HACachesContainer` accessible as `connection.caches` which contains built-in caches.
- Added: `connection.caches.states` which contains and keeps up-to-date all entity states.
- Added: `connection.caches.user` which contains the current user.
- Added: Optional `PromiseKit` target/subspec.
- Added: Optional `HAMockConnection` target/subspec for use in test cases.
- Added: `connectAutomatically` parameter to connection creation. This will call `connect()` when requests are sent if not connected.
- Added: `.getServices()` typed request.
- Added: `.getStates()` typed request.
- Changed: `attributes` and `context` on `HAEntity` are now represented by parsed types.
- Fixed: Calling `connect()` when already connected no longer disconnects and reconnects.

## [0.1.0] - 2021-03-05
Initial release.

<!--
Types of changes

- Added for new features.
- Changed for changes in existing functionality.
- Deprecated for soon-to-be removed features.
- Removed for now removed features.
- Fixed for any bug fixes.
- Security in case of vulnerabilities.
-->
