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
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // JS workaround chống pause khi background
        let scriptSource = """
        Object.defineProperty(document, 'hidden', { value: false });
        Object.defineProperty(document, 'visibilityState', { value: 'visible' });
        
        document.addEventListener('visibilitychange', function(e) {
            e.stopImmediatePropagation();
        }, true);
        """
        
        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        let contentController = WKUserContentController()
        contentController.addUserScript(script)
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .black

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

           let location = gestureRecognizer.location(in: view)
           let halfHeight = view.bounds.height / 3

           // ❌ Chạm ở nửa dưới → không bắt gesture
           if location.y > halfHeight {
               return false
           }

           // (GIỮ LẠI logic cũ nếu có)
           let velocity = (gestureRecognizer as! UIPanGestureRecognizer)
               .velocity(in: view)

           // ❌ Vuốt lên → không bắt
           if velocity.y < 0 {
               return false
           }

           // ❌ Web chưa ở top → không bắt
//           if webView.scrollView.contentOffset.y > 0 {
//               return false
//           }

           return true
       }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
