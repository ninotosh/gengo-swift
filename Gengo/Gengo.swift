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
    private func toInt(value: AnyObject?) -> Int? {
        if let s = value as? String {
            return s.toInt()
        } else if let i = value as? Int {
            return i
        } else {
            return nil
        }
    }
    
    private func toInt(value: AnyObject?, defaultValue: Int = 0) -> Int {
        if let int = toInt(value) {
            return int
        } else {
            return defaultValue
        }
    }
    
    private func toFloat(value: AnyObject?) -> Float? {
        if let s = value as? NSString {
            return s.floatValue
        } else if let f = value as? Float {
            return f
        } else {
            return nil
        }
    }
    
    private func toFloat(value: AnyObject?, defaultValue: Float = 0.0) -> Float {
        if let float = toFloat(value) {
            return float
        } else {
            return defaultValue
        }
    }
}

public class GengoError: NSError {
    // TODO make this private
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
                ) as? NSDictionary {
                    var isOK = false
                    var code: Int?
                    var message: AnyObject?
                    if let opstat = json["opstat"] as? String {
                        if opstat == "ok" {
                            isOK = true
                        } else {
                            if let err = json["err"] as? NSDictionary {
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
    func getLanguages(callback: (Array<GengoLanguage>, NSError?) -> ()) {
        let request = GengoGet(gengo: self, endpoint: "translate/service/languages")
        request.access() {result, error in
            var languages: Array<GengoLanguage> = []
            if let unwrappedResult = result as? NSArray {
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
    
    func getLanguagePairs(source: GengoLanguage? = nil, callback: (Array<GengoLanguagePair>, NSError?) -> ()) {
        var queries: [String: AnyObject] = [:]
        if let src = source {
            queries["lc_src"] = src.code
        }
        
        let request = GengoGet(gengo: self, endpoint: "translate/service/language_pairs", queries: queries)
        request.access() {result, error in
            var pairs: Array<GengoLanguagePair> = []
            if let unwrappedResult = result as? NSArray {
                for pair in unwrappedResult {
                    pairs.append(GengoLanguagePair(
                        source: GengoLanguage(code: pair["lc_src"] as String),
                        target: GengoLanguage(code: pair["lc_tgt"] as String),
                        tier: GengoTier(rawValue: pair["tier"] as String)!,
                        price: GengoMoney(
                            amount: (pair["unit_price"] as NSString).floatValue,
                            currency: GengoCurrency(rawValue: pair["currency"] as String)!
                        )
                        ))
                }
            }
            callback(pairs, error)
        }
    }
    
    func getQuoteText(jobs: Array<GengoJob>, callback: (Array<GengoJob>, NSError?) -> ()) {
        getQuote("translate/service/quote", jobs: jobs, callback: callback)
    }
    
    func getQuoteFile(jobs: Array<GengoJob>, callback: (Array<GengoJob>, NSError?) -> ()) {
        getQuote("translate/service/quote/file", jobs: jobs, callback: callback)
    }
    
    private func getQuote(endpoint: String, jobs: Array<GengoJob>, callback: (Array<GengoJob>, NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        var files: [String: GengoFile] = [:]
        for (index, job) in enumerate(jobs) {
            let job_key = "job_\(index + 1)"
            jobsDictionary[job_key] = [
                "lc_src": job.languagePair.source.code,
                "lc_tgt": job.languagePair.target.code,
                "tier": job.languagePair.tier.rawValue,
                "type": job.type.rawValue,
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
    
    private func fillJobs(jobs: Array<GengoJob>, result: AnyObject?) -> Array<GengoJob> {
        var jobArray: Array<GengoJob> = []
        if let unwrappedResult = result as? NSDictionary {
            if let unwrappedJobs = unwrappedResult["jobs"] as? NSDictionary {
                for (key, job) in unwrappedJobs {
                    // "job_3" -> ["job", "3"] -> "3" -> 3 -> 2
                    let i = split(key as String, {$0 == "_"})[1].toInt()! - 1
                    jobs[i].credit = GengoMoney(
                        amount: self.toFloat(job["credits"]),
                        currency: GengoCurrency(rawValue: job["currency"] as String)!
                    )
                    jobs[i].eta = self.toInt(job["eta"])
                    jobs[i].unitCount = self.toInt(job["unit_count"])
                    jobs[i].identifier = job["identifier"] as? String
                    if jobs[i].slug == nil {
                        jobs[i].slug = job["title"] as? String
                    }
                    
                    jobArray.append(jobs[i])
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
    func createJobs(jobs: Array<GengoJob>, callback: (GengoOrder?, NSError?) -> ()) {
        var jobsDictionary: [String: [String: AnyObject]] = [:]
        for (index, job) in enumerate(jobs) {
            var jobDictionary: [String: AnyObject?] = [
                "type": job.type.rawValue,
                "slug": job.slug,
                "body_src": job.sourceText,
                "lc_src": job.languagePair.source.code,
                "lc_tgt": job.languagePair.target.code,
                "tier": job.languagePair.tier.rawValue,
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
            if let orderDictionary = result as? NSDictionary {
                if let orderIDString = orderDictionary["order_id"] as? String {
                    if let orderID = orderIDString.toInt() {
                        order = GengoOrder(
                            id: orderID,
                            credit: GengoMoney(
                                amount: self.toFloat(orderDictionary["credits_used"]),
                                currency: GengoCurrency(rawValue: orderDictionary["currency"] as String)!
                            )
                        )
                        order!.jobCount = orderDictionary["job_count"] as Int
                    }
                }
            }
            callback(order, error)
        }
    }
}

public enum GengoLanguageUnitType: String {
    case Word = "word"
    case Character = "character"
}

public class GengoLanguage: Printable {
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

public class GengoMoney: Printable {
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

public class GengoLanguagePair: Printable {
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
    case True, False
    
    init(i: Int?) {
        self = .False
        if let value = i {
            if value >= 1 {
                self = .True
            }
        }
    }
    
    init(s: String?) {
        self = .False
        if let value = s {
            if let i = value.toInt() {
                self = (i >= 1) ? .True : .False
                return
            }
            if countElements(value) > 0 {
                self = .True
            }
        }
    }
    
    func toInt() -> Int {
        return (self == .True) ? 1 : 0
    }
}

public class GengoFile {
    let data: NSData
    let name: String
    let mimeType: String
    
    convenience init(path: String) {
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

public class GengoJob: Printable {
    let languagePair: GengoLanguagePair
    let type: GengoJobType
    var sourceText: String?
    var sourceFile: GengoFile?
    var slug: String?
    
    var autoApprove: GengoBool?
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
    
    var targetText: String?
    var credit: GengoMoney?
    var eta: Int?
    var unitCount: Int?
    
    init(languagePair: GengoLanguagePair, sourceText: String, slug: String? = nil) {
        self.languagePair = languagePair
        self.type = GengoJobType.Text
        self.sourceText = sourceText
        if let s = slug {
            self.slug = s
        } else {
            self.slug = sourceText.substringToIndex(advance(sourceText.startIndex, 15, sourceText.endIndex)) + "..."
        }
    }
    
    init(languagePair: GengoLanguagePair, sourceFile: GengoFile, slug: String? = nil) {
        self.languagePair = languagePair
        self.type = GengoJobType.File
        self.sourceFile = sourceFile
        if let s = slug {
            self.slug = s
        } // else set to the file name by getQuoteFile()
    }
    
    public var description: String {
        return "GengoJob(\(languagePair))"
    }
}

public class GengoOrder: Printable {
    let id: Int
    let money: GengoMoney
    
    var jobCount: Int = 0
    
    private init(id: Int, credit: GengoMoney) {
        self.id = id
        self.money = credit
    }
    
    public var description: String {
        return "GengoOrder#\(id)"
    }
}
