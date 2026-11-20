import AppKit
import SwiftUI

// MARK: - Helpers

func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return (1 - cos(.pi * c)) / 2 }

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255)
    }
}

struct Palette { let a: Color; let b: Color; let c: Color }

let palettes: [Palette] = [
    Palette(a: Color(hex: 0xFF8A65), b: Color(hex: 0xBA68C8), c: Color(hex: 0x4FC3F7)), // dusk
    Palette(a: Color(hex: 0x4DD0E1), b: Color(hex: 0x26A69A), c: Color(hex: 0x9575CD)), // sea
    Palette(a: Color(hex: 0xFFD54F), b: Color(hex: 0xFF8F00), c: Color(hex: 0xF06292)), // gold
    Palette(a: Color(hex: 0x81C784), b: Color(hex: 0xAED581), c: Color(hex: 0x4DB6AC)), // forest
    Palette(a: Color(hex: 0xF48FB1), b: Color(hex: 0xCE93D8), c: Color(hex: 0xFFCC80)), // rose
    Palette(a: Color(hex: 0xB3E5FC), b: Color(hex: 0x80DEEA), c: Color(hex: 0xE1F5FE)), // ice
    Palette(a: Color(hex: 0xFF7043), b: Color(hex: 0xFFCA28), c: Color(hex: 0xEC407A)), // ember
]

let singleWords = [
    "Here.", "Alive.", "Now.", "Breathe.", "This.", "Awake?", "Are you here?",
    "You are alive.", "Who is aware?", "Notice.", "Feel your body.", "Hello.",
    "Still here?", "Look.", "Who is seeing?", "Listen.", "Wake up.", "Be.",
]

let pairs: [(String, String)] = [
    ("Who", "is aware of this?"), ("Right now", "you are alive."), ("Stop.", "Breathe once."),
    ("Where", "are you?"), ("Feel", "your hands."), ("This moment", "is it."),
    ("You", "are here."), ("Who", "is breathing?"),
]

enum Kind: String, CaseIterable {
    case word, question, breath, edge, ripple, firefly, halo, ink, dawn, frost, leaf, pulse, bloom, stars

    var weight: Double {
        switch self {
        case .word, .breath: return 10
        case .edge: return 9
        case .ripple, .firefly: return 8
        case .halo, .ink, .question: return 7
        case .dawn, .frost, .leaf, .pulse: return 6
        case .bloom, .stars: return 3   // the rare big ones
        }
    }
    /// Probability the moment carries a word. Words stay rare-ish and short.
    var wordChance: Double {
        switch self {
        case .word, .question: return 1
        case .firefly, .leaf, .pulse: return 0
        case .breath, .dawn, .frost: return 0.45
        case .bloom, .stars: return 0.55
        case .edge, .ink: return 0.3
        case .ripple, .halo: return 0.2
        }
    }
    var floating: Bool { self == .firefly || self == .leaf || self == .pulse }
    var title: String {
        switch self {
        case .word: return "A word"
        case .question: return "A question"
        case .breath: return "Breath"
        case .edge: return "Edge glow"
        case .ripple: return "Ripple"
        case .firefly: return "Firefly"
        case .halo: return "Halo"
        case .ink: return "Ink drop"
        case .dawn: return "Dawn"
        case .frost: return "Stillness"
        case .leaf: return "Falling petal"
        case .pulse: return "Heartbeat"
        case .bloom: return "Bloom (rare)"
        case .stars: return "Night sky (rare)"
        }
    }
}

struct Ctx {
    let word: String?
    let pair: (String, String)
    let p: Palette
    let design: Font.Design
    let weight: Font.Weight
    let frame: CGRect          // screen frame (global, bottom-left origin)
    let cursor: CGPoint        // in view coords (top-left origin)
    let start: Date
    let seed: [Double]         // 64 randoms in 0...1

    var size: CGSize { frame.size }
    func t(_ d: Date) -> Double { d.timeIntervalSince(start) }
    func s(_ i: Int) -> Double { seed[i % seed.count] }

    static func make(kind: Kind, frame: CGRect) -> Ctx {
        let m = NSEvent.mouseLocation
        let word: String? = Double.random(in: 0...1) < kind.wordChance ? singleWords.randomElement()! : nil
        return Ctx(word: word,
                   pair: pairs.randomElement()!,
                   p: palettes.randomElement()!,
                   design: [Font.Design.serif, .default, .rounded].randomElement()!,
                   weight: [Font.Weight.ultraLight, .thin, .light].randomElement()!,
                   frame: frame,
                   cursor: CGPoint(x: m.x - frame.minX, y: frame.maxY - m.y),
                   start: Date(),
                   seed: (0..<64).map { _ in Double.random(in: 0...1) })
    }
}

// MARK: - Building blocks

struct WordLabel: View {
    let text: String
    let ctx: Ctx
    var size: CGFloat = 64
    var vignette = true
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: ctx.weight, design: ctx.design))
            .foregroundStyle(.white)
            .tracking(1.5)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.45), radius: 16)
            .fixedSize()
            .background {
                if vignette {
                    Ellipse()
                        .fill(RadialGradient(colors: [.black.opacity(0.42), .clear],
                                             center: .center, startRadius: 0, endRadius: size * 4))
                        .frame(width: size * 10, height: size * 4)
                        .blur(radius: 24)
                }
            }
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .fullScreenUI
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Moments

struct WordMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let k = ease(t / 3)
            WordLabel(text: ctx.word ?? "Here.", ctx: ctx, size: 84)
                .blur(radius: 14 * (1 - k))
                .scaleEffect(0.94 + 0.06 * k + 0.01 * sin(t * 0.6))
                .opacity(k)
                .position(x: ctx.size.width / 2, y: ctx.size.height * 0.46)
        }
    }
}

struct QuestionMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let k1 = ease((t - 0.3) / 2), k2 = ease((t - 2.4) / 2)
            VStack(spacing: 18) {
                WordLabel(text: ctx.pair.0, ctx: ctx, size: 54).opacity(k1).blur(radius: 10 * (1 - k1))
                WordLabel(text: ctx.pair.1, ctx: ctx, size: 54).opacity(k2).blur(radius: 10 * (1 - k2))
                    .offset(y: 8 * (1 - k2))
            }
            .position(x: ctx.size.width / 2, y: ctx.size.height * 0.45)
        }
    }
}

struct BreathMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let cycle = 10.0
            let ph = t.truncatingRemainder(dividingBy: cycle) / cycle
            let s = ph < 0.4 ? ease(ph / 0.4) : 1 - ease((ph - 0.4) / 0.6)
            let d = 160 + 340 * s
            ZStack {
                Color.black.opacity(0.5 * ease(t / 2))
                Circle()
                    .fill(RadialGradient(colors: [ctx.p.a.opacity(0.95), ctx.p.b.opacity(0.35), .clear],
                                         center: .center, startRadius: 0, endRadius: d / 2))
                    .frame(width: d, height: d)
                    .blur(radius: 6)
                    .opacity(ease(t / 1.5))
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 40, vignette: false)
                        .opacity(ease((t - 1.5) / 2))
                        .offset(y: 300)
                }
            }
        }
    }
}

struct EdgeMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let pulse = 0.6 + 0.4 * sin(t * 1.1)
            ZStack {
                Rectangle()
                    .strokeBorder(AngularGradient(colors: [ctx.p.a, ctx.p.b, ctx.p.c, ctx.p.a],
                                                  center: .center, angle: .degrees(t * 14)),
                                  lineWidth: 50)
                    .blur(radius: 34)
                    .opacity(0.9 * pulse * ease(t / 1.5))
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 44)
                        .opacity(ease((t - 1) / 2))
                        .position(x: ctx.size.width / 2, y: ctx.size.height * 0.8)
                }
            }
        }
    }
}

struct RippleMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let ph = (t * 0.22 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                    let d = 30 + ph * 900
                    Circle()
                        .stroke(i % 2 == 0 ? ctx.p.a : ctx.p.b, lineWidth: 3)
                        .opacity((1 - ph) * 0.85 * ease(t / 1.2))
                        .frame(width: d, height: d)
                        .blur(radius: 1.5)
                        .position(ctx.cursor)
                }
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 38)
                        .opacity(ease((t - 1.5) / 2))
                        .position(x: ctx.cursor.x, y: min(ctx.cursor.y + 120, ctx.size.height - 60))
                }
            }
        }
    }
}

struct HaloMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let m = NSEvent.mouseLocation
            let pt = CGPoint(x: m.x - ctx.frame.minX, y: ctx.frame.maxY - m.y)
            let r = 70 + 10 * sin(t * 1.8)
            ZStack {
                Circle()
                    .stroke(AngularGradient(colors: [ctx.p.a, ctx.p.b, ctx.p.c, ctx.p.a],
                                            center: .center, angle: .degrees(t * 40)), lineWidth: 4)
                    .frame(width: r * 2, height: r * 2)
                    .shadow(color: ctx.p.a, radius: 14)
                    .position(pt)
                ForEach(0..<3, id: \.self) { i in
                    let a = t * 0.9 + Double(i) * 2.094
                    Circle().fill(ctx.p.c).frame(width: 7, height: 7)
                        .shadow(color: ctx.p.c, radius: 6)
                        .position(x: pt.x + cos(a) * (r + 18), y: pt.y + sin(a) * (r + 18))
                }
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 30, vignette: false)
                        .position(x: pt.x, y: pt.y + r + 50)
                }
            }
            .opacity(ease(t / 1.2))
        }
    }
}

struct InkMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let c = CGPoint(x: ctx.size.width * (0.25 + 0.5 * ctx.s(0)), y: ctx.size.height * (0.25 + 0.5 * ctx.s(1)))
            let R = 420 * ease(t / 6)
            ZStack {
                Color.black.opacity(0.15 * ease(t / 2))
                ForEach(0..<7, id: \.self) { i in
                    let ox = (ctx.s(2 + i) - 0.5) * R * 0.5, oy = (ctx.s(10 + i) - 0.5) * R * 0.5
                    let d = R * (0.7 + 0.5 * ctx.s(20 + i))
                    Circle().fill(i % 2 == 0 ? ctx.p.a : ctx.p.b)
                        .opacity(0.32)
                        .frame(width: d, height: d)
                        .blur(radius: 22)
                        .position(x: c.x + ox, y: c.y + oy)
                }
                Circle().fill(ctx.p.c.opacity(0.8)).frame(width: 18, height: 18).blur(radius: 3).position(c)
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 44)
                        .opacity(ease((t - 2.5) / 2))
                        .position(c)
                }
            }
        }
    }
}

struct DawnMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let k = ease(t / 5)
            let h = ctx.size.height
            ZStack {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(colors: [ctx.p.a.opacity(0), ctx.p.b.opacity(0.5), ctx.p.a.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: h * 0.75 * k)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.95), ctx.p.c.opacity(0.7), .clear],
                                         center: .center, startRadius: 0, endRadius: 230))
                    .frame(width: 460, height: 460)
                    .position(x: ctx.size.width / 2, y: h + 140 - 420 * k)
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 60)
                        .opacity(ease((t - 3) / 2))
                        .position(x: ctx.size.width / 2, y: h * 0.38)
                }
            }
        }
    }
}

struct FrostMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let b = 0.5 + 0.5 * sin(t * 0.7)
            ZStack {
                VisualEffect().opacity(ease(t / 2.5))
                Circle().fill(ctx.p.a)
                    .frame(width: 14 + 10 * b, height: 14 + 10 * b)
                    .shadow(color: ctx.p.a, radius: 10 + 14 * b)
                    .opacity(ease((t - 1) / 1.5))
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 44, vignette: false)
                        .foregroundStyle(.primary)
                        .opacity(ease((t - 2) / 2))
                        .offset(y: 90)
                }
            }
        }
    }
}

struct BloomMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let w = ctx.size.width, h = ctx.size.height
            let cols = [ctx.p.a, ctx.p.b, ctx.p.c]
            ZStack {
                Color.black.opacity(0.4 * ease(t / 2))
                ForEach(0..<6, id: \.self) { i in
                    let f = 0.15 + 0.1 * Double(i)
                    Circle().fill(cols[i % 3])
                        .frame(width: w * 0.5, height: w * 0.5)
                        .blur(radius: 110)
                        .position(x: w / 2 + w * 0.28 * sin(t * f + ctx.s(i) * 6),
                                  y: h / 2 + h * 0.28 * cos(t * f * 1.3 + ctx.s(i + 8) * 6))
                }
                .opacity(0.85 * ease(t / 3))
                if let word = ctx.word {
                    WordLabel(text: word, ctx: ctx, size: 104, vignette: false)
                        .opacity(ease((t - 2) / 2.5))
                        .scaleEffect(1 + 0.015 * sin(t * 0.8))
                }
            }
        }
    }
}

struct StarsMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            ZStack {
                Color(red: 0.02, green: 0.03, blue: 0.08).opacity(0.9 * ease(t / 3))
                Canvas { g, size in
                    for i in 0..<160 {
                        let x = ctx.s(i) * size.width
                        let y = ctx.s(i * 7 + 3) * size.height
                        let appear = ease((t - 1 - Double(i) * 0.02) / 1.5)
                        let tw = 0.55 + 0.45 * sin(t * (1 + ctx.s(i + 11) * 3) + ctx.s(i + 5) * 9)
                        let r = 0.6 + 1.6 * ctx.s(i + 23)
                        g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(appear * tw)))
                    }
                    // one shooting star
                    let st = (t - 5.5) / 1.1
                    if st > 0 && st < 1 {
                        let x0 = size.width * (0.2 + 0.4 * ctx.s(40)), y0 = size.height * 0.15
                        var p = Path()
                        let hx = x0 + 420 * st, hy = y0 + 180 * st
                        p.move(to: CGPoint(x: hx - 120, y: hy - 52))
                        p.addLine(to: CGPoint(x: hx, y: hy))
                        g.stroke(p, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.9 * (1 - st))]),
                                                         startPoint: CGPoint(x: hx - 120, y: hy - 52),
                                                         endPoint: CGPoint(x: hx, y: hy)), lineWidth: 2)
                    }
                }
                if let w = ctx.word {
                    WordLabel(text: w, ctx: ctx, size: 56, vignette: false)
                        .opacity(ease((t - 3.5) / 2.5))
                }
            }
        }
    }
}

// Floating, small-window moments. They move; click them to catch them.

struct FireflyMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let flick = 0.6 + 0.4 * sin(t * 6 + sin(t * 2.3) * 2)
            let d = 12 + 26 * min(t / 60, 1)   // grows if ignored
            Circle()
                .fill(RadialGradient(colors: [.white, ctx.p.a, ctx.p.a.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: d * 1.6))
                .frame(width: d * 3.2, height: d * 3.2)
                .shadow(color: ctx.p.a, radius: 18 * flick)
                .opacity((0.5 + 0.5 * flick) * ease(t / 1.5))
        }
    }
    static func motion(_ ctx: Ctx, _ t: Double) -> CGPoint {
        let w = ctx.size.width, h = ctx.size.height
        return CGPoint(x: w / 2 + w * 0.34 * sin(0.11 * t + ctx.s(0) * 6) + w * 0.07 * sin(0.37 * t + ctx.s(1) * 6),
                       y: h / 2 + h * 0.30 * sin(0.09 * t + ctx.s(2) * 6) + h * 0.07 * sin(0.41 * t + ctx.s(3) * 6))
    }
}

struct LeafMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            Ellipse()
                .fill(LinearGradient(colors: [ctx.p.a, ctx.p.b], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 16)
                .overlay(Ellipse().stroke(.white.opacity(0.5), lineWidth: 0.6))
                .rotationEffect(.degrees(35 * sin(0.7 * t + 0.6)))
                .rotation3DEffect(.degrees(50 * sin(1.3 * t)), axis: (x: 1, y: 0, z: 0))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .opacity(ease(t / 1))
        }
    }
    static func motion(_ ctx: Ctx, _ t: Double) -> CGPoint {
        let speed = 42.0
        let dur = (ctx.size.height + 200) / speed
        let n = Int(t / dur)
        let tt = t - Double(n) * dur
        let x0 = ctx.size.width * (0.15 + 0.7 * ctx.s(n + 5))
        return CGPoint(x: x0 + 90 * sin(0.7 * t), y: -80 + speed * tt)
    }
}

struct PulseMoment: View {
    let ctx: Ctx
    var body: some View {
        TimelineView(.animation) { tl in
            let t = ctx.t(tl.date)
            let x = t.truncatingRemainder(dividingBy: 1.4)
            let b = max(exp(-pow((x - 0.1) / 0.07, 2)), 0.7 * exp(-pow((x - 0.38) / 0.07, 2)))
            Circle()
                .fill(ctx.p.a)
                .frame(width: 18 + 14 * b, height: 18 + 14 * b)
                .shadow(color: ctx.p.a, radius: 8 + 20 * b)
                .opacity(ease(t / 1.5))
        }
    }
    static func motion(_ ctx: Ctx, _ t: Double) -> CGPoint {
        CGPoint(x: ctx.size.width * (0.1 + 0.8 * ctx.s(0)), y: ctx.size.height * (0.15 + 0.7 * ctx.s(1)))
    }
}

func momentView(_ kind: Kind, _ ctx: Ctx) -> AnyView {
    switch kind {
    case .word: return AnyView(WordMoment(ctx: ctx))
    case .question: return AnyView(QuestionMoment(ctx: ctx))
    case .breath: return AnyView(BreathMoment(ctx: ctx))
    case .edge: return AnyView(EdgeMoment(ctx: ctx))
    case .ripple: return AnyView(RippleMoment(ctx: ctx))
    case .halo: return AnyView(HaloMoment(ctx: ctx))
    case .ink: return AnyView(InkMoment(ctx: ctx))
    case .dawn: return AnyView(DawnMoment(ctx: ctx))
    case .frost: return AnyView(FrostMoment(ctx: ctx))
    case .bloom: return AnyView(BloomMoment(ctx: ctx))
    case .stars: return AnyView(StarsMoment(ctx: ctx))
    case .firefly: return AnyView(FireflyMoment(ctx: ctx))
    case .leaf: return AnyView(LeafMoment(ctx: ctx))
    case .pulse: return AnyView(PulseMoment(ctx: ctx))
    }
}

func momentMotion(_ kind: Kind) -> ((Ctx, Double) -> CGPoint)? {
    switch kind {
    case .firefly: return FireflyMoment.motion
    case .leaf: return LeafMoment.motion
    case .pulse: return PulseMoment.motion
    default: return nil
    }
}
