# ha-swift-api

**This is still in development. You should not yet use this library.**

[![Documentation](https://home-assistant.github.io/ha-swift-api/badge.svg)](https://home-assistant.github.io/ha-swift-api/) [![codecov](https://codecov.io/gh/home-assistant/ha-swift-api/branch/main/graph/badge.svg?token=M0ZUCTQMBM)](https://codecov.io/gh/home-assistant/ha-swift-api) [![License Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-green.svg?style=flat)](https://github.com/home-assistant/ha-swift-api/blob/master/LICENSE)

This library allows you to connect to the [Home Assistant WebSocket API](https://developers.home-assistant.io/docs/api/websocket) to issue commands and subscribe to events. Future plans include offering minimal [Rest API](https://developers.home-assistant.io/docs/api/rest) support.

## API Reference

You can view the [full set of documentation](https://home-assistant.github.io/ha-swift-api/). The most important set of available method sare on the [HAConnectionProtocol](https://home-assistant.github.io/ha-swift-api/Protocols/HAConnectionProtocol.html) protocol. This protocol acts as the main entrypoint to talking to a Home Assistant instance.

## Creating and connecting

Creating a connection needs two pieces of information: the server URL and an access token. Both are retrieved when a connection attempt is made. Since Home Assistant instances' connectivity may differ based on the current network, these values are re-queried on each connection attempt.

You can get a connection instance using the exposed initializer:

```swift
let connection = HAConnection.api(configuration: .init(
  connectionInfo: {
    // Connection is required to be returned synchronously.
    .init(url: URL(string: "http://homeassistant.local:8123")!)
  },
  fetchAuthToken: { completion in
    // Access tokens are retrieved asynchronously, but be aware that Home Assistant
    // has a timeout of 10 seconds for sending your access token.
    completion(.success("API_Token_Here"))
  }
))
```

You may further configure other attributes of this connection, such as `callbackQueue` (where your handlers are invoked), as well as triggering manual connection attempts. See the protocol for more information.

Once you invoke `.connection()` and until you invoke `.disconnect()` the connection will try to stay connected by attempting to reconnect when network status changes and after a retry period following disconnection.

## Sending and subscribing

There are two types of requests: those with an immediate result and those which fire events until cancelled. The actions for these are "sending" and "subscribing." For example, you might _send_ a service call but _subscribe to_ a template's rendering.

Requests issued will continue to retry across reconnects until executed once, and subscriptions will automatically re-register when necessary until cancelled. Each `send` or `subscribe` returns an `HACancellable` token which you can cancel and each subscription handler includes a token as well.

Retrieving the current user for example, like other calls in [HATypedRequest](https://home-assistant.github.io/ha-swift-api/Structs/HATypedRequest.html) and [HATypedSubscription](https://home-assistant.github.io/ha-swift-api/Structs/HATypedSubscription.html), has helper methods to offer strongly-typed values. For example, you could write it one of two ways:

```swift
// with the CallService convenience helper
connection.send(.currentUser()) { result in
  switch result {
  case let .success(user):
    // e.g. user.id or user.name are available on the result object
  case let .failure(error):
    // an error occurred with the request
  }
}

// or issued directly, and getting the raw response
connection.send(.init(type: .currentUser, data: [:])) { result in
  switch result {
  case let .success(data):
    // data is an `HAData` which wraps possible responses and provides decoding
  case let .failure(error):
    // an error occurred with the request
  }
}
```

Similarly, subscribing to events can be done both using the convenience helper or directly. 

```swift
// with the RenderTemplate convenience helper
connection.subscribe(
  to: .renderTemplate("{{ states('sun.sun') }} {{ states.device_tracker | count }}"),
  initiated: { result in
    // when the initiated method is provided, this is the result of the subscription
  },
  handler: { [textView] cancelToken, response in
    // the overall response is parsed for type, but native template rendering means
    // the rendered type will be a Dictionary, Array, etc.
    textView.text = String(describing: response.result)
    // you could call `cancelToken.cancel()` to end the subscription here if desired
  }
)

// or issued directly, and getting the raw response
connection.subscribe(
  to: .init(type: .renderTemplate, data: [
    "template": "{{ states('sun.sun') }} {{ states.device_tracker | count }}"
  ]),
  initiated: { result in
    // when the initiated method is provided, this is the result of the subscription
  },
  handler: { [textView] cancelToken, data in
    // data is an `HAData` which wraps possible responses and provides decoding
    // the decode methods infer which type you're asking for and attempt to convert
    textView.text = try? data.decode("result")
    // you could call `cancelToken.cancel()` to end the subscription here if desired
  }
)  
```

You can also invoke any request or subscription, even those without convenience accessors around their name. The event names and request types conform to `ExpressibleByStringLiteral` or you can initialize them with a raw value.

## Decoding

Many methods will deliver results as `HAData` when not using convenience wrappers. This is delivered in place of an underlying dictionary or array response and it features convenience methods to decode keys from the dictionaries as particular types. This works similarly to `Decodable` but not identically -- many Home Assistant calls will return results that _must_ be preserved as `Any` and Swift's JSON coding does not handle this well.

See [`HADataDecodable`](Source/Data/HADataDecodable.swift) for the available methods.

## Installation

### Swift Package Manager

To install the library, either add it as a dependency in a `Package.swift` like:

```swift
.Package(url: "https://github.com/home-assistant/ha-swift-api.git", majorVersion: 1)
```

To add it to an Xcode project, you can do this by adding the URL to File > Swift Packages > Add Package Dependency and.

### CocoaPods
Add the following line to your Podfile:

```ruby
pod "TODO: What am I naming this? lol", "~> 1.0"
```

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) more information on how to build and modify this library.

## License
This library is available under the [Apache 2.0 license](LICENSE.md). It also has an underlying dependency on [Starscream](https://github.com/daltoniam/Starscream) for WebSocket connectivity on older versions of iOS. Starscream is also available under the Apache 2.0 license.

