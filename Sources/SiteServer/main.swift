//
//  main.swift
//  Loic Engineer Portfolio
//
//  Created by Loïc Lavergne on 25/03/2026
//  Copyright © 2026 Loïc Lavergne. All rights reserved.
//

import Dispatch
import Foundation
import Network

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
    case invalidPort(String)
    case missingArgument(String)
    case unknownArgument(String)
    case invalidRoot(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidPort(value):
            return "Invalid port value '\(value)'."
        case let .missingArgument(flag):
            return "Missing value for \(flag)."
        case let .unknownArgument(argument):
            return "Unknown argument '\(argument)'."
        case let .invalidRoot(url):
            return "Static root does not exist: \(url.path)"
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

/// Serves static files from the generated site output folder over loopback HTTP.
final class StaticSiteServer: @unchecked Sendable {
    private let configuration: ServerConfiguration
    private let listener: NWListener
    private let rootURL: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "loic.engineer.siteserver.listener")
    private var signalSource: DispatchSourceSignal?

    init(configuration: ServerConfiguration) throws {
        self.configuration = configuration
        self.rootURL = configuration.rootURL.standardizedFileURL

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SiteServerError.invalidRoot(rootURL)
        }

        guard let port = NWEndpoint.Port(rawValue: configuration.port) else {
            throw SiteServerError.invalidPort(String(configuration.port))
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters, on: port)
        configureLifecycle()
    }

    /// Start the listener and keep the process alive until interrupted.
    func start() {
        listener.start(queue: queue)
        installSignalHandler()
        dispatchMain()
    }

    /// Configure lifecycle and connection handling callbacks.
    private func configureLifecycle() {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }

            switch state {
            case .ready:
                print("Serving \(self.rootURL.path) at http://localhost:\(self.configuration.port)")
            case let .failed(error):
                fputs("SiteServer failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
    }

    /// Allow clean termination with Ctrl-C during local preview sessions.
    private func installSignalHandler() {
        signal(SIGINT, SIG_IGN)

        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signalSource.setEventHandler { [weak self] in
            self?.listener.cancel()
            print("\nSiteServer stopped")
            exit(0)
        }
        signalSource.resume()
        self.signalSource = signalSource
    }

    /// Read a single request from the connection and reply once.
    private func handle(_ connection: NWConnection) {
        let connectionQueue = DispatchQueue(label: "loic.engineer.siteserver.connection.\(UUID().uuidString)")
        connection.start(queue: connectionQueue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                self.log("Connection error: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            guard let data else {
                connection.cancel()
                return
            }

            let response = self.response(for: data)
            let headOnly = HTTPRequest.parse(data)?.method.uppercased() == "HEAD"
            connection.send(content: response.encoded(headOnly: headOnly), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    /// Build a response for a raw HTTP request payload.
    private func response(for data: Data) -> HTTPResponse {
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
                return errorResponse(statusCode: 404, reasonPhrase: "Not Found", message: "File not found.")
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

    /// Resolve a request target into a safe file path inside the site root.
    private func resolveFileURL(for target: String) throws -> URL {
        let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "/"
        let decodedPath = path.removingPercentEncoding ?? path
        let trimmedPath = decodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var candidateURL = rootURL

        if trimmedPath.isEmpty {
            candidateURL = rootURL.appendingPathComponent("index.html")
        } else {
            candidateURL = rootURL.appendingPathComponent(trimmedPath)
        }

        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: candidateURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            candidateURL = candidateURL.appendingPathComponent("index.html")
        } else if !candidateURL.pathExtension.isEmpty == false,
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

/// Boot the local static server for development previews.
do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let configuration = try ServerConfiguration.parse(
        arguments: arguments,
        currentDirectoryPath: FileManager.default.currentDirectoryPath
    )

    let server = try StaticSiteServer(configuration: configuration)
    server.start()
} catch {
    fputs("SiteServer failed: \(error.localizedDescription)\n", stderr)
    ServerConfiguration.printHelp()
    exit(1)
}
