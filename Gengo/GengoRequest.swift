import Foundation

public class GengoRequest: NSMutableURLRequest {
    let gengo: Gengo
    let endpoint: String
    
    let now: NSDate = NSDate()
    
    init(gengo: Gengo, endpoint: String) {
        self.gengo = gengo
        self.endpoint = endpoint
        super.init(URL: NSURL(string: "")!, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 60)
        self.URL = NSURL(string: url)
        
        self.HTTPMethod = "GET"
        self.setValue("application/json", forHTTPHeaderField: "Accept")
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func access(callback: (AnyObject?, NSError?) -> ()) {
        let session = NSURLSession.sharedSession()
        let dataTask = session.dataTaskWithRequest(self, completionHandler: {data, response, error in
            let gengoError = GengoError(optionalData: data, optionalResponse: response, optionalError: error)
            
            var result: AnyObject?
            if let json = NSJSONSerialization.JSONObjectWithData(
                data,
                options: NSJSONReadingOptions.MutableContainers,
                error: nil
                ) as? NSDictionary {
                    result = json["response"]
            }
            
            callback(result, gengoError)
        })
        
        dataTask.resume()
    }
    
    var url: String {
        return gengo.apiHost + endpoint
    }
    
    var queryString: String {
        var pairs: [String] = []
        for (key, value) in parameters {
            if let v = value.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet(charactersInString: "")) {
                pairs.append("\(key)=\(v)")
            }
        }
        
        return "&".join(pairs)
    }
    
    var parameters: [String: String] {
        var p: [String: String] = [:]
        p["api_key"] = apiKey
        p["ts"] = timestamp
        p["api_sig"] = apiSignature
        return p
    }
    
    private var apiKey: String {
        return gengo.publicKey
    }
    
    private var timestamp: String {
        return String(Int(now.timeIntervalSince1970))
    }
    
    private var apiSignature: String {
        let str = timestamp.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = timestamp.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.alloc(digestLen)
        let objcKey = gengo.privateKey as NSString
        let keyStr = objcKey.cStringUsingEncoding(NSUTF8StringEncoding)
        let keyLen = objcKey.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), keyStr, keyLen, str!, strLen, result)
        
        var hash = NSMutableString()
        for i in 0..<digestLen {
            hash.appendFormat("%02x", result[i])
        }
        
        result.destroy()
        
        return String(hash)
    }
}

class GengoGet: GengoRequest {
    let query: [String: AnyObject]
    
    init(gengo: Gengo, endpoint: String, query: [String: AnyObject] = [:]) {
        self.query = query
        super.init(gengo: gengo, endpoint: endpoint)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var url: String {
        return super.url + "?" + queryString
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
        
        self.HTTPMethod = "DELETE"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GengoPost: GengoRequest {
    let body: [String: AnyObject]
    
    init(gengo: Gengo, endpoint: String, body: [String: AnyObject] = [:]) {
        self.body = body
        super.init(gengo: gengo, endpoint: endpoint)
        
        self.HTTPMethod = "POST"
        self.HTTPBody = queryString.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var parameters: [String: String] {
        var p = super.parameters
        let bodyData = NSJSONSerialization.dataWithJSONObject(body, options: nil, error: nil)
        p["data"] = NSString(data: bodyData!, encoding: NSUTF8StringEncoding)! as String
        return p
    }
}

class GengoUpload: GengoPost {
    let files: [String: GengoFile]
    init(gengo: Gengo, endpoint: String, body: [String: AnyObject] = [:], files: [String: GengoFile] = [:]) {
        self.files = files
        super.init(gengo: gengo, endpoint: endpoint, body: body)
        
        self.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var httpBody = NSMutableData()
        
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
            httpBody.appendData(file.data)
            appendLine(httpBody, string: "")
        }
        appendLine(httpBody, string: "--\(boundary)--")
        
        self.HTTPBody = httpBody
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var boundary: String {
        return "GengoSwiftBoundary\(timestamp)"
    }
    
    private func appendLine(data: NSMutableData, string: String = "") {
        let s = string + "\r\n"
        if let d = s.dataUsingEncoding(NSUTF8StringEncoding) {
            data.appendData(d)
        }
    }
}

class GengoPut: GengoPost {
    override init(gengo: Gengo, endpoint: String, body: [String : AnyObject]) {
        super.init(gengo: gengo, endpoint: endpoint, body: body)
        
        self.HTTPMethod = "PUT"
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

