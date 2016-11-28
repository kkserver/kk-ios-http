//
//  KKHttp.swift
//  KKHttp
//
//  Created by zhanghailong on 2016/11/28.
//  Copyright © 2016年 kkserver.cn. All rights reserved.
//

import Foundation
import KKCrypto

public class KKHttpTask : NSObject {
    
    public let identity:Int
    public let options:KKHttpOptions
    public let key:String?
    
    private weak var _http:KKHttp?
    private weak var _weakObject:AnyObject?
    
    public var weakObject:AnyObject? {
        get {
            return _weakObject
        }
    }
    
    internal init(http:KKHttp,options:KKHttpOptions, weakObject:AnyObject?, identity:Int) {
        self.options = options
        self.key = options.key
        self.identity = identity
        _http = http
        _weakObject = weakObject
        super.init()
    }
    
    public func cancel() {
        if _http != nil {
            _http!.cancel(task: self)
        }
    }
}

internal class KKHttpResponse : NSObject {
    
    public let options:KKHttpOptions
    public let key:String?
    
    private var _maxValue:Int64 = 0
    private var _path:String = ""
    private var _tmppath:String = ""
    private var _data:Data?
    private var _encoding:String.Encoding = String.Encoding.utf8
    
    public var value:Int64 = 0
    
    internal init(options:KKHttpOptions) {
        self.options = options
        self.key = options.key
        
        if self.key != nil {
            (_path,_,_) = KKHttpOptions.cachePath(url: options.absoluteUrl)
            (_tmppath,_,_) = KKHttpOptions.cacheTmpPath(url: options.absoluteUrl)
        }
        
        super.init()
    }
    
    public func onResponse(_ response:HTTPURLResponse) ->Void {
        
        var v = response.allHeaderFields["Content-Length"] as! String?
        
        if v != nil {
            _maxValue = Int64.init(v!)!
        }
        
        v = response.allHeaderFields["Content-Type"] as! String?
        
        if v != nil {
            if v!.lowercased().contains("charset=gbk")
                || v!.lowercased().contains("charset=gb2312") {
                _encoding = String.Encoding.init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))

            }
        }
        
        if key != nil {
            
            let fm = FileManager.default
            
            if !fm.fileExists(atPath: _tmppath) {
                
                try? fm.createDirectory(atPath: (_tmppath as NSString).deletingLastPathComponent
                    , withIntermediateDirectories: true, attributes: nil)
                
                let fd = FileHandle.init(forWritingAtPath: _tmppath)
                if( fd != nil) {
                    fd!.closeFile()
                }
            }
            
        } else {
            _data = Data.init()
        }
    }
    
    public func onData(_ data:Data) -> Void {
        
        if key != nil {
            
            let fd = FileHandle.init(forUpdatingAtPath: _tmppath)
            
            if( fd != nil) {
                
                fd!.seekToEndOfFile()
                
                fd!.write(data)
                
                fd!.closeFile()
            }
            
        } else {
            _data!.append(data)
        }
        
    }

    public func onFail(error:Error?) ->Void {
        
        if key != nil {
            
            let fm = FileManager.default
            
            try? fm.removeItem(atPath: _tmppath)
            
        }

    }
    
    public func onLoad() ->Void {
        
        if key != nil {
            
            let fm = FileManager.default
            
            do {
                try fm.removeItem(atPath: _path);
                try fm.moveItem(atPath: _tmppath, toPath: _path)
            }
            catch {
                _error = KKHttpOptionsError.FILE
            }
            
            if options.type == .Uri {
                _body = _path
            }
            else if(options.type == .Image) {
                _body = UIImage.init(named: _path)
            }
            
        } else if(options.type == .Json) {
            do {
                _body = try JSONSerialization.jsonObject(with: _data!, options: JSONSerialization.ReadingOptions.mutableLeaves)
            }
            catch{
                _error = KKHttpOptionsError.JSON
            }
        } else if(options.type == .Text) {
            _body = String.init(data: _data!, encoding: _encoding)
        } else {
            _body = _data
        }
        
    }
    
    public var background:Bool {
        get {
            return key != nil
        }
    }
    
    public var maxValue:Int64 {
        get {
            return _maxValue
        }
    }
    
    private var _body:Any?
    private var _error:Error?
    
    public func body() -> (Any?,Error?) {
        return (_data,_error)
    }
    
}

public class KKHttp : NSObject,URLSessionDataDelegate {

    private let _identitysWithKey:NSMutableDictionary = NSMutableDictionary.init()
    private let _tasksWithIdentity:NSMutableDictionary = NSMutableDictionary.init()
    private let _sessionTasks:NSMutableDictionary = NSMutableDictionary.init()
    private let _responsesWithIdentity:NSMutableDictionary = NSMutableDictionary.init()
    
    private let _io:DispatchQueue = DispatchQueue.init(label: "cn.kkserver.KKHttpIO")
    
    private var _session:URLSession?
    
    public var session:URLSession {
        get {
            return _session!
        }
    }
    
    public override init() {
        super.init()
        _session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        onInit()
    }
    
    public init(configuration: URLSessionConfiguration) {
        super.init()
        _session = URLSession.init(configuration: configuration, delegate: self, delegateQueue: OperationQueue.current)
        onInit()
    }
    
    internal func onInit() ->Void {
        
    }
    
    public func send(_ options:KKHttpOptions, _ weakObject:AnyObject?) throws -> KKHttpTask {
        
        let key = options.key
        
        if key != nil {
            let identity = _identitysWithKey.object(forKey: (key as NSString?)!)
            if identity != nil {
                let tasks:NSMutableArray? = _tasksWithIdentity.object(forKey: identity!) as! NSMutableArray?
                if tasks != nil {
                    let v = KKHttpTask.init(http: self, options: options, weakObject: weakObject, identity:(identity as! NSNumber).intValue)
                    tasks!.add(v)
                    return v
                }
            }
        }
        
        let sessionTask = _session!.dataTask(with: try options.request())
        
        let v = KKHttpTask.init(http: self, options: options, weakObject: weakObject, identity:sessionTask.taskIdentifier)
        
        let identity = NSNumber.init(value: sessionTask.taskIdentifier);
        
        if key != nil {
            _identitysWithKey.setObject(identity, forKey: (key as NSString?)!)
        }
        
        var tasks:NSMutableArray? = _tasksWithIdentity.object(forKey: identity) as! NSMutableArray?
        
        if tasks == nil {
            tasks = NSMutableArray.init(capacity: 4)
            _tasksWithIdentity.setObject(tasks, forKey: identity)
        }
        
        tasks!.add(v)
        
        _sessionTasks.setObject(sessionTask, forKey: identity)
        _responsesWithIdentity.setObject(KKHttpResponse.init(options: options), forKey: identity)
        
        sessionTask.resume()
        
        return v
    }
    
    public func cancel(_ weakObject:AnyObject? ) -> Void {
        
        var idens:[NSNumber] = []
        
        for (key,tasks) in _tasksWithIdentity {
            
            let v = tasks as! NSMutableArray
            var i = 0
            
            while i < v.count {
                
                let task = v.object(at:i) as! KKHttpTask
                
                if task.weakObject === weakObject {
                    v.remove(at:i)
                }
                else {
                    i = i + 1
                }
            }
            
            if v.count == 0 {
                idens.append(key as! NSNumber)
            }
        
        }
        
        for iden in idens {
            
            let v:URLSessionTask? = _sessionTasks.object(forKey: iden) as! URLSessionTask?
            
            if v != nil {
                v!.cancel()
                _sessionTasks.removeObject(forKey: iden)
                _responsesWithIdentity.removeObject(forKey: iden)
            }
            
            var keys:[NSString] = []
            
            for (key,value) in _identitysWithKey {
                
                if (value as! NSNumber) == iden {
                    keys.append(key as! NSString)
                }
                
            }
            
            for key in keys {
                _identitysWithKey.removeObject(forKey: key)
            }
        }
        
    }
    
    internal func cancel(task:KKHttpTask) -> Void {
        
        let iden = NSNumber.init(value: task.identity)
        
        let tasks = _tasksWithIdentity.object(forKey: iden) as! NSMutableArray?
        
        if tasks != nil {
            
            tasks!.remove(task)
            
            if tasks!.count == 0 {
                
                _tasksWithIdentity.removeObject(forKey: iden)
                
                if task.key != nil {
                    _identitysWithKey.removeObject(forKey: (task.key as NSString?)!)
                }
                
                let v:URLSessionTask? = _sessionTasks.object(forKey: iden) as! URLSessionTask?
                
                if v != nil {
                    v!.cancel()
                    _sessionTasks.removeObject(forKey: iden)
                    _responsesWithIdentity.removeObject(forKey: iden)
                }
                
            }
        }
        
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Swift.Void) {
        completionHandler(request)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        
        let iden = NSNumber.init(value: dataTask.taskIdentifier)
        
        let r  = _responsesWithIdentity.object(forKey: iden) as! KKHttpResponse?
        
        r?.onResponse(response as! HTTPURLResponse)
        
        let tasks = _tasksWithIdentity.object(forKey: iden) as! NSMutableArray?
        
        if tasks != nil {
            
            for task in tasks! {
                
                let v = task as! KKHttpTask
                
                v.options.onResponse?(response as! HTTPURLResponse)
                
            }
            
        }
        
        completionHandler(URLSession.ResponseDisposition.allow)
    }
    
    /*
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        
    }
    */
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        let iden = NSNumber.init(value: dataTask.taskIdentifier)
        
        let r  = _responsesWithIdentity.object(forKey: iden) as! KKHttpResponse?
        
        if r != nil {
            
            if r!.background {
                _io.async {
                    r!.onData(data)
                }
            } else {
                r!.onData(data)
            }
            
            r!.value = r!.value + data.count
            
            let tasks = _tasksWithIdentity.object(forKey: iden) as! NSMutableArray?
            
            if tasks != nil {
                
                for task in tasks! {
                    
                    let v = task as! KKHttpTask
                    
                    v.options.onProcess?(r!.value,r!.maxValue)
                    
                }
                
            }
        }
        
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        let iden = NSNumber.init(value: task.taskIdentifier)
        
        let tasks = _tasksWithIdentity.object(forKey: iden) as! NSMutableArray?
        
        if tasks != nil {
            
            for task in tasks! {
                
                let v = task as! KKHttpTask
                
                v.options.onProcess?(totalBytesSent,totalBytesExpectedToSend)
                
            }
            
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        let iden = NSNumber.init(value: task.taskIdentifier)
        
        let r  = _responsesWithIdentity.object(forKey: iden) as! KKHttpResponse?
        
        if r != nil {
            
            let tasks = _tasksWithIdentity.object(forKey: iden) as! NSMutableArray?
            
            let fn = {
            
                if tasks != nil {
                    
                    for task in tasks! {
                        
                        let v = task as! KKHttpTask
                        
                        if error == nil {
                            let (data,err) = r!.body()
                            v.options.onLoad?(data,err)
                        } else {
                            v.options.onFail?(error)
                        }
                        
                        
                    }
                    
                }
                
            }
            
            if r!.background {
                
                let q = session.delegateQueue
                
                _io.async {
                    
                    if error == nil {
                        r!.onLoad()
                    } else {
                        r!.onFail(error: error)
                    }
                    
                    q.addOperation(fn)
                }
                
            } else {
                
                if error == nil {
                    r!.onLoad()
                } else {
                    r!.onFail(error: error)
                }
                
                fn()
            }
            
            _tasksWithIdentity.removeObject(forKey: iden)
            _sessionTasks.removeObject(forKey: iden)
            _responsesWithIdentity.removeObject(forKey: iden)
            
            var keys:[NSString] = []
            
            for (key,value) in _identitysWithKey {
                if (value as! NSNumber) == iden {
                    keys.append(key as! NSString)
                }
            }
            
            for key in keys {
                _identitysWithKey.removeObject(forKey: key)
            }
        }
        
    }
    
    private static var _main:KKHttp?
    
    public static var main:KKHttp {
        get {
            if(_main == nil) {
                _main = KKHttp.init()
            }
            return _main!
        }
    }

    
}
