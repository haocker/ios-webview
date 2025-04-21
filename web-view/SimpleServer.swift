import Foundation

class SimpleServer {
    private static var serverSocket: Int32 = -1
    private static var clientSockets: [Int32] = []
    private static var documentRoot: String = ""
    private static var port: UInt16 = 0
    private static let maxConnections = 10
    
    static func start(documentRoot: String, port: Int = 0) {
        self.documentRoot = documentRoot
        if port == 0 {
            self.port = findAvailablePort()
        } else {
            self.port = UInt16(port)
        }
        setupServer()
        startServer()
    }
    
    private static func setupServer() {
        // 创建 socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("创建 socket 失败: \(errno)")
            return
        }
        
        // 设置 socket 选项
        var reuseAddr = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int>.size))
        
        // 设置地址结构
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = htons(port)
        addr.sin_addr.s_addr = INADDR_ANY
        
        // 绑定 socket
        let bindResult = withUnsafePointer(to: &addr) { pointer in
            bind(serverSocket, UnsafeRawPointer(pointer).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        
        guard bindResult == 0 else {
            print("绑定失败: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }
        
        // 监听连接
        guard listen(serverSocket, Int32(maxConnections)) == 0 else {
            print("监听失败: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }
        
        print("服务器启动在端口 \(port)")
    }
    
    private static func startServer() {
        guard serverSocket >= 0 else {
            print("服务器未初始化")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            while true {
                var clientAddr = sockaddr_in()
                var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                
                let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { pointer in
                    accept(serverSocket, UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: sockaddr.self), &clientAddrLen)
                }
                
                guard clientSocket >= 0 else {
                    print("接受连接失败: \(errno)")
                    continue
                }
                
                clientSockets.append(clientSocket)
                print("新连接已接受: \(clientSocket)")
                
                // 处理客户端请求
                handleClient(clientSocket)
            }
        }
    }
    
    private static func handleClient(_ clientSocket: Int32) {
        // 读取请求
        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        
        guard bytesRead > 0 else {
            print("读取请求失败: \(errno)")
            close(clientSocket)
            if let index = clientSockets.firstIndex(of: clientSocket) {
                clientSockets.remove(at: index)
            }
            return
        }
        
        let request = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? "无法解码请求"
        print("收到请求: \(request)")
        
        // 解析请求路径
        var filePath = ""
        if let range = request.range(of: "GET ") {
            let getRequest = request[range.upperBound...]
            if let endRange = getRequest.range(of: " HTTP") {
                let path = getRequest[..<endRange.lowerBound]
                filePath = String(path).trimmingCharacters(in: .whitespaces)
                if filePath == "/" {
                    filePath = "/index.html"
                }
            }
        }
        
        // 读取文件内容
        let fullPath = documentRoot + filePath
        var response = ""
        if let fileData = FileManager.default.contents(atPath: fullPath) {
            let fileExtension = (filePath as NSString).pathExtension.lowercased()
            var contentType = "text/plain"
            
            switch fileExtension {
            case "html":
                contentType = "text/html"
            case "css":
                contentType = "text/css"
            case "js":
                contentType = "application/javascript"
            case "png":
                contentType = "image/png"
            case "jpg", "jpeg":
                contentType = "image/jpeg"
            case "gif":
                contentType = "image/gif"
            default:
                contentType = "application/octet-stream"
            }
            
            response = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(fileData.count)\r\n\r\n"
            let responseHeaderData = response.data(using: .utf8)!
            let _ = responseHeaderData.withUnsafeBytes { bufferPointer in
                write(clientSocket, bufferPointer.baseAddress, responseHeaderData.count)
            }
            let _ = fileData.withUnsafeBytes { bufferPointer in
                write(clientSocket, bufferPointer.baseAddress, fileData.count)
            }
        } else {
            response = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
            let responseData = response.data(using: .utf8)!
            let _ = responseData.withUnsafeBytes { bufferPointer in
                write(clientSocket, bufferPointer.baseAddress, responseData.count)
            }
        }
        
        // 关闭连接
        close(clientSocket)
        if let index = clientSockets.firstIndex(of: clientSocket) {
            clientSockets.remove(at: index)
        }
    }
    
    private static func htons(_ value: UInt16) -> UInt16 {
        return (value << 8) + (value >> 8)
    }
    private static func findAvailablePort() -> UInt16 {
        var testSocket: Int32 = -1
        var availablePort: UInt16 = 0
        
        for port in 8000...9000 {
            testSocket = socket(AF_INET, SOCK_STREAM, 0)
            guard testSocket >= 0 else {
                continue
            }
            
            var reuseAddr = 1
            setsockopt(testSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int>.size))
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = htons(UInt16(port))
            addr.sin_addr.s_addr = INADDR_ANY
            
            let bindResult = withUnsafePointer(to: &addr) { pointer in
                bind(testSocket, UnsafeRawPointer(pointer).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
            }
            
            if bindResult == 0 {
                availablePort = UInt16(port)
                close(testSocket)
                break
            }
            
            close(testSocket)
        }
        
        if availablePort == 0 {
            print("未找到可用端口")
            return 8080 // 默认端口作为备用
        }
        
        print("找到可用端口: \(availablePort)")
        return availablePort
    }
}