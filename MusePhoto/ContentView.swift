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
    @State private var isShowingTicketPreview = false

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
                                    isShowingTicketPreview = true
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
            .navigationDestination(isPresented: $isShowingTicketPreview) {
                if let ticket = selectedTicket {
                    ExhibitionPreviewView(ticket: ticket) {
                        isShowingTicketPreview = false
                        selectedTicket = nil
                    }
                } else {
                    EmptyView()
                }
            }
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

/// チケットタップ後に表示する展示プレビュー画面です。
struct ExhibitionPreviewView: View {
    let ticket: ExhibitionTicket
    let onExitToHome: () -> Void

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
