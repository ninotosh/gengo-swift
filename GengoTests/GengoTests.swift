import UIKit
import XCTest

let TIMEOUT: NSTimeInterval = 5
let gengo = Gengo(
    publicKey: "EV6nE@gBD8]VB2aX1507)I[^OXmG^PyXIiwncr5nZ68D|Tq25(7XwPF7oZw}BpT5",
    privateKey: "gaxi4i58IbaLIz@slxAmKeV}PlS@uLd83jG$XiSRBZphUX@Y0$8$7mFH1c3(uxAJ",
    sandbox: true
)

class GengoFixtures {
    var job1 = GengoJob()
    var job2 = GengoJob()
    
    init() {
        job1.languagePair = GengoLanguagePair(
            source: GengoLanguage(code: "en"),
            target: GengoLanguage(code: "ja"),
            tier: GengoTier.Standard
        )
        job1.sourceText = "Testing Gengo API library calls."
        
        job2.languagePair = GengoLanguagePair(
            source: GengoLanguage(code: "ja"),
            target: GengoLanguage(code: "en"),
            tier: GengoTier.Standard
        )
        job2.sourceText = "API呼出しのテスト"
        job2.slug = "テストslug"
    }
    
    var testJobs: [GengoJob] {
        return [job1, job2]
    }
}

class GengoAccountTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = expectationWithDescription("GengoAccountTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetStats() {
        gengo.getStats() {account, error in
            XCTAssertNil(error)
            XCTAssertLessThan(account.since!.timeIntervalSince1970, NSDate().timeIntervalSince1970)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}

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
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetQuoteText() {
        gengo.getQuoteText(GengoFixtures().testJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(jobs), 0)
            
            // the job order in `jobs` may be different from that in `tests`
            for job in jobs {
                if job.languagePair!.source.code == "ja" {
                    XCTAssertEqual(job.unitCount!, 8)
                } else if job.languagePair!.source.code == "en" {
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
        for (i, job) in enumerate(GengoFixtures().testJobs) {
            var fileJob = GengoJob()
            fileJob.languagePair = job.languagePair
            fileJob.sourceFile = GengoFile(
                data: job.sourceText!.dataUsingEncoding(NSUTF8StringEncoding)!,
                name: "\(i).txt"
            )
            fileJobs.append(fileJob)
        }
        
        for job in fileJobs {
            XCTAssertEqual(job.type!, GengoJobType.File)
        }
        
        gengo.getQuoteFile(fileJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan(countElements(jobs), 0)
            
            // the job order in `jobs` may be different from that in `tests`
            for job in jobs {
                if job.languagePair!.source.code == "ja" {
                    XCTAssertEqual(job.unitCount!, 8)
                } else if job.languagePair!.source.code == "en" {
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
        gengo.createJobs(GengoFixtures().testJobs) {order, error in
            if let e = error {
                if e.code == GengoErrorCode.NotEnoughCredits.rawValue {
                    self.expectation!.fulfill()
                    return
                }
                XCTFail("error is not nil: \(e)")
            }
            
            if let o = order {
                XCTAssertGreaterThanOrEqual(o.id!, 0)
                XCTAssertGreaterThanOrEqual(o.credit!.amount, 0.0 as Float)
                XCTAssertGreaterThanOrEqual(o.jobCount!, 0)
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
        gengo.getJobs([1217482, 1217483]) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual(countElements(jobs), 2)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}

class GengoJobTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = expectationWithDescription("GengoJobTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetJob() {
        let jobID = 1222384
        gengo.getJob(jobID, mt: GengoBool.False) {job, error in
            XCTAssertNil(error)
            if let j = job {
                XCTAssertEqual(j.id!, jobID)
                
                if let order = j.order {
                    XCTAssertGreaterThan(order.id!, 0)
                } else {
                    XCTFail("order is nil")
                }
            } else {
                XCTFail("job is nil")
            }
            
            self.expectation!.fulfill()
        }

        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testPutJob() {
        var feedback = GengoFeedback()
        feedback.rating = 5
        feedback.commentForTranslator = "thank you"
        feedback.commentForGengo = "awesome"
        gengo.putJob(1222396, action: GengoJobAction.Approve(feedback)) {error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testDeleteJob() {
        gengo.deleteJob(1222391) {error in
            XCTAssertNil(error)

            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetRevisions() {
        gengo.getRevisions(1222391) {revisions, error in
            XCTAssertNil(error)
            for revision in revisions {
                XCTAssertGreaterThan(revision.id!, 0)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetRevision() {
        gengo.getRevision(1222106, revisionID: 2569054) {revision, error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetFeedback() {
        gengo.getFeedback(1222396) {feedback, error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testGetComments() {
        gengo.getComments(1222395) {comments, error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testPostComment() {
        gengo.postComment(1222395, comment: "どうも") {error in
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
        gengo.getOrder(321447) {order, error in
            XCTAssertNil(error)
            if let o = order {
                XCTAssertGreaterThan(o.id!, 0)
                XCTAssertGreaterThan(o.jobCount!, 0)
                XCTAssertGreaterThan(o.units!, 0)
                XCTAssertGreaterThan(o.credit!.amount, 0.0 as Float)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
    
    func testDeleteOrder() {
        gengo.deleteOrder(321747) {error in
            XCTAssertNil(error)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectationsWithTimeout(TIMEOUT, nil)
    }
}

class GengoBoolTests: XCTestCase {
    func test() {
        XCTAssertEqual(GengoBool(value: true), GengoBool.True)
        XCTAssertEqual(GengoBool(value: false), GengoBool.False)
        XCTAssertEqual(GengoBool(value: nil), GengoBool.False)
        XCTAssertEqual(GengoBool(value: ""), GengoBool.False)
        XCTAssertEqual(GengoBool(value: "1"), GengoBool.True)
        XCTAssertEqual(GengoBool(value: "0"), GengoBool.False)
        XCTAssertEqual(GengoBool(value: 2), GengoBool.True)
        XCTAssertEqual(GengoBool(value: 1), GengoBool.True)
        XCTAssertEqual(GengoBool(value: 0), GengoBool.False)
        XCTAssertEqual(GengoBool(value: -1), GengoBool.False)
        
        XCTAssertEqual(GengoBool.True.toInt(), 1)
        XCTAssertEqual(GengoBool.False.toInt(), 0)
    }
}
