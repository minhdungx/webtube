import UIKit
import WebKit

class ViewController: UIViewController {

    private var webView: WKWebView!
    private var isPushingVideo = false


    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupWebView()
        loadYouTubeHome()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ẩn navigation bar trên màn hình chính
        navigationController?.setNavigationBarHidden(true, animated: animated)
        isPushingVideo = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Hiện lại navigation bar khi push sang màn hình khác
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "videoTapped")
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()

        // Media config giống browser
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // JS workaround chống pause khi background
        let scriptSource = """
        Object.defineProperty(document, 'hidden', { value: false });
        Object.defineProperty(document, 'visibilityState', { value: 'visible' });

        document.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);
        """
        
        let scriptSource2 = """
        document.addEventListener('click', function(e) {
            let el = e.target;
            while (el && el.tagName !== 'A') el = el.parentElement;

            if (el && el.href && el.href.includes('/watch')) {
                e.preventDefault();
                e.stopPropagation();
                window.webkit.messageHandlers.videoTapped.postMessage(el.href);
            }
        }, true);
        """

        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        let script2 = WKUserScript(
            source: scriptSource2,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        let contentController = WKUserContentController()
        contentController.addUserScript(script)
        contentController.addUserScript(script2)
        contentController.add(self, name: "videoTapped")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.navigationDelegate = self

        view.addSubview(webView)

        // ✅ Ghim vào Safe Area
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func loadYouTubeHome() {
        let url = URL(string: "https://m.youtube.com")!
        webView.load(URLRequest(url: url))
    }
}

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ Loaded:", webView.url?.absoluteString ?? "")
    }
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        guard !isPushingVideo,
              message.name == "videoTapped",
              let urlString = message.body as? String,
              let url = URL(string: urlString) else { return }
        
        isPushingVideo = true

        let vc = VideoWebViewController(videoURL: url)
        navigationController?.pushViewController(vc, animated: true)
    }
}

