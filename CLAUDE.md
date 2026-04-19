# YTDL Manager

macOS uygulaması. SwiftUI ile yazılıyor.
yt-dlp için native Mac GUI'si.

## Proje Yapısı
- `YTDL Manager/ContentView.swift` — ana ekran
- `YTDL Manager/YTDL_ManagerApp.swift` — uygulama giriş noktası

## Kurallar
- Swift ve SwiftUI kullan, UIKit kullanma
- macOS 13+ hedef al
- yt-dlp'yi Process() ile çalıştır
- Ayarları UserDefaults'a kaydet
- Türkçe yorum satırı yazma, İngilizce yaz
- Her view ayrı dosyada olsun

## Özellikler
- Çoklu URL ekleme
- Format seçimi: MP4, MKV, MP3, AAC
- Kalite seçimi: Best, 1080p, 720p, 480p
- İndirme klasörü seçimi
- İlerleme göstergesi
- İndirme geçmişi

## Git Kuralları
- Her anlamlı değişiklikten sonra commit at
- Commit mesajları Conventional Commits formatında olsun:
  - feat: yeni özellik
  - fix: hata düzeltme
  - refactor: kod düzenleme
  - chore: genel bakım
- Her commit'ten sonra git push ile remote'a gönder
- Commit atmadan önce git status ile değişiklikleri kontrol et
