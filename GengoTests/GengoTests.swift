import UIKit
import XCTest

let TIMEOUT: NSTimeInterval = 5
let gengo = Gengo(
    publicKey: "EV6nE@gBD8]VB2aX1507)I[^OXmG^PyXIiwncr5nZ68D|Tq25(7XwPF7oZw}BpT5",
    privateKey: "gaxi4i58IbaLIz@slxAmKeV}PlS@uLd83jG$XiSRBZphUX@Y0$8$7mFH1c3(uxAJ",
    sandbox: true
)

let testJobs = [
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

class GengoServiceTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = expectationWithDescription("GengoServiceTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetLanguages() {
        gengo.getLanguages() {languages, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(languages), 0)
            var english: GengoLanguage?
            for language in languages {
                if language.code == "en" {
                    english = language
                }
            }
            if let e = english {
                XCTAssertEqual(e.name!, "English")
                XCTAssertEqual(e.unitType!, GengoLanguageUnitType.Word)
            } else {
                XCTFail("English not found")
            }

            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetLanguagePairs() {
        gengo.getLanguagePairs(source: GengoLanguage(code: "ja")) {pairs, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(pairs), 0)
            var nonJaCount = 0
            for pair in pairs {
                if pair.source.code != "ja" {
                    ++nonJaCount
                }
            }
            XCTAssertEqual(nonJaCount, 0)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT*9999, nil)
    }
    
    func testGetQuoteText() {
        gengo.getQuoteText(testJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(jobs), 0)
            
            // the job order in `jobs` may be different from that in `tests`
            for job in jobs {
                if job.languagePair.source.code == "ja" {
                    XCTAssertEqual(job.unitCount!, 8)
                } else if job.languagePair.source.code == "en" {
                    XCTAssertEqual(job.unitCount!, 5)
                } else {
                    XCTFail("invalid source language")
                }
                XCTAssertGreaterThan(job.credit!.amount, 0.0 as Float)
            }

            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetQuoteFile() {
        var fileJobs: [GengoJob] = []
        for (i, job) in enumerate(testJobs) {
            fileJobs.append(
                GengoJob(
                    languagePair: job.languagePair,
                    sourceFile: GengoFile(
                        data: job.sourceText!.dataUsingEncoding(NSUTF8StringEncoding)!,
                        name: "\(i).txt"
                    )
                )
            )
        }
        
        for job in fileJobs {
            XCTAssertEqual(job.type, GengoJobType.File)
        }
        
        gengo.getQuoteFile(fileJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(jobs), 0)
            
            // the job order in `jobs` may be different from that in `tests`
            for job in jobs {
                if job.languagePair.source.code == "ja" {
                    XCTAssertEqual(job.unitCount!, 8)
                } else if job.languagePair.source.code == "en" {
                    XCTAssertEqual(job.unitCount!, 5)
                } else {
                    XCTFail("invalid source language")
                }
                XCTAssertGreaterThan(job.credit!.amount, 0.0 as Float)
                XCTAssertFalse(job.identifier!.isEmpty)
            }
            
            self.expectation!.fulfill()
        }

        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}

class GengoJobsTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = expectationWithDescription("GengoJobsTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testCreateJobs() {
        gengo.createJobs(testJobs) {order, error in
            if let e = error {
                if e.code == GengoErrorCode.NotEnoughCredits.rawValue {
                    self.expectation!.fulfill()
                    return
                }
                XCTFail("error is not nil: \(e)")
            }
            
            if let o = order {
                XCTAssertGreaterThanOrEqual(o.id, 0)
                XCTAssertGreaterThanOrEqual(o.money!.amount, 0.0 as Float)
                XCTAssertGreaterThanOrEqual(o.jobCount, 0)
            } else {
                if error == nil { // all the jobs are duplicates
                    self.expectation!.fulfill()
                    return
                }
                XCTFail("order is nil")
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetJobsWithParameters() {
        var parameters: [String: Any] = ["count": 1]
        gengo.getJobs(parameters: parameters) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual(countElements(jobs), 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetJobsWithIDs() {
        gengo.getJobs([1215564]) {jobs, error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}

class GengoOrderTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = expectationWithDescription("GengoOrderTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetOrder() {
        gengo.getOrder(321281) {order, error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}