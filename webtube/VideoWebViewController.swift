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
            console.log("🎬 Injected Video Visibility Script");

            /* ==============================
               1. VISIBILITY & FOCUS HACK
               ============================== */

            Object.defineProperty(document, 'hidden', {
                configurable: true,
                get: () => false
            });

            Object.defineProperty(document, 'visibilityState', {
                configurable: true,
                get: () => 'visible'
            });

            Object.defineProperty(document, 'webkitVisibilityState', {
                configurable: true,
                get: () => 'visible'
            });

            window.addEventListener('blur', e => e.stopPropagation(), true);
            window.addEventListener('focus', e => e.stopPropagation(), true);

            /* ==============================
               2. VIDEO RESUME LOGIC (SAFE)
               ============================== */

            let hasUserInteracted = false;
            let autoStartTimer = null;

            function getVideo() {
                return document.querySelector('video');
            }

            function ensureVideoPlaying(reason = "") {
                const v = getVideo();
                if (!v) return;
        
                if (v.muted) v.muted = false;

                if (v.readyState < 2) return;

                // ❗ Không ép play nếu user chủ động pause
                if (v.paused && hasUserInteracted) {
                    console.log("▶️ Resume video", reason);
                    v.play().catch(() => {});
                }

                
            }

            function startAutoStartLoop() {
                if (autoStartTimer) return;

                let unmuteAttempts = 0; // Đếm số lần thử unmute

                autoStartTimer = setInterval(() => {
                    const v = document.querySelector('video');
                    if (!v) return;

                    // 1. Kiểm tra nếu video đã sẵn sàng dữ liệu
                    if (v.readyState >= 2) {
                        
                        // 2. ÉP BẬT TIẾNG
                        if (v.muted) {
                            v.muted = false;
                            v.volume = 1.0;
                        }

                        // 3. ÉP PHÁT VIDEO
                        if (v.paused) {
                            v.play().catch(e => console.log("Chờ tương tác..."));
                        }

                        // 4. KIỂM TRA ĐIỀU KIỆN DỪNG
                        // Nếu video đang chạy VÀ đã có tiếng thành công
                        if (!v.paused && v.muted === false) {
                            unmuteAttempts++;
                            
                            // Thử giữ trạng thái này trong 1 giây (2 lần lặp) để tránh YouTube tự mute lại
                            if (unmuteAttempts >= 2) {
                                console.log("✅ Đã bật tiếng thành công!");
                                clearInterval(autoStartTimer);
                                autoStartTimer = null;
                            }
                        }
                    }
                }, 500); // Kiểm tra mỗi 0.5 giây
            }

            /* ==============================
               3. USER INTENT TRACKING
               ============================== */

            document.addEventListener('pointerdown', () => {
                hasUserInteracted = true;
            }, true);

            document.addEventListener('play', () => {
                hasUserInteracted = true;
            }, true);

            /* ==============================
               4. VISIBILITY / PAGE EVENTS
               ============================== */

            document.addEventListener('visibilitychange', () => {
                console.log("👀 visibilitychange");
                setTimeout(() => ensureVideoPlaying("visibility"), 300);
            });

            window.addEventListener('pagehide', () => {
                console.log("📴 pagehide");
            });

            window.addEventListener('pageshow', () => {
                console.log("📺 pageshow");
                setTimeout(startAutoStartLoop, 500);
            });

            /* ==============================
               5. SPA / URL CHANGE SUPPORT
               ============================== */

            let lastURL = location.href;

            setInterval(() => {
                if (location.href !== lastURL) {
                    lastURL = location.href;
                    console.log("🔄 URL changed", lastURL);
                    hasUserInteracted = false;
                    setTimeout(startAutoStartLoop, 1000);
                }
            }, 800);

            /* ==============================
               6. INITIAL START
               ============================== */

            setTimeout(startAutoStartLoop, 1000);

        })();

        """
        
        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        let playScript = """
// 1. Cấu hình để chạy nền (không thay đổi)
Object.defineProperty(document, 'hidden', { value: false });
Object.defineProperty(document, 'visibilityState', { value: 'visible' });
document.addEventListener('visibilitychange', function(e) {
    e.stopImmediatePropagation();
}, true);

// 2. Logic khởi tạo video thông minh
var autoStartInterval = setInterval(function() {
    var v = document.querySelector('video');
    
    // Kiểm tra nếu video đã sẵn sàng (readyState >= 2)
    if (v && v.readyState >= 2) {
        // Nếu video đang pause thì mới gọi play (để khởi động lần đầu)
        if (v.paused) {
            v.play();
        }
        
        // Luôn đảm bảo bỏ tắt tiếng ở lần đầu này
        v.muted = false;
        
        // QUAN TRỌNG: Nếu video đã bắt đầu chạy (không còn paused nữa)
        // thì xóa bỏ vòng lặp này ngay lập tức để người dùng có thể bấm Dừng thủ công
        if (!v.paused) {
            console.log("✅ Video đã phát, dừng kiểm tra tự động.");
            clearInterval(autoStartInterval);
        }
    }
}, 500); // Kiểm tra mỗi 0.5 giây cho mượt
"""
        let script2 = WKUserScript(source: playScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        

                
        
        let contentController = WKUserContentController()
        contentController.addUserScript(script)
//        contentController.addUserScript(script2)

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
