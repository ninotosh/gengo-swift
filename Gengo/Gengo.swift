import Foundation
import MobileCoreServices

public class Gengo {
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
    class func toInt(value: AnyObject?) -> Int? {
        if let i = value as? Int {
            return i
        } else if let s = value as? String {
            if let i = s.toInt() {
                return i
            }
        }
        return nil
    }
    
    class func toInt(value: AnyObject?, defaultValue: Int = 0) -> Int {
        if let i = toInt(value) {
            return i
        } else {
            return defaultValue
        }
    }
    
    class func toFloat(value: AnyObject?, defaultValue: Float = 0.0) -> Float {
        if let f = value as? Float {
            return f
        } else if let s = value as? NSString {
            return s.floatValue
        } else {
            return defaultValue
        }
    }
    
    class func toDate(value: AnyObject?) -> NSDate? {
        if let i = toInt(value) {
            return NSDate(timeIntervalSince1970: Double(i))
        } else {
            return nil
        }
    }
}

public enum GengoErrorCode: Int {
    case NotEnoughCredits = 2700
}

public class GengoError: NSError {
    init?(optionalData: NSData?, optionalResponse: NSURLResponse?, optionalError: NSError?) {
        let GENGO_DOMAIN = "com.gengo.api"
        
        var instance: NSError?
        
        if let error = optionalError {
            instance = error
        }
        
        if let response = optionalResponse {
            if let httpResponse = response as? NSHTTPURLResponse {
                let code = httpResponse.statusCode
                if code < 200 || 300 <= code {
                    var userInfo: [NSObject : AnyObject] = ["message": NSHTTPURLResponse.localizedStringForStatusCode(code)]
                    if let i = instance {
                        userInfo[NSUnderlyingErrorKey] = i
                    }
                    instance = NSError(domain: GENGO_DOMAIN, code: code, userInfo: userInfo)
                }
            }
        }
        
        if let data = optionalData {
            if let json = NSJSONSerialization.JSONObjectWithData(
                data,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil
                ) as? [String: AnyObject] {
                    var isOK = false
                    var code: Int?
                    var message: AnyObject?
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
                        var userInfo: [NSObject : AnyObject] = ["message": (message == nil) ? "operation failed" : message!]
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
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Service methods
extension Gengo {
    func getLanguages(callback: ([GengoLanguage], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/service/languages")
        request.access() {result, error in
            var languages: [GengoLanguage] = []
            if let unwrappedResult = result as? [AnyObject] {
                for language in unwrappedResult {
                    languages.append(GengoLanguage(
                        code: language["lc"] as String,
                        name: language["language"] as? String,
                        localizedName: language["localized_name"] as? String,
                        unitType: GengoLanguageUnitType(rawValue: language["unit_type"] as String)
                    ))
                }
            }
            callback(languages, error)
        }
    }
    
    func getLanguagePairs(source: GengoLanguage? = nil, callback: ([GengoLanguagePair], NSError?) -> ()) {
        var queries: [String: AnyObject] = [:]
        if let src = source {
            queries["lc_src"] = src.code
        }
        
        let request = GengoGet(gengo: self, endpoint: "translate/service/language_pairs", queries: queries)
        request.access() {result, error in
            var pairs: [GengoLanguagePair] = []
            if let unwrappedResult = result as? [AnyObject] {
                for pair in unwrappedResult {
                    pairs.append(GengoLanguagePair(
                        source: GengoLanguage(code: pair["lc_src"] as String),
                        target: GengoLanguage(code: pair["lc_tgt"] as String),
                        tier: GengoTier(rawValue: pair["tier"] as String)!,
                        price: GengoMoney(
                            amount: Gengo.toFloat(pair["unit_price"]),
                            currency: GengoCurrency(rawValue: pair["currency"] as String)!
                        )
                    ))
                }
            }
            callback(pairs, error)
        }
    }
    
    func getQuoteText(jobs: [GengoJob], callback: ([GengoJob], NSError?) -> ()) {
        getQuote("translate/service/quote", jobs: jobs, callback: callback)
    }
    
    func getQuoteFile(jobs: [GengoJob], callback: ([GengoJob], NSError?) -> ()) {
        getQuote("translate/service/quote/file", jobs: jobs, callback: callback)
    }
    
    private func getQuote(endpoint: String, jobs: [GengoJob], callback: ([GengoJob], NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        var files: [String: GengoFile] = [:]
        for (index, job) in enumerate(jobs) {
            let job_key = "job_\(index + 1)"
            jobsDictionary[job_key] = [
                "lc_src": job.languagePair!.source.code,
                "lc_tgt": job.languagePair!.target.code,
                "tier": job.languagePair!.tier.rawValue,
                "type": job.type!.rawValue,
            ]
            if (job.type == GengoJobType.File) {
                let file_key = "file_\(index + 1)"
                jobsDictionary[job_key]?.updateValue(file_key, forKey: "file_key")
                files[file_key] = job.sourceFile
            } else {
                jobsDictionary[job_key]?.updateValue(job.sourceText!, forKey: "body_src")
            }
        }
        let body = ["jobs": jobsDictionary]
        
        let request = GengoUpload(gengo: self, endpoint: endpoint, body: body, files: files)
        request.access() {result, error in
            callback(self.fillJobs(jobs, result: result), error)
        }
    }
    
    // jobs are passed by value
    private func fillJobs(jobs: [GengoJob], result: AnyObject?) -> [GengoJob] {
        var jobArray: [GengoJob] = []
        if let unwrappedResult = result as? [String: AnyObject] {
            if let unwrappedJobs = unwrappedResult["jobs"] as? [String: AnyObject] {
                for (key, jobDictionary) in unwrappedJobs {
                    // "job_3" -> ["job", "3"] -> "3" -> 3 -> 2
                    let i = split(key, {$0 == "_"})[1].toInt()! - 1
                    var job = jobs[i]
                    job.credit = GengoMoney(
                        amount: Gengo.toFloat(jobDictionary["credits"]),
                        currency: GengoCurrency(rawValue: jobDictionary["currency"] as String)!
                    )
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
    /// :returns: Nothing, but calls the callback. If both of the GengoOrder and the NSError are nil, it is probably that all the jobs are old.
    func createJobs(jobs: [GengoJob], callback: (GengoOrder?, NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        for (index, job) in enumerate(jobs) {
            var jobDictionary: [String: AnyObject?] = [
                "type": job.type!.rawValue,
                "slug": job.slug,
                "body_src": job.sourceText,
                "lc_src": job.languagePair!.source.code,
                "lc_tgt": job.languagePair!.target.code,
                "tier": job.languagePair!.tier.rawValue,
                "identifier": job.identifier,
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
        
        let request = GengoPost(gengo: self, endpoint: "translate/jobs", body: body)
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
    
    /// :param: parameters["status"]: GengoJobStatus
    /// :param: parameters["after"]: NSDate or Int
    /// :param: parameters["count"]: Int
    func getJobs(parameters: [String: Any] = [:], callback: ([GengoJob], NSError?) -> ()) {
        var q: [String: AnyObject] = [:]
        if let status = parameters["status"] as? GengoJobStatus {
            q["status"] = status.rawValue
        }
        if let date = parameters["after"] as? NSDate {
            q["timestamp_after"] = Int(date.timeIntervalSince1970)
        } else if let int = parameters["after"] as? Int {
            q["timestamp_after"] = int
        }
        if let count = parameters["count"] as? Int {
            q["count"] = count
        }
        
        let request = GengoGet(gengo: self, endpoint: "translate/jobs", queries: q)
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
    
    func getJobs(ids: [Int], callback: ([GengoJob], NSError?) -> ()) {
        var stringIDs: [String] = []
        for id in ids {
            stringIDs.append(String(id))
        }
        let joinedIDs = ",".join(stringIDs)
        
        let request = GengoGet(gengo: self, endpoint: "translate/jobs/\(joinedIDs)")
        request.access() {result, error in
            var jobs: [GengoJob] = []
            if let unwrappedResult = result as? [String: AnyObject] {
                if let unwrappedJobs = unwrappedResult["jobs"] as? [AnyObject] {
                    for job in unwrappedJobs {
                        jobs.append(Gengo.toJob(job as [String: AnyObject]))
                    }
                }
            }
            
            callback(jobs, error)
        }
    }
}

// Job methods
extension Gengo {
    func getJob(id: Int, mt: GengoBool, callback: (GengoJob?, NSError?) -> ()) {
        let query = ["pre_mt": mt.toInt()]
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(id)", queries: query)
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
    
    func putJob(id: Int, action: GengoJobAction, callback: (NSError?) -> ()) {
        var body: [String: AnyObject] = [:]
        
        switch action {
        case .Revise(let comment):
            body = ["action": "revise", "comment": comment]
        case .Approve(let feedback):
            body = ["action": "approve"]
            if let rating = feedback.rating {
                body["rating"] = rating
            }
            if let commentForTranslator = feedback.commentForTranslator {
                body["for_translator"] = commentForTranslator
            }
            if let commentForGengo = feedback.commentForGengo {
                body["for_mygengo"] = commentForGengo
            }
            if let isPublic = feedback.isPublic {
                body["public"] = isPublic.toInt()
            }
        case .Reject(let reason, let comment, let captcha, let followUp):
            body["action"] = "reject"
            body["reason"] = reason.rawValue
            body["comment"] = comment
            body["captcha"] = captcha
            body["follow_up"] = followUp.rawValue
        }
        
        let request = GengoPut(gengo: self, endpoint: "translate/job/\(id)", body: body)
        request.access() {result, error in
            callback(error)
        }
    }
    
    func deleteJob(id: Int, callback: (NSError?) -> ()) {
        let request = GengoDelete(gengo: self, endpoint: "translate/job/\(id)")
        request.access() {result, error in
            callback(error)
        }
    }
    
    func getRevisions(jobID: Int, callback: ([GengoRevision], NSError?) -> ()) {
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
    
    func getRevision(jobID: Int, revisionID: Int, callback: (GengoRevision?, NSError?) -> ()) {
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
    
    func getFeedback(jobID: Int, callback: (GengoFeedback?, NSError?) -> ()) {
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
    
    func getComments(jobID: Int, callback: ([GengoComment], NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/job/\(jobID)/comments")
        request.access() {result, error in
            var comments: [GengoComment] = []
            if let unwrappedResult = result as? [String: AnyObject] {
                if let commentsArray = unwrappedResult["thread"] as? [[String: AnyObject]] {
                    for commentDictionary in commentsArray {
                        var comment = GengoComment()
                        comment.body = commentDictionary["body"] as? String
                        comment.author = GengoComment.Author(rawValue: commentDictionary["author"] as String)
                        comment.createdTime = Gengo.toDate(commentDictionary["ctime"])
                        
                        comments.append(comment)
                    }
                }
            }

            callback(comments, error)
        }
    }
    
    func postComment(jobID: Int, comment: String, callback: (NSError?) -> ()) {
        let body = ["body": comment]
        let request = GengoPost(gengo: self, endpoint: "translate/job/\(jobID)/comment", body: body)
        request.access() {result, error in
            callback(error)
        }
    }
}

// Order methods
extension Gengo {
    func getOrder(id: Int, callback: (GengoOrder?, NSError?) -> ()) {
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

    func deleteOrder(id: Int, callback: (NSError?) -> ()) {
        let request = GengoDelete(gengo: self, endpoint: "translate/order/\(id)")
        request.access() {result, error in
            callback(error)
        }
    }
}

// JSON to object
extension Gengo {
    private class func toJob(json: [String: AnyObject]) -> GengoJob {
        var job = GengoJob()
        
        if let tierString = json["tier"] as? String {
            if let tier = GengoTier(rawValue: tierString) {
                job.languagePair = GengoLanguagePair(
                    source: GengoLanguage(code: json["lc_src"] as String),
                    target: GengoLanguage(code: json["lc_tgt"] as String),
                    tier: tier
                )
            }
        }
        job.sourceText = json["body_src"] as? String
        job.autoApprove = GengoBool(value: json["auto_approve"])
        if let currencyString = json["currency"] as? String {
            if let currency = GengoCurrency(rawValue: currencyString) {
                job.credit = GengoMoney(
                    amount: toFloat(json["credits"]),
                    currency: currency
                )
            }
        }
        job.eta = toInt(json["eta"])
        job.id = toInt(json["job_id"])
        job.order = GengoOrder()
        job.order!.id = toInt(json["order_id"])
        job.slug = json["slug"] as? String
        if let statusString = json["status"] as? String {
            job.status = GengoJobStatus(rawValue: statusString)
        }
        job.unitCount = toInt(json["unit_count"])
        job.createdTime = toDate(json["ctime"])
        
        return job
    }

    private class func toRevision(json: [String: AnyObject]) -> GengoRevision {
        var revision = GengoRevision()

        revision.id = Gengo.toInt(json["rev_id"])
        if let body = json["body_tgt"] as? String {
            revision.body = body
        }
        revision.createdTime = Gengo.toDate(json["ctime"])
        
        return revision
    }
    
    private class func toOrder(json: [String: AnyObject]) -> GengoOrder {
        var order = GengoOrder()
        order.id = toInt(json["order_id"])
        if let currencyString = json["currency"] as? String {
            if let currency = GengoCurrency(rawValue: currencyString) {
                order.credit = GengoMoney(
                    amount: toFloat(json["total_credits"]),
                    currency: currency
                )
            }
        }
        if let count = toInt(json["job_count"]) {
            order.jobCount = count
        } else if let count = toInt(json["total_jobs"]) {
            order.jobCount = count
        }
        order.asGroup = GengoBool(value: json["as_group"])
        order.units = toInt(json["total_units"])

        return order
    }
}

// enums and structs

public enum GengoLanguageUnitType: String {
    case Word = "word"
    case Character = "character"
}

public struct GengoLanguage: Printable {
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
        return (name? == nil) ? code : name!
    }
}

public enum GengoTier: String, Printable {
    case Standard = "standard"
    case Pro = "pro"
    case Ultra = "ultra"
    
    public var description: String {
        return rawValue
    }
}

public enum GengoCurrency: String, Printable {
    case USD = "USD"
    case EUR = "EUR"
    case JPY = "JPY"
    case GBP = "GBP"
    
    public var description: String {
        return rawValue
    }
}

public struct GengoMoney: Printable {
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

public struct GengoLanguagePair: Printable {
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

public enum GengoBool: BooleanType {
    case True, False
    
    init(value: AnyObject?) {
        if let i = Gengo.toInt(value) {
            self = (i >= 1) ? .True : .False
        } else {
            self = .False
        }
    }
    
    public var boolValue: Bool {
        return self == .True
    }

    func toInt() -> Int {
        return (self == .True) ? 1 : 0
    }
}

public struct GengoFile {
    let data: NSData
    let name: String
    let mimeType: String
    
    init(path: String) {
        self.init(data: NSData(contentsOfFile: path)!, name: path.lastPathComponent)
    }
    
    /// :param: name: file name as if returned by String#lastPathComponent
    init(data: NSData, name: String) {
        self.data = data
        self.name = name
        
        self.mimeType =  "application/octet-stream";
        if let identifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, name.pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(identifier, kUTTagClassMIMEType)?.takeRetainedValue() {
                self.mimeType = mimetype
            }
        }
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

public struct GengoJob: Printable {
    var languagePair: GengoLanguagePair?
    var type: GengoJobType? = GengoJobType.Text
    var sourceText: String? {
        didSet {
            if sourceText != nil && slug == nil {
                slug = sourceText!.substringToIndex(advance(sourceText!.startIndex, 15, sourceText!.endIndex)) + "..."
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
    var createdTime: NSDate?
    
    init() {}
    
    public var description: String {
        return "GengoJob(\(languagePair))"
    }
}

public enum GengoJobAction {
    case Revise(String)
    case Approve(GengoFeedback)
    case Reject(RejectData.Reason, String, String, RejectData.FollowUp)
    
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
    var createdTime: NSDate?
    
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
    var createdTime: NSDate?
    
    public enum Author: String {
        case Customer = "customer"
        case Worker = "worker"
    }
    
    init() {}
}

public struct GengoOrder: Printable {
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
