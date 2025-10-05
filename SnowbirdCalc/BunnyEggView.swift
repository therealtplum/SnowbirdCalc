import SwiftUI

struct BunnyEggView: View {
    @Binding var isPresented: Bool

    // Bunny motion
    @State private var x: CGFloat = -120
    @State private var y: CGFloat = 0
    @State private var scale: CGFloat = 0.9

    // Effects
    @State private var showTapHint = true
    @State private var confettiBursts: [ConfettiBurst] = []
    @State private var drops: [Drop] = [] // carrots + eggs trail

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Confetti layers (behind the bunny)
            ZStack {
                ForEach(confettiBursts) { burst in
                    ConfettiBurstView(burst: burst)
                }
            }

            // Bunny + shadow + trail
            ZStack(alignment: .bottomLeading) {

                // Trail (carrots & eggs)
                ForEach(drops) { d in
                    Text(d.emoji)
                        .font(.system(size: d.size))
                        .scaleEffect(d.scale)
                        .opacity(d.opacity)
                        .offset(x: d.position.x, y: d.position.y)
                        .allowsHitTesting(false)
                }

                // Simple drop shadow ellipse
                Ellipse()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: 80, height: 14)
                    .offset(x: x + 50, y: 60)

                // Bunny
                Image(systemName: "hare.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.white)
                    .shadow(radius: 4, y: 2)
                    .scaleEffect(scale)
                    .offset(x: x, y: y)
                    .onAppear { startShow() }
                    .accessibilityLabel("Easter egg bunny")
            }

            if showTapHint {
                Text("tap to skip 🥕")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(y: 200)
                    .transition(.opacity)
            }
        }
        .transaction { $0.disablesAnimations = false }
        .animation(.easeInOut(duration: 0.25), value: showTapHint)
    }

    // MARK: - Script

    private func startShow() {
        // Initial confetti burst
        spawnConfetti(at: CGPoint(x: x + 60, y: y), count: 18)
        // Hide hint soon
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showTapHint = false }
        }
        // Start hopping
        runHops()
    }

    private func runHops() {
        let hopCount = 6
        let hopDistance: CGFloat = 72
        let hopHeight: CGFloat = 36
        let hopDur = 0.26

        func dropAtCurrentPosition() {
            // Randomly carrot or egg
            let isEgg = Bool.random()
            let emoji = isEgg ? ["🥚","🐣","🌸"].randomElement()! : ["🥕","🥕","🥕","🍀"].randomElement()!
            let size: CGFloat = isEgg ? CGFloat.random(in: 18...24) : CGFloat.random(in: 18...22)
            let pos = CGPoint(x: x + CGFloat.random(in: 20...80), y: 40 + CGFloat.random(in: -6...6))
            let drop = Drop(emoji: emoji, position: pos, size: size, scale: 0.6, opacity: 0)
            drops.append(drop)
            let idx = drops.count - 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                drops[idx].opacity = 1
                drops[idx].scale = 1.0
            }
        }

        func hop(_ i: Int) {
            guard i < hopCount else {
                // Final confetti + exit right
                spawnConfetti(at: CGPoint(x: x + 70, y: y), count: 24)
                withAnimation(.easeInOut(duration: 0.38)) {
                    x += 220
                    scale = 0.85
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
                return
            }

            // Up & forward
            withAnimation(.interpolatingSpring(stiffness: 220, damping: 14)) {
                y = -hopHeight
                x += hopDistance
                scale = 1.0
            }

            // Leave a carrot/egg mid-flight
            DispatchQueue.main.asyncAfter(deadline: .now() + hopDur * 0.55) {
                dropAtCurrentPosition()
            }

            // Down
            DispatchQueue.main.asyncAfter(deadline: .now() + hopDur) {
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 18)) {
                    y = 0
                    scale = 0.95
                }
                // Small confetti burst every other hop
                if i % 2 == 1 {
                    spawnConfetti(at: CGPoint(x: x + 50, y: y), count: 10, light: true)
                }
                // Next hop
                DispatchQueue.main.asyncAfter(deadline: .now() + hopDur * 0.8) {
                    hop(i + 1)
                }
            }
        }

        hop(0)
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
        // Clean old bursts to keep memory tidy
        confettiBursts.removeAll(where: { Date().timeIntervalSince($0.createdAt) > 2.0 })
        // Keep drops as little souvenirs until next time
    }

    // MARK: - Confetti

    private func spawnConfetti(at point: CGPoint, count: Int, light: Bool = false) {
        let burst = ConfettiBurst(
            origin: point,
            particles: (0..<count).map { _ in
                ConfettiParticle(
                    angle: .random(in: .pi/8 ... 7 * .pi/8),
                    speed: light ? .random(in: 90...140) : .random(in: 140...220),
                    spin: .random(in: -2.5...2.5),
                    color: ConfettiPalette.random,
                    size: .random(in: 6...10),
                    lifetime: .random(in: 0.9...1.4)
                )
            }
        )
        confettiBursts.append(burst)
    }
}

// MARK: - Models

private struct Drop: Identifiable {
    let id = UUID()
    let emoji: String
    var position: CGPoint
    var size: CGFloat
    var scale: CGFloat
    var opacity: CGFloat
}

private struct ConfettiBurst: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let particles: [ConfettiParticle]
    let createdAt = Date()
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let angle: CGFloat
    let speed: CGFloat
    let spin: CGFloat
    let color: Color
    let size: CGFloat
    let lifetime: Double
}

private enum ConfettiPalette {
    static var random: Color {
        let palette: [Color] = [
            Color.pink,
            Color.mint,
            Color.teal,
            Color.indigo,
            Color.orange,
            Color.yellow,
            Color.cyan,
            Color.purple
        ].map { $0.opacity(0.85) }
        return palette.randomElement()!
    }
}

// MARK: - Views

private struct ConfettiBurstView: View {
    let burst: ConfettiBurst
    @State private var progress: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let _ = timeline.date.timeIntervalSince1970
            ZStack {
                ForEach(burst.particles) { p in
                    ConfettiPiece(p: p, origin: burst.origin, t: progress)
                }
            }
            .onChange(of: timeline.date) {
                progress += 1.0 / 60.0
            }
        }
        .onAppear {
            // Auto remove after the longest particle lifetime
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (burst.particles.map(\.lifetime).max() ?? 1.2) + 0.2
            ) {
                // no-op; the parent view prunes old bursts on dismiss
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiPiece: View {
    let p: ConfettiParticle
    let origin: CGPoint
    let t: Double

    var body: some View {
        // Simple physics: position = origin + velocity*t + gravity*t^2
        let g: CGFloat = 260 // gravity
        let vx = cos(p.angle) * p.speed
        let vy0 = -sin(p.angle) * p.speed
        let dt = CGFloat(t)
        let dx = vx * dt
        let dy = vy0 * dt + 0.5 * g * dt * dt

        Rectangle()
            .fill(p.color)
            .frame(width: p.size, height: p.size * 0.6)
            .rotationEffect(.radians(Double(p.spin) * t))
            .opacity(opacity(at: t))
            .offset(x: origin.x + dx, y: origin.y + dy)
    }

    private func opacity(at t: Double) -> Double {
        let fadeStart = p.lifetime * 0.7
        if t < fadeStart { return 1 }
        let remaining = max(0, p.lifetime - t)
        return Double(remaining / (p.lifetime - fadeStart + 0.0001))
    }
}
