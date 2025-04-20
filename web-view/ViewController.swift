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
    
    var webView: WKWebView!
    // JSBridge实例
    private var jsBridge: JSBridge?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // 设置WKWebView的userContentController
        let userContentController = WKUserContentController()
        
        // 创建WKWebView配置
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        // 通过编程方式创建WKWebView
        webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        // 初始化JSBridge
        jsBridge = JSBridge(webView: webView)
        
        // 加载本地HTML文件
        if let htmlPath = Bundle.main.path(forResource: "www/index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("无法找到本地HTML文件")
        }
        
        // 设置WebView为全屏，考虑安全区域以实现沉浸式效果
        webView.frame = self.view.bounds
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // 禁止WebView缩放
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
    
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 添加返回手势支持
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 启用返回手势
        webView.allowsBackForwardNavigationGestures = true
    }
    
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                // 允许打开外部链接
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
        } else {
            decisionHandler(.allow)
        }
    }
    
    
}


