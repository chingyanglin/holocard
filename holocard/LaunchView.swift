import SwiftUI
import AVKit

struct LaunchView: View {
    
    var onStart: () -> Void
    
    var body: some View {
        ZStack {
            // 背景影片
            VideoPlayerView()
                .ignoresSafeArea()
            
            // 漸層遮罩
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 內容
            VStack {
                Spacer()
                
                Text("Create Your Own")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Holographic Card")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "BFFF00"))
                
                Text("in Seconds.")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer().frame(height: 40)
                
                Button(action: onStart) {
                    HStack {
                        Text("Start now")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right.2")
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color(hex: "BFFF00"))
                    .cornerRadius(30)
                }
                
                Spacer().frame(height: 60)
            }
            .padding()
        }
    }
}

// MARK: - 影片播放器
struct VideoPlayerView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {
        return PlayerUIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        guard let url = Bundle.main.url(forResource: "launch_bg_vid", withExtension: "mp4") else {
            print("找不到影片檔案")
            return
        }
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
        
        queuePlayer.isMuted = true
        queuePlayer.play()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = CGRect(
            x: -100,
            y: -100,
            width: bounds.width + 200,
            height: bounds.height + 200
        )
    }
}

#Preview {
    LaunchView(onStart: {})
}
