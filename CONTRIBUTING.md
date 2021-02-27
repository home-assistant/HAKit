# Contributing

 - Read [How to get faster PR reviews](https://github.com/kubernetes/community/blob/master/contributors/guide/pull-requests.md#best-practices-for-faster-reviews) by Kubernetes (but skip step 0)
 - Create a Pull Request against the **main** branch.

## Guidelines

- Convenience methods, request types and event names can be added for any request or event in the Home Assistant core repository. Calls which are added via third-party components should not be added here.
- Code coverage must be maintained for all changes. Make sure your tests execute successfully.

## Building the library
- `brew bundle` installs linting and other utilities.
- `make open` launches the Swift Project Manager version of the library in Xcode.
- `make generate-project` creates an openable `.xcodeproj` from the Swift package.
- `make test` executes all tests for the library.
- `make lint` execute linting. Locally, this will also apply autocorrects.

## Learn Swift
This project is a good opportunity to learn Swift programming and contribute back to a friendly and welcoming Open Source community. We've collected some pointers to get you started.

* Apple's [The Swift Programming Language](https://www.apple.com/swift/) is a great resource to start learning Swift programming. It also happens to be free.
* There are also some great tutorials and boot camps available:
  * [Big Nerd Ranch](https://www.bignerdranch.com/)
  * [objc.io](https://www.objc.io)
  * [Point-Free](https://www.pointfree.co)
  * [raywenderlich.com](https://www.raywenderlich.com/)
