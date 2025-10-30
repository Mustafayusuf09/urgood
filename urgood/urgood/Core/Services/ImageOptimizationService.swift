import UIKit
import SwiftUI
import Accelerate

/// Comprehensive image optimization service for UrGood mental health app
/// Provides image compression, caching, and performance optimization
@MainActor
class ImageOptimizationService: ObservableObject {
    static let shared = ImageOptimizationService()
    
    // MARK: - Published Properties
    @Published var compressionQuality: CompressionQuality = .balanced
    @Published var cacheEnabled: Bool = true
    @Published var totalCacheSize: Int64 = 0
    @Published var optimizedImagesCount: Int = 0
    
    // MARK: - Private Properties
    private let crashlytics = CrashlyticsService.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    private let metadataCache = NSCache<NSString, ImageMetadata>()
    
    // MARK: - Cache Configuration
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Cache Directories
    private lazy var cacheDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("ImageCache")
        
        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        return cacheURL
    }()
    
    private lazy var optimizedDirectory: URL = {
        let optimizedURL = cacheDirectory.appendingPathComponent("Optimized")
        
        if !fileManager.fileExists(atPath: optimizedURL.path) {
            try? fileManager.createDirectory(at: optimizedURL, withIntermediateDirectories: true)
        }
        
        return optimizedURL
    }()
    
    private init() {
        setupImageCache()
        calculateCacheSize()
        cleanupExpiredCache()
        
        crashlytics.log("Image optimization service initialized", level: .info)
    }
    
    // MARK: - Image Optimization
    
    /// Optimize image with specified quality and target size
    func optimizeImage(
        _ image: UIImage,
        quality: CompressionQuality? = nil,
        targetSize: CGSize? = nil,
        preserveAspectRatio: Bool = true
    ) async -> UIImage? {
        let startTime = Date()
        let usedQuality = quality ?? compressionQuality
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let optimizedImage = self.performImageOptimization(
                    image,
                    quality: usedQuality,
                    targetSize: targetSize,
                    preserveAspectRatio: preserveAspectRatio
                )
                
                let processingTime = Date().timeIntervalSince(startTime)
                
                DispatchQueue.main.async {
                    self.optimizedImagesCount += 1
                    
                    self.crashlytics.recordFeatureUsage("image_optimization", success: optimizedImage != nil, metadata: [
                        "quality": usedQuality.rawValue,
                        "processing_time": processingTime,
                        "original_size": "\(image.size.width)x\(image.size.height)",
                        "target_size": targetSize != nil ? "\(targetSize!.width)x\(targetSize!.height)" : "none"
                    ])
                    
                    continuation.resume(returning: optimizedImage)
                }
            }
        }
    }
    
    /// Optimize image from URL with caching
    func optimizeImageFromURL(
        _ url: URL,
        quality: CompressionQuality? = nil,
        targetSize: CGSize? = nil,
        cacheKey: String? = nil
    ) async -> UIImage? {
        let key = cacheKey ?? url.absoluteString
        let cacheKey = NSString(string: key)
        
        // Check cache first
        if cacheEnabled, let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Load and optimize image
        guard let imageData = try? Data(contentsOf: url),
              let originalImage = UIImage(data: imageData) else {
            return nil
        }
        
        let optimizedImage = await optimizeImage(
            originalImage,
            quality: quality,
            targetSize: targetSize
        )
        
        // Cache optimized image
        if cacheEnabled, let optimizedImage = optimizedImage {
            imageCache.setObject(optimizedImage, forKey: cacheKey)
            await saveToDiskCache(optimizedImage, key: key)
        }
        
        return optimizedImage
    }
    
    /// Batch optimize images
    func batchOptimizeImages(
        _ images: [UIImage],
        quality: CompressionQuality? = nil,
        targetSize: CGSize? = nil,
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async -> [UIImage?] {
        let usedQuality = quality ?? compressionQuality
        var optimizedImages: [UIImage?] = []
        
        for (index, image) in images.enumerated() {
            let optimizedImage = await optimizeImage(
                image,
                quality: usedQuality,
                targetSize: targetSize
            )
            optimizedImages.append(optimizedImage)
            
            let progress = Double(index + 1) / Double(images.count)
            await MainActor.run {
                progressHandler(progress)
            }
        }
        
        return optimizedImages
    }
    
    // MARK: - Image Processing
    
    nonisolated private func performImageOptimization(
        _ image: UIImage,
        quality: CompressionQuality,
        targetSize: CGSize?,
        preserveAspectRatio: Bool
    ) -> UIImage? {
        var processedImage = image
        
        // Resize if target size specified
        if let targetSize = targetSize {
            processedImage = resizeImage(
                processedImage,
                targetSize: targetSize,
                preserveAspectRatio: preserveAspectRatio
            ) ?? processedImage
        }
        
        // Apply compression
        processedImage = compressImage(processedImage, quality: quality) ?? processedImage
        
        // Apply additional optimizations
        processedImage = applyImageEnhancements(processedImage, quality: quality) ?? processedImage
        
        return processedImage
    }
    
    nonisolated private func resizeImage(
        _ image: UIImage,
        targetSize: CGSize,
        preserveAspectRatio: Bool
    ) -> UIImage? {
        let size = preserveAspectRatio ? 
            calculateAspectFitSize(image.size, targetSize: targetSize) : 
            targetSize
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    nonisolated private func compressImage(_ image: UIImage, quality: CompressionQuality) -> UIImage? {
        guard let imageData = image.jpegData(compressionQuality: quality.compressionRatio) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    nonisolated private func applyImageEnhancements(_ image: UIImage, quality: CompressionQuality) -> UIImage? {
        guard quality == .high || quality == .maximum else { return image }
        
        // Apply subtle sharpening for high quality images
        return applySharpeningFilter(image)
    }
    
    nonisolated private func applySharpeningFilter(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else { return image }
        sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputIntensityKey)
        sharpenFilter.setValue(1.0, forKey: kCIInputRadiusKey)
        
        guard let outputImage = sharpenFilter.outputImage,
              let sharpened = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: sharpened)
    }
    
    // MARK: - Utility Functions
    
    nonisolated private func calculateAspectFitSize(_ originalSize: CGSize, targetSize: CGSize) -> CGSize {
        let aspectRatio = originalSize.width / originalSize.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        if aspectRatio > targetAspectRatio {
            // Width is the limiting factor
            return CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
        } else {
            // Height is the limiting factor
            return CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
        }
    }
    
    // MARK: - Caching
    
    private func setupImageCache() {
        imageCache.countLimit = 100
        imageCache.totalCostLimit = Int(maxCacheSize / 2) // Use half for memory cache
        
        metadataCache.countLimit = 500
    }
    
    private func saveToDiskCache(_ image: UIImage, key: String) async {
        guard cacheEnabled else { return }
        
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = optimizedDirectory.appendingPathComponent("\(filename).jpg")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    try? imageData.write(to: fileURL)
                    
                    let metadata = ImageMetadata(
                        key: key,
                        fileURL: fileURL,
                        size: Int64(imageData.count),
                        createdAt: Date()
                    )
                    
                    DispatchQueue.main.async {
                        self.metadataCache.setObject(metadata, forKey: NSString(string: key))
                        self.calculateCacheSize()
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func loadFromDiskCache(key: String) -> UIImage? {
        guard cacheEnabled,
              let metadata = metadataCache.object(forKey: NSString(string: key)),
              fileManager.fileExists(atPath: metadata.fileURL.path) else {
            return nil
        }
        
        // Check if file is not expired
        let age = Date().timeIntervalSince(metadata.createdAt)
        if age > maxCacheAge {
            removeCacheEntry(key: key)
            return nil
        }
        
        return UIImage(contentsOfFile: metadata.fileURL.path)
    }
    
    private func removeCacheEntry(key: String) {
        let cacheKey = NSString(string: key)
        
        if let metadata = metadataCache.object(forKey: cacheKey) {
            try? fileManager.removeItem(at: metadata.fileURL)
            metadataCache.removeObject(forKey: cacheKey)
        }
        
        imageCache.removeObject(forKey: cacheKey)
        calculateCacheSize()
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        imageCache.removeAllObjects()
        metadataCache.removeAllObjects()
        
        try? fileManager.removeItem(at: optimizedDirectory)
        try? fileManager.createDirectory(at: optimizedDirectory, withIntermediateDirectories: true)
        
        totalCacheSize = 0
        optimizedImagesCount = 0
        
        crashlytics.recordFeatureUsage("image_cache_cleared", success: true)
    }
    
    func cleanupExpiredCache() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: optimizedDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            let now = Date()
            var didRemoveFiles = false
            
            for url in fileURLs {
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
                let modifiedDate = values.contentModificationDate ?? now
                if now.timeIntervalSince(modifiedDate) > maxCacheAge {
                    try fileManager.removeItem(at: url)
                    didRemoveFiles = true
                }
            }
            
            if didRemoveFiles {
                metadataCache.removeAllObjects()
            }
            
            calculateCacheSize()
        } catch {
            crashlytics.recordError(error)
        }
    }
    
    private func calculateCacheSize() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: optimizedDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            let size = fileURLs.reduce(into: Int64(0)) { partialResult, url in
                if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = values.fileSize {
                    partialResult += Int64(fileSize)
                }
            }
            totalCacheSize = size
            
            if size > maxCacheSize {
                cleanupOldestEntries()
            }
        } catch {
            crashlytics.recordError(error)
        }
    }
    
    private func cleanupOldestEntries() {
        do {
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
            let fileData = try fileManager.contentsOfDirectory(
                at: optimizedDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ).compactMap { url -> (URL, Date, Int64)? in
                guard let values = try? url.resourceValues(forKeys: Set(resourceKeys)),
                      let modifiedDate = values.contentModificationDate,
                      let fileSize = values.fileSize else {
                    return nil
                }
                return (url, modifiedDate, Int64(fileSize))
            }
            var remainingSize = totalCacheSize
            let sortedFiles = fileData.sorted { $0.1 < $1.1 } // Oldest first
            
            for (url, _, fileSize) in sortedFiles where remainingSize > maxCacheSize {
                try fileManager.removeItem(at: url)
                remainingSize -= fileSize
            }
            
            if remainingSize <= maxCacheSize {
                totalCacheSize = max(0, remainingSize)
            } else {
                totalCacheSize = maxCacheSize
            }
            
            imageCache.removeAllObjects()
            metadataCache.removeAllObjects()
            optimizedImagesCount = 0
        } catch {
            crashlytics.recordError(error)
        }
    }
    
    // MARK: - Settings
    
    func setCompressionQuality(_ quality: CompressionQuality) {
        compressionQuality = quality
        UserDefaults.standard.set(quality.rawValue, forKey: "image_compression_quality")
        
        crashlytics.recordFeatureUsage("image_compression_quality_change", success: true, metadata: [
            "quality": quality.rawValue
        ])
    }
    
    func setCacheEnabled(_ enabled: Bool) {
        cacheEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "image_cache_enabled")
        
        if !enabled {
            clearCache()
        }
        
        crashlytics.recordFeatureUsage("image_cache_toggle", success: true, metadata: [
            "enabled": enabled
        ])
    }
}

// MARK: - Supporting Types

enum CompressionQuality: Float, CaseIterable {
    case low = 0.3
    case medium = 0.5
    case balanced = 0.7
    case high = 0.8
    case maximum = 0.9
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .balanced: return "Balanced"
        case .high: return "High"
        case .maximum: return "Maximum"
        }
    }
    
    var compressionRatio: CGFloat {
        return CGFloat(self.rawValue)
    }
    
    var description: String {
        switch self {
        case .low: return "Smallest file size, lower quality"
        case .medium: return "Good balance of size and quality"
        case .balanced: return "Optimal balance for most uses"
        case .high: return "High quality, larger file size"
        case .maximum: return "Best quality, largest file size"
        }
    }
}

class ImageMetadata {
    let key: String
    let fileURL: URL
    let size: Int64
    let createdAt: Date
    
    init(key: String, fileURL: URL, size: Int64, createdAt: Date) {
        self.key = key
        self.fileURL = fileURL
        self.size = size
        self.createdAt = createdAt
    }
}

// MARK: - SwiftUI Integration

struct OptimizedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let quality: CompressionQuality
    let targetSize: CGSize?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageService = ImageOptimizationService.shared
    @State private var optimizedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        quality: CompressionQuality = .balanced,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.quality = quality
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let optimizedImage = optimizedImage {
                content(Image(uiImage: optimizedImage))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        Task {
            let image = await imageService.optimizeImageFromURL(
                url,
                quality: quality,
                targetSize: targetSize
            )
            
            await MainActor.run {
                self.optimizedImage = image
                self.isLoading = false
            }
        }
    }
}
