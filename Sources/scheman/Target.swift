import UniformTypeIdentifiers

/// What a user can ask to handle: a URL scheme or a file type.
enum Target {
    case scheme(String)
    case type(UTType)

    var label: String {
        switch self {
        case .scheme(let name): "\(name)://"
        case .type(let type): type.identifier
        }
    }
}

struct TargetError: Error, CustomStringConvertible {
    let description: String
}

/// Infers the kind from the text:
/// `mailto`, `mailto:`, `mailto://` -> scheme; `.md` -> extension;
/// `text/plain` -> MIME type; `public.json` -> UTI.
func parseTarget(_ raw: String) throws -> Target {
    let text = raw.trimmingCharacters(in: .whitespaces)
    if text.hasPrefix(".") {
        let ext = String(text.dropFirst())
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else {
            throw TargetError(description: "invalid extension '\(raw)'")
        }
        return .type(type)
    }
    if text.contains("/") && !text.contains(":") {
        guard let type = UTType(mimeType: text) else {
            throw TargetError(description: "unknown MIME type '\(raw)'")
        }
        return .type(type)
    }
    if text.contains(".") && !text.contains(":") {
        guard let type = UTType(text) else {
            throw TargetError(description: "unknown UTI '\(raw)'")
        }
        return .type(type)
    }
    var scheme = text
    if scheme.hasSuffix("://") { scheme.removeLast(3) } else if scheme.hasSuffix(":") { scheme.removeLast() }
    guard !scheme.isEmpty, scheme.allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) }) else {
        throw TargetError(description: "invalid URL scheme '\(raw)'")
    }
    return .scheme(scheme.lowercased())
}
