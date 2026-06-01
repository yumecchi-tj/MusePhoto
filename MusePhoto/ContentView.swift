//
//  ContentView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import Observation

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

/// ホーム画面で使う表示データを管理します。
@Observable
final class HomeViewModel {
    var museumTitle = "My Museum"
    var tickets: [ExhibitionTicket] = []

    /// 新しい写真展チケットを先頭に追加します。
    func addTicket(
        title: String,
        comment: String,
        photoCount: Int,
        coverImage: UIImage?,
        photos: [ExhibitionPhoto],
        backgroundImageName: String
    ) {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeTitle.isEmpty else { return }
        guard photoCount > 0 else { return }

        let safeComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let ticket = ExhibitionTicket(
            title: safeTitle,
            comment: safeComment,
            photoCount: photoCount,
            coverImage: coverImage,
            photos: photos,
            backgroundImageName: backgroundImageName,
            publishedAt: Date()
        )
        tickets.insert(ticket, at: 0)
    }
}

struct ContentView: View {
    @State private var viewModel = HomeViewModel()
    @State private var isShowingAddExhibitionView = false
    @State private var selectedTicket: ExhibitionTicket?
    @State private var isShowingTicketPreview = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.90, green: 0.84, blue: 0.81)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .center) {
                            Text(viewModel.museumTitle)
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .foregroundStyle(Color(red: 0.30, green: 0.15, blue: 0.10))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        VStack(spacing: 18) {
                            ForEach(viewModel.tickets) { ticket in
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
                        isShowingAddExhibitionView = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                    .tint(.black)
                    .accessibilityLabel("展示を追加")
                }
            }
            .navigationDestination(isPresented: $isShowingAddExhibitionView) {
                AddExhibitionView { title, comment, photoCount, coverImage, photos, backgroundImageName in
                    viewModel.addTicket(
                        title: title,
                        comment: comment,
                        photoCount: photoCount,
                        coverImage: coverImage,
                        photos: photos,
                        backgroundImageName: backgroundImageName
                    )
                    isShowingAddExhibitionView = false
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
                .padding(.bottom, 34)
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

    var body: some View {
        HStack(spacing: 0) {
            TicketMainArea(ticket: ticket)

            TicketStubArea()
        }
        .frame(height: 190)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay {
            TicketPerforationEdge()
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}

/// チケットの左側メイン情報を表示します。
struct TicketMainArea: View {
    let ticket: ExhibitionTicket

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let coverImage = ticket.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.72), Color.black.opacity(0.25), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.title)
                    .font(.system(size: 37, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("\(ticket.photoCount)枚の写真")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)

                if !ticket.comment.isEmpty {
                    Text(ticket.comment)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 10)
        .padding(.vertical, 10)
        .padding(.trailing, 10)
        .background(.white)
    }
}

/// チケットの右側スタブを表示します。
struct TicketStubArea: View {
    var body: some View {
        ZStack {
            Color.white

            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 2)
                .overlay(
                    VStack(spacing: 5) {
                        ForEach(0..<18, id: \.self) { _ in
                            Rectangle()
                                .fill(.black.opacity(0.4))
                                .frame(width: 2, height: 4)
                        }
                    }
                )
        }
        .frame(width: 68)
    }
}

/// チケット左右の切り込みと中央ミシン線を描画します。
struct TicketPerforationEdge: View {
    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height

            ZStack {
                HStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: -9)
                    Spacer()
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: 9)
                }
                .position(x: proxy.size.width / 2, y: h * 0.25)

                HStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: -9)
                    Spacer()
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: 9)
                }
                .position(x: proxy.size.width / 2, y: h * 0.50)

                HStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: -9)
                    Spacer()
                    Circle()
                        .fill(Color(red: 0.90, green: 0.84, blue: 0.81))
                        .frame(width: 18, height: 18)
                        .offset(x: 9)
                }
                .position(x: proxy.size.width / 2, y: h * 0.75)

                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 2, height: h - 20)
                    .position(x: proxy.size.width - 68, y: h / 2)
            }
        }
    }
}

#Preview {
    ContentView()
}
