gengo-swift
===========

A fully objectified client in Swift for the Gengo API

## Usage

```swift
let gengo = Gengo(publicKey: "...", privateKey: "...", sandbox: true)

var job1 = GengoJob()
job1.languagePair = GengoLanguagePair(
  source: GengoLanguage(code: "en"),
  target: GengoLanguage(code: "ja"),
  tier: GengoTier.Standard
)
job1.sourceText = "Testing Gengo API library calls."

var job2 = GengoJob()
job2.languagePair = GengoLanguagePair(
  source: GengoLanguage(code: "ja"),
  target: GengoLanguage(code: "en"),
  tier: GengoTier.Standard
)
job2.sourceText = "API呼出しのテスト"
job2.slug = "テストslug"

gengo.createJobs([job1, job2]) {order, error in
  switch order!.jobCount! {
  case 0:
    println("I ordered no jobs.")
  case 1:
    println("I ordered 1 job.")
  default:
    println("I ordered \(order!.jobCount!) jobs.")
  }
}
```

The output will be:

```
I ordered 2 jobs.
```

The [test code](GengoTests/GengoTests.swift) has a lot more usage examples.

## Files

- [Gengo.swift](Gengo/Gengo.swift) - public and basic objects such as Gengo, GengoJob and GengoLanguage
- [GengoRequest.swift](Gengo/GengoRequest.swift) - internal objects related with HTTP communication
- [Gengo-Bridging-Header.h](Gengo/Gengo-Bridging-Header.h) - one import statement for generation of API signature

## Dependencies

None.
