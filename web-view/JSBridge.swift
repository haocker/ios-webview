import UIKit
import WebKit

class JSBridge: NSObject, WKScriptMessageHandler {
    // 定义方法处理逻辑的映射表
    private let methodHandlers: [String: ([String: Any]) -> Any?] = {
        var handlers: [String: ([String: Any]) -> Any?] = [:]
        
        handlers["getStatusBarHeight"] = { _ in
            if let windowScene = UIApplication.shared.windows.first?.windowScene {
                return windowScene.statusBarManager?.statusBarFrame.height ?? 0
            }
            return 0
        }
        
        handlers["getDeviceInfo"] = { _ in
            return [
                "model": UIDevice.current.model,
                "systemName": UIDevice.current.systemName,
                "systemVersion": UIDevice.current.systemVersion
            ]
        }
        
        handlers["processData"] = { params in
            if let data = params["args"] as? [String: Any],
               let input = data["data"] as? String {
                return ["processed": "处理后的数据: \(input)" ]
            }
            return ["error": "无效的输入数据"]
        }
        
        return handlers
    }()
    
    // 统一处理返回值
    private func sendResponse(callbackId: String, result: Any?) {
        if let result = result {
            if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let jsString = "acjsapi.callback('\(callbackId)', \(jsonString), null);"
                webView?.evaluateJavaScript(jsString, completionHandler: nil)
            } else {
                let jsString = "acjsapi.callback('\(callbackId)', null, 'Error in result processing');"
                webView?.evaluateJavaScript(jsString, completionHandler: nil)
            }
        } else {
            let jsString = "acjsapi.callback('\(callbackId)', null, null);"
            webView?.evaluateJavaScript(jsString, completionHandler: nil)
        }
    }
    private weak var webView: WKWebView?
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        setupMessageHandlers()
        setupUserScript()
    }
    
    private func setupMessageHandlers() {
        // 自动注册所有需要暴露给JS的方法
        let exposedMethods = Array(methodHandlers.keys)
        if let contentController = webView?.configuration.userContentController {
            for method in exposedMethods {
                contentController.add(self, name: method)
            }
        }
    }
    
    private func setupUserScript() {
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
        if let contentController = webView?.configuration.userContentController {
            contentController.addUserScript(userScript)
        }
    }
    
    // 实现WKScriptMessageHandler协议方法
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let callbackId = body["callbackId"] as? String else {
            return
        }
        
        // 动态处理暴露的方法
        if let handler = methodHandlers[message.name] {
            let result = handler(body)
            sendResponse(callbackId: callbackId, result: result)
        } else {
            let jsString = "acjsapi.callback('\(callbackId)', null, 'Method \(message.name) not implemented');"
            webView?.evaluateJavaScript(jsString, completionHandler: nil)
        }
    }
}