gengo-swift
===========

A client library in Swift for the Gengo API

[![Build Status](https://travis-ci.org/ninotoshi/gengo-swift.svg)](https://travis-ci.org/ninotoshi/gengo-swift)

## Usage

```swift
let gengo = Gengo(publicKey: "...", privateKey: "...", sandbox: true)
gengo.getLanguages() {languages, error in
  println(languages)
}
```
