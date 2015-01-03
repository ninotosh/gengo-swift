gengo-swift
===========

A client library in Swift for the Gengo API

[![Build Status](https://travis-ci.org/ninotoshi/gengo-swift.svg)](https://travis-ci.org/ninotoshi/gengo-swift)

## Usage

```swift
let gengo = Gengo(publicKey: "...", privateKey: "...", sandbox: true)
gengo.getLanguages() {languages, error in
  for language in languages {
    println("name: \(language.name!)")
  }
}
```

The output will be:

```
name: English
name: Japanese
name: Spanish (Spain)
name: Chinese (Simplified)
name: German
name: French
name: Russian
name: Italian
name: Portuguese (Brazil)
name: Thai
name: Spanish (Latin America)
name: French (Canada)
name: Norwegian
name: Tagalog
name: Korean
name: Romanian
name: Indonesian
name: Turkish
name: Portuguese (Europe)
name: Chinese (Traditional)
name: Swedish
name: Bulgarian
name: Danish
name: English (British)
name: Malay
name: Greek
name: Vietnamese
name: Hebrew
name: Hungarian
name: Arabic
name: Finnish
name: Polish
name: Dutch
name: Czech
```
