# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.4] - 2024-12-05
- Changed: Differentiate cache also by data provided (e.g. domain filter for states)

## [0.4.3] - 2024-12-03
- Changed: Allow passing data to entities state subcription, so you can filter what you want to receive

## [0.4.2] - 2024-04-22
- Changed: Avoid JSON cache by JSONSerialization NSString

## [0.4.1] - 2024-04-03
- Added: Typed request to send Assist audio data to Assist pipeline
- Changed: Use of forked StarScream which fixes usage of URLSession

## [0.4] - 2024-03-06
- Added: REST API calls can now be issued.
* Added: `HAConnectionInfo` can now provide a closure to handle SecTrust (TLS certificate) validation other than the default.
- Changed: `HARequestType` is now an enum of `webSocket` and `rest`. The command value for REST calls is the value after 'api/', e.g. 'api/template' has a type of `.rest(.post, "template")`.
- Changed: `HAData` now includes a `primitive` case to express non-array/dictionary values that aren't `null`.
- Changed: WebSocket connection will now enable compression.
- Fixed: Calling `HAConnection.connect()` and `HAConnection.disconnect()` off the main thread no longer occasionally crashes.
- Removed: Usage of "get_states"
- Added: More efficient API "subscribe_entities" replacing "get_states"

## [0.3] - 2021-07-08
- Added: Subscriptions will now retry (when their request `shouldRetry`) when the HA config changes or components are loaded.
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
