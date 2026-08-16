//
//  ShareViewController.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    // responder chain 이 연결된 뒤 UIApplication 을 찾음
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedItem()
    }

    private func handleSharedItem() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap(\.attachments)
            .flatMap { $0 } ?? []

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] value, _ in
                let url = value as? URL
                Task { @MainActor in self?.finish(with: url) }
            }
        } else if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(textType)
        }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] value, _ in
                let url = Self.httpURL(from: value as? String)
                Task { @MainActor in self?.finish(with: url) }
            }
        } else {
            close()
        }
    }

    private nonisolated static func httpURL(from text: String?) -> URL? {
        guard let text else { return nil }
        if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            return url
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, range: range),
           let url = match.url,
           url.scheme?.hasPrefix("http") == true {
            return url
        }
        return nil
    }

    private func finish(with sharedURL: URL?) {
        if let deepLink = deepLink(for: sharedURL) {
            openHostApp(deepLink)
        }
        close()
    }

    private func deepLink(for sharedURL: URL?) -> URL? {
        guard
            let sharedURL,
            var components = URLComponents(string: "dulpick://import")
        else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "url", value: sharedURL.absoluteString)]
        return components.url
    }

    // iOS 18 은 deprecated openURL: 을 막으므로, responder chain 의 UIApplication 에서 non-deprecated open 을 런타임 호출
    private typealias OpenURLFunction = @convention(c) (
        UIApplication,
        Selector,
        URL,
        [UIApplication.OpenExternalURLOptionsKey: Any],
        (@convention(block) (Bool) -> Void)?
    ) -> Void

    private func openHostApp(_ url: URL) {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication, application.responds(to: selector) {
                let implementation = application.method(for: selector)
                let openURL = unsafeBitCast(implementation, to: OpenURLFunction.self)
                openURL(application, selector, url, [:], nil)
                return
            }
            responder = current.next
        }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
