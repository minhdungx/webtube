import UIKit
import WebKit

protocol VideoWebViewDelegate: AnyObject {
    func videoDidHide()
}

class VideoWebViewController: UIViewController {

    weak var delegate: VideoWebViewDelegate?
    private var webView: WKWebView!
    private var videoURL: URL

    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupWebView()
        setupGesture()
        loadVideo(url: videoURL)
    }

    // MARK: - WebView
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }

    func loadVideo(url: URL) {
        videoURL = url
        webView.load(URLRequest(url: url))
    }

    // MARK: - Gesture
    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: view)

        guard t.y > 0 else { return }

        switch g.state {
        case .changed:
            view.transform = CGAffineTransform(translationX: 0, y: t.y)

        case .ended:
            if t.y > 120 {
                hide()
            } else {
                show()
            }
        default: break
        }
    }

    // MARK: - Show / Hide
    func hide() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(
                translationX: 0,
                y: self.view.bounds.height
            )
            self.view.alpha = 0
        }) { _ in
            self.view.isHidden = true
            self.delegate?.videoDidHide()
        }
    }

    func show() {
        view.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.view.transform = .identity
            self.view.alpha = 1
        }
    }
}

// MARK: - Gesture Delegate
extension VideoWebViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
