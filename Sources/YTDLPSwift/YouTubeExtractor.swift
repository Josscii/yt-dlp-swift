import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Main class for extracting YouTube video information
public class YouTubeExtractor {
    
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Validates if a URL is a valid YouTube URL
    public func isValidYouTubeURL(_ url: String) -> Bool {
        guard let urlComponents = URLComponents(string: url) else { return false }
        
        let validHosts = [
            "youtube.com", "www.youtube.com", "m.youtube.com",
            "youtu.be", "www.youtu.be"
        ]
        
        guard let host = urlComponents.host?.lowercased(),
              validHosts.contains(host) else {
            return false
        }
        
        // Check for video ID
        return extractVideoId(from: url) != nil
    }
    
    /// Extracts video ID from YouTube URL
    public func extractVideoId(from url: String) -> String? {
        guard let urlComponents = URLComponents(string: url) else { return nil }
        
        // Validate that this is a YouTube URL first
        let validHosts = [
            "youtube.com", "www.youtube.com", "m.youtube.com",
            "youtu.be", "www.youtu.be"
        ]
        
        guard let host = urlComponents.host?.lowercased(),
              validHosts.contains(host) else {
            return nil
        }
        
        // Handle youtu.be format
        if host.contains("youtu.be") {
            let path = urlComponents.path
            let videoId = String(path.dropFirst()) // Remove leading "/"
            return videoId.isEmpty ? nil : videoId
        }
        
        // Handle youtube.com format
        if let queryItems = urlComponents.queryItems {
            for item in queryItems {
                if item.name == "v", let value = item.value, !value.isEmpty {
                    return value
                }
            }
        }
        
        return nil
    }
    
    /// Extracts video information from YouTube URL
    public func extractVideoInfo(from url: String) async throws -> VideoInfo {
        guard isValidYouTubeURL(url) else {
            throw YouTubeExtractorError.invalidURL
        }
        
        guard let videoId = extractVideoId(from: url) else {
            throw YouTubeExtractorError.videoIdNotFound
        }
        
        // Get video page HTML
        let videoPageURL = "https://www.youtube.com/watch?v=\(videoId)"
        guard let pageURL = URL(string: videoPageURL) else {
            throw YouTubeExtractorError.invalidURL
        }
        
        let (data, _) = try await session.data(from: pageURL)
        guard let html = String(data: data, encoding: .utf8) else {
            throw YouTubeExtractorError.failedToDecodeHTML
        }
        
        return try parseVideoInfo(from: html, videoId: videoId)
    }
    
    /// Parses video information from HTML content
    private func parseVideoInfo(from html: String, videoId: String) throws -> VideoInfo {
        // Extract basic video information
        let title = extractTitle(from: html) ?? "Unknown Title"
        let description = extractDescription(from: html)
        let uploader = extractUploader(from: html)
        let duration = extractDuration(from: html)
        let viewCount = extractViewCount(from: html)
        let thumbnail = extractThumbnail(from: html, videoId: videoId)
        
        // Extract formats and subtitles
        let formats = try extractFormats(from: html)
        let subtitles = extractSubtitles(from: html)
        
        return VideoInfo(
            id: videoId,
            title: title,
            description: description,
            uploader: uploader,
            duration: duration,
            viewCount: viewCount,
            thumbnail: thumbnail,
            formats: formats,
            subtitles: subtitles
        )
    }
    
    /// Extracts video title from HTML
    private func extractTitle(from html: String) -> String? {
        // Look for title in meta property
        if let range = html.range(of: #"<meta property="og:title" content="([^"]*)">"#, options: .regularExpression) {
            let match = String(html[range])
            if let contentRange = match.range(of: #"content="([^"]*)"#, options: .regularExpression) {
                let content = String(match[contentRange])
                return String(content.dropFirst(9).dropLast(1)) // Remove 'content="' and '"'
            }
        }
        
        // Fallback to title tag
        if let range = html.range(of: #"<title>([^<]*)</title>"#, options: .regularExpression) {
            let match = String(html[range])
            return String(match.dropFirst(7).dropLast(8)) // Remove <title> and </title>
        }
        
        return nil
    }
    
    /// Extracts video description from HTML
    private func extractDescription(from html: String) -> String? {
        if let range = html.range(of: #"<meta property="og:description" content="([^"]*)">"#, options: .regularExpression) {
            let match = String(html[range])
            if let contentRange = match.range(of: #"content="([^"]*)"#, options: .regularExpression) {
                let content = String(match[contentRange])
                return String(content.dropFirst(9).dropLast(1)) // Remove 'content="' and '"'
            }
        }
        return nil
    }
    
    /// Extracts uploader name from HTML
    private func extractUploader(from html: String) -> String? {
        // This is a simplified extraction - in reality, YouTube's HTML structure is more complex
        if let range = html.range(of: #""ownerChannelName":"([^"]*)"#, options: .regularExpression) {
            let match = String(html[range])
            if let nameRange = match.range(of: #":"([^"]*)"#, options: .regularExpression) {
                let name = String(match[nameRange])
                return String(name.dropFirst(2).dropLast(1)) // Remove ':"' and '"'
            }
        }
        return nil
    }
    
    /// Extracts video duration from HTML
    private func extractDuration(from html: String) -> Int? {
        if let range = html.range(of: #""lengthSeconds":"(\d+)"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"(\d+)"#, options: .regularExpression) {
                let numberString = String(match[numberRange])
                return Int(numberString)
            }
        }
        return nil
    }
    
    /// Extracts view count from HTML
    private func extractViewCount(from html: String) -> Int64? {
        if let range = html.range(of: #""viewCount":"(\d+)"#, options: .regularExpression) {
            let match = String(html[range])
            if let numberRange = match.range(of: #"(\d+)"#, options: .regularExpression) {
                let numberString = String(match[numberRange])
                return Int64(numberString)
            }
        }
        return nil
    }
    
    /// Extracts thumbnail URL
    private func extractThumbnail(from html: String, videoId: String) -> String? {
        // Use standard YouTube thumbnail format
        return "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
    }
    
    /// Extracts video formats from HTML
    private func extractFormats(from html: String) throws -> [VideoFormat] {
        // This is a simplified implementation
        // In reality, YouTube uses complex JavaScript to generate streaming URLs
        // For a production implementation, you would need to:
        // 1. Extract player JavaScript URL
        // 2. Download and parse the player JavaScript
        // 3. Extract signature decryption functions
        // 4. Parse adaptive formats from the player response
        
        // For demonstration purposes, we'll create some mock formats
        // that represent the typical YouTube format structure
        
        let sampleFormats = [
            VideoFormat(
                formatId: "140",
                url: "https://example.com/audio.m4a",
                audioBitrate: 128,
                container: "m4a",
                audioCodec: "mp4a.40.2",
                isAudioOnly: true
            ),
            VideoFormat(
                formatId: "298",
                url: "https://example.com/video_720p.mp4",
                resolution: "1280x720",
                width: 1280,
                height: 720,
                fps: 30,
                videoBitrate: 3000,
                container: "mp4",
                videoCodec: "avc1.4d401f",
                isVideoOnly: true
            ),
            VideoFormat(
                formatId: "22",
                url: "https://example.com/video_720p_with_audio.mp4",
                resolution: "1280x720",
                width: 1280,
                height: 720,
                fps: 30,
                videoBitrate: 2500,
                audioBitrate: 192,
                container: "mp4",
                videoCodec: "avc1.4d401f",
                audioCodec: "mp4a.40.2"
            )
        ]
        
        return sampleFormats
    }
    
    /// Extracts subtitle information from HTML
    private func extractSubtitles(from html: String) -> [Subtitle] {
        // This is a simplified implementation
        // In reality, subtitle URLs would be extracted from the player response
        
        let sampleSubtitles = [
            Subtitle(
                language: "en",
                languageName: "English",
                url: "https://example.com/captions_en.vtt",
                format: "vtt"
            ),
            Subtitle(
                language: "es",
                languageName: "Spanish",
                url: "https://example.com/captions_es.vtt",
                format: "vtt",
                isAutoGenerated: true
            )
        ]
        
        return sampleSubtitles
    }
}

/// Errors that can occur during YouTube extraction
public enum YouTubeExtractorError: Error, LocalizedError {
    case invalidURL
    case videoIdNotFound
    case failedToDecodeHTML
    case formatExtractionFailed
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid YouTube URL provided"
        case .videoIdNotFound:
            return "Could not extract video ID from URL"
        case .failedToDecodeHTML:
            return "Failed to decode HTML content"
        case .formatExtractionFailed:
            return "Failed to extract video formats"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}