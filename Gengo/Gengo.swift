import Foundation
import MobileCoreServices

open class Gengo {
    let publicKey: String
    let privateKey: String
    let apiHost: String
    
    init(publicKey: String, privateKey: String, sandbox: Bool = false) {
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.apiHost = sandbox ? "http://api.sandbox.gengo.com/v2/" : "https://api.gengo.com/v2/"
    }
}

// utilities
extension Gengo {
    class func toInt(_ value: Any?) -> Int? {
        if let i = value as? Int {
            return i
        } else if let s = value as? String {
            if let i = Int(s) {
                return i
            }
        }
        return nil
    }
    
    class func toFloat(_ value: Any?) -> Float? {
        if let f = value as? Float {
            return f
        } else if let s = value as? NSString {
            return s.floatValue
        }
        return nil
    }
    
    class func toDate(_ value: Any?) -> Date? {
        if let i = toInt(value) {
            return Date(timeIntervalSince1970: Double(i))
        }
        return nil
    }
}

public enum GengoErrorCode: Int {
    case notEnoughCredits = 2700
}

open class GengoError: NSError {
    init?(optionalData: Data?, optionalResponse: URLResponse?, optionalError: NSError?) {
        let GENGO_DOMAIN = "com.gengo.api"
        
        var instance: NSError?
        
        if let error = optionalError {
            instance = error
        }
        
        if let response = optionalResponse {
            if let httpResponse = response as? HTTPURLResponse {
                let code = httpResponse.statusCode
                if code < 200 || 300 <= code {
                    var userInfo: [AnyHashable: Any] = ["message": HTTPURLResponse.localizedString(forStatusCode: code)]
                    if let i = instance {
                        userInfo[NSUnderlyingErrorKey] = i
                    }
                    instance = NSError(domain: GENGO_DOMAIN, code: code, userInfo: userInfo)
                }
            }
        }
        
        if let data = optionalData {
            if let json = (try? JSONSerialization.jsonObject(
                with: data,
                options: JSONSerialization.ReadingOptions.mutableContainers)) as? [String: AnyObject] {
                    var isOK = false
                    var code: Int?
                    var message: String?
                    if let opstat = json["opstat"] as? String {
                        if opstat == "ok" {
                            isOK = true
                        } else {
                            if let err = json["err"] as? [String: AnyObject] {
                                code = err["code"] as? Int
                                message = err["msg"] as? String
                            }
                        }
                    }
                    if !isOK {
                        var userInfo: [AnyHashable: Any] = ["message": (message == nil) ? "operation failed" : message!]
                        if let i = instance {
                            userInfo[NSUnderlyingErrorKey] = i
                        }
                        instance = NSError(domain: GENGO_DOMAIN, code: (code == nil) ? 0 : code!, userInfo: userInfo)
                    }
            }
        }
        
        if let i = instance {
            super.init(domain: i.domain, code: i.code, userInfo: i.userInfo)
        } else {
            // only to avoid "All stored properties of a class instance must be initialized before returning nil"
            super.init(domain: "", code: 0, userInfo: nil)
            return nil
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Account methods
extension Gengo {
    func getStats(_ callback: @escaping (GengoAccount, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "account/stats")
        request.access() {result, error in
            var account = GengoAccount()
            if let accountDictionary = result as? [String: AnyObject] {
                account = Gengo.toAccount(accountDictionary)
            }
            callback(account, error)
        }
    }
    
    func getBalance(_ callback: @escaping (GengoAccount, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "account/balance")
        request.access() {result, error in
            var account = GengoAccount()
            if let accountDictionary = result as? [String: AnyObject] {
                account = Gengo.toAccount(accountDictionary)
            }
            
            callback(account, error)
        }
    }
    
    func getPreferredTranslators(_ callback: @escaping ([GengoTranslator], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "account/preferred_translators")
        request.access() {result, error in
            var translators: [GengoTranslator] = []
            if let unwrappedResult = result as? [[String: AnyObject]] {
                for json in unwrappedResult {
                    let languagePair = Gengo.toLanguagePair(json)
                    
                    if let translatorArray = json["translators"] as? [[String: AnyObject]] {
                        for translatorDictionary in translatorArray {
                            var translator = GengoTranslator()
                            translator.id = Gengo.toInt(translatorDictionary["id"])
                            translator.jobCount = Gengo.toInt(translatorDictionary["number_of_jobs"])
                            translator.languagePair = languagePair
                            translators.append(translator)
                        }
                    }
                }
            }
            
            callback(translators, error)
        }
    }
}

// Service methods
extension Gengo {
    func getLanguages(_ callback: @escaping ([GengoLanguage], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/service/languages")
        request.access() {result, error in
            var languages: [GengoLanguage] = []
            if let unwrappedResult = result as? [[String: AnyObject]] {
                for language in unwrappedResult {
                    if let code = language["lc"] as? String, let unitType = language["unit_type"] as? String {
                        languages.append(GengoLanguage(
                            code: code,
                            name: language["language"] as? String,
                            localizedName: language["localized_name"] as? String,
                            unitType: GengoLanguageUnitType(rawValue: unitType)
                        ))
                    }
                }
            }
            callback(languages, error)
        }
    }
    
    func getLanguagePairs(_ source: GengoLanguage? = nil, callback: @escaping ([GengoLanguagePair], NSError?) -> ()) {
        var query: [String: AnyObject] = [:]
        if let src = source {
            query["lc_src"] = src.code as AnyObject?
        }
        
        let request = GengoGet(gengo: self, endpoint: "translate/service/language_pairs", query: query)
        request.access() {result, error in
            var pairs: [GengoLanguagePair] = []
            if let unwrappedResult = result as? [[String: AnyObject]] {
                for pair in unwrappedResult {
                    if let p = Gengo.toLanguagePair(pair) {
                        pairs.append(p)
                    }
                }
            }
            callback(pairs, error)
        }
    }
    
    func getQuoteText(_ jobs: [GengoJob], callback: @escaping ([GengoJob], NSError?) -> ()) {
        getQuote("translate/service/quote", jobs: jobs, callback: callback)
    }
    
    func getQuoteFile(_ jobs: [GengoJob], callback: @escaping ([GengoJob], NSError?) -> ()) {
        getQuote("translate/service/quote/file", jobs: jobs, callback: callback)
    }
    
    fileprivate func getQuote(_ endpoint: String, jobs: [GengoJob], callback: @escaping ([GengoJob], NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        var files: [String: GengoFile] = [:]
        for (index, job) in jobs.enumerated() {
            if job.languagePair == nil {
                continue
            }
            if job.type == nil {
                continue
            }
            let job_key = "job_\(index + 1)"
            jobsDictionary[job_key] = [
                "lc_src": job.languagePair!.source.code as AnyObject,
                "lc_tgt": job.languagePair!.target.code as AnyObject,
                "tier": job.languagePair!.tier.rawValue as AnyObject,
                "type": job.type!.rawValue as AnyObject,
            ]
            if (job.type == GengoJobType.File) {
                let file_key = "file_\(index + 1)"
                _ = jobsDictionary[job_key]?.updateValue(file_key as AnyObject, forKey: "file_key")
                files[file_key] = job.sourceFile
            } else {
                if let sourceText = job.sourceText {
                    _ = jobsDictionary[job_key]?.updateValue(sourceText as AnyObject, forKey: "body_src")
                }
            }
        }
        let body = ["jobs": jobsDictionary]
        
        let request = GengoUpload(gengo: self, endpoint: endpoint, body: body as [String : AnyObject], files: files)
        request.access() {result, error in
            callback(self.fillJobs(jobs, result: result), error)
        }
    }
    
    // jobs are passed by value
    fileprivate func fillJobs(_ jobs: [GengoJob], result: AnyObject?) -> [GengoJob] {
        var jobArray: [GengoJob] = []
        if let unwrappedResult = result as? [String: AnyObject] {
            if let unwrappedJobs = unwrappedResult["jobs"] as? [String: [String : AnyObject]] {
                for (key, jobDictionary) in unwrappedJobs {
                    // "job_3" -> ["job", "3"] -> "3" -> 3 -> 2
                    let i = Int(key.characters.split(whereSeparator: {$0 == "_"}).map { String($0) }[1])! - 1
                    var job = jobs[i]
                    job.credit = Gengo.toMoney(jobDictionary)
                    job.eta = Gengo.toInt(jobDictionary["eta"])
                    job.unitCount = Gengo.toInt(jobDictionary["unit_count"])
                    job.identifier = jobDictionary["identifier"] as? String
                    if job.slug == nil {
                        job.slug = jobDictionary["title"] as? String
                    }
                    
                    jobArray.append(job)
                }
            }
        }
        
        return jobArray
    }
}

// Jobs methods
extension Gengo {
    /// Posts GengoJobs.
    ///
    /// - returns: Nothing, but calls the callback. If both of the GengoOrder and the NSError are nil, it is probably that all the jobs are old.
    func createJobs(_ jobs: [GengoJob], callback: @escaping (GengoOrder?, NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        for (index, job) in jobs.enumerated() {
            if job.type == nil {
                continue
            }
            if job.languagePair == nil {
                continue
            }
            let jobDictionary: [String: AnyObject?] = [
                "type": job.type!.rawValue as Optional<AnyObject>,
                "slug": job.slug as Optional<AnyObject>,
                "body_src": job.sourceText as Optional<AnyObject>,
                "lc_src": job.languagePair!.source.code as Optional<AnyObject>,
                "lc_tgt": job.languagePair!.target.code as Optional<AnyObject>,
                "tier": job.languagePair!.tier.rawValue as Optional<AnyObject>,
                "identifier": job.identifier as Optional<AnyObject>,
                "auto_approve": job.autoApprove?.toInt(),
                "comment": job.comment,
                "custom_data": job.customData,
                "force": job.force?.toInt(),
                "use_preferred": job.usePreferred?.toInt(),
                "position": job.position,
                "purpose": job.purpose,
                "tone": job.tone,
                "callback_url": job.callbackURL,
                "max_chars": job.maxChars,
                "as_group": job.asGroup?.toInt()
            ]
            
            // pick up and unwrap Optional.Some values
            let sequence = "job_\(index + 1)"
            jobsDictionary[sequence] = [:]
            for (k, v) in jobDictionary {
                if let value: AnyObject = v {
                    jobsDictionary[sequence]![k] = value
                }
            }
        }
        let body = ["jobs": jobsDictionary]
        
        let request = GengoPost(gengo: self, endpoint: "translate/jobs", body: body as [String : AnyObject])
        request.access() {result, error in
            var order: GengoOrder? = nil
            if let orderDictionary = result as? [String: AnyObject] {
                if orderDictionary["order_id"] != nil {
                    order = Gengo.toOrder(orderDictionary)
                }
            }
            callback(order, error)
        }
    }
    
    /// - parameter parameters["status"]:: GengoJobStatus
    /// - parameter parameters["after"]:: NSDate or Int
    /// - parameter parameters["count"]:: Int
    func getJobs(_ parameters: [String: Any] = [:], callback: @escaping ([GengoJob], NSError?) -> ()) {
        var q: [String: AnyObject] = [:]
        if let status = parameters["status"] as? GengoJobStatus {
            q["status"] = status.rawValue as AnyObject?
        }
        if let date = parameters["after"] as? Date {
            q["timestamp_after"] = Int(date.timeIntervalSince1970) as AnyObject?
        } else if let int = parameters["after"] as? Int {
            q["timestamp_after"] = int as AnyObject?
        }
        if let count = parameters["count"] as? Int {
            q["count"] = count as AnyObject?
        }
        
        let request = GengoGet(gengo: self, endpoint: "translate/jobs", query: q)
        request.access() {result, error in
            var jobs: [GengoJob] = []
            if let unwrappedJobs = result as? [[String: AnyObject]] {
                for job in unwrappedJobs {
                    jobs.append(Gengo.toJob(job))
                }
            }
            
            callback(jobs, error)
        }
    }
    
    func getJobs(_ ids: [Int], callback: @escaping ([GengoJob], NSError?) -> ()) {
        var stringIDs: [String] = []
        for id in ids {
            stringIDs.append(String(id))
        }
        let joinedIDs = stringIDs.joined(separator: ",")
        
        let request = GengoGet(gengo: self, endpoint: "translate/jobs/\(joinedIDs)")
        request.access() {result, error in
            var jobs: [GengoJob] = []
            if let unwrappedResult = result as? [String: AnyObject] {
                if let unwrappedJobs = unwrappedResult["jobs"] as? [[String: AnyObject]] {
                    for job in unwrappedJobs {
                        jobs.append(Gengo.toJob(job))
                    }
                }
            }
            
            callback(jobs, error)
        }
    }
}

// Job methods
extension Gengo {
    func getJob(_ id: Int, mt: GengoBool, callback: @escaping (GengoJob?, NSError?) -> ()) {
        let query = ["pre_mt": mt.toInt()]
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(id)", query: query as [String : AnyObject])
        request.access() {result, error in
            var job: GengoJob?
            if let unwrappedResult = result as? [String: AnyObject] {
                if let jobDictionary = unwrappedResult["job"] as? [String: AnyObject] {
                    job = Gengo.toJob(jobDictionary)
                }
            }
            
            callback(job, error)
        }
    }
    
    func putJob(_ id: Int, action: GengoJobAction, callback: @escaping (NSError?) -> ()) {
        var body: [String: AnyObject] = [:]
        
        switch action {
        case .revise(let comment):
            body = ["action": "revise" as AnyObject, "comment": comment as AnyObject]
        case .approve(let feedback):
            body = ["action": "approve" as AnyObject]
            if let rating = feedback.rating {
                body["rating"] = rating as AnyObject?
            }
            if let commentForTranslator = feedback.commentForTranslator {
                body["for_translator"] = commentForTranslator as AnyObject?
            }
            if let commentForGengo = feedback.commentForGengo {
                body["for_mygengo"] = commentForGengo as AnyObject?
            }
            if let isPublic = feedback.isPublic {
                body["public"] = isPublic.toInt() as AnyObject?
            }
        case .reject(let reason, let comment, let captcha, let followUp):
            body["action"] = "reject" as AnyObject?
            body["reason"] = reason.rawValue as AnyObject?
            body["comment"] = comment as AnyObject?
            body["captcha"] = captcha as AnyObject?
            body["follow_up"] = followUp.rawValue as AnyObject?
        }
        
        let request = GengoPut(gengo: self, endpoint: "translate/job/\(id)", body: body)
        request.access() {result, error in
            callback(error)
        }
    }
    
    func deleteJob(_ id: Int, callback: @escaping (NSError?) -> ()) {
        let request = GengoDelete(gengo: self, endpoint: "translate/job/\(id)")
        request.access() {result, error in
            callback(error)
        }
    }
    
    func getRevisions(_ jobID: Int, callback: @escaping ([GengoRevision], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(jobID)/revisions")
        request.access() {result, error in
            var revisions: [GengoRevision] = []
            if let unwrappedResult = result as? [String: AnyObject] {
                if let revisionsArray = unwrappedResult["revisions"] as? [[String: AnyObject]] {
                    for revision in revisionsArray {
                        revisions.append(Gengo.toRevision(revision))
                    }
                }
            }
            
            callback(revisions, error)
        }
    }
    
    func getRevision(_ jobID: Int, revisionID: Int, callback: @escaping (GengoRevision?, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(jobID)/revision/\(revisionID)")
        request.access() {result, error in
            var revision: GengoRevision?
            if let unwrappedResult = result as? [String: AnyObject] {
                if let revisionDictionary = unwrappedResult["revision"] as? [String: AnyObject] {
                    revision = Gengo.toRevision(revisionDictionary)
                }
            }
            
            callback(revision, error)
        }
    }
    
    func getFeedback(_ jobID: Int, callback: @escaping (GengoFeedback?, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(jobID)/feedback")
        request.access() {result, error in
            var feedback: GengoFeedback?
            if let unwrappedResult = result as? [String: AnyObject] {
                if let feedbackDictionary = unwrappedResult["feedback"] as? [String: AnyObject] {
                    feedback = GengoFeedback()
                    feedback?.rating = Gengo.toInt(feedbackDictionary["rating"])
                    feedback?.commentForTranslator = feedbackDictionary["for_translator"] as? String
                }
            }
            
            callback(feedback, error)
        }
    }
    
    func getComments(_ jobID: Int, callback: @escaping ([GengoComment], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(jobID)/comments")
        request.access() {result, error in
            var comments: [GengoComment] = []
            if let unwrappedResult = result as? [String: AnyObject] {
                if let commentsArray = unwrappedResult["thread"] as? [[String: AnyObject]] {
                    for commentDictionary in commentsArray {
                        var comment = GengoComment()
                        comment.body = commentDictionary["body"] as? String
                        if let author = commentDictionary["author"] as? String {
                            comment.author = GengoComment.Author(rawValue: author)
                        }
                        comment.createdTime = Gengo.toDate(commentDictionary["ctime"])
                        
                        comments.append(comment)
                    }
                }
            }

            callback(comments, error)
        }
    }
    
    func postComment(_ jobID: Int, comment: String, callback: @escaping (NSError?) -> ()) {
        let body = ["body": comment]
        let request = GengoPost(gengo: self, endpoint: "translate/job/\(jobID)/comment", body: body as [String : AnyObject])
        request.access() {result, error in
            callback(error)
        }
    }
}

// Order methods
extension Gengo {
    func getOrder(_ id: Int, callback: @escaping (GengoOrder?, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/order/\(id)")
        request.access() {result, error in
            var order: GengoOrder? = nil
            if let unwrappedResult = result as? [String: AnyObject] {
                if let orderDictionary = unwrappedResult["order"] as? [String: AnyObject] {
                    order = Gengo.toOrder(orderDictionary)
                }
            }
            
            callback(order, error)
        }
    }

    func deleteOrder(_ id: Int, callback: @escaping (NSError?) -> ()) {
        let request = GengoDelete(gengo: self, endpoint: "translate/order/\(id)")
        request.access() {result, error in
            callback(error)
        }
    }
}

// Glossary methods
extension Gengo {
    func getGlossaries(_ callback: @escaping ([GengoGlossary], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/glossary")
        request.access() {result, error in
            var glossaries: [GengoGlossary] = []
            if let glossaryArray = result as? [[String: AnyObject]] {
                for glossaryDictionary in glossaryArray {
                    glossaries.append(Gengo.toGlossary(glossaryDictionary))
                }
            }
            
            callback(glossaries, error)
        }
    }
    
    func getGlossary(_ id: Int, callback: @escaping (GengoGlossary?, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/glossary/\(id)")
        request.access() {result, error in
            var glossary: GengoGlossary?
            if let glossaryDictionary = result as? [String: AnyObject] {
                if let _ = glossaryDictionary["id"] as? Int {
                    glossary = Gengo.toGlossary(glossaryDictionary)
                }
            }

            callback(glossary, error)
        }
    }
}

// JSON to object
extension Gengo {
    fileprivate class func toLanguagePair(_ json: [String: AnyObject]) -> GengoLanguagePair? {
        let price: GengoMoney? = toMoney(json)
        
        var languagePair: GengoLanguagePair?
        if let src = json["lc_src"] as? String, let tgt = json["lc_tgt"] as? String {
            if let tierString = json["tier"] as? String {
                if let tier = GengoTier(rawValue: tierString) {
                    languagePair = GengoLanguagePair(
                        source: GengoLanguage(code: src),
                        target: GengoLanguage(code: tgt),
                        tier: tier,
                        price: price
                    )
                }
            }
        }
        
        return languagePair
    }
    
    fileprivate class func toMoney(_ json: [String: AnyObject]) -> GengoMoney? {
        var money: GengoMoney?
        
        var amount = toFloat(json["credits"])
        if amount == nil {
            amount = toFloat(json["credits_used"])
        }
        if amount == nil {
            amount = toFloat(json["total_credits"])
        }
        if amount == nil {
            return money
        }

        if let currencyString = json["currency"] as? String {
            if let currency = GengoCurrency(rawValue: currencyString) {
                money = GengoMoney(
                    amount: amount!,
                    currency: currency
                )
            }
        }
        
        return money
    }
    
    fileprivate class func toJob(_ json: [String: AnyObject]) -> GengoJob {
        var job = GengoJob()
        
        job.languagePair = toLanguagePair(json)
        job.sourceText = json["body_src"] as? String
        job.autoApprove = GengoBool(value: json["auto_approve"])
        job.credit = toMoney(json)
        job.eta = toInt(json["eta"])
        job.id = toInt(json["job_id"])
        job.order = GengoOrder()
        job.order!.id = toInt(json["order_id"])
        job.slug = json["slug"] as? String
        if let status = json["status"] as? String {
            job.status = GengoJobStatus(rawValue: status)
        }
        job.unitCount = toInt(json["unit_count"])
        job.createdTime = toDate(json["ctime"])
        
        return job
    }

    fileprivate class func toRevision(_ json: [String: AnyObject]) -> GengoRevision {
        var revision = GengoRevision()

        revision.id = Gengo.toInt(json["rev_id"])
        if let body = json["body_tgt"] as? String {
            revision.body = body
        }
        revision.createdTime = Gengo.toDate(json["ctime"])
        
        return revision
    }
    
    fileprivate class func toOrder(_ json: [String: AnyObject]) -> GengoOrder {
        var order = GengoOrder()
        order.id = toInt(json["order_id"])
        order.credit = toMoney(json)
        if let count = toInt(json["job_count"]) {
            order.jobCount = count
        } else if let count = toInt(json["total_jobs"]) {
            order.jobCount = count
        }
        order.asGroup = GengoBool(value: json["as_group"])
        order.units = toInt(json["total_units"])

        return order
    }
    
    fileprivate class func toAccount(_ json: [String: AnyObject]) -> GengoAccount {
        var account = GengoAccount()
        
        account.creditSpent = Gengo.toFloat(json["credits_spent"])
        account.creditPresent = Gengo.toFloat(json["credits"])
        if let currency = json["currency"] as? String {
            account.currency = GengoCurrency(rawValue: currency)
        }
        account.since = Gengo.toDate(json["user_since"])
        
        return account
    }
    
    fileprivate class func toGlossary(_ json: [String: AnyObject]) -> GengoGlossary {
        var glossary = GengoGlossary()
        
        glossary.id = Gengo.toInt(json["id"])
        if let source = json["source_language_code"] as? String {
            glossary.sourceLanguage = GengoLanguage(code: source)
        }
        var targets: [GengoLanguage] = []
        if let targetArray = json["target_languages"] as? [[AnyObject]] {
            for target in targetArray {
                if target.count >= 2 {
                    if let code = target[1] as? String {
                        targets.append(GengoLanguage(code: code))
                    }
                }
            }
        }
        glossary.targetLanguages = targets
        glossary.isPublic = GengoBool(value: json["is_public"])
        glossary.unitCount = Gengo.toInt(json["unit_count"])
        glossary.description = json["description"] as? String
        glossary.title = json["title"] as? String
        glossary.status = Gengo.toInt(json["status"])
        glossary.createdTime = Gengo.toDate(json["ctime"])
        
        return glossary
    }
}

// enums and structs

public enum GengoLanguageUnitType: String {
    case Word = "word"
    case Character = "character"
}

public struct GengoLanguage: CustomStringConvertible {
    let code: String
    let name: String?
    let localizedName: String?
    let unitType: GengoLanguageUnitType?
    
    init(code: String, name: String? = nil, localizedName: String? = nil, unitType: GengoLanguageUnitType? = nil) {
        self.code = code
        self.name = name
        self.localizedName = localizedName
        self.unitType = unitType
    }
    
    public var description: String {
        return (name == nil) ? code : name!
    }
}

public enum GengoTier: String, CustomStringConvertible {
    case Standard = "standard"
    case Pro = "pro"
    case Ultra = "ultra"
    
    public var description: String {
        return rawValue
    }
}

public enum GengoCurrency: String, CustomStringConvertible {
    case USD = "USD"
    case EUR = "EUR"
    case JPY = "JPY"
    case GBP = "GBP"
    
    public var description: String {
        return rawValue
    }
}

public struct GengoMoney: CustomStringConvertible {
    let amount: Float
    let currency: GengoCurrency
    
    init(amount: Float, currency: GengoCurrency) {
        self.amount = amount
        self.currency = currency
    }
    
    public var description: String {
        return "\(currency)\(amount)"
    }
}

public struct GengoLanguagePair: CustomStringConvertible {
    let source: GengoLanguage
    let target: GengoLanguage
    let tier: GengoTier
    let price: GengoMoney?
    
    init(source: GengoLanguage, target: GengoLanguage, tier: GengoTier, price: GengoMoney? = nil) {
        self.source = source
        self.target = target
        self.tier = tier
        self.price = price
    }
    
    public var description: String {
        return "\(tier): \(source) -> \(target)"
    }
}

public enum GengoJobType: String {
    case Text = "text"
    case File = "file"
}

public enum GengoBool {
    case `true`, `false`
    
    init(value: AnyObject?) {
        if let i = Gengo.toInt(value) {
            self = (i >= 1) ? .true : .false
        } else {
            self = .false
        }
    }
    
    public var boolValue: Bool {
        return self == .true
    }

    func toInt() -> Int {
        return (self == .true) ? 1 : 0
    }
}

public struct GengoFile {
    let data: Data
    let name: String
    let mimeType: String
    
    init(path: String) {
        self.init(data: try! Data(contentsOf: URL(fileURLWithPath: path)), name: (path as NSString).lastPathComponent)
    }
    
    /// - parameter name:: file name as if returned by String#lastPathComponent
    init(data: Data, name: String) {
        self.data = data
        self.name = name
        
        var mime =  "application/octet-stream";
        if let identifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (name as NSString).pathExtension as CFString, nil)?.takeRetainedValue() {
            if let m = UTTypeCopyPreferredTagWithClass(identifier, kUTTagClassMIMEType)?.takeRetainedValue() as? String {
                mime = m
            }
        }
        self.mimeType = mime
    }
}

public enum GengoJobStatus: String {
    case Queued = "queued"
    case Available = "available"
    case Pending = "pending"
    case Reviewable = "reviewable"
    case Approved = "approved"
    case Revising = "revising"
    case Rejected = "rejected"
    case Canceled = "canceled"
}

public struct GengoJob: CustomStringConvertible {
    var languagePair: GengoLanguagePair?
    var type: GengoJobType? = GengoJobType.Text
    var sourceText: String? {
        didSet {
            if let text = sourceText, slug == nil {
                slug = text.substring(to: text.characters.index(text.startIndex, offsetBy: 15, limitedBy: text.endIndex)!) + "..."
            }
        }
    }
    var sourceFile: GengoFile? {
        didSet {
            type = (sourceFile == nil) ? nil : GengoJobType.File
        }
    }
    var slug: String?
    
    var autoApprove: GengoBool?
    /// a string to link with a file uploaded by getQuoteFile()
    var identifier: String?
    var comment: String?
    var customData: String?
    var force: GengoBool?
    var usePreferred: GengoBool?
    //    var glossaryID: String? // TODO
    var position: String?
    var purpose: String?
    var tone: String?
    var callbackURL: String?
    var maxChars: Int?
    var asGroup: GengoBool?
    
    var id: Int?
    var order: GengoOrder?
    var targetText: String?
    var credit: GengoMoney?
    var eta: Int?
    var unitCount: Int?
    var status: GengoJobStatus?
    var createdTime: Date?
    
    init() {}
    
    public var description: String {
        return "GengoJob(\(languagePair))"
    }
}

public enum GengoJobAction {
    case revise(String)
    case approve(GengoFeedback)
    case reject(RejectData.Reason, String, String, RejectData.FollowUp)
    
    public struct RejectData {
        public enum Reason: String {
            case Quality = "quality"
            case Incomplete = "incomplete"
            case Other = "other"
        }
        
        public enum FollowUp: String {
            case Requeue = "requeue"
            case Cancel = "cancel"
        }
    }
}

public struct GengoRevision {
    var id: Int?
    var body: String?
    var createdTime: Date?
    
    init() {}
}

public struct GengoFeedback {
    var rating: Int?
    var commentForTranslator: String?
    var commentForGengo: String?
    var isPublic: GengoBool?

    init() {}
}

public struct GengoComment {
    var body: String?
    var author: Author?
    var createdTime: Date?
    
    public enum Author: String {
        case Customer = "customer"
        case Worker = "worker"
    }
    
    init() {}
}

public struct GengoOrder: CustomStringConvertible {
    var id: Int?
    var credit: GengoMoney?
    var jobCount: Int?
    var jobs: [GengoJob]?
    var asGroup: GengoBool?
    var units: Int?
    
    init() {}
    
    public var description: String {
        return "GengoOrder#\(id)"
    }
}

public struct GengoAccount {
    var creditSpent: Float?
    var creditPresent: Float?
    var currency: GengoCurrency?
    var since: Date?
    
    init() {}
}

public struct GengoTranslator {
    var id: Int?
    var jobCount: Int?
    var languagePair: GengoLanguagePair?
    
    init() {}
}

public struct GengoGlossary {
    var id: Int?
    var sourceLanguage: GengoLanguage?
    var targetLanguages: [GengoLanguage]?
    var isPublic: GengoBool?
    var unitCount: Int?
    var description: String?
    var title: String?
    var status: Int?
    var createdTime: Date?
    
    init() {}
}
