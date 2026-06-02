//
//  ContentView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import SwiftData

/// 展示に含まれる1枚分の写真情報です。
struct ExhibitionPhoto {
    let image: UIImage
    let title: String
    let cameraInfo: CameraInfo
}

/// ホーム画面で表示する写真展チケットのデータです。
struct ExhibitionTicket: Identifiable {
    let id = UUID()
    let title: String
    let comment: String
    let photoCount: Int
    let coverImage: UIImage?
    let photos: [ExhibitionPhoto]
    let backgroundImageName: String
    let publishedAt: Date
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExhibitionRecord.publishedAt, order: .reverse) private var records: [ExhibitionRecord]

    @State private var isShowingAddExhibitionView = false
    @State private var selectedTicket: ExhibitionTicket?
    @State private var showTicketOverlay = false
    @State private var animationPhase = 0
    @State private var seamShift: CGFloat = 0
    @State private var ticketVisible = true
    @State private var showEntranceOverlay = false
    @State private var entrancePhase = 0
    @State private var entranceRevealProgress: CGFloat = 0
    @State private var shouldStartDetailWhiteReveal = false
    @State private var showExhibitionDetail = false

    private let museumTitle = "My Museum"

    var body: some View {
        NavigationStack {
            ZStack {
                Image("home_picture")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .center) {
                            Text(museumTitle)
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        VStack(spacing: 18) {
                            ForEach(ticketsFromRecords()) { ticket in
                                Button {
                                    selectedTicket = ticket
                                    ticketVisible = true
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                                        showTicketOverlay = true
                                    }
                                } label: {
                                    TicketView(ticket: ticket)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 28)
                }
                .blur(radius: showTicketOverlay ? 7 : 0)
                .animation(.easeInOut(duration: 0.25), value: showTicketOverlay)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isShowingAddExhibitionView = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                    .tint(.black)
                    .accessibilityLabel("展示を追加")
                }
            }
            .overlay {
                if isShowingAddExhibitionView {
                    NavigationStack {
                        AddExhibitionView { title, comment, photoCount, coverImage, photos, backgroundImageName in
                            saveTicket(
                                title: title,
                                comment: comment,
                                photoCount: photoCount,
                                coverImage: coverImage,
                                photos: photos,
                                backgroundImageName: backgroundImageName
                            )
                            withAnimation(.easeInOut(duration: 0.35)) {
                                isShowingAddExhibitionView = false
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        isShowingAddExhibitionView = false
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .overlay {
                if showTicketOverlay, let selectedTicket {
                    TicketUseOverlay(
                        ticket: selectedTicket,
                        animationPhase: $animationPhase,
                        seamShift: seamShift,
                        ticketVisible: ticketVisible,
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showTicketOverlay = false
                            }
                            animationPhase = 0
                            seamShift = 0
                            ticketVisible = true
                        },
                        onUse: {
                            playTicketCutAnimation()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(3)
                }
            }
            .overlay {
                if showExhibitionDetail, let activeTicket = selectedTicket {
                    ExhibitionPreviewView(ticket: activeTicket, startWithWhiteReveal: shouldStartDetailWhiteReveal) {
                        showExhibitionDetail = false
                        selectedTicket = nil
                    }
                    .zIndex(3)
                    .transition(.identity)
                }
            }
            .overlay {
                if showEntranceOverlay, let activeTicket = selectedTicket {
                    ExhibitionEntranceOverlay(
                        ticket: activeTicket,
                        phase: entrancePhase,
                        revealProgress: entranceRevealProgress
                    )
                    .zIndex(4)
                    .allowsHitTesting(true)
                }
            }
        }
    }

    /// チケットを破る演出を順番に再生し、完了したら展示説明へ進みます。
    private func playTicketCutAnimation() {
        // phase 1: 全体が少し下に沈み込む
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.08)) {
            animationPhase = 1
        }
        
        // phase 2: ミシン目へ力を集める「溜め」
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = 2
            }
            withAnimation(.easeInOut(duration: 0.09)) {
                seamShift = -4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.easeInOut(duration: 0.09)) {
                    seamShift = 4
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.06)) {
                    seamShift = 0
                }
            }
        }
        
        // phase 3: 破れ始め（まだ小さく開く）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.43) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84, blendDuration: 0.12)) {
                animationPhase = 3
            }
        }
        
        // phase 4: 弧を描きながら左右へ開く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.15)) {
                animationPhase = 4
            }
        }
        
        // phase 5: フェードアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.03) {
            withAnimation(.easeOut(duration: 0.3)) {
                animationPhase = 5
            }
        }
        
        // 破れ演出が終わったらチケット本体を完全に消す
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            ticketVisible = false
        }

        // アニメーション完了後に展示説明画面へ遷移
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.34) {
            // 暗転開始時点でチケット関連UIを確実に隠します
            showTicketOverlay = false
            seamShift = 0
            playExhibitionEntranceAnimation()
        }
    }
    
    /// チケット使用後の「展示室へ入室」演出を再生します。
    private func playExhibitionEntranceAnimation() {
        entrancePhase = 0
        entranceRevealProgress = 0
        shouldStartDetailWhiteReveal = false
        showEntranceOverlay = true
        
        // phase 1: 暗転（約1秒）
        withAnimation(.easeInOut(duration: 1.0)) {
            entrancePhase = 1
        }
        
        // phase 2: タイトルをゆっくり表示（約1秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            withAnimation(.easeInOut(duration: 1.0)) {
                entrancePhase = 2
            }
        }
        
        // phase 3: タイトルをしっかり読めるだけ見せた後、中央の白い光を拡張開始（約1.8秒）
        // 1.05 + 1.0 でタイトル出現完了。その後さらに約2.25秒保持。
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeInOut(duration: 1.8)) {
                entrancePhase = 3
                entranceRevealProgress = 1
            }
        }
        
        // 白が最大になった瞬間に展示説明画面へ切り替え（白の下で表示を差し替える）
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.1) {
            shouldStartDetailWhiteReveal = true
            showExhibitionDetail = true
            withAnimation(.linear(duration: 0.12)) {
                entrancePhase = 4
            }
        }
        
        // phase 5: 白がゆっくり晴れていく（約1秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.25) {
            withAnimation(.easeOut(duration: 1.0)) {
                entrancePhase = 5
            }
        }
        
        // 完了後にオーバーレイを閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.35) {
            showEntranceOverlay = false
            entrancePhase = 0
            entranceRevealProgress = 0
            animationPhase = 0
            ticketVisible = true
            shouldStartDetailWhiteReveal = false
        }
    }

    /// SwiftDataに展示情報を保存します。
    private func saveTicket(
        title: String,
        comment: String,
        photoCount: Int,
        coverImage: UIImage?,
        photos: [ExhibitionPhoto],
        backgroundImageName: String
    ) {
        let storedPhotos = photos.compactMap { photo -> StoredPhoto? in
            guard let imageData = photo.image.jpegData(compressionQuality: 0.95) else { return nil }
            return StoredPhoto(imageData: imageData, title: photo.title, cameraInfo: photo.cameraInfo)
        }

        let encoder = JSONEncoder()
        guard let photosData = try? encoder.encode(storedPhotos) else { return }

        let record = ExhibitionRecord(
            title: title,
            comment: comment,
            photoCount: photoCount,
            backgroundImageName: backgroundImageName,
            publishedAt: Date(),
            coverImageData: coverImage?.jpegData(compressionQuality: 0.95),
            photosData: photosData
        )
        modelContext.insert(record)
    }

    /// SwiftData保存データを画面表示用データへ変換します。
    private func ticketsFromRecords() -> [ExhibitionTicket] {
        let decoder = JSONDecoder()

        return records.map { record in
            let storedPhotos = (try? decoder.decode([StoredPhoto].self, from: record.photosData)) ?? []
            let photos = storedPhotos.compactMap { stored -> ExhibitionPhoto? in
                guard let uiImage = UIImage(data: stored.imageData) else { return nil }
                return ExhibitionPhoto(image: uiImage, title: stored.title, cameraInfo: stored.cameraInfo)
            }

            return ExhibitionTicket(
                title: record.title,
                comment: record.comment,
                photoCount: record.photoCount,
                coverImage: record.coverImageData.flatMap { UIImage(data: $0) },
                photos: photos,
                backgroundImageName: record.backgroundImageName,
                publishedAt: record.publishedAt
            )
        }
    }
}

/// チケットを使う前の確認モーダル（中央表示）です。
struct TicketUseOverlay: View {
    let ticket: ExhibitionTicket
    @Binding var animationPhase: Int
    let seamShift: CGFloat
    let ticketVisible: Bool
    let onCancel: () -> Void
    let onUse: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                if ticketVisible {
                    TicketCutAnimationView(
                        ticket: ticket,
                        animationPhase: animationPhase,
                        seamShift: seamShift
                    )
                        .frame(height: 170)
                        .scaleEffect(overlayScale(phase: animationPhase))
                        .offset(y: overlayOffsetY(phase: animationPhase))
                        .opacity(animationPhase == 5 ? 0.0 : 1.0)
                }

                VStack(spacing: 12) {
                    Button {
                        onUse()
                    } label: {
                        Text("チケットを使う")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(.white)
                            .background(Color.black.opacity(0.82))
                            .clipShape(Capsule())
                    }
                    .disabled(animationPhase > 0)

                    Button {
                        onCancel()
                    } label: {
                        Text("キャンセル")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white.opacity(0.95))
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .disabled(animationPhase > 0)
                }
                .padding(.horizontal, 26)
                .opacity(ticketVisible ? 1 : 0)
            }
            .padding(.horizontal, 20)
        }
    }
    
    /// フェーズごとの全体スケールです（沈み込みと溜め）。
    private func overlayScale(phase: Int) -> CGFloat {
        switch phase {
        case 1: return 0.975
        case 2: return 0.985
        case 5: return 0.95
        default: return 1.0
        }
    }
    
    /// フェーズごとの全体Y移動です（最初に沈み込む）。
    private func overlayOffsetY(phase: Int) -> CGFloat {
        switch phase {
        case 1: return 14
        case 2: return 9
        case 5: return 18
        default: return 0
        }
    }
}

/// 展示室へ入室するための暗転・タイトル・光の演出オーバーレイです。
struct ExhibitionEntranceOverlay: View {
    let ticket: ExhibitionTicket
    let phase: Int
    let revealProgress: CGFloat
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(darkOverlayOpacity(phase: phase))
                .ignoresSafeArea()
            
            // 中央の柔らかい光。phase 3 で円形に広がる
            RadialGradient(
                colors: [
                    Color.white.opacity(0.72),
                    Color.white.opacity(0.24),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 820 * revealProgress
            )
            .blendMode(.screen)
            .ignoresSafeArea()
            .opacity(phase >= 3 ? 1 : 0)
            
            // 全体を白で包む層。phase4で最大化し、phase5で晴れる
            Color.white
                .opacity(whiteWrapOpacity(phase: phase))
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("Exhibition \(String(format: "%02d", max(ticket.photoCount, 1)))")
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(.white.opacity(0.84))
                
                Text(ticket.title)
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                Text(themeText)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .opacity(phase >= 2 ? 1 : 0)
            .scaleEffect(phase >= 2 ? 1 : 0.95)
            .animation(.easeInOut(duration: 1.0), value: phase)
        }
    }
    
    /// 展示テーマの補助テキストを返します。
    private var themeText: String {
        if !ticket.comment.isEmpty {
            return ticket.comment
        }
        return "\(ticket.photoCount)作品の展示"
    }
    
    /// フェーズごとの暗転濃度です。
    private func darkOverlayOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 0: return 0
        case 1: return 1
        case 2: return 1
        case 3: return 0.96
        case 4: return 0.0
        case 5: return 0.0
        default: return 0
        }
    }
    
    /// 画面全体を白く包む層の不透明度です。
    private func whiteWrapOpacity(phase: Int) -> CGFloat {
        switch phase {
        case 0, 1, 2: return 0
        case 3: return min(0.92, 0.15 + revealProgress * 0.77)
        case 4: return 1
        case 5: return 0
        default: return 0
        }
    }
}

/// チケットが左右に破れる見た目を作るビューです。
struct TicketCutAnimationView: View {
    let ticket: ExhibitionTicket
    let animationPhase: Int
    let seamShift: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let splitX = width * 0.68
            let leftState = leftTransform(phase: animationPhase)
            let rightState = rightTransform(phase: animationPhase)

            ZStack {
                // 左側チケット片
                TicketView(ticket: ticket)
                    .frame(width: width, height: proxy.size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: splitX)
                    }
                    .offset(x: leftState.x, y: leftState.y)
                    .rotationEffect(.degrees(leftState.zRotation))
                    .rotation3DEffect(.degrees(leftState.x3D), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(leftState.y3D), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(leftState.scale)
                    .opacity(leftState.opacity)

                // 右側チケット片
                TicketView(ticket: ticket)
                    .frame(width: width, height: proxy.size.height)
                    .mask(alignment: .trailing) {
                        Rectangle().frame(width: width - splitX)
                    }
                    .offset(x: rightState.x, y: rightState.y)
                    .rotationEffect(.degrees(rightState.zRotation))
                    .rotation3DEffect(.degrees(rightState.x3D), axis: (x: 1, y: 0, z: 0))
                    .rotation3DEffect(.degrees(rightState.y3D), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(rightState.scale)
                    .opacity(rightState.opacity)

                // 破れ目に出る紙くずの粒
                TicketPaperParticleView(isActive: animationPhase >= 2, splitX: splitX + seamShift)

                // 中央のミシン目を少し揺らす表示（phase 1のみ）
                if animationPhase == 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 1.5, height: proxy.size.height * 0.76)
                        .overlay {
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                                .foregroundStyle(Color.black.opacity(0.35))
                        }
                        .offset(x: seamShift)
                        .position(x: splitX, y: proxy.size.height * 0.5)
                }
                if animationPhase == 2 {
                    Rectangle()
                        .fill(Color.white.opacity(0.68))
                        .frame(width: 2, height: proxy.size.height * 0.78)
                        .offset(x: seamShift)
                        .position(x: splitX, y: proxy.size.height * 0.5)
                        .blur(radius: 0.25)
                }
            }
        }
    }

    /// フェーズごとの左片の動きです。
    private func leftTransform(phase: Int) -> TicketPieceTransform {
        switch phase {
        case 1:
            return .init(x: -2, y: 2, zRotation: -1, x3D: 1, y3D: -2, scale: 0.988, opacity: 1)
        case 2:
            return .init(x: -6, y: -1, zRotation: -2, x3D: 2, y3D: -4, scale: 0.99, opacity: 1)
        case 3:
            return .init(x: -42, y: -10, zRotation: -4, x3D: 5, y3D: -9, scale: 0.985, opacity: 1)
        case 4:
            return .init(x: -146, y: 24, zRotation: -14, x3D: 11, y3D: -22, scale: 0.955, opacity: 0.96)
        case 5:
            return .init(x: -156, y: 28, zRotation: -16, x3D: 13, y3D: -24, scale: 0.92, opacity: 0.0)
        default:
            return .init(x: 0, y: 0, zRotation: 0, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        }
    }

    /// フェーズごとの右片の動きです。
    private func rightTransform(phase: Int) -> TicketPieceTransform {
        switch phase {
        case 1:
            return .init(x: 2, y: 2, zRotation: 1, x3D: -1, y3D: 2, scale: 0.988, opacity: 1)
        case 2:
            return .init(x: 6, y: -1, zRotation: 2, x3D: -2, y3D: 4, scale: 0.99, opacity: 1)
        case 3:
            return .init(x: 42, y: -10, zRotation: 4, x3D: -5, y3D: 9, scale: 0.985, opacity: 1)
        case 4:
            return .init(x: 146, y: 24, zRotation: 14, x3D: -11, y3D: 22, scale: 0.955, opacity: 0.96)
        case 5:
            return .init(x: 156, y: 28, zRotation: 16, x3D: -13, y3D: 24, scale: 0.92, opacity: 0.0)
        default:
            return .init(x: 0, y: 0, zRotation: 0, x3D: 0, y3D: 0, scale: 1, opacity: 1)
        }
    }
}

/// チケット片の位置・角度・透明度をまとめるための構造体です。
struct TicketPieceTransform {
    let x: CGFloat
    let y: CGFloat
    let zRotation: CGFloat
    let x3D: CGFloat
    let y3D: CGFloat
    let scale: CGFloat
    let opacity: CGFloat
}

/// 破れた瞬間に紙くずの粒が散る演出です。
struct TicketPaperParticleView: View {
    let isActive: Bool
    let splitX: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<18, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2 + CGFloat(index % 3), height: 2 + CGFloat(index % 3))
                        .offset(
                            x: isActive ? particleX(index) : 0,
                            y: isActive ? particleY(index) : 0
                        )
                        .opacity(isActive ? 0.0 : 0.95)
                        .scaleEffect(isActive ? 0.5 : 1.0)
                        .position(x: splitX, y: proxy.size.height * 0.52)
                        .animation(
                            .easeOut(duration: 0.55).delay(Double(index) * 0.008),
                            value: isActive
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func particleX(_ i: Int) -> CGFloat {
        let sign: CGFloat = i % 2 == 0 ? -1 : 1
        return sign * (12 + CGFloat((i * 7) % 24))
    }

    private func particleY(_ i: Int) -> CGFloat {
        CGFloat(-18 + (i % 9) * 4)
    }
}

/// チケットタップ後に表示する展示プレビュー画面です。
struct ExhibitionPreviewView: View {
    let ticket: ExhibitionTicket
    let startWithWhiteReveal: Bool
    let onExitToHome: () -> Void
    @State private var detailRevealOpacity: CGFloat = 1

    var body: some View {
        ZStack {
            Image(ticket.backgroundImageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.28), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(ticket.title)
                        .font(.system(size: 45, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(ticket.photoCount)枚の写真")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Text("公開中   \(publishedDateText(ticket.publishedAt)) -")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    if !ticket.comment.isEmpty {
                        Text(ticket.comment)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineSpacing(5)
                    }

                    NavigationLink {
                        GalleyView(ticket: ticket, onExitToHome: onExitToHome)
                    } label: {
                        Text("展示を見る")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.24))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, 54)
            }
            
            if detailRevealOpacity > 0.001 {
                Color.white
                    .ignoresSafeArea()
                    .opacity(detailRevealOpacity)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                onExitToHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding(.leading, 20)
            .padding(.top, 70)
        }
        .onAppear {
            if startWithWhiteReveal {
                detailRevealOpacity = 1
                withAnimation(.easeOut(duration: 1.0)) {
                    detailRevealOpacity = 0
                }
            } else {
                detailRevealOpacity = 0
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    /// 公開日を表示用の文字列に変換します。
    private func publishedDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

/// 写真展のチケット見た目を表示します。
struct TicketView: View {
    let ticket: ExhibitionTicket
    private let ticketPaperColor = Color(red: 0.95, green: 0.94, blue: 0.90)
    private let ticketInkColor = Color(red: 0.27, green: 0.25, blue: 0.21)

    var body: some View {
        GeometryReader { proxy in
            let splitX = proxy.size.width * 0.68

            HStack(spacing: 0) {
                TicketMainArea(ticket: ticket, ticketInkColor: ticketInkColor, ticketPaperColor: ticketPaperColor)
                    .frame(width: splitX)
                TicketStubArea(ticketInkColor: ticketInkColor, ticketPaperColor: ticketPaperColor)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(ticketPaperColor)
            .overlay {
                TicketPaperTexture()
                    .clipShape(TicketShape(cornerRadius: 10, sideNotchRadius: 16))
                    .allowsHitTesting(false)
            }
            .clipShape(TicketShape(cornerRadius: 10, sideNotchRadius: 16))
            .overlay(
                TicketShape(cornerRadius: 10, sideNotchRadius: 16)
                    .stroke(ticketInkColor.opacity(0.14), lineWidth: 1)
            )
            .overlay {
                TicketPerforationCutout(xPosition: splitX)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
        .frame(height: 130)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

/// チケットの左側メイン情報を表示します。
struct TicketMainArea: View {
    let ticket: ExhibitionTicket
    let ticketInkColor: Color
    let ticketPaperColor: Color

    var body: some View {
        HStack(spacing: 10) {
            TicketThumbnailView(ticket: ticket)
                .padding(.leading, 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(ticket.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ticketInkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(publishedDateText(ticket.publishedAt))-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ticketInkColor.opacity(0.8))

                Text("全\(ticket.photoCount)作品")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ticketInkColor.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(ticketPaperColor)
    }

    private func publishedDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

/// チケット内の正方形サムネイルを表示します。
struct TicketThumbnailView: View {
    let ticket: ExhibitionTicket

    var body: some View {
        let image = ticket.photos.first?.image ?? ticket.coverImage

        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.28))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .frame(width: 96, height: 96)
        .clipped()
    }
}

/// チケットの右側スタブを表示します。
struct TicketStubArea: View {
    let ticketInkColor: Color
    let ticketPaperColor: Color

    var body: some View {
        VStack {
            Spacer()
            Text("入場する")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ticketInkColor.opacity(0.85))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ticketPaperColor)
    }
}

/// 右側半円ノッチ付きの再利用可能なチケット形状です。
struct TicketShape: Shape {
    var cornerRadius: CGFloat = 10
    var sideNotchRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) * 0.2)
        let notchR = min(sideNotchRadius, rect.height * 0.4)
        let left = rect.minX
        let right = rect.maxX
        let top = rect.minY
        let bottom = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: left + r, y: top))
        path.addLine(to: CGPoint(x: right - r, y: top))
        path.addArc(
            center: CGPoint(x: right - r, y: top + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: right, y: rect.midY - notchR))
        path.addArc(
            center: CGPoint(x: right, y: rect.midY),
            radius: notchR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: true
        )
        path.addLine(to: CGPoint(x: right, y: bottom - r))
        path.addArc(
            center: CGPoint(x: right - r, y: bottom - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left + r, y: bottom))

        path.addArc(
            center: CGPoint(x: left + r, y: bottom - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left, y: top + r))
        path.addArc(
            center: CGPoint(x: left + r, y: top + r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// チケット中央の上下半円と点線をくり抜くための描画Viewです。
struct TicketPerforationCutout: View {
    let xPosition: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            
            ZStack {
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: 0)
                
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                    .position(x: xPosition, y: h)
                
                VStack(spacing: 4) {
                    ForEach(0..<14, id: \.self) { _ in
                        Rectangle()
                            .fill(.black)
                            .frame(width: 2, height: 4)
                    }
                }
                .position(x: xPosition, y: h / 2)
            }
        }
    }
}

/// チケットに薄い紙の質感を重ねるためのビューです。
struct TicketPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<360 {
                let x = pseudoRandom(i * 17 + 3) * size.width
                let y = pseudoRandom(i * 31 + 11) * size.height
                let w = 0.8 + pseudoRandom(i * 13 + 7) * 1.8
                let h = 0.8 + pseudoRandom(i * 19 + 5) * 1.8
                let alpha = 0.025 + pseudoRandom(i * 23 + 2) * 0.055
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                    with: .color(.black.opacity(alpha))
                )
            }
        }
        .blendMode(.multiply)
        .opacity(0.82)
    }
    
    private func pseudoRandom(_ seed: Int) -> CGFloat {
        let x = sin(Double(seed) * 12.9898 + 78.233) * 43758.5453
        return CGFloat(x - floor(x))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ExhibitionRecord.self], inMemory: true)
}
