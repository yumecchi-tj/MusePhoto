//
//  GalleyView.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI

/// 展示写真を手動スライドで鑑賞する画面です。
struct GalleyView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: ExhibitionTicket

    @State private var currentIndex = 0
    @State private var blackoutOpacity = 0.0
    @State private var isTransitioning = false
    @State private var isShowingEnding = false

    var body: some View {
        ZStack {
            Image(ticket.backgroundImageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 30)

                if isShowingEnding {
                    endingView
                } else if ticket.photos.indices.contains(currentIndex) {
                    FramedSlidePhotoView(photo: ticket.photos[currentIndex])
                }

                Text("\(currentIndex + 1) / \(ticket.photos.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(isShowingEnding ? 0 : 1)

                Spacer(minLength: 70)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        guard !isTransitioning else { return }
                        if value.translation.width < -45 {
                            moveToNextPhoto()
                        } else if value.translation.width > 45 {
                            moveToPreviousPhoto()
                        }
                    }
            )

            Color.black
                .opacity(blackoutOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .navigationTitle(ticket.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 右方向スワイプで前の写真へ移動します。
    private func moveToPreviousPhoto() {
        guard currentIndex > 0 else { return }
        transition(to: currentIndex - 1)
    }

    /// 左方向スワイプで次の写真へ移動します。
    private func moveToNextPhoto() {
        guard currentIndex < ticket.photos.count - 1 else {
            showEndingScene()
            return
        }
        transition(to: currentIndex + 1)
    }

    /// 暗転を挟んで写真を切り替えます。
    private func transition(to nextIndex: Int) {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.35)) {
            blackoutOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            currentIndex = nextIndex
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.2)) {
                blackoutOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                isTransitioning = false
            }
        }
    }

    /// 最終写真の次で、展示終了メッセージに切り替えます。
    private func showEndingScene() {
        isTransitioning = true
        withAnimation(.easeInOut(duration: 0.35)) {
            blackoutOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            isShowingEnding = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.25)) {
                blackoutOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                isTransitioning = false
            }
        }
    }

    /// 展示終了後に表示する案内UIです。
    private var endingView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Text("この展示は終了しました")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("新たな作品との出会いをお楽しみください")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                isShowingEnding = false
                currentIndex = 0
            } label: {
                Text("もう一度鑑賞する")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.24))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("次の展示を探す")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 写真サイズにぴったり合わせて白い縁をつける表示です。
struct FramedSlidePhotoView: View {
    let photo: UIImage

    private let maxHeight: CGFloat = 470
    private let frameLineWidth: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let imageAspect = photo.size.width / max(photo.size.height, 1)
            let fittedWidth = min(availableWidth, maxHeight * imageAspect)
            let fittedHeight = fittedWidth / imageAspect

            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: fittedWidth, height: fittedHeight)
                .clipped()
                .overlay {
                    Rectangle()
                        .stroke(Color.white, lineWidth: frameLineWidth)
                }
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight)
    }
}

#Preview {
    NavigationStack {
        GalleyView(
            ticket: ExhibitionTicket(
                title: "海辺の休日",
                comment: "サンプル",
                photoCount: 2,
                coverImage: nil,
                photos: [],
                backgroundImageName: "gallery_background_white",
                publishedAt: Date()
            )
        )
    }
}
