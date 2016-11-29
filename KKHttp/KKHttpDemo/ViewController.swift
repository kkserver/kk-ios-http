//
//  ViewController.swift
//  KKHttpDemo
//
//  Created by zhanghailong on 2016/11/29.
//  Copyright © 2016年 kkserver.cn. All rights reserved.
//

import UIKit
import KKHttp

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        _ = try? KKHttp.main.get("http://www.baidu.com/img/baidu_jgylogo3.gif", nil, KKHttpOptions.TypeImage, { (data:Any?, error:Error?) in
            
                print(data)
            
            }, { (error:Error?) in
                
                print(error)
                
            }, self)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

