//
//  main.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Darwin
import Foundation

/// Supported command-line options for the local static server.
struct ServerConfiguration {
    let port: UInt16
    let rootURL: URL

    /// Parse CLI options while keeping sensible defaults for local preview use.
    static func parse(arguments: [String], currentDirectoryPath: String) throws -> ServerConfiguration {
        var port: UInt16 = 8080
        var rootURL = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)

        var iterator = arguments.makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--help", "-h":
                printHelp()
                exit(0)
            case "--port":
                guard let value = iterator.next(), !value.isEmpty else {
                    throw SiteServerError.missingArgument("--port")
                }
                guard let parsedPort = UInt16(value) else {
                    throw SiteServerError.invalidPort(value)
                }
                port = parsedPort
            case "--root":
                guard let value = iterator.next(), !value.isEmpty else {
                    throw SiteServerError.missingArgument("--root")
                }
                rootURL = URL(fileURLWithPath: value, isDirectory: true).standardizedFileURL
            default:
                throw SiteServerError.unknownArgument(argument)
            }
        }

        return ServerConfiguration(port: port, rootURL: rootURL)
    }

    /// Print usage instructions for local development.
    static func printHelp() {
        let help = """
        SiteServer serves the generated static site from a local folder.

        Usage:
          swift run SiteServer [--port 8080] [--root /path/to/site]

        Defaults:
          --port 8080
          --root current working directory
        """

        print(help)
    }
}

/// Errors surfaced by the local server configuration and request lifecycle.
enum SiteServerError: Error, LocalizedError {
    case acceptFailed(String)
    case bindFailed(String)
    case invalidPort(String)
    case invalidRoot(URL)
    case listenFailed(String)
    case missingArgument(String)
    case sendFailed(String)
    case socketFailed(String)
    case unknownArgument(String)

    var errorDescription: String? {
        switch self {
        case let .acceptFailed(message):
            return "Failed to accept a connection: \(message)"
        case let .bindFailed(message):
            return "Failed to bind the local server: \(message)"
        case let .invalidPort(value):
            return "Invalid port value '\(value)'."
        case let .invalidRoot(url):
            return "Static root does not exist: \(url.path)"
        case let .listenFailed(message):
            return "Failed to listen for connections: \(message)"
        case let .missingArgument(flag):
            return "Missing value for \(flag)."
        case let .sendFailed(message):
            return "Failed to send the response: \(message)"
        case let .socketFailed(message):
            return "Failed to create the local server socket: \(message)"
        case let .unknownArgument(argument):
            return "Unknown argument '\(argument)'."
        }
    }
}

/// A minimal HTTP request parsed from the incoming connection payload.
struct HTTPRequest {
    let method: String
    let target: String

    /// Parse the request line and extract the HTTP method and target path.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let rawRequest = String(data: data, encoding: .utf8) else {
            return nil
        }

        let requestLine = rawRequest.split(separator: "\r\n", maxSplits: 1, omittingEmptySubsequences: true).first
        let components = requestLine?.split(separator: " ", omittingEmptySubsequences: true) ?? []

        guard components.count >= 2 else {
            return nil
        }

        return HTTPRequest(method: String(components[0]), target: String(components[1]))
    }
}

/// Response payload returned by the local static server.
struct HTTPResponse {
    let statusCode: Int
    let reasonPhrase: String
    let headers: [String: String]
    let body: Data

    /// Encode the HTTP response into wire-format bytes.
    func encoded(headOnly: Bool) -> Data {
        var headerLines = ["HTTP/1.1 \(statusCode) \(reasonPhrase)"]

        for key in headers.keys.sorted() {
            if let value = headers[key] {
                headerLines.append("\(key): \(value)")
            }
        }

        headerLines.append("")
        headerLines.append("")

        var responseData = Data(headerLines.joined(separator: "\r\n").utf8)
        if !headOnly {
            responseData.append(body)
        }
        return responseData
    }
}

/// Resolves requests and maps them to static files inside the generated site.
struct StaticSiteResponder {
    let rootURL: URL

    /// Build a response for a raw HTTP request payload.
    func response(for data: Data) -> HTTPResponse {
        guard let request = HTTPRequest.parse(data) else {
            return errorResponse(statusCode: 400, reasonPhrase: "Bad Request", message: "Malformed HTTP request.")
        }

        let method = request.method.uppercased()
        guard method == "GET" || method == "HEAD" else {
            return errorResponse(
                statusCode: 405,
                reasonPhrase: "Method Not Allowed",
                message: "Only GET and HEAD are supported.",
                extraHeaders: ["Allow": "GET, HEAD"]
            )
        }

        do {
            let fileURL = try resolveFileURL(for: request.target)
            let body = try Data(contentsOf: fileURL)
            let mimeType = mimeType(for: fileURL.pathExtension)
            log("\(method) \(request.target) -> 200")

            return HTTPResponse(
                statusCode: 200,
                reasonPhrase: "OK",
                headers: defaultHeaders(
                    contentType: mimeType,
                    contentLength: body.count
                ),
                body: body
            )
        } catch {
            if let cocoaError = error as? CocoaError, cocoaError.code == .fileReadNoSuchFile {
                log("\(method) \(request.target) -> 404")
                return notFoundResponse()
            }

            if case SiteServerError.invalidRoot = error {
                log("\(method) \(request.target) -> 403")
                return errorResponse(statusCode: 403, reasonPhrase: "Forbidden", message: "Path resolution failed.")
            }

            if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileReadNoPermissionError {
                log("\(method) \(request.target) -> 403")
                return errorResponse(statusCode: 403, reasonPhrase: "Forbidden", message: "Path resolution failed.")
            }

            log("\(method) \(request.target) -> 500 (\(error.localizedDescription))")
            return errorResponse(statusCode: 500, reasonPhrase: "Internal Server Error", message: "Static file lookup failed.")
        }
    }

    /// Return the custom site 404 page when available, otherwise fall back to plain text.
    private func notFoundResponse() -> HTTPResponse {
        let fallbackURL = rootURL.appendingPathComponent("404.html")

        if let body = try? Data(contentsOf: fallbackURL) {
            return HTTPResponse(
                statusCode: 404,
                reasonPhrase: "Not Found",
                headers: defaultHeaders(
                    contentType: "text/html; charset=utf-8",
                    contentLength: body.count
                ),
                body: body
            )
        }

        return errorResponse(statusCode: 404, reasonPhrase: "Not Found", message: "File not found.")
    }

    /// Resolve a request target into a safe file path inside the site root.
    private func resolveFileURL(for target: String) throws -> URL {
        let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "/"
        let decodedPath = path.removingPercentEncoding ?? path
        let trimmedPath = decodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var candidateURL = rootURL
        let fileManager = FileManager.default

        if trimmedPath.isEmpty {
            candidateURL = rootURL.appendingPathComponent("index.html")
        } else {
            candidateURL = rootURL.appendingPathComponent(trimmedPath)
        }

        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            candidateURL = candidateURL.appendingPathComponent("index.html")
        } else if candidateURL.pathExtension.isEmpty,
                  !fileManager.fileExists(atPath: candidateURL.path) {
            let directoryIndexURL = candidateURL.appendingPathComponent("index.html")
            if fileManager.fileExists(atPath: directoryIndexURL.path) {
                candidateURL = directoryIndexURL
            }
        }

        let standardizedCandidate = candidateURL.standardizedFileURL
        let normalizedRootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"

        guard standardizedCandidate.path == rootURL.path || standardizedCandidate.path.hasPrefix(normalizedRootPath) else {
            throw SiteServerError.invalidRoot(standardizedCandidate)
        }

        return standardizedCandidate
    }

    /// Build default headers shared by all responses.
    private func defaultHeaders(contentType: String, contentLength: Int, extraHeaders: [String: String] = [:]) -> [String: String] {
        var headers = [
            "Cache-Control": "no-store",
            "Connection": "close",
            "Content-Length": String(contentLength),
            "Content-Type": contentType
        ]

        extraHeaders.forEach { headers[$0.key] = $0.value }
        return headers
    }

    /// Build a plaintext error response.
    private func errorResponse(statusCode: Int, reasonPhrase: String, message: String, extraHeaders: [String: String] = [:]) -> HTTPResponse {
        let body = Data("\(message)\n".utf8)
        return HTTPResponse(
            statusCode: statusCode,
            reasonPhrase: reasonPhrase,
            headers: defaultHeaders(
                contentType: "text/plain; charset=utf-8",
                contentLength: body.count,
                extraHeaders: extraHeaders
            ),
            body: body
        )
    }

    /// Map file extensions to the content types needed for local preview.
    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "css":
            return "text/css; charset=utf-8"
        case "gif":
            return "image/gif"
        case "html":
            return "text/html; charset=utf-8"
        case "ico":
            return "image/x-icon"
        case "jpeg", "jpg":
            return "image/jpeg"
        case "js":
            return "text/javascript; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "png":
            return "image/png"
        case "svg":
            return "image/svg+xml"
        case "txt":
            return "text/plain; charset=utf-8"
        case "webp":
            return "image/webp"
        case "xml":
            return "application/xml; charset=utf-8"
        default:
            return "application/octet-stream"
        }
    }

    /// Keep local preview logging minimal and readable.
    private func log(_ message: String) {
        print("[SiteServer] \(message)")
    }
}

/// A blocking POSIX HTTP server for local development previews.
final class StaticSiteServer {
    private let configuration: ServerConfiguration
    private let responder: StaticSiteResponder
    private let socketDescriptor: Int32

    init(configuration: ServerConfiguration) throws {
        self.configuration = configuration

        var isDirectory: ObjCBool = false
        let standardizedRootURL = configuration.rootURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: standardizedRootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SiteServerError.invalidRoot(standardizedRootURL)
        }

        responder = StaticSiteResponder(rootURL: standardizedRootURL)
        socketDescriptor = try StaticSiteServer.makeSocket(port: configuration.port)
    }

    deinit {
        close(socketDescriptor)
    }

    /// Start the local server and block until the process is terminated.
    func start() throws {
        signal(SIGPIPE, SIG_IGN)
        print("Serving \(responder.rootURL.path) at http://localhost:\(configuration.port)")

        while true {
            let clientDescriptor = accept(socketDescriptor, nil, nil)

            if clientDescriptor < 0 {
                if errno == EINTR {
                    continue
                }

                throw SiteServerError.acceptFailed(StaticSiteServer.errorMessage())
            }

            do {
                try handleConnection(clientDescriptor)
            } catch {
                fputs("SiteServer warning: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    /// Accept one request, write one response, then close the connection.
    private func handleConnection(_ clientDescriptor: Int32) throws {
        defer {
            shutdown(clientDescriptor, SHUT_RDWR)
            close(clientDescriptor)
        }

        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let bytesRead = recv(clientDescriptor, &buffer, buffer.count, 0)

        guard bytesRead > 0 else {
            return
        }

        let requestData = Data(buffer.prefix(Int(bytesRead)))
        let response = responder.response(for: requestData)
        let headOnly = HTTPRequest.parse(requestData)?.method.uppercased() == "HEAD"
        try writeAll(response.encoded(headOnly: headOnly), to: clientDescriptor)
    }

    /// Send all response bytes before returning.
    private func writeAll(_ data: Data, to clientDescriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }

            var totalBytesSent = 0

            while totalBytesSent < rawBuffer.count {
                let bytesRemaining = rawBuffer.count - totalBytesSent
                let bytesSent = send(clientDescriptor, baseAddress.advanced(by: totalBytesSent), bytesRemaining, 0)

                if bytesSent < 0 {
                    throw SiteServerError.sendFailed(StaticSiteServer.errorMessage())
                }

                totalBytesSent += bytesSent
            }
        }
    }

    /// Create, bind, and listen on the TCP socket used for local preview.
    private static func makeSocket(port: UInt16) throws -> Int32 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)

        guard descriptor >= 0 else {
            throw SiteServerError.socketFailed(errorMessage())
        }

        var shouldReuseAddress: Int32 = 1
        if setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &shouldReuseAddress, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            close(descriptor)
            throw SiteServerError.socketFailed(errorMessage())
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(descriptor)
            throw SiteServerError.bindFailed(errorMessage())
        }

        guard listen(descriptor, SOMAXCONN) == 0 else {
            close(descriptor)
            throw SiteServerError.listenFailed(errorMessage())
        }

        return descriptor
    }

    /// Convert the current `errno` value into a readable message.
    private static func errorMessage() -> String {
        String(cString: strerror(errno))
    }
}

/// Convert the current `errno` value into a readable message.
private func errorMessage() -> String {
    String(cString: strerror(errno))
}

/// Boot the local static server for development previews.
do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let configuration = try ServerConfiguration.parse(
        arguments: arguments,
        currentDirectoryPath: FileManager.default.currentDirectoryPath
    )

    let server = try StaticSiteServer(configuration: configuration)
    try server.start()
} catch {
    fputs("SiteServer failed: \(error.localizedDescription)\n", stderr)
    ServerConfiguration.printHelp()
    exit(1)
}
