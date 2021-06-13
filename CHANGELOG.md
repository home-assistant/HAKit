# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Changed: `HAConnectionInfo` now has a throwing initializer. See `HAConnectionInfo.CreationError` for details.

## [0.2.2] - 2021-05-01
- Added: Allow overriding `User-Agent` header in connection via `HAConnectionInfo`.
- Fixed: `Host` header now properly excludes port so we match URLSession behavior.
- Fixed: Services now load successfully for versions of HA Core prior to 2021.3 when `name` was added.

## [0.2.1] - 2021-04-05
- Changed: `HAGlobal`'s `log` block now contains a log level, either `info` or `error`.
- Fixed: Failed populate requests no longer crash when a later subscription is updated.
- Fixed: The error log from a failed `HACache<T>` populate now contains more information.
- Fixed: Dates from HA which lack milliseconds no longer fail to parse.

## [0.2.0] - 2021-04-04
- Added: `HACache<T>` which can send requests and subscribe to events to keep its value up-to-date.
- Added `HACachesContainer` accessible as `connection.caches` which contains built-in caches.
- Added: `connection.caches.states` which contains and keeps up-to-date all entity states.
- Added: `connection.caches.user` which contains the current user.
- Added: Optional `PromiseKit` target/subspec.
- Added: Optional `HAMockConnection` target/subspec for use in test cases.
- Added: `connectAutomatically` parameter to connection creation. This will call `connect()` when requests are sent if not connected.
- Added: `.getServices()` typed request.
- Added: `.getStates()` typed request.
- Changed: Swapped to using the custom (not URLSession) engine in Starscream to try and figure out if URLSession is causing connectivity issues.
- Changed: `attributes` and `context` on `HAEntity` are now represented by parsed types.
- Changed: Many internal cases of JSON parsing and decoding are now done off the main thread.
- Changed: Events to unknown subscriptions (that is, a logic error in the library somewhere) no longer unsubscribe as this was sending erroneously during reconnects.
- Fixed: Calling `connect()` when already connected no longer disconnects and reconnects.
- Fixed: Calling `cancel()` on a subscription more than once or on a non-retried subscription sends multiple unsubscribe requests.
- Fixed: Disconnections silently occurred due to e.g. suspension; pings are now sent regularly to make sure the connection really is active.

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
