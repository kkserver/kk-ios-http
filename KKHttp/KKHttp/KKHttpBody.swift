//
//  KKHttpBody.swift
//  KKHttp
//
//  Created by zhanghailong on 2016/11/28.
//  Copyright © 2016年 kkserver.cn. All rights reserved.
//

import UIKit

public class KKHttpBody: NSObject {
    
    private static let TOKEN = "8jej23fkdxxd".data(using: String.Encoding.utf8)!
    private static let BEGIN_TOKEN = "--8jej23fkdxxd".data(using: String.Encoding.utf8)!
    private static let END_TOKEN = "--8jej23fkdxxd--".data(using: String.Encoding.utf8)!
    private static let MUTILPART_TYPE = "multipart/form-data; boundary=8jej23fkdxxd"
    private static let URLENCODED_TYPE = "application/x-www-form-urlencoded"
    
    private var _items:[Item] = []
    private var _type:String?
    private var _data:Data?
    
    public func add(key:String,value:String) -> Void {
        _items.append(ValueItem.init(key: key, value: value))
    }
    
    public func add(key:String,data:Data,type:String,name:String) -> Void {
        _items.append(DataItem.init(key: key, data: data, type:type, name:name))
    }
    
    public func add(key:String,path:String,type:String) -> Void {
        let v = try? Data.init(contentsOf: URL.init(fileURLWithPath: path))
        if v != nil {
            add(key: key, data: v!, type: type, name: (path as NSString).lastPathComponent)
        }
    }
    
    private func gen() ->Void {
        
        if( mutilpart ) {
            
            _type = KKHttpBody.URLENCODED_TYPE
            _data = Data.init()
            
            for item in _items {
                if item is ValueItem {
                    let v = item as! ValueItem
                    if _data!.count != 0 {
                        _data!.append("&".data(using: String.Encoding.utf8)!)
                    }
                    _data!.append(v.key.data(using: String.Encoding.utf8)!)
                    _data!.append("=".data(using: String.Encoding.utf8)!)
                    _data!.append(v.value.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!.data(using: String.Encoding.utf8)!)
                }
            }
            
        }
        else {
            
            _type = KKHttpBody.MUTILPART_TYPE
            _data = Data.init()
            
            for item in _items {
                
                if item is ValueItem {
                    let v = item as! ValueItem
                    
                    _data!.append(KKHttpBody.BEGIN_TOKEN)
                    _data!.append("\r\n".data(using: String.Encoding.utf8)!)
                    _data!.append(String.init(format: "Content-Disposition: form-data; name=\"%@\"", v.key).data(using: String.Encoding.utf8)!)
                    _data!.append("\r\n\r\n".data(using: String.Encoding.utf8)!)
                    _data!.append(v.value.data(using: String.Encoding.utf8)!)
                    _data!.append("\r\n".data(using: String.Encoding.utf8)!)
                    
                } else if item is DataItem {
                    
                    let v = item as! DataItem
                    
                    _data!.append(KKHttpBody.BEGIN_TOKEN)
                    _data!.append("\r\n".data(using: String.Encoding.utf8)!)
                    _data!.append(String.init(format: "Content-Disposition: form-data; name=\"%@\"", v.key).data(using: String.Encoding.utf8)!)
                    
                    if v.name != "" {
                        _data!.append(String.init(format: "; filename=\"%@\"", v.name).data(using: String.Encoding.utf8)!)
                    }
                    
                    _data!.append("\r\n".data(using: String.Encoding.utf8)!)
                    _data!.append(String.init(format: "Content-Type: %d\r\n", v.data.count).data(using: String.Encoding.utf8)!)
                    _data!.append("Content-Transfer-Encoding: binary\r\n\r\n".data(using: String.Encoding.utf8)!)
                    
                    _data!.append(v.data)
                    
                    _data!.append("\r\n".data(using: String.Encoding.utf8)!)
                }
                
            }
            
            _data!.append(KKHttpBody.END_TOKEN)
            
        }
        
    }
    
    public var type:String {
        get {
            if(_type == nil) {
                gen()
            }
            return _type!
        }
    }
    
    public var mutilpart:Bool {
        get {
            for item in _items {
                if item is DataItem {
                    return true
                }
            }
            return false
        }
    }
    
    public var data:Data {
        get {
            if(_data == nil) {
                gen()
            }
            return _data!
        }
    }
    
    private class Item {
        public let key:String
        
        public init(key:String) {
            self.key = key;
        }
    }
    
    private class ValueItem : Item {
        
        public let value:String
        
        public init(key:String,value:String) {
            self.value = value
            super.init(key:key)
        }
    }
    
    private class DataItem : Item {
        public var data:Data
        public var type:String
        public var name:String
        
        public init(key:String,data:Data,type:String,name:String) {
            self.data = data
            self.type = type
            self.name = name
            super.init(key:key)
        }
    }
}
