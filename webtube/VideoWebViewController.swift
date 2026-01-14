import UIKit
import AVFAudio
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
        (function () {
            console.log("🎬 Injected Smart Video Controller");

            /* ==============================
               1. VISIBILITY & FOCUS HACK
               ============================== */
            Object.defineProperty(document, 'hidden', { get: () => false });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible' });
            Object.defineProperty(document, 'webkitVisibilityState', { get: () => 'visible' });

            window.addEventListener('blur', e => e.stopPropagation(), true);
            window.addEventListener('focus', e => e.stopPropagation(), true);

            /* ==============================
               2. STATE MANAGEMENT
               ============================== */
            let isManualPaused = false; // QUAN TRỌNG: Đánh dấu user chủ động dừng
            let autoStartTimer = null;

            function getVideo() { return document.querySelector('video'); }

            /* ==============================
               3. VIDEO RESUME LOGIC (SỬA ĐỔI)
               ============================== */
            function ensureVideoPlaying(reason = "") {
                const v = getVideo();
                if (!v || v.readyState < 2) return;

                // Nếu user đã chủ động pause, tuyệt đối không ép play lại
                if (isManualPaused) return; 

                if (v.muted) v.muted = false;
                if (v.paused) {
                    v.play().catch(() => {});
                }
            }

            function startAutoStartLoop() {
                if (autoStartTimer) return;
                
                let stableCount = 0;
                autoStartTimer = setInterval(() => {
                    const v = getVideo();
                    if (!v) return;

                    // Nếu user bấm pause trong lúc đang loop, dừng loop ngay
                    if (isManualPaused) {
                        clearInterval(autoStartTimer);
                        autoStartTimer = null;
                        return;
                    }

                    if (v.readyState >= 2) {
                        // Ép bật tiếng
                        if (v.muted) {
                            v.muted = false;
                            v.volume = 1.0;
                        }

                        // Ép phát
                        if (v.paused) {
                            v.play().catch(() => {});
                        }

                        // Kiểm tra điều kiện dừng: Video đang chạy và không mute
                        if (!v.paused && !v.muted) {
                            stableCount++;
                            if (stableCount >= 2) { // Ổn định trong 1 giây
                                console.log("✅ Video Autostart & Unmute thành công");
                                clearInterval(autoStartTimer);
                                autoStartTimer = null;
                            }
                        }
                    }
                }, 500);
            }

            /* ==============================
               4. USER INTENT TRACKING (SỬA ĐỔI)
               ============================== */
            
            // Bắt sự kiện pause để biết user có chủ động dừng không
            document.addEventListener('pause', () => {
                // Nếu video bị pause khi màn hình đang được focus -> User bấm dừng
                if (document.hasFocus()) {
                    isManualPaused = true;
                    console.log("⏸ User manual pause");
                }
            }, true);

            // Bắt sự kiện play để reset trạng thái
            document.addEventListener('play', () => {
                isManualPaused = false;
                console.log("▶️ User manual play");
            }, true);

            /* ==============================
               5. EVENTS & SPA SUPPORT
               ============================== */
            document.addEventListener('visibilitychange', () => {
                // Chỉ tự resume khi ẩn app nếu user TRƯỚC ĐÓ đang xem (không phải đang pause)
                if (!isManualPaused) {
                    setTimeout(() => ensureVideoPlaying("visibility"), 300);
                }
            });

            window.addEventListener('pageshow', () => {
                isManualPaused = false; // Reset khi trang mới hiện ra
                setTimeout(startAutoStartLoop, 500);
            });

            // Hỗ trợ khi chuyển video khác trên YouTube (SPA)
            let lastURL = location.href;
            setInterval(() => {
                if (location.href !== lastURL) {
                    lastURL = location.href;
                    isManualPaused = false; // Reset để video mới tự phát có tiếng
                    setTimeout(startAutoStartLoop, 1000);
                }
            }, 800);

            // Khởi chạy lần đầu
            setTimeout(startAutoStartLoop, 1000);
        })();
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
//        try? AVAudioSession.sharedInstance().setActive(true)
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
