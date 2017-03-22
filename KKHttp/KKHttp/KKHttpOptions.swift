//
//  KKHttpOptions.swift
//  KKHttp
//
//  Created by zhanghailong on 2016/11/28.
//  Copyright © 2016年 kkserver.cn. All rights reserved.
//

import Foundation
import KKCrypto

public enum KKHttpOptionsError : Error {
    case URL
    case JSON
    case FILE
}

public class KKHttpOptions : NSObject {
    
    public typealias OnLoad = (_ data:Any?,_ error:Error?,_ weakObject:AnyObject?) -> Void
    public typealias OnFail = (_ error:Error?,_ weakObject:AnyObject?) ->Void
    public typealias OnResponse = (_ response:HTTPURLResponse,_ weakObject:AnyObject?) -> Void
    public typealias OnProcess = (_ value:Int64,_ maxValue:Int64,_ weakObject:AnyObject?) -> Void
    
    public static let GET = "GET"
    public static let POST = "POST"
    
    public static let TypeText = "text"
    public static let TypeJson = "json"
    public static let TypeData = "data"
    public static let TypeUri = "uri"
    public static let TypeImage = "image"
    
    public var url:String
    public var method:String = GET
    public var data:Any?
    public var headers:[String:String] = [:]
    public var type:String = TypeText
    public var timeout:TimeInterval = 30
    
    public var onLoad:OnLoad?
    public var onFail:OnFail?
    public var onResponse:OnResponse?
    public var onProcess:OnProcess?
    
    public init(url:String) {
        self.url = url
        super.init()
    }
    
    public static func path(uri:String) -> String {
        
        if uri.hasPrefix("document://") {
            return NSHomeDirectory().appending(uri.substring(from: uri.index(uri.startIndex, offsetBy: 11)))
        }
        else if uri.hasPrefix("app://") {
            return Bundle.main.resourcePath!.appending(uri.substring(from: uri.index(uri.startIndex, offsetBy: 6)))
        }
        else if uri.hasPrefix("cache://") {
            return NSHomeDirectory().appendingFormat("/Library/Caches%@", uri.substring(from: uri.index(uri.startIndex, offsetBy: 8)))
        }
        else {
            return uri
        }
        
    }
    
    private var _absoluteUrl:String?
    
    public var absoluteUrl:String {
        get {
            
            if(_absoluteUrl == nil) {
                
                if (type == KKHttpOptions.TypeUri || type == KKHttpOptions.TypeImage || method == KKHttpOptions.GET)
                    && data != nil && data is Dictionary<String,Any> {
                    var query:String=""
                    var i = 0
                    for (key,value) in (data as! Dictionary<String,Any>?)! {
                        if i != 0 {
                            query.append("&")
                        }
                        query.append(key)
                        query.append("=")
                        query.append(KKHttpOptions.stringValue(value).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)
                        i = i + 1
                    }
                    if url.hasSuffix("?") {
                        _absoluteUrl = url + query
                    } else if url.contains("?") {
                        _absoluteUrl = url + "&" + query
                    } else {
                        _absoluteUrl = url + "?" + query
                    }
                }
                else {
                    _absoluteUrl = url
                }
            }
            return _absoluteUrl!
        }
    }
    
    private var _key:String?
    
    public var key:String? {
        get {
            if(_key == nil) {
                if type == KKHttpOptions.TypeUri || type == KKHttpOptions.TypeImage {
                    _key = KKHttpOptions.cacheKey(url: absoluteUrl)
                }
            }
            return _key
        }
    }
    
    public func request() throws -> URLRequest {
        
        let u = URL.init(string: absoluteUrl)
        
        if u != nil {
            
            var req = URLRequest.init(url: u!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
            
            req.httpMethod = method
            
            if method == "POST" {
                
                if data != nil {
                
                    if data is Dictionary<String,Any> {
                        
                        let body = KKHttpBody.init()
                        
                        for (key,value) in data as! Dictionary<String,Any> {
                            
                            if value is Dictionary<String,Any> {
                                let v = value as! Dictionary<String,Any>
                                let uri = v["uri"]
                                let name = v["name"]
                                let type = v["type"]
                                if uri != nil && type != nil{
                                    let path = KKHttpOptions.path(uri: uri as! String)
                                    body.add(key: key, data:try Data.init(contentsOf: URL.init(fileURLWithPath: path)) , type: type as! String, name: name as! String)
                                }
                            } else {
                                body.add(key: key, value: KKHttpOptions.stringValue(value))
                            }
                            
                        }
                        
                        req.setValue(body.type,forHTTPHeaderField:"Content-Type")
                        req.httpBody = body.data
                        
                    }
                    else if data is String {
                        req.httpBody = (data as! String).data(using: String.Encoding.utf8)
                    }
                    else if data is Data {
                        req.httpBody = (data as! Data)
                    }
                }
                
            }
            
            for (key,value) in headers {
                req.setValue(value,forHTTPHeaderField:key)
            }
            
            if type == KKHttpOptions.TypeUri || type == KKHttpOptions.TypeImage {
                
                let (path,_,b) = KKHttpOptions.cacheTmpPath(url:absoluteUrl)
                let fm = FileManager.default
                
                if b {
                    
                    let attrs = try fm.attributesOfItem(atPath: path)
                    
                    req.setValue(String.init(format: "%llu-", (attrs[FileAttributeKey.size] as! NSNumber).uint64Value), forHTTPHeaderField: "Range")
                    
                }
            }
            
            print("[KK]","[KKHttp]", req);
            
            return req
            
        } else {
            throw KKHttpOptionsError.URL
        }
        
    }
    
    public static func cacheKey(url:String) -> String {
        return (url as NSString).kkmd5()
    }
    
    public static func cachePath(url:String) -> (String,String,Bool) {
        let key = KKHttpOptions.cacheKey(url:url)
        let path = KKHttpOptions.path(uri:String.init(format: "cache:///kk/%@", key))
        let fm = FileManager.default
        return (path,key,fm.fileExists(atPath:path))
    }
    
    public static func cacheTmpPath(url:String) -> (String,String,Bool) {
        let key = KKHttpOptions.cacheKey(url:url)
        let path = KKHttpOptions.path(uri:String.init(format: "cache:///kk/%@.t", key))
        let fm = FileManager.default
        return (path,key,fm.fileExists(atPath:path))
    }
    
    public static func stringValue(_ object:Any?) -> String {
        
        if(object == nil) {
            return "";
        }
        
        if(object is String || object is NSString) {
            return object as! String;
        }
        
        if(object is Int) {
            return String.init(object as! Int);
        }
        
        if(object is Int64) {
            return String.init(object as! Int64);
        }
        
        if(object is Float) {
            return String.init(object as! Float);
        }
        
        if(object is Double) {
            return String.init(object as! Double);
        }
        
        if(object is NSNumber) {
            return (object as! NSNumber).stringValue;
        }
        
        if(object is NSObject) {
            return (object as! NSObject).description;
        }
        
        return ""
    }

}
