import XCTest

let TIMEOUT: TimeInterval = 5

class MockURLSession: URLSessionProtocol {
    let sessionDataTask = MockURLSessionDataTask()
    
    let data: Data?
    let urlResponse: URLResponse?
    let error: Error?
    
    init(dataString: String = "{}", statusCode: Int = 200, erred: Bool = false) {
        data = dataString.data(using: String.Encoding.utf8)
        urlResponse = HTTPURLResponse(url: URL(string: "http://example.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        error = erred ? NSError(domain: "\(MockURLSession.self)", code: 0, userInfo: nil) : nil
    }
    
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        DispatchQueue.main.async {
            completionHandler(self.data, self.urlResponse, self.error)
        }
        return self.sessionDataTask
    }
}

class MockURLSessionDataTask: URLSessionDataTaskProtocol {
    private (set) var resumeCalled = 0
    
    func resume() {
        resumeCalled += 1
    }
}

var gengo = Gengo(
    publicKey: "API Key",
    privateKey: "Private Key",
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
        expectation = self.expectation(description: "GengoAccountTests")
    }
    
    func testGetStats() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"user_since\":1420216747,\"credits_spent\":\"0.35\",\"processing\":\"0.00\",\"currency\":\"USD\",\"customer_type\":\"\",\"billing_type\":\"\"}}")
        
        gengo.getStats() {account, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            guard let since = account.since else {
                XCTFail("\(account.since)")
                return
            }
            XCTAssertLessThan(since.timeIntervalSince1970, Date().timeIntervalSince1970)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetBalance() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"credits\":123.45,\"currency\":\"USD\"}}")
        
        gengo.getBalance() {account, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(account.creditPresent, 123.45)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    // http://developers.gengo.com/v2/api_methods/account/#preferred-translators-get
    func testGetPreferredTranslators() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":[{\"translators\":[{\"last_login\":1375824155,\"id\":8596},{\"last_login\":1372822132,\"id\":24123}],\"lc_tgt\":\"ja\",\"lc_src\":\"en\",\"tier\":\"standard\"},{\"translators\":[{\"last_login\":1375825234,\"id\":14765},{\"last_login\":1372822132,\"id\":3627}],\"lc_tgt\":\"en\",\"lc_src\":\"ja\",\"tier\":\"pro\"}]}")
        
        gengo.getPreferredTranslators() {translators, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(translators.count, 4)
            
            for translator in translators {
                guard let id = translator.id else {
                    XCTFail("\(translator.id)")
                    return
                }
                XCTAssertGreaterThan(id, 0)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoServiceTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = self.expectation(description: "GengoServiceTests")
    }
    
    // http://developers.gengo.com/v2/api_methods/service/#languages-get
    func testGetLanguages() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":[{\"unit_type\":\"character\",\"lc\":\"ja\",\"localized_name\":\"日本語\",\"language\":\"Japanese\"},{\"language\":\"English\",\"lc\":\"en\",\"localized_name\":\"English\",\"unit_type\":\"word\"}]}")
        
        gengo.getLanguages() {languages, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(languages.count, 2)
            
            var japanese: GengoLanguage?
            for language in languages {
                if language.code == "ja" {
                    japanese = language
                }
            }
            
            XCTAssertEqual(japanese?.localizedName, "日本語")
            XCTAssertEqual(japanese?.unitType, GengoLanguageUnitType.Character)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetLanguagePairs() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":[{\"lc_src\":\"ja\",\"lc_tgt\":\"en\",\"tier\":\"standard\",\"unit_price\":\"0.0300\",\"currency\":\"USD\"},{\"lc_src\":\"ja\",\"lc_tgt\":\"en\",\"tier\":\"pro\",\"unit_price\":\"0.0700\",\"currency\":\"USD\"}]}")
        
        gengo.getLanguagePairs(GengoLanguage(code: "ja")) {pairs, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(pairs.count, 2)
            
            for pair in pairs {
                if pair.source.code != "ja" {
                    XCTFail("invalid language code: \(pair.source.code)")
                }
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetQuoteText() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"jobs\":{\"job_2\":{\"unit_count\":8,\"credits\":0.24,\"eta\":15300,\"currency\":\"USD\",\"type\":\"text\",\"lc_src_detected\":\"ja\"},\"job_1\":{\"unit_count\":5,\"credits\":0.35,\"eta\":15300,\"currency\":\"USD\",\"type\":\"text\",\"lc_src_detected\":\"\"}}}}")
        
        gengo.getQuoteText(GengoFixtures().testJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(jobs.count, 2)
            
            for job in jobs {
                if job.languagePair?.source.code == "ja" {
                    XCTAssertEqual(job.unitCount, 8)
                    XCTAssertEqual(job.credit?.amount, 0.24)
                } else if job.languagePair?.source.code == "en" {
                    XCTAssertEqual(job.unitCount, 5)
                    XCTAssertEqual(job.credit?.amount, 0.35)
                } else {
                    XCTFail("invalid source language")
                }
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetQuoteFile() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"jobs\":{\"job_2\":{\"unit_count\":8,\"credits\":\"0.24\",\"eta\":15300,\"currency\":\"USD\",\"identifier\":\"a5c8c325acf1db7c16966e7cab774cfaac26a87c86ffef6c8cd8e890ca013cef\",\"type\":\"file\",\"lc_src\":\"ja\",\"lc_src_detected\":\"ja\"},\"job_1\":{\"unit_count\":5,\"credits\":\"0.35\",\"eta\":15300,\"currency\":\"USD\",\"identifier\":\"723867e303c66d46ebb60bbf46bec56aec474fa20a0c20f4b9bda908c8274377\",\"type\":\"file\",\"lc_src\":\"en\",\"lc_src_detected\":\"\"}}}}")
        
        var fileJobs: [GengoJob] = []
        for (i, job) in GengoFixtures().testJobs.enumerated() {
            var fileJob = GengoJob()
            fileJob.languagePair = job.languagePair
            fileJob.sourceFile = GengoFile(
                data: job.sourceText!.data(using: String.Encoding.utf8)!,
                name: "\(i).txt"
            )
            fileJobs.append(fileJob)
        }
        
        gengo.getQuoteFile(fileJobs) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(jobs.count, 2)
            
            for job in jobs {
                if job.languagePair?.source.code == "ja" {
                    XCTAssertEqual(job.unitCount, 8)
                    XCTAssertEqual(job.credit?.amount, 0.24)
                } else if job.languagePair?.source.code == "en" {
                    XCTAssertEqual(job.unitCount, 5)
                    XCTAssertEqual(job.credit?.amount, 0.35)
                } else {
                    XCTFail("invalid source language")
                }
                
                guard let identifier = job.identifier else {
                    XCTFail("\(job.identifier)")
                    return
                }
                XCTAssertFalse(identifier.isEmpty)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoJobsTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = self.expectation(description: "GengoJobsTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCreateJobs() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"order_id\":65465,\"job_count\":2,\"credits_used\":\"0.59\",\"currency\":\"USD\"}}")
        
        gengo.createJobs(GengoFixtures().testJobs) {order, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(order?.id, 65465)
            XCTAssertEqual(order?.credit?.amount, 0.59)
            XCTAssertEqual(order?.jobCount, 2)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetJobsWithParameters() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":[{\"ctime\":1483701101,\"job_id\":\"659079\"}]}")
        
        gengo.getJobs(["count": 1]) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(jobs.count, 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetJobsWithIDs() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"jobs\":[{\"job_id\":\"659080\",\"order_id\":\"65465\",\"body_src\":\"TestingGengoAPIlibrarycalls.\",\"slug\":\"TestingGengoA...\",\"lc_src\":\"en\",\"lc_tgt\":\"ja\",\"unit_count\":\"5\",\"tier\":\"standard\",\"credits\":\"0.35\",\"currency\":\"USD\",\"status\":\"available\",\"eta\":15300,\"ctime\":1483701101,\"auto_approve\":\"0\",\"position\":0},{\"job_id\":\"659079\",\"order_id\":\"65465\",\"body_src\":\"API呼出しのテスト\",\"slug\":\"テストslug\",\"lc_src\":\"ja\",\"lc_tgt\":\"en\",\"unit_count\":\"8\",\"tier\":\"standard\",\"credits\":\"0.24\",\"currency\":\"USD\",\"status\":\"available\",\"eta\":15300,\"ctime\":1483701101,\"auto_approve\":\"0\",\"position\":0}]}}")
        
        gengo.getJobs([659080, 659079]) {jobs, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(jobs.count, 2)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoJobTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = self.expectation(description: "GengoJobTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetJob() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"job\":{\"job_id\":\"659079\",\"order_id\":\"65465\",\"slug\":\"テストslug\",\"body_src\":\"API呼出しのテスト\",\"lc_src\":\"ja\",\"lc_tgt\":\"en\",\"unit_count\":\"8\",\"tier\":\"standard\",\"credits\":\"0.24\",\"currency\":\"USD\",\"status\":\"available\",\"eta\":15300,\"ctime\":1483701101,\"auto_approve\":\"0\"}}}")
        
        gengo.getJob(659079, mt: GengoBool.false) {job, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(job?.id, 659079)
            XCTAssertEqual(job?.order?.id, 65465)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testPutJob() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{}}")
        
        var feedback = GengoFeedback()
        feedback.rating = 5
        feedback.commentForTranslator = "thank you"
        feedback.commentForGengo = "awesome"
        
        gengo.putJob(659573, action: GengoJobAction.approve(feedback)) {error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testDeleteJob() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{}}")
        
        gengo.deleteJob(659645) {error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetRevisions() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"job_id\":\"659415\",\"revisions\":[{\"ctime\":1483852599,\"rev_id\":\"1438747\"}]}}")
        
        gengo.getRevisions(659415) {revisions, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(revisions.count, 1)
            
            for revision in revisions {
                guard let id = revision.id else {
                    XCTFail("\(revision.id)")
                    return
                }
                XCTAssertGreaterThan(id, 0)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetRevision() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"revision\":{\"ctime\":1483852599,\"body_tgt\":\"Testing API calls\"}}}")
        
        gengo.getRevision(659415, revisionID: 1438747) {revision, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertNotNil(revision?.body)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testGetFeedback() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"feedback\":{\"rating\":\"0.0\",\"for_translator\":null}}}")
        
        gengo.getFeedback(659412) {feedback, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertNotNil(feedback)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testPostComment() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{}}")
        
        gengo.postComment(659573, comment: "どうも") {error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    // http://developers.gengo.com/v2/api_methods/job/#comments-get
    func testGetComments() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"thread\":[{\"body\":\"....\",\"author\":\"translator\",\"ctime\":1266322028},{\"body\":\"....\",\"author\":\"customer\",\"ctime\":1266324432}]}}")
        
        gengo.getComments(659573) {comments, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(comments.count, 2)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoOrderTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = self.expectation(description: "GengoOrderTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGetOrder() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"order\":{\"order_id\":\"65642\",\"total_credits\":\"0.59\",\"total_units\":\"13\",\"currency\":\"USD\",\"jobs_available\":[\"659572\",\"659573\"],\"jobs_pending\":[],\"jobs_reviewable\":[],\"jobs_approved\":[],\"jobs_revising\":[],\"jobs_queued\":\"0\",\"total_jobs\":\"2\"}}}")
        
        gengo.getOrder(65642) {order, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(order?.id, 65642)
            XCTAssertEqual(order?.jobCount, 2)
            XCTAssertEqual(order?.credit?.amount, 0.59)
            XCTAssertEqual(order?.units, 13)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    func testDeleteOrder() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{}}")
        
        gengo.deleteOrder(65642) {error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoGlossaryTests: XCTestCase {
    var expectation: XCTestExpectation?
    
    override func setUp() {
        super.setUp()
        expectation = self.expectation(description: "GengoGlossaryTests")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // http://developers.gengo.com/v2/api_methods/glossary/#glossaries-get
    func testGetGlossaries() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":[{\"customer_user_id\":50110,\"source_language_id\":8,\"target_languages\":[[14,\"ja\"]],\"id\":115,\"is_public\":false,\"unit_count\":2,\"description\":null,\"source_language_code\":\"en-US\",\"title\":\"1342666627_50110_en_ja_glossary.csv\",\"status\":1}]}")
        
        gengo.getGlossaries() {glossaries, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(glossaries.count, 1)
            
            for glossary in glossaries {
                guard let id = glossary.id else {
                    XCTFail("\(glossary.id)")
                    return
                }
                XCTAssertGreaterThan(id, 0)
            }
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
    
    // http://developers.gengo.com/v2/api_methods/glossary/#glossary-get
    func testGetGlossary() {
        gengo.urlSession = MockURLSession(dataString: "{\"opstat\":\"ok\",\"response\":{\"customer_user_id\":50110,\"source_language_id\":8,\"target_languages\":[[14,\"ja\"]],\"id\":115,\"is_public\":false,\"unit_count\":2,\"description\":null,\"source_language_code\":\"en-US\",\"title\":\"1342666627_50110_en_ja_glossary.csv\",\"status\":1}}")
        
        gengo.getGlossary(0) {glossary, error in
            XCTAssertNil(error)
            XCTAssertEqual((gengo.urlSession as? MockURLSession)?.sessionDataTask.resumeCalled, 1)
            
            XCTAssertEqual(glossary?.id, 115)
            
            self.expectation!.fulfill()
        }
        
        waitForExpectations(timeout: TIMEOUT, handler: nil)
    }
}

class GengoConvertPrimitiveTests: XCTestCase {
    func testToInt() {
        XCTAssertEqual(Gengo.toInt(1), 1)
        XCTAssertEqual(Gengo.toInt("1"), 1)
        XCTAssertEqual(Gengo.toInt("0"), 0)
        XCTAssertEqual(Gengo.toInt(1.8 as Float), 1)
        XCTAssertEqual(Gengo.toInt(1.8 as Double), 1)
        XCTAssertEqual(Gengo.toInt(true), 1)
        XCTAssertEqual(Gengo.toInt(false), 0)
        
        XCTAssertNil(Gengo.toInt(""))
        XCTAssertNil(Gengo.toInt("a"))
        XCTAssertNil(Gengo.toInt(nil))
    }
    
    func testToFloat() {
        XCTAssertEqual(Gengo.toFloat(1.8 as Float), 1.8)
        XCTAssertEqual(Gengo.toFloat(1.8 as Double), 1.8)
        XCTAssertEqual(Gengo.toFloat(1 as Int), 1.0)
        XCTAssertEqual(Gengo.toFloat("1.8"), 1.8)
        XCTAssertEqual(Gengo.toFloat("1"), 1.0)
        XCTAssertEqual(Gengo.toFloat(true), 1.0)
        XCTAssertEqual(Gengo.toFloat(false), 0.0)
        
        XCTAssertNil(Gengo.toFloat(""))
        XCTAssertNil(Gengo.toFloat("a"))
        XCTAssertNil(Gengo.toFloat(nil))
    }
    
    func testToDate() {
        XCTAssertEqual(Gengo.toDate("1")!, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(Gengo.toDate(1)!, Date(timeIntervalSince1970: 1))
        
        XCTAssertNil(Gengo.toDate(""))
        XCTAssertNil(Gengo.toDate("a"))
        XCTAssertNil(Gengo.toDate(nil))
    }
}

class GengoErrorTests: XCTestCase {
    func test() {
        struct Test {
            let data: Data?
            let response: URLResponse?
            let error: Error?
            let expectNil: Bool
        }

        let tests: [Test] = [
            Test(data: nil, response: nil, error: nil, expectNil: false),
            Test(
                data: nil,
                response: HTTPURLResponse(
                    url: URL(string: "http://example.com")!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil,
                expectNil: false
            ),
            Test(
                data: "{\"opstat\": \"ok\"}".data(using: String.Encoding.utf8),
                response: HTTPURLResponse(
                    url: URL(string: "http://example.com")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                ),
                error: nil,
                expectNil: true
            ),
        ]

        for test in tests {
            let gengoError = Gengo.toError(
                data: test.data,
                response: test.response,
                error: test.error
            )
            XCTAssertTrue((gengoError == nil) == test.expectNil)
        }
    }
}

class GengoBoolTests: XCTestCase {
    func test() {
        XCTAssertEqual(GengoBool(value: true), GengoBool.true)
        XCTAssertEqual(GengoBool(value: false), GengoBool.false)
        XCTAssertEqual(GengoBool(value: nil), GengoBool.false)
        XCTAssertEqual(GengoBool(value: ""), GengoBool.false)
        XCTAssertEqual(GengoBool(value: "1"), GengoBool.true)
        XCTAssertEqual(GengoBool(value: "0"), GengoBool.false)
        XCTAssertEqual(GengoBool(value: 2), GengoBool.true)
        XCTAssertEqual(GengoBool(value: 1), GengoBool.true)
        XCTAssertEqual(GengoBool(value: 0), GengoBool.false)
        XCTAssertEqual(GengoBool(value: -1), GengoBool.false)
        
        XCTAssertEqual(GengoBool.true.toInt(), 1)
        XCTAssertEqual(GengoBool.false.toInt(), 0)
        
        XCTAssertTrue(GengoBool.true.boolValue)
        XCTAssertFalse(GengoBool.false.boolValue)
        
        XCTAssert(true == GengoBool.true)
        XCTAssert(true != GengoBool.false)
        XCTAssert(false == GengoBool.false)
        XCTAssert(false != GengoBool.true)
        XCTAssert(GengoBool.true == true)
        XCTAssert(GengoBool.true != false)
        XCTAssert(GengoBool.false == false)
        XCTAssert(GengoBool.false != true)
        
        XCTAssertFalse(true == GengoBool.false)
        XCTAssertFalse(true != GengoBool.true)
        XCTAssertFalse(false == GengoBool.true)
        XCTAssertFalse(false != GengoBool.false)
        XCTAssertFalse(GengoBool.true == false)
        XCTAssertFalse(GengoBool.true != true)
        XCTAssertFalse(GengoBool.false == true)
        XCTAssertFalse(GengoBool.false != false)
        
        XCTAssertTrue(Bool(GengoBool.true))
        XCTAssertFalse(Bool(GengoBool.false))
    }
}
