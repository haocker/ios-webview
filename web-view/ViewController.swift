//
//  ViewController.swift
//  Web View App
//
//  Created by John Cotton on 5/3/18.
// 
//

import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // 设置WKWebView的userContentController
        let userContentController = WKUserContentController()
        
        // 在文档加载前注入acjsapi
        let scriptSource = """
        // 创建通用对象acjsapi来调用Swift暴露的方法，使用Proxy来动态处理方法调用
        const acjsapi = new Proxy({
            // 存储回调函数的映射
            _callbacks: new Map(),
            _callbackId: 0,
            
            // 生成唯一的回调ID
            _generateCallbackId: function() {
                return 'cb_' + this._callbackId++;
            },
            
            // 调用Swift方法
            _call: function(methodName, ...args) {
                return new Promise((resolve, reject) => {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[methodName]) {
                        const callbackId = this._generateCallbackId();
                        this._callbacks.set(callbackId, { resolve, reject });
                        
                        // 发送消息给Swift，包括回调ID和参数
                        window.webkit.messageHandlers[methodName].postMessage({
                            callbackId: callbackId,
                            args: args
                        });
                    } else {
                        reject(new Error(`方法 ${methodName} 不可用`));
                    }
                });
            },
            
            // 接收Swift的回调
            callback: function(callbackId, result, error) {
                if (this._callbacks.has(callbackId)) {
                    const { resolve, reject } = this._callbacks.get(callbackId);
                    if (error) {
                        reject(new Error(error));
                    } else {
                        resolve(result);
                    }
                    this._callbacks.delete(callbackId);
                }
            }
        }, {
            get: function(target, property, receiver) {
                if (typeof property === 'string' && property !== 'callback' && !property.startsWith('_')) {
                    return function(...args) {
                        return target._call(property, ...args);
                    };
                }
                return Reflect.get(target, property, receiver);
            }
        });
        
        // 暴露acjsapi到全局作用域
        window.acjsapi = acjsapi;
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)
        
        
        userContentController.add(self, name: "getStatusBarHeight")
        
        // 创建WKWebView配置
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        // 通过编程方式创建WKWebView
        webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        // 加载本地HTML文件
        if let htmlPath = Bundle.main.path(forResource: "www/index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("无法找到本地HTML文件")
        }
        
        // 设置WebView为全屏，考虑安全区域以实现沉浸式效果
        if #available(iOS 11.0, *) {
            webView.frame = self.view.safeAreaLayoutGuide.layoutFrame
        } else {
            webView.frame = self.view.bounds
        }
        
        // 禁止WebView缩放
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
    
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 实现WKScriptMessageHandler协议方法
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "getStatusBarHeight" {
            guard let body = message.body as? [String: Any],
                  let callbackId = body["callbackId"] as? String else {
                return
            }
            
            let statusBarHeight = UIApplication.shared.statusBarFrame.height
            let jsString = "acjsapi.callback('\(callbackId)', \(statusBarHeight), null);"
            webView.evaluateJavaScript(jsString, completionHandler: nil)
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
    
    
}


