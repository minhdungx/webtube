import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {

    private var webView: WKWebView!
    private var videoPlayerVC: VideoWebViewController?
    private var showVideoButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

//        setupAudioSession()
        setupWebView()
        setupShowVideoButton()
        loadYouTubeHome()
    }

//    // MARK: - Audio Session (để video không tắt)
//    private func setupAudioSession() {
//        try? AVAudioSession.sharedInstance().setCategory(.playback)
//        try? AVAudioSession.sharedInstance().setActive(true)
//    }

    // MARK: - WebView (Feed)
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        // JS bắt click video
        let js = """
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
            source: js,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )

        let content = WKUserContentController()
        content.addUserScript(script)
        content.add(self, name: "videoTapped")
        config.userContentController = content

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadYouTubeHome() {
        let url = URL(string: "https://m.youtube.com")!
        webView.load(URLRequest(url: url))
    }

    // MARK: - Floating Button
    private func setupShowVideoButton() {
        let btn = UIButton(type: .system)
        btn.setTitle("▶︎ Video", for: .normal)
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        btn.tintColor = .white
        btn.layer.cornerRadius = 22
        btn.addTarget(self, action: #selector(showVideoTapped), for: .touchUpInside)

        btn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            btn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            btn.widthAnchor.constraint(equalToConstant: 100),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])

        btn.isHidden = true
        showVideoButton = btn
    }

    @objc private func showVideoTapped() {
        videoPlayerVC?.show()
        showVideoButton.isHidden = true
    }

    // MARK: - Show Video
    private func showVideo(url: URL) {
        if let vc = videoPlayerVC {
            vc.loadVideo(url: url)
            vc.show()
            showVideoButton.isHidden = true
            return
        }

        let vc = VideoWebViewController(videoURL: url)
        vc.delegate = self
        vc.view.frame = view.bounds

        addChild(vc)
        view.addSubview(vc.view)
        vc.didMove(toParent: self)

        videoPlayerVC = vc
        showVideoButton.isHidden = true
    }
}

// MARK: - JS Message
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "videoTapped",
              let urlString = message.body as? String,
              let url = URL(string: urlString) else { return }

        showVideo(url: url)
    }
}

// MARK: - Video Delegate
extension ViewController: VideoWebViewDelegate {
    func videoDidHide() {
        showVideoButton.isHidden = false
    }
}
