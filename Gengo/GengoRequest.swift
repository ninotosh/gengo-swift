import Foundation

open class GengoRequest: NSMutableURLRequest {
    let gengo: Gengo
    let endpoint: String
    
    let now: Date = Date()
    
    init(gengo: Gengo, endpoint: String) {
        self.gengo = gengo
        self.endpoint = endpoint
        // fill `url` temporarily with any valid URL as self.apiURL is inaccessible before calling self.init()
        super.init(url: URL(string: "https://example.com")!, cachePolicy: NSURLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 60)
        // now that `apiURL` is accessible, self.url can be properly set
        self.url = URL(string: apiURL)
        
        self.httpMethod = "GET"
        self.setValue("application/json", forHTTPHeaderField: "Accept")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func access(_ callback: @escaping (AnyObject?, GengoError?) -> ()) {
        let session = gengo.urlSession
        let dataTask = session.dataTask(with: self as URLRequest, completionHandler: {data, response, error in
            let gengoError = GengoError(optionalData: data, optionalResponse: response, optionalError: error as NSError?)
            
            var result: AnyObject?
            if let d = data, let json = (
                try? JSONSerialization.jsonObject(with: d, options: JSONSerialization.ReadingOptions.mutableContainers)
                ) as? [String: AnyObject] {
                result = json["response"]
            }
            
            callback(result, gengoError)
        })
        
        dataTask.resume()
    }
    
    var apiURL: String {
        return gengo.apiHost + endpoint
    }
    
    var queryString: String {
        var pairs: [String] = []
        for (key, value) in parameters {
            if let v = value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "")) {
                pairs.append("\(key)=\(v)")
            }
        }
        
        return pairs.joined(separator: "&")
    }
    
    var parameters: [String: String] {
        var p: [String: String] = [:]
        p["api_key"] = apiKey
        p["ts"] = timestamp
        p["api_sig"] = apiSignature
        return p
    }
    
    fileprivate var apiKey: String {
        return gengo.publicKey
    }
    
    fileprivate var timestamp: String {
        return String(Int(now.timeIntervalSince1970))
    }
    
    fileprivate var apiSignature: String {
        let str = timestamp.cString(using: String.Encoding.utf8)
        let strLen = timestamp.lengthOfBytes(using: String.Encoding.utf8)
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        let objcKey = gengo.privateKey as NSString
        let keyStr = objcKey.cString(using: String.Encoding.utf8.rawValue)
        let keyLen = objcKey.lengthOfBytes(using: String.Encoding.utf8.rawValue)
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyStr, keyLen, str!, strLen, result)
        
        let hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.deinitialize()
        
        return String(hash)
    }
}

class GengoGet: GengoRequest {
    let query: [String: AnyObject]
    
    init(gengo: Gengo, endpoint: String, query: [String: AnyObject] = [:]) {
        self.query = query
        super.init(gengo: gengo, endpoint: endpoint)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var apiURL: String {
        return super.apiURL + "?" + queryString
    }
    
    override var parameters: [String: String] {
        var p: [String: String] = [:]
        for (key, value) in query {
            p[key] = value.description
        }
        for (key, value) in super.parameters {
            p[key] = value
        }
        return p
    }
}

class GengoDelete: GengoGet {
    override init(gengo: Gengo, endpoint: String, query: [String: AnyObject] = [:]) {
        super.init(gengo: gengo, endpoint: endpoint, query: query)
        
        self.httpMethod = "DELETE"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GengoPost: GengoRequest {
    let body: [String: AnyObject]
    
    init(gengo: Gengo, endpoint: String, body: [String: AnyObject] = [:]) {
        self.body = body
        super.init(gengo: gengo, endpoint: endpoint)
        
        self.httpMethod = "POST"
        self.httpBody = queryString.data(using: String.Encoding.utf8)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var parameters: [String: String] {
        var p = super.parameters
        let bodyData = try? JSONSerialization.data(withJSONObject: body, options: [])
        p["data"] = NSString(data: bodyData!, encoding: String.Encoding.utf8.rawValue)! as String
        return p
    }
}

class GengoUpload: GengoPost {
    let files: [String: GengoFile]
    init(gengo: Gengo, endpoint: String, body: [String: AnyObject] = [:], files: [String: GengoFile] = [:]) {
        self.files = files
        super.init(gengo: gengo, endpoint: endpoint, body: body)
        
        self.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = NSMutableData()
        
        for (key, value) in parameters {
            appendLine(httpBody, string: "--\(boundary)")
            appendLine(httpBody, string: "Content-Disposition: form-data; name=\"\(key)\"")
            appendLine(httpBody, string: "Content-Type: text/plain")
            appendLine(httpBody, string: "")
            appendLine(httpBody, string: "\(value)")
        }
        for (name, file) in files {
            appendLine(httpBody, string: "--\(boundary)")
            appendLine(httpBody, string: "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(file.name)\"")
            appendLine(httpBody, string: "Content-Type: \(file.mimeType)")
            appendLine(httpBody, string: "")
            httpBody.append(file.data as Data)
            appendLine(httpBody, string: "")
        }
        appendLine(httpBody, string: "--\(boundary)--")
        
        self.httpBody = httpBody as Data
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate var boundary: String {
        return "GengoSwiftBoundary\(timestamp)"
    }
    
    fileprivate func appendLine(_ data: NSMutableData, string: String = "") {
        let s = string + "\r\n"
        if let d = s.data(using: String.Encoding.utf8) {
            data.append(d)
        }
    }
}

class GengoPut: GengoPost {
    override init(gengo: Gengo, endpoint: String, body: [String : AnyObject]) {
        super.init(gengo: gengo, endpoint: endpoint, body: body)
        
        self.httpMethod = "PUT"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol
}

// avoid "Value of type 'URLSession' does not conform to specified type 'URLSessionProtocol'"
// or avoid always appending "as! URLSessionProtocol" to a URLSession variable
extension URLSession: URLSessionProtocol {
    internal func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        return (dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask) as URLSessionDataTaskProtocol
    }
}

protocol URLSessionDataTaskProtocol {
    func resume()
}

extension URLSessionDataTask: URLSessionDataTaskProtocol {}
