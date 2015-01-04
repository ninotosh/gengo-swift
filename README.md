gengo-swift
===========

A fully objectified client in Swift for the Gengo API

## Usage

```swift
let gengo = Gengo(publicKey: "...", privateKey: "...", sandbox: true)

let jobs = [
  GengoJob(
    languagePair: GengoLanguagePair(
      source: GengoLanguage(code: "en"),
      target: GengoLanguage(code: "ja"),
      tier: GengoTier.Standard
    ),
    sourceText: "Testing Gengo API library calls."
  ),
  GengoJob(
    languagePair: GengoLanguagePair(
      source: GengoLanguage(code: "ja"),
      target: GengoLanguage(code: "en"),
      tier: GengoTier.Standard
    ),
    sourceText: "API呼出しのテスト",
    slug: "テストslug"
  )
]

gengo.createJobs(jobs) {order, error in
  switch order!.jobCount {
  case 0:
    println("I ordered no jobs.")
  case 1:
    println("I ordered 1 job.")
  default:
    println("I ordered \(order!.jobCount) jobs.")
  }
}
```

The output will be:

```
I ordered 2 jobs.
```

## Files

- Gengo.swift - public and basic objects such as Gengo, GengoJob and GengoLanguage
- GengoRequest.swift - internal objects related with HTTP communication
- Gengo-Bridging-Header.h - one import statement for generation of API signature
