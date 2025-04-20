//
//  ViewController.swift
//  Web View App
//
//  Created by John Cotton on 5/3/18.
// 
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Do any additional setup after loading the view, typically from a nib.
        //加载本地HTML文件
        if let htmlPath = Bundle.main.path(forResource: "www/index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("无法找到本地HTML文件")
        }
        
        // // 设置WebView为全屏，但不隐藏状态栏
        webView.frame = self.view.bounds
        
        // 设置导航代理
        //webView.navigationDelegate = self
        
        // 获取状态栏高度并传递给WebView
        // 由于页面可能尚未加载完成，我们在didFinishNavigation中执行JavaScript
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        // MARK: - WKNavigationDelegate
        
        //func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // let statusBarHeight = UIApplication.shared.statusBarFrame.height
            // let jsString = "setStatusBarHeight(\(statusBarHeight));"
            // webView.evaluateJavaScript(jsString, completionHandler: nil)
        //}
    }
    
    
}


